/**
 * DietAI I2S 麦克风驱动 — INMP441
 *
 * 功能:
 *   - I2S RX 模式 (16kHz, 16bit, 单声道)
 *   - PCM 录音缓冲 (PSRAM, 最大 15 秒 ≈ 480KB)
 *   - WAV 封装 (44 字节头 + PCM 数据)
 *   - HTTP multipart 上传 → /api/voice/recognize
 *   - RMS 静音检测 (连续 3s 低于阈值 → 自动停止)
 *
 * 引脚 (括号内为模块实物丝印):
 *   INMP441 VDD (VOD) → 3.3V
 *   INMP441 GND       → GND
 *   INMP441 L/R (UR)  → GND (左声道)
 *   INMP441 BCLK(SCK) → GPIO 40
 *   INMP441 WS        → GPIO 41
 *   INMP441 DOUT(SD)  → GPIO 47
 */

#pragma once

#include <Arduino.h>
#include <driver/i2s.h>
#include <HTTPClient.h>
#include <WiFiClient.h>

// ===== I2S 引脚 (与 MAX98357 功放共享 BCLK/WS) =====
#define I2S_MIC_BCLK  GPIO_NUM_40
#define I2S_MIC_WS    GPIO_NUM_41
#define I2S_MIC_DOUT  GPIO_NUM_47

// ===== 录音参数 =====
#define MIC_SAMPLE_RATE     16000
#define MIC_BITS_PER_SAMPLE 16
#define MIC_I2S_CHANNELS    2        // I2S 双声道采集
#define MIC_OUT_CHANNELS    1        // 输出 WAV 为单声道 (提取有效声道)
#define MIC_MAX_SEC         10       // 双声道缓冲 10s
// 最大 PCM 字节数: 16000 * 2ch * 2byte * 10s = 640,000
#define MIC_BUF_BYTES     (MIC_SAMPLE_RATE * MIC_I2S_CHANNELS * (MIC_BITS_PER_SAMPLE / 8) * MIC_MAX_SEC)
#define MIC_BUF_SAMPLES   (MIC_BUF_BYTES / (MIC_BITS_PER_SAMPLE / 8))

// ===== 静音检测 =====
#define MIC_RMS_THRESHOLD  400    // RMS 阈值 (~0-32767, 经验值)
#define MIC_SILENCE_MS     3000   // 连续静音 3 秒自动停止
#define MIC_SILENCE_GUARD  1000   // 前 1 秒不检测静音 (避免初始噪声)

// ===== 全局录音状态 =====
static int16_t* mic_buf     = nullptr;  // PSRAM 录音缓冲 (立体声交错)
static size_t   mic_samples = 0;        // 已录制样本数 (立体声对)
static bool     mic_running = false;
static unsigned long mic_last_sound = 0; // 最后检测到声音的时间戳
static int      mic_active_ch = 0;       // 有效声道偏移: 0=Right, 1=Left (自动检测)
static bool     mic_ch_detected = false; // 是否已完成声道检测

// ===== 初始化 I2S 麦克风 =====
static bool i2s_mic_init() {
    // --- I2S 配置 ---
    i2s_config_t cfg;
    memset(&cfg, 0, sizeof(cfg));
    cfg.mode                 = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX);
    cfg.sample_rate          = MIC_SAMPLE_RATE;
    cfg.bits_per_sample      = I2S_BITS_PER_SAMPLE_16BIT;
    cfg.channel_format       = I2S_CHANNEL_FMT_RIGHT_LEFT; // 双声道 → 软件提取有效声道
    cfg.communication_format = I2S_COMM_FORMAT_STAND_I2S;
    cfg.intr_alloc_flags     = ESP_INTR_FLAG_LEVEL1;
    cfg.dma_buf_count        = 4;
    cfg.dma_buf_len          = 512;   // 512×16bit = 1KB per DMA block
    cfg.use_apll             = false;

    esp_err_t err = i2s_driver_install(I2S_NUM_0, &cfg, 0, NULL);
    if (err != ESP_OK) {
        Serial.printf("[MIC] driver_install FAIL: %d\n", err);
        return false;
    }

    // --- 引脚配置 ---
    i2s_pin_config_t pin;
    memset(&pin, 0, sizeof(pin));
    pin.bck_io_num     = I2S_MIC_BCLK;
    pin.ws_io_num      = I2S_MIC_WS;
    pin.data_out_num   = I2S_PIN_NO_CHANGE;
    pin.data_in_num    = I2S_MIC_DOUT;

    err = i2s_set_pin(I2S_NUM_0, &pin);
    if (err != ESP_OK) {
        Serial.printf("[MIC] set_pin FAIL: %d\n", err);
        return false;
    }

    // --- 分配 PSRAM 录音缓冲 ---
    mic_buf = (int16_t*)ps_malloc(MIC_BUF_BYTES);
    if (!mic_buf) {
        mic_buf = (int16_t*)malloc(MIC_BUF_BYTES);  // fallback
    }
    if (!mic_buf) {
        Serial.println("[MIC] buffer alloc FAIL");
        return false;
    }

    Serial.printf("[MIC] Init OK, buf=%dKB\n", MIC_BUF_BYTES / 1024);
    return true;
}

