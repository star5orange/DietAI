/**
 * DietAI I2S 功放驱动 — MAX98357
 *
 * 功能:
 *   - I2S TX 模式 (24kHz, 16bit, 单声道, I2S_NUM_1)
 *   - HTTP 下载 TTS WAV/PCM 音频
 *   - 解析 WAV 头 → 自动适配采样率
 *   - 非阻塞 DMA 播放 (loop 中轮询)
 *
 * 引脚 (模块实物丝印):
 *   MAX98357 VIN      → 5V (或 3.3V 看模块)
 *   MAX98357 GND      → GND
 *   MAX98357 BCLK(SCK)→ GPIO 17
 *   MAX98357 LRC(WS)  → GPIO 16
 *   MAX98357 DIN(SD)  → GPIO 42
 *   MAX98357 GAIN(SD_MODE) → GND (接地=15dB 增益, 注意: 悬空=9dB / 接地=15dB / 接VIN=3dB)
 *
 * 注: GAIN 接地为 15dB 高增益, 若 TTS PCM 满幅易削波破音 → 由后端 volume_rate 降低输出音量
 *
 * 注意: 与 INMP441 (I2S_NUM_0, GPIO40/41/47) 使用独立的 I2S 控制器,
 *        避免共享 BCLK/WS 导致的采样率冲突 (INMP441=16kHz, MAX98357=24kHz).
 */

#pragma once

#include <Arduino.h>
#include <driver/i2s.h>
#include <HTTPClient.h>
#include <WiFiClient.h>

// ===== I2S 引脚 (MAX98357, I2S_NUM_1) =====
#define I2S_SPK_BCLK  GPIO_NUM_17
#define I2S_SPK_WS    GPIO_NUM_16
#define I2S_SPK_DOUT  GPIO_NUM_42

// ===== 播放参数 (TTS WAV 通常为 24000Hz/16bit/mono) =====
#define SPK_DEFAULT_RATE      24000
#define SPK_BITS_PER_SAMPLE   16
#define SPK_DMA_BUF_COUNT     8
#define SPK_DMA_BUF_LEN       512     // 512×16bit = 1KB per DMA block

// ===== 播放状态 =====
static bool     spk_inited   = false;
static bool     spk_playing  = false;
static uint32_t spk_rate     = SPK_DEFAULT_RATE;  // 实际采样率 (从 WAV 头解析)
static uint8_t* spk_buf      = nullptr;  // PSRAM 音频缓冲
static size_t   spk_buf_len  = 0;       // 缓冲总字节数
static size_t   spk_write_pos = 0;      // 已写入 I2S 的字节位置
static size_t   spk_write_total = 0;    // I2S 排队总字节数 (DMA 深度)
static unsigned long spk_drain_start = 0; // DMA 排空开始时间

// ===== 初始化 I2S 功放 (I2S_NUM_1, TX Master) =====
static bool i2s_speaker_init() {
    if (spk_inited) return true;

    i2s_config_t cfg;
    memset(&cfg, 0, sizeof(cfg));
    cfg.mode                 = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX);
    cfg.sample_rate          = spk_rate;
    cfg.bits_per_sample      = I2S_BITS_PER_SAMPLE_16BIT;
    cfg.channel_format       = I2S_CHANNEL_FMT_ONLY_LEFT;  // 单声道, 仅左通道有数据
    cfg.communication_format = I2S_COMM_FORMAT_STAND_I2S;
    cfg.intr_alloc_flags     = ESP_INTR_FLAG_LEVEL1;
    cfg.dma_buf_count        = SPK_DMA_BUF_COUNT;
    cfg.dma_buf_len          = SPK_DMA_BUF_LEN;
    cfg.use_apll             = false;  // 不用 APLL, 避免与 I2S_NUM_0 冲突

    esp_err_t err = i2s_driver_install(I2S_NUM_1, &cfg, 0, NULL);
    if (err != ESP_OK) {
        Serial.printf("[SPK] driver_install FAIL: %d\n", err);
        return false;
    }

    i2s_pin_config_t pin;
    memset(&pin, 0, sizeof(pin));
    pin.bck_io_num     = I2S_SPK_BCLK;
    pin.ws_io_num      = I2S_SPK_WS;
    pin.data_out_num   = I2S_SPK_DOUT;
    pin.data_in_num    = I2S_PIN_NO_CHANGE;

    err = i2s_set_pin(I2S_NUM_1, &pin);
    if (err != ESP_OK) {
        Serial.printf("[SPK] set_pin FAIL: %d\n", err);
        i2s_driver_uninstall(I2S_NUM_1);
        return false;
    }

    spk_inited = true;
    Serial.printf("[SPK] Init OK — I2S_NUM_1, rate=%d, pins: bck=%d ws=%d dout=%d\n",
                  spk_rate, I2S_SPK_BCLK, I2S_SPK_WS, I2S_SPK_DOUT);
    return true;
}

