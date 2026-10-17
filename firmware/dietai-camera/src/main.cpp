/**
 * DietAI Camera — ESP32-CAM 摄像头模块固件 v4.0
 *
 * 功能：
 *   - OV3660 摄像头拍照（JPEG）
 *   - 二进制串口协议与主控 ESP32-S3 通信
 *   - JPEG 分片传输（每片 ≤ 4KB，带校验和）
 *   - ★ 帧差自动拍照：饭点窗口内检测到画面变化 → 自动拍照发送
 *
 * 串口协议：
 *   主控→CAM（单字符）：
 *     'C'  手动拍照请求
 *     'M'  开启帧差监控（饭点窗口开始）
 *     'm'  关闭帧差监控（饭点窗口结束 / 已拍照）
 *   CAM→主控（二进制帧）：
 *     帧格式：[0xAA] [0x55] [CMD] [LEN_H] [LEN_L] [DATA...] [XOR_CHECKSUM]
 *     CMD:
 *       0x02  JPEG 数据分片
 *       0x03  传输完成
 *       0x04  错误
 *
 * v4.0 变更：
 *   - 帧差检测改为 QQVGA(160×120) 低分辨率，10秒间隔
 *   - 检测到变化直接拍 SVGA 全分辨率照片 + 自动停止监控
 *   - 移除 MOTION_ALERT(0x08)，由 CAM 端直接拍照替代
 *
 * 硬件：途格斯 ESP32-CAM + OV3660
 * 串口：UART0 (GPIO1=TX, GPIO3=RX) → 主控 UART1 (GPIO21/GPIO38)
 * 波特率：115200
 */

#include <Arduino.h>
#include "esp_camera.h"
#include <driver/uart.h>
#include <string.h>
#include <stdarg.h>

// ===== 串口协议定义 =====
#define FRAME_HEADER_1  0xAA
#define FRAME_HEADER_2  0x55

#define CMD_CAPTURE_REQ   0x01
#define CMD_JPEG_CHUNK    0x02
#define CMD_TRANSFER_DONE 0x03
#define CMD_ERROR         0x04
#define CMD_ACK           0x05
#define CMD_MOTION_ON     0x06
#define CMD_MOTION_OFF    0x07
#define CMD_MOTION_ALERT  0x08

#define CHUNK_SIZE        4096
#define UART_BUF_SIZE     512

// ===== 帧差检测参数 =====
#define MOTION_INTERVAL_MS   10000   // 检测间隔（ms），10秒一帧足够覆盖端菜过程
#define MOTION_THRESHOLD     15      // 哈希距离阈值（0-32）

// ===== 摄像头引脚（途格斯 ESP32-CAM + OV3660）=====
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

#define FLASH_PIN 4

// ===== 帧差检测状态 =====
static sensor_t* camSensor = nullptr;   // 全局 sensor 指针，用于切换分辨率
static bool monitoring = false;
static unsigned long lastMotionFrame = 0;
static uint32_t lastFrameHash = 0;

// ===== ESP-IDF UART 输出 =====
static void uart_print(const char* str) {
    uart_write_bytes(UART_NUM_0, str, strlen(str));
}

static void uart_printf(const char* fmt, ...) {
    char buf[256];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    uart_write_bytes(UART_NUM_0, buf, strlen(buf));
}

// ===== XOR 校验和 =====
static uint8_t xor_checksum(const uint8_t* data, size_t len) {
    uint8_t cs = 0;
    for (size_t i = 0; i < len; i++) cs ^= data[i];
    return cs;
}

// ===== 发送一帧 =====
static void send_frame(uint8_t cmd, const uint8_t* data, uint16_t len) {
    uint8_t header[5];
    header[0] = FRAME_HEADER_1;
    header[1] = FRAME_HEADER_2;
    header[2] = cmd;
    header[3] = (len >> 8) & 0xFF;
    header[4] = len & 0xFF;

    uint8_t cs = cmd ^ header[3] ^ header[4];
    if (data && len > 0) cs ^= xor_checksum(data, len);

    uart_write_bytes(UART_NUM_0, (const char*)header, 5);
    if (data && len > 0) uart_write_bytes(UART_NUM_0, (const char*)data, len);
    uart_write_bytes(UART_NUM_0, (const char*)&cs, 1);
}

static void send_error(uint8_t errCode) {
    send_frame(CMD_ERROR, &errCode, 1);
}