// ===== 开始录音 =====
static void i2s_mic_start() {
    mic_samples     = 0;
    mic_running     = true;
    mic_last_sound  = millis();
    mic_ch_detected = false;
    mic_active_ch   = 0;
    i2s_zero_dma_buffer(I2S_NUM_0);
    Serial.println("[MIC] Start recording...");
}

// ===== 停止录音 =====
static void i2s_mic_stop() {
    mic_running = false;
    // 排空 DMA 残留
    size_t bytes = 0;
    size_t remain = MIC_BUF_SAMPLES - mic_samples;
    if (remain > 1024) remain = 1024;
    i2s_read(I2S_NUM_0, mic_buf + mic_samples, remain * sizeof(int16_t), &bytes, 0);
    mic_samples += bytes / sizeof(int16_t);

    float dur = (float)mic_samples / MIC_SAMPLE_RATE;
    Serial.printf("[MIC] Stop: %d samples (%.1fs)\n", mic_samples, dur);
}

// ===== 循环中从 DMA 拉取数据 (非阻塞) =====
// 每 100ms 自动做一次 RMS 静音检测
static void i2s_mic_poll() {
    if (!mic_running || !mic_buf) return;

    size_t remain = MIC_BUF_SAMPLES - mic_samples;
    if (remain < 512) return;  // 缓冲快满

    size_t want = (remain > 1024) ? 1024 : remain;
    size_t bytes = 0;
    // 短超时等待 DMA 填满, 避免 0-timeout 总是返回 0
    esp_err_t err = i2s_read(I2S_NUM_0, mic_buf + mic_samples,
                              want * sizeof(int16_t), &bytes, pdMS_TO_TICKS(20));
    if (err == ESP_OK && bytes > 0) {
        mic_samples += bytes / sizeof(int16_t);
        // 首次采到足够数据: 自动检测有效声道 + 打印采样
        if (!mic_ch_detected && mic_samples >= 200) {
            mic_ch_detected = true;
            int64_t eR = 0, eL = 0;
            for (int i = 0; i < 200; i += 2) {
                eR += abs(mic_buf[i]);      // even = RIGHT
                eL += abs(mic_buf[i+1]);    // odd  = LEFT
            }
            mic_active_ch = (eR > eL) ? 0 : 1;
            Serial.printf("[MIC] Channel detect: R_energy=%lld L_energy=%lld → using %s\n",
                          eR, eL, mic_active_ch == 0 ? "RIGHT" : "LEFT");
            Serial.print("[MIC] First 20 raw: ");
            for (int i = 0; i < 20; i++) { Serial.print(mic_buf[i]); Serial.print(" "); }
            Serial.println();
        }
    } else if (err != ESP_OK && err != ESP_ERR_TIMEOUT) {
        static unsigned long lastErr = 0;
        if (millis() - lastErr > 3000) {
            Serial.printf("[MIC] i2s_read err: %d\n", err);
            lastErr = millis();
        }
    }

    // 每秒输出一次采集进度
    static unsigned long lastProgress = 0;
    if (millis() - lastProgress > 1000) {
        lastProgress = millis();
        Serial.printf("[MIC] captured=%d samples (%.1fs)\n",
                      mic_samples, (float)mic_samples / MIC_SAMPLE_RATE);
    }

    // --- RMS 静音检测 (每 100ms) ---
    static unsigned long lastCheck = 0;
    if (millis() - lastCheck < 100) return;
    lastCheck = millis();

    // 前 N 秒保护期
    if (mic_samples < (size_t)MIC_SAMPLE_RATE * MIC_SILENCE_GUARD / 1000) return;

    // 分析最近 100ms (1600 个样本)
    size_t n = 1600;
    if (mic_samples < n) n = mic_samples;
    size_t start = mic_samples - n;

    int64_t sum = 0;
    for (size_t i = start; i < mic_samples; i++) {
        sum += (int64_t)mic_buf[i] * mic_buf[i];
    }
    float rms = sqrtf((float)sum / n);
    if (rms > MIC_RMS_THRESHOLD) {
        mic_last_sound = millis();
    }
}