// ===== 解析 WAV 头, 返回 PCM 数据偏移和采样率 =====
// 成功返回 PCM 起始偏移 (通常是 44), 失败返回 0
static size_t parse_wav_header(const uint8_t* data, size_t len, uint32_t* out_rate,
                                uint16_t* out_bits, uint16_t* out_channels) {
    if (len < 44) return 0;

    // RIFF header
    if (memcmp(data, "RIFF", 4) != 0) return 0;
    if (memcmp(data + 8, "WAVE", 4) != 0) return 0;

    // 查找 fmt 和 data chunk
    size_t pos = 12;
    bool got_fmt = false, got_data = false;
    uint32_t data_size = 0;
    size_t data_offset = 0;

    while (pos + 8 <= len) {
        char tag[5] = {0};
        memcpy(tag, data + pos, 4);
        uint32_t chunk_size = data[pos + 4]
                            | (data[pos + 5] << 8)
                            | (data[pos + 6] << 16)
                            | (data[pos + 7] << 24);

        if (strcmp(tag, "fmt ") == 0 && chunk_size >= 16 && pos + 8 + chunk_size <= len) {
            uint16_t audio_fmt  = data[pos + 8] | (data[pos + 9] << 8);
            *out_channels       = data[pos + 10] | (data[pos + 11] << 8);
            *out_rate           = data[pos + 12] | (data[pos + 13] << 8)
                                | (data[pos + 14] << 16) | (data[pos + 15] << 24);
            *out_bits           = data[pos + 22] | (data[pos + 23] << 8);

            if (audio_fmt != 1) {  // 非 PCM
                Serial.printf("[SPK] WAV fmt=%d (not PCM)\n", audio_fmt);
                return 0;
            }
            got_fmt = true;
        } else if (strcmp(tag, "data") == 0) {
            data_size = chunk_size;
            data_offset = pos + 8;
            got_data = true;
        }

        pos += 8 + chunk_size;
        // 对齐到偶数边界
        if (chunk_size & 1) pos++;
    }

    if (!got_fmt || !got_data) return 0;

    Serial.printf("[SPK] WAV: rate=%d bits=%d ch=%d data=%d bytes @ offset %d\n",
                  *out_rate, *out_bits, *out_channels, data_size, data_offset);
    return data_offset;
}

// ===== 重新初始化 I2S (采样率变化时调用) =====
static bool i2s_speaker_reinit(uint32_t new_rate) {
    if (spk_inited) {
        i2s_driver_uninstall(I2S_NUM_1);
        spk_inited = false;
    }
    spk_rate = new_rate;
    return i2s_speaker_init();
}