// ===== 帧差检测：计算 JPEG 帧哈希 =====
// 从 JPEG 缓冲区等距采样 64 个点计算哈希，用于快速比对帧间差异
static uint32_t compute_frame_hash(camera_fb_t* fb) {
    uint32_t hash = 0;
    if (!fb || !fb->buf || fb->len == 0) return 0;
    size_t step = fb->len / 64;
    if (step < 4) step = 4;
    for (size_t i = 0; i < fb->len; i += step) {
        hash = hash * 31 + fb->buf[i];
    }
    return hash;
}

// ===== 帧差检测：计算两个哈希的汉明距离 =====
static int hash_distance(uint32_t a, uint32_t b) {
    uint32_t diff = a ^ b;
    int count = 0;
    while (diff) { count++; diff &= diff - 1; }  // Brian Kernighan
    return count;
}

// ===== 发送 JPEG 分片并等待 ACK =====
static bool send_jpeg_chunk(const uint8_t* data, uint16_t len, uint16_t seqNum) {
    uint8_t buf[CHUNK_SIZE];
    buf[0] = (seqNum >> 8) & 0xFF;
    buf[1] = seqNum & 0xFF;
    memcpy(buf + 2, data, len);
    send_frame(CMD_JPEG_CHUNK, buf, len + 2);

    uint8_t rx;
    int got = uart_read_bytes(UART_NUM_0, &rx, 1, pdMS_TO_TICKS(3000));
    if (got > 0 && rx == CMD_ACK) return true;

    // 重试一次
    uart_printf("[CAM] ACK timeout seq=%u, retry\n", seqNum);
    send_frame(CMD_JPEG_CHUNK, buf, len + 2);
    got = uart_read_bytes(UART_NUM_0, &rx, 1, pdMS_TO_TICKS(3000));
    if (got > 0 && rx == CMD_ACK) return true;

    uart_printf("[CAM] ACK fail seq=%u\n", seqNum);
    return false;
}

// ===== 拍照并通过串口发送 =====
static void capture_and_send() {
    uart_print("[CAM] Capture...\n");

    digitalWrite(FLASH_PIN, HIGH);
    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb) {
        digitalWrite(FLASH_PIN, LOW);
        uart_print("[CAM] Capture FAIL\n");
        send_error(0x01);
        return;
    }
    digitalWrite(FLASH_PIN, LOW);

    uart_printf("[CAM] OK %u bytes\n", fb->len);

    uint32_t offset = 0;
    uint16_t seqNum = 0;

    while (offset < fb->len) {
        uint16_t chunkLen = (fb->len - offset > (CHUNK_SIZE - 2))
                            ? (CHUNK_SIZE - 2)
                            : (uint16_t)(fb->len - offset);
        if (!send_jpeg_chunk(fb->buf + offset, chunkLen, seqNum)) {
            send_error(0x02);
            esp_camera_fb_return(fb);
            return;
        }
        offset += chunkLen;
        seqNum++;
    }

    uint8_t doneData[4];
    doneData[0] = (fb->len >> 24) & 0xFF;
    doneData[1] = (fb->len >> 16) & 0xFF;
    doneData[2] = (fb->len >> 8) & 0xFF;
    doneData[3] = fb->len & 0xFF;
    send_frame(CMD_TRANSFER_DONE, doneData, 4);

    esp_camera_fb_return(fb);
    uart_printf("[CAM] Done %u bytes %u chunks\n", fb->len, seqNum);
}