// ===== 是否静音超时 =====
static bool i2s_mic_silence() {
    if (!mic_running) return false;
    if (mic_samples < (size_t)MIC_SAMPLE_RATE * MIC_SILENCE_GUARD / 1000) return false;
    return (millis() - mic_last_sound) > MIC_SILENCE_MS;
}

// ===== 是否录满 =====
static bool i2s_mic_full() {
    return mic_samples >= MIC_BUF_SAMPLES - 2048;
}

// ===== 已录时长 ms =====
static unsigned long i2s_mic_elapsed() {
    return (unsigned long)mic_samples * 1000 / MIC_SAMPLE_RATE;
}

// ===== 构建 WAV 数据到缓冲 (调用者负责 free) =====
// 立体声采集 → 提取有效声道 → 输出单声道 WAV
static uint8_t* i2s_mic_to_wav(size_t* wav_size) {
    // 输出: 单声道, 采样数 = 立体声对数
    uint32_t out_samples = mic_samples / MIC_I2S_CHANNELS;
    uint32_t data_bytes  = out_samples * sizeof(int16_t);
    *wav_size = 44 + data_bytes;

    uint8_t* wav = (uint8_t*)malloc(*wav_size);
    if (!wav) return nullptr;

    // RIFF header
    memcpy(wav + 0,  "RIFF", 4);
    uint32_t chunk = 36 + data_bytes;
    memcpy(wav + 4,  &chunk, 4);
    memcpy(wav + 8,  "WAVE", 4);

    // fmt subchunk (单声道)
    memcpy(wav + 12, "fmt ", 4);
    uint32_t fmt_size  = 16;
    uint16_t audio_fmt = 1;       // PCM
    uint16_t channels  = MIC_OUT_CHANNELS;  // 1
    uint32_t rate      = MIC_SAMPLE_RATE;
    uint16_t bits      = MIC_BITS_PER_SAMPLE;
    uint32_t byte_rate = rate * channels * (bits / 8);
    uint16_t align     = channels * (bits / 8);
    memcpy(wav + 16, &fmt_size,  4);
    memcpy(wav + 20, &audio_fmt, 2);
    memcpy(wav + 22, &channels,  2);
    memcpy(wav + 24, &rate,      4);
    memcpy(wav + 28, &byte_rate, 4);
    memcpy(wav + 32, &align,     2);
    memcpy(wav + 34, &bits,      2);

    // data subchunk
    memcpy(wav + 36, "data", 4);
    memcpy(wav + 40, &data_bytes, 4);

    // 提取有效声道 (立体声→单声道)
    int16_t* dst = (int16_t*)(wav + 44);
    for (size_t i = 0; i < mic_samples; i += MIC_I2S_CHANNELS) {
        *dst++ = mic_buf[i + mic_active_ch];
    }

    return wav;
}