// ===== HTTP 下载 TTS 音频 → PSRAM 缓冲 =====
// text: 要合成的文字 (≤200字)
// api_base: 后端地址
// token: 认证令牌
// 返回 true=缓冲就绪可播放, false=下载失败
static bool i2s_speaker_fetch_tts(const char* api_base, const char* token, const String& text) {
    // 释放旧缓冲
    if (spk_buf) { free(spk_buf); spk_buf = nullptr; }
    spk_buf_len = 0;
    spk_write_pos = 0;
    spk_write_total = 0;
    spk_drain_start = 0;

    // 用时初始化 I2S (避免空闲时 BCLK/WS 持续输出导致噪声)
    if (!spk_inited) {
        if (!i2s_speaker_init()) {
            Serial.println("[SPK] Init FAIL, cannot play");
            return false;
        }
    }

    // JSON 转义文字 (双引号 → \", 反斜杠 → \\)
    String escaped = text;
    escaped.replace("\\", "\\\\");
    escaped.replace("\"", "\\\"");
    escaped.replace("\n", "\\n");

    HTTPClient http;
    String url = String(api_base) + "/voice/tts";
    http.begin(url);
    http.addHeader("Content-Type", "application/json");
    if (token && strlen(token) > 0) {
        http.addHeader("Authorization", "Bearer " + String(token));
    }
    http.setTimeout(30000);  // TTS 合成最长 30s

    // POST body: {"text":"...", "format":"pcm", "voice_type":"zh_female_linjianvhai_moon_bigtts"}
    String body = "{\"text\":\"" + escaped + "\",\"format\":\"pcm\",\"voice_type\":\"zh_female_linjianvhai_moon_bigtts\"}";
    Serial.printf("[SPK] TTS fetch: %s\n", text.substring(0, 60).c_str());

    int code = http.POST(body);
    if (code != 200) {
        String err = http.getString();
        Serial.printf("[SPK] TTS HTTP %d: %s\n", code, err.substring(0, 120).c_str());
        http.end();
        return false;
    }

    // 读取全部响应数据到 PSRAM
    int contentLen = http.getSize();
    if (contentLen <= 0) contentLen = 256 * 1024;  // 预估最大 256KB

    spk_buf = (uint8_t*)ps_malloc(contentLen);
    if (!spk_buf) {
        spk_buf = (uint8_t*)malloc(contentLen);
    }
    if (!spk_buf) {
        Serial.println("[SPK] PSRAM alloc FAIL");
        http.end();
        return false;
    }

    WiFiClient* stream = http.getStreamPtr();
    size_t readTotal = 0;
    unsigned long startMs = millis();

    while (stream->connected() && readTotal < (size_t)contentLen) {
        int avail = stream->available();
        if (avail <= 0) {
            if (millis() - startMs > 15000) break;  // 15s 超时
            delay(5);
            continue;
        }
        size_t toRead = (avail > (contentLen - readTotal)) ? (contentLen - readTotal) : avail;
        int n = stream->readBytes(spk_buf + readTotal, toRead);
        if (n > 0) readTotal += n;
    }

    http.end();
    spk_buf_len = readTotal;

    if (spk_buf_len == 0) {
        Serial.println("[SPK] TTS: 0 bytes received");
        free(spk_buf); spk_buf = nullptr;
        return false;
    }

    Serial.printf("[SPK] TTS downloaded: %d bytes\n", spk_buf_len);

    // 解析 WAV 头
    uint32_t wav_rate = 0;
    uint16_t wav_bits = 0, wav_ch = 0;
    size_t pcm_offset = parse_wav_header(spk_buf, spk_buf_len, &wav_rate, &wav_bits, &wav_ch);

    if (pcm_offset == 0) {
        // 不是 WAV, 可能是原始 PCM — 直接按默认采样率播放
        Serial.println("[SPK] Not WAV, treating as raw PCM");
        spk_write_pos = 0;
    } else {
        // 检查是否需要重配 I2S 采样率
        if (wav_rate != spk_rate || wav_bits != SPK_BITS_PER_SAMPLE) {
            Serial.printf("[SPK] Rate change: %d → %d\n", spk_rate, wav_rate);
            if (!i2s_speaker_reinit(wav_rate)) {
                Serial.println("[SPK] Reinit FAIL");
                free(spk_buf); spk_buf = nullptr;
                spk_buf_len = 0;
                return false;
            }
        }
        spk_write_pos = pcm_offset;
        spk_buf_len = spk_buf_len;  // 保留完整 buffer (含 WAV 头)
    }

    return true;
}