void setup() {
    // ---- ESP-IDF UART0 (TX=GPIO1, RX=GPIO3) ----
    uart_config_t ucfg;
    ucfg.baud_rate  = 115200;
    ucfg.data_bits  = UART_DATA_8_BITS;
    ucfg.parity     = UART_PARITY_DISABLE;
    ucfg.stop_bits  = UART_STOP_BITS_1;
    ucfg.flow_ctrl  = UART_HW_FLOWCTRL_DISABLE;
    ucfg.source_clk = UART_SCLK_APB;
    uart_param_config(UART_NUM_0, &ucfg);
    uart_set_pin(UART_NUM_0, 1, 3, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE);
    uart_driver_install(UART_NUM_0, 256, 256, 0, NULL, 0);

    delay(500);

    // 启动快闪 2 次
    pinMode(FLASH_PIN, OUTPUT);
    for (int i = 0; i < 2; i++) {
        digitalWrite(FLASH_PIN, HIGH); delay(80);
        digitalWrite(FLASH_PIN, LOW);  delay(150);
    }

    // 摄像头初始化
    camera_config_t config;
    config.ledc_channel = LEDC_CHANNEL_0;
    config.ledc_timer   = LEDC_TIMER_0;
    config.pin_d0       = Y2_GPIO_NUM;
    config.pin_d1       = Y3_GPIO_NUM;
    config.pin_d2       = Y4_GPIO_NUM;
    config.pin_d3       = Y5_GPIO_NUM;
    config.pin_d4       = Y6_GPIO_NUM;
    config.pin_d5       = Y7_GPIO_NUM;
    config.pin_d6       = Y8_GPIO_NUM;
    config.pin_d7       = Y9_GPIO_NUM;
    config.pin_xclk     = XCLK_GPIO_NUM;
    config.pin_pclk     = PCLK_GPIO_NUM;
    config.pin_vsync    = VSYNC_GPIO_NUM;
    config.pin_href     = HREF_GPIO_NUM;
    config.pin_sccb_sda = SIOD_GPIO_NUM;
    config.pin_sccb_scl = SIOC_GPIO_NUM;
    config.pin_pwdn     = PWDN_GPIO_NUM;
    config.pin_reset    = RESET_GPIO_NUM;
    config.xclk_freq_hz = 10000000;
    config.pixel_format = PIXFORMAT_JPEG;
    config.frame_size   = FRAMESIZE_SVGA;
    config.jpeg_quality = 10;
    config.fb_count     = 1;

    esp_err_t err = esp_camera_init(&config);
    if (err != ESP_OK) {
        uart_printf("CAM ERR: 0x%x\n", err);
        // 慢闪 5 次 = 失败
        for (int i = 0; i < 5; i++) {
            digitalWrite(FLASH_PIN, HIGH); delay(400);
            digitalWrite(FLASH_PIN, LOW);  delay(400);
        }
        return;
    }

    camSensor = esp_camera_sensor_get();
    if (camSensor) uart_printf("Sensor PID=0x%x\n", camSensor->id.PID);

    // 快闪 5 次 = OK
    for (int i = 0; i < 5; i++) {
        digitalWrite(FLASH_PIN, HIGH); delay(50);
        digitalWrite(FLASH_PIN, LOW);  delay(100);
    }

    uart_print("READY\n");
}

void loop() {
    // ---- 处理主控发来的单字符命令 ----
    uint8_t cmd;
    int len = uart_read_bytes(UART_NUM_0, &cmd, 1, 0);
    if (len > 0) {
        if (cmd == 'C' || cmd == 'c') {
            // 手动拍照：暂停监控 → SVGA 拍照 → 恢复监控 → 重置哈希
            bool wasMonitoring = monitoring;
            monitoring = false;
            capture_and_send();
            monitoring = wasMonitoring;
            lastFrameHash = 0;
            return;
        }
        if (cmd == 'M') {
            // 开启帧差监控（饭点窗口到）
            monitoring = true;
            lastFrameHash = 0;
            lastMotionFrame = 0;
            uart_print("[CAM] Motion monitoring ON\n");
        }
        if (cmd == 'm') {
            // 关闭帧差监控（饭点窗口过 / 已拍照）
            monitoring = false;
            uart_print("[CAM] Motion monitoring OFF\n");
        }
    }

    // ---- 帧差检测监控循环 ----
    // 每 MOTION_INTERVAL_MS 抓一帧 QQVGA(160×120) 比对哈希
    // 检测到变化 → 自动切 SVGA(800×600) 拍照发送 → 关闭监控
    if (monitoring && (millis() - lastMotionFrame > MOTION_INTERVAL_MS)) {
        lastMotionFrame = millis();

        // 切到 QQVGA 低分辨率，快速抓帧 + 省带宽
        if (camSensor) camSensor->set_framesize(camSensor, FRAMESIZE_QQVGA);

        camera_fb_t *fb = esp_camera_fb_get();
        if (fb) {
            uint32_t hash = compute_frame_hash(fb);

            if (lastFrameHash != 0) {
                int dist = hash_distance(hash, lastFrameHash);

                if (dist > MOTION_THRESHOLD) {
                    uart_printf("[CAM] Motion detected! dist=%d, auto-capturing...\n", dist);
                    esp_camera_fb_return(fb);

                    // 切回 SVGA 拍全分辨率照片
                    if (camSensor) camSensor->set_framesize(camSensor, FRAMESIZE_SVGA);
                    monitoring = false;   // 检测到就关监控，等主控下次饭点再开
                    capture_and_send();   // 拍照 + 分片发送
                    lastFrameHash = 0;
                    return;
                }
            }

            lastFrameHash = hash;
            esp_camera_fb_return(fb);
        }

        // 恢复 SVGA（为手动 'C' 拍照做准备）
        if (camSensor) camSensor->set_framesize(camSensor, FRAMESIZE_SVGA);
    }

    delay(10);
}