// ===== 上传到后端语音识别 =====
// result_text: 输出识别文字
// 返回 true 表示成功
static bool i2s_mic_upload(const char* api_base, const char* token, String& result_text) {
    if (mic_samples == 0) {
        Serial.println("[MIC] No data to upload");
        return false;
    }

    size_t wav_size = 0;
    uint8_t* wav = i2s_mic_to_wav(&wav_size);
    if (!wav) {
        Serial.println("[MIC] WAV alloc FAIL");
        return false;
    }

    Serial.printf("[MIC] Upload WAV %d bytes...\n", wav_size);

    // --- 构建 multipart/form-data ---
    String boundary = "----DietAIMicBoundary";
    String hdr = "--" + boundary + "\r\n";
    hdr += "Content-Disposition: form-data; name=\"audio\"; filename=\"rec.wav\"\r\n";
    hdr += "Content-Type: audio/wav\r\n\r\n";
    String ftr = "\r\n--" + boundary + "--\r\n";

    size_t body_len = hdr.length() + wav_size + ftr.length();
    uint8_t* body = (uint8_t*)malloc(body_len);
    if (!body) {
        free(wav);
        Serial.println("[MIC] Body alloc FAIL");
        return false;
    }

    size_t pos = 0;
    memcpy(body + pos, hdr.c_str(), hdr.length());  pos += hdr.length();
    memcpy(body + pos, wav, wav_size);              pos += wav_size;
    memcpy(body + pos, ftr.c_str(), ftr.length());  pos += ftr.length();
    free(wav);

    // --- HTTP POST ---
    HTTPClient http;
    String url = String(api_base) + "/voice/recognize";
    http.begin(url);
    http.addHeader("Content-Type", "multipart/form-data; boundary=" + boundary);
    if (token && strlen(token) > 0) {
        http.addHeader("Authorization", "Bearer " + String(token));
    }
    http.setTimeout(65000); // ASR 轮询最长 60s, 留 5s 余量 (单位: ms!)

    int code = http.POST(body, body_len);
    free(body);

    if (code != 200) {
        String err = http.getString();
        Serial.printf("[MIC] HTTP %d: %s\n", code, err.substring(0, 120).c_str());
        http.end();
        return false;
    }

    String resp = http.getString();
    http.end();

    // --- 打印完整响应用于调试 ---
    Serial.printf("[MIC] Response(%d): %s\n", resp.length(), resp.substring(0, 200).c_str());

    // --- 解析 JSON: 找 "text" 键的值 (兼容冒号后有/无空格) ---
    int tk = resp.indexOf("\"text\"");
    if (tk < 0) {
        Serial.printf("[MIC] No 'text' key in response\n");
        return false;
    }
    // 跳过 "text" 和冒号, 找到值的开始引号
    int colon = resp.indexOf(':', tk);
    if (colon < 0) { Serial.println("[MIC] No colon after text"); return false; }
    int ts = resp.indexOf('"', colon + 1);
    if (ts < 0) { Serial.println("[MIC] No opening quote"); return false; }
    ts++;  // 跳过开始引号, 指向值首字符

    // 找到未转义的结束引号
    int te = ts;
    while (te < (int)resp.length()) {
        te = resp.indexOf('"', te);
        if (te <= 0) break;
        if (resp.charAt(te - 1) != '\\') break;  // 非转义 → 值结束
        te++;  // 转义引号, 继续
    }
    if (te <= ts) {
        Serial.println("[MIC] Parse text fail");
        return false;
    }

    result_text = resp.substring(ts, te);
    result_text.replace("\\\"", "\"");   // 反转义
    Serial.printf("[MIC] Recognized: %s\n", result_text.c_str());
    return true;
}

// ===== 食物分析结果 =====
static String mic_food_items   = "";    // "螺蛳粉 ×1"
static int    mic_food_cal     = 0;     // 380
static String mic_food_comment = "";    // "螺蛳粉热量适中..."