// ===== 开始播放 (非阻塞, 只排队第一批 DMA 数据) =====
static bool i2s_speaker_start() {
    if (!spk_inited || !spk_buf || spk_buf_len == 0) return false;
    if (spk_playing) return true;  // 已在播放

    spk_playing = true;
    spk_write_total = 0;
    spk_drain_start = 0;

    Serial.printf("[SPK] Play start: %d bytes @ %d Hz\n",
                  spk_buf_len - spk_write_pos, spk_rate);

    // 写入第一块数据到 I2S DMA
    size_t chunk = spk_buf_len - spk_write_pos;
    if (chunk > 4096) chunk = 4096;
    size_t written = 0;
    esp_err_t err = i2s_write(I2S_NUM_1, spk_buf + spk_write_pos, chunk, &written, 0);
    if (err == ESP_OK) {
        spk_write_pos += written;
        spk_write_total += written;
    }

    return true;
}

// ===== 播放中轮询: 继续喂数据到 I2S DMA (每 loop 调用) =====
// 返回 true=仍在播放, false=播放完毕
static bool i2s_speaker_poll() {
    if (!spk_playing || !spk_buf) return false;

    // 检查是否还有数据要写
    if (spk_write_pos < spk_buf_len) {
        size_t remain = spk_buf_len - spk_write_pos;
        size_t chunk = (remain > 2048) ? 2048 : remain;
        size_t written = 0;
        // 短超时: DMA 有空位就写, 没有就等下次 poll
        esp_err_t err = i2s_write(I2S_NUM_1, spk_buf + spk_write_pos, chunk, &written, pdMS_TO_TICKS(1));
        if (err == ESP_OK && written > 0) {
            spk_write_pos += written;
            spk_write_total += written;
        }
    }

    // 全部 PCM 已写入 DMA 后, 估算排空时间
    if (spk_write_pos >= spk_buf_len) {
        if (spk_drain_start == 0) {
            spk_drain_start = millis();
            Serial.printf("[SPK] All %d bytes queued, waiting for DMA drain...\n", spk_write_total);
        }
        // DMA 缓冲深度 ≈ dma_buf_count × dma_buf_len × 2 bytes = 8 × 512 × 2 = 8192 bytes
        // 排空时间 ≈ 8192 / (sample_rate × 2) × 1000ms + 余量
        unsigned long drainMs = 1000 * SPK_DMA_BUF_COUNT * SPK_DMA_BUF_LEN * 2 / (spk_rate * 2) + 80;
        if (millis() - spk_drain_start > drainMs) {
            i2s_zero_dma_buffer(I2S_NUM_1);
            i2s_driver_uninstall(I2S_NUM_1);  // 停止 I2S 时钟, 消除空闲噪声
            spk_inited = false;
            spk_playing = false;
            Serial.printf("[SPK] Done: %d bytes played, I2S released\n", spk_write_total);
            return false;
        }
    }

    return spk_playing;
}

// ===== 强制停止播放 =====
static void i2s_speaker_stop() {
    if (!spk_playing) return;
    i2s_zero_dma_buffer(I2S_NUM_1);
    i2s_driver_uninstall(I2S_NUM_1);  // 释放 I2S, 停止时钟输出
    spk_inited = false;
    spk_playing = false;
    Serial.println("[SPK] Stopped, I2S released");
}

// ===== 是否正在播放 =====
static bool i2s_speaker_is_playing() {
    return spk_playing;
}

// ===== 释放资源 =====
static void i2s_speaker_free() {
    i2s_speaker_stop();
    if (spk_buf) { free(spk_buf); spk_buf = nullptr; }
    spk_buf_len = 0;
    spk_write_pos = 0;
    spk_write_total = 0;
    if (spk_inited) {
        i2s_driver_uninstall(I2S_NUM_1);
        spk_inited = false;
        Serial.println("[SPK] Freed");
    }
}