// ===== 调用后端 Agent 分析食物文字 (异步提交 + 轮询) =====
static bool i2s_mic_analyze(const char* api_base, const char* token, const String& food_text) {
    mic_food_items   = "";
    mic_food_cal     = 0;
    mic_food_comment = "";

    // 转义食物名中的引号
    String escaped = food_text;
    escaped.replace("\\", "\\\\");
    escaped.replace("\"", "\\\"");

    // 1. 提交分析任务
    HTTPClient http;
    String url = String(api_base) + "/voice/analyze-food";
    http.begin(url);
    http.addHeader("Content-Type", "application/json");
    if (token && strlen(token) > 0) {
        http.addHeader("Authorization", "Bearer " + String(token));
    }
    http.setTimeout(30000); // 提交只需 30 秒

    String body = "{\"text\":\"" + escaped + "\"}";
    int code = http.POST(body);
    if (code != 200) {
        String err = http.getString();
        Serial.printf("[MIC] Submit HTTP %d: %s\n", code, err.substring(0, 120).c_str());
        http.end();
        return false;
    }

    String resp = http.getString();
    http.end();
    Serial.printf("[MIC] Submit resp: %s\n", resp.substring(0, 200).c_str());

    // 提取 task_id
    int tid = resp.indexOf("\"task_id\"");
    if (tid < 0) { Serial.println("[MIC] No task_id"); return false; }
    int colon = resp.indexOf(':', tid);
    int q1 = resp.indexOf('"', colon + 1);
    int q2 = resp.indexOf('"', q1 + 1);
    if (q1 < 0 || q2 < 0) { Serial.println("[MIC] Parse task_id fail"); return false; }
    String taskId = resp.substring(q1 + 1, q2);
    Serial.printf("[MIC] Task: %s\n", taskId.c_str());

    // 2. 轮询结果 (前 30 次每 400ms, 之后退回 2s; 最多 90 次 ≈ 132 秒上限)
    //    提交后立即查一次: 结果可能已就绪, 不必干等一个完整间隔
    String queryUrl = String(api_base) + "/voice/analyze-food/" + taskId;
    for (int i = 0; i < 90; i++) {
        if (i > 0) delay(i <= 30 ? 400 : 2000);

        HTTPClient qHttp;
        qHttp.begin(queryUrl);
        qHttp.addHeader("Content-Type", "application/json");
        if (token && strlen(token) > 0) {
            qHttp.addHeader("Authorization", "Bearer " + String(token));
        }
        qHttp.setTimeout(10000);

        int qCode = qHttp.GET();
        if (qCode != 200) {
            Serial.printf("[MIC] Poll %d HTTP %d\n", i, qCode);
            qHttp.end();
            continue;  // 重试
        }

        String qResp = qHttp.getString();
        qHttp.end();

        // 检查状态
        if (qResp.indexOf("\"processing\"") >= 0) {
            Serial.printf("[MIC] Poll %d: processing...\n", i);
            continue;
        }

        if (qResp.indexOf("\"failed\"") >= 0) {
            Serial.printf("[MIC] Poll %d: failed — %s\n", i, qResp.substring(0, 200).c_str());
            return false;
        }

        if (qResp.indexOf("\"done\"") >= 0) {
            Serial.printf("[MIC] Poll %d: done! resp(%d): %s\n",
                          i, qResp.length(), qResp.substring(0, 300).c_str());

            // 解析 food_items (提取所有, 顿号连接)
            int fi = qResp.indexOf("\"food_items\"");
            if (fi >= 0) {
                int lb = qResp.indexOf('[', fi);
                int rb = qResp.indexOf(']', lb + 1);
                if (lb >= 0 && rb > lb) {
                    int pos = lb;
                    String allItems = "";
                    while (pos < rb) {
                        int qa = qResp.indexOf('"', pos);
                        if (qa < 0 || qa >= rb) break;
                        int qb = qResp.indexOf('"', qa + 1);
                        if (qb < 0 || qb > rb) break;
                        String item = qResp.substring(qa + 1, qb);
                        if (item.length() > 0) {
                            if (allItems.length() > 0) allItems += "\xE3\x80\x81";
                            allItems += item;
                        }
                        pos = qb + 1;
                    }
                    if (allItems.length() > 0) mic_food_items = allItems;
                }
            }

            // 解析 total_calories
            int tc = qResp.indexOf("\"total_calories\"");
            if (tc >= 0) {
                int colon2 = qResp.indexOf(':', tc);
                if (colon2 >= 0) {
                    int vs = colon2 + 1;
                    while (vs < (int)qResp.length() && (qResp.charAt(vs) == ' ' || qResp.charAt(vs) == '"')) vs++;
                    int ve = vs;
                    while (ve < (int)qResp.length() && (qResp.charAt(ve) >= '0' && qResp.charAt(ve) <= '9' || qResp.charAt(ve) == '.')) ve++;
                    mic_food_cal = qResp.substring(vs, ve).toInt();
                }
            }

            // 解析 short_comment
            int sc = qResp.indexOf("\"short_comment\"");
            if (sc >= 0) {
                int colon3 = qResp.indexOf(':', sc);
                if (colon3 >= 0) {
                    int qa = qResp.indexOf('"', colon3 + 1);
                    if (qa >= 0) {
                        int qb = qResp.indexOf('"', qa + 1);
                        if (qb >= 0 && qb - qa > 2) {
                            mic_food_comment = qResp.substring(qa + 1, qb);
                        }
                    }
                }
            }

            if (mic_food_items.length() == 0 && mic_food_cal == 0) {
                Serial.println("[MIC] Analyze: no items or calories found");
                return false;
            }

            Serial.printf("[MIC] Food: %s | %d kcal | %s\n",
                          mic_food_items.c_str(), mic_food_cal, mic_food_comment.c_str());
            return true;
        }
    }

    Serial.println("[MIC] Poll timeout (120s)");
    return false;
}

// ===== 释放资源 =====
static void i2s_mic_free() {
    if (mic_buf) { free(mic_buf); mic_buf = nullptr; }
    mic_samples = 0;
    mic_running = false;
}
