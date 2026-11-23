/**
 * DietAI 主控端 — ESP32-CAM 串口通信模块 v3.0
 *
 * 功能：
 *   - 通过 UART1 (GPIO21=TX, GPIO38=RX) 与 ESP32-CAM 通信
 *   - 发送拍照/帧差开关命令（单字符）
 *   - 接收 JPEG 分片并拼装完整图像
 *   - 接收帧差告警 → 自动触发拍照
 *   - 上传 JPEG 到 DietAI 后端 AI 分析接口
 *
 * 协议 v3.0：
 *   主控→CAM（单字符）：
 *     'C'  拍照请求
 *     'M'  开启帧差监控
 *     'm'  关闭帧差监控
 *   CAM→主控（二进制帧）：
 *     帧格式：[0xAA] [0x55] [CMD] [LEN_H] [LEN_L] [DATA...] [XOR_CHECKSUM]
 *     CMD:
 *       0x02  JPEG 数据分片 → cam_handle_chunk()
 *       0x03  传输完成     → cam_handle_done()
 *       0x04  错误         → cam_handle_error()
 *       0x08  帧差触发告警  → cam_handle_motion_alert() → 自动拍照
 */

#pragma once

#include <Arduino.h>
#include <HardwareSerial.h>
#include <HTTPClient.h>

// ===== 协议定义（与 CAM 端保持一致）=====
#define CAM_HEADER_1     0xAA
#define CAM_HEADER_2     0x55

#define CAM_CMD_CAPTURE   0x01  // 主控→CAM: 拍照请求
#define CAM_CMD_CHUNK     0x02  // CAM→主控: JPEG 分片
#define CAM_CMD_DONE      0x03  // CAM→主控: 传输完成
#define CAM_CMD_ERROR     0x04  // CAM→主控: 错误
#define CAM_CMD_ACK       0x05  // 主控→CAM: 确认收到分片
#define CAM_CMD_MOTION_ON  0x06  // 主控→CAM: 开启帧差
#define CAM_CMD_MOTION_OFF 0x07  // 主控→CAM: 关闭帧差
#define CAM_CMD_MOTION_ALERT 0x08  // CAM→主控: 帧差触发

// ===== UART1 引脚 =====
#define CAM_UART_RX  38   // GPIO38 ← CAM UART1 TX (GPIO12)
#define CAM_UART_TX  21   // GPIO21 → CAM UART1 RX (GPIO13)
#define CAM_BAUD     115200

// ===== JPEG 接收缓冲 =====
// SVGA 800×600 JPEG quality=10 约 30-80KB
#define JPEG_BUF_SIZE  131072  // 128KB

// ===== 全局状态 =====
static uint8_t* jpegBuf = nullptr;      // JPEG 接收缓冲（PSRAM 分配）
static uint32_t jpegBufLen = 0;         // 当前已接收字节数
static bool camReceiving = false;        // 是否正在接收 JPEG
static bool camTransferDone = false;     // 传输是否完成
static uint32_t camTransferTotal = 0;    // 传输完成时的总字节数

// ===== XOR 校验和 =====
static uint8_t cam_xor_checksum(const uint8_t* data, size_t len) {
    uint8_t cs = 0;
    for (size_t i = 0; i < len; i++) cs ^= data[i];
    return cs;
}

// ===== 发送协议帧到 CAM =====
static void cam_send_frame(uint8_t cmd, const uint8_t* data = nullptr, uint16_t len = 0) {
    uint8_t header[5];
    header[0] = CAM_HEADER_1;
    header[1] = CAM_HEADER_2;
    header[2] = cmd;
    header[3] = (len >> 8) & 0xFF;
    header[4] = len & 0xFF;

    uint8_t cs = cmd ^ header[3] ^ header[4];
    if (data && len > 0) cs ^= cam_xor_checksum(data, len);

    Serial1.write(header, 5);
    if (data && len > 0) Serial1.write(data, len);
    Serial1.write(cs);
}

// ===== 发送 ACK =====
static void cam_send_ack() {
    Serial1.write(0x05);  // 只发单字节 ACK，CAM 端 uart_read_bytes 读 1 字节直接匹配
}

// ===== 初始化 CAM 通信 =====
static bool cam_init() {
    // 分配 JPEG 缓冲（优先 PSRAM）
    if (psramFound()) {
        jpegBuf = (uint8_t*)ps_malloc(JPEG_BUF_SIZE);
    } else {
        jpegBuf = (uint8_t*)malloc(JPEG_BUF_SIZE);
    }
    if (!jpegBuf) {
        Serial.println("[CAM] JPEG buffer alloc FAIL");
        return false;
    }

    // 初始化 UART1（大 RX 缓冲区，防止中途被屏幕绘制阻塞丢分片）
    Serial1.setRxBufferSize(16384);  // ★ 必须在 begin() 之前设置
    Serial1.begin(CAM_BAUD, SERIAL_8N1, CAM_UART_RX, CAM_UART_TX);
    Serial.printf("[CAM] UART1 initialized @ %d baud (RX=%d, TX=%d)\n", CAM_BAUD, CAM_UART_RX, CAM_UART_TX);

    jpegBufLen = 0;
    camReceiving = false;
    camTransferDone = false;

    return true;
}

// ===== 发送拍照命令 =====
static void cam_request_capture() {
    jpegBufLen = 0;
    camReceiving = true;
    camTransferDone = false;
    Serial1.write('C');  // CAM 监听字符 'C' 触发拍照
    Serial.println("[CAM] Capture request sent");
}

// ===== 发送帧差开关命令（v3.0: 改用单字符，与CAM固件一致）=====
static void cam_set_motion(bool on) {
    Serial1.write(on ? 'M' : 'm');
    Serial.printf("[CAM] Motion detection %s\n", on ? "ON" : "OFF");
}

// ===== 处理接收到的 JPEG 分片 =====
static void cam_handle_chunk(const uint8_t* data, uint16_t len) {
    if (len < 2) {
        Serial.println("[CAM] Chunk too short");
        return;
    }

    // 分片格式：[SEQ_H] [SEQ_L] [JPEG_DATA...]
    uint16_t seqNum = ((uint16_t)data[0] << 8) | data[1];
    uint16_t jpegLen = len - 2;

    if (jpegBufLen + jpegLen > JPEG_BUF_SIZE) {
        Serial.printf("[CAM] JPEG buffer overflow: %u + %u > %u\n", jpegBufLen, jpegLen, JPEG_BUF_SIZE);
        camReceiving = false;
        return;
    }

    memcpy(jpegBuf + jpegBufLen, data + 2, jpegLen);
    jpegBufLen += jpegLen;

    // 发送 ACK
    cam_send_ack();
}

// ===== 处理传输完成帧 =====
static void cam_handle_done(const uint8_t* data, uint16_t len) {
    if (len >= 4) {
        camTransferTotal = ((uint32_t)data[0] << 24) | ((uint32_t)data[1] << 16) |
                           ((uint32_t)data[2] << 8)  | (uint32_t)data[3];
    } else {
        camTransferTotal = jpegBufLen;
    }
    camReceiving = false;
    camTransferDone = true;
    Serial.printf("[CAM] Transfer complete: %u bytes received, %u expected\n", jpegBufLen, camTransferTotal);
}

// ===== 处理错误帧 =====
static void cam_handle_error(const uint8_t* data, uint16_t len) {
    uint8_t errCode = (len > 0) ? data[0] : 0xFF;
    Serial.printf("[CAM] Error: 0x%02x\n", errCode);
    camReceiving = false;
}

// ===== 处理帧差触发通知 → 自动拍照 =====
static void cam_handle_motion_alert(const uint8_t* data, uint16_t len) {
    uint32_t dist = 0;
    if (len >= 4) {
        dist = ((uint32_t)data[0] << 24) | ((uint32_t)data[1] << 16) |
               ((uint32_t)data[2] << 8)  | (uint32_t)data[3];
    }
    Serial.printf("[CAM] Motion alert! dist=%u, auto-capturing...\n", dist);
    // 自动触发拍照 → CAM拍照 → JPEG回传 → 上传后端AI识别
    cam_request_capture();
}

// ===== 解析 CAM 发来的协议帧（在 loop 中调用）=====
static void cam_process_incoming() {
    // 查找帧头
    while (Serial1.available() > 0) {
        uint8_t b = Serial1.read();
        if (b != CAM_HEADER_1) continue;

        // 等待第二个帧头字节
        unsigned long t0 = millis();
        while (millis() - t0 < 100) {
            if (Serial1.available()) {
                b = Serial1.read();
                break;
            }
        }
        if (b != CAM_HEADER_2) continue;

        // 读取 CMD
        t0 = millis();
        while (!Serial1.available() && millis() - t0 < 200) { delay(1); }
        if (!Serial1.available()) { Serial.println("[CAM] Timeout: no CMD"); return; }
        uint8_t cmd = Serial1.read();

        // 读取 LEN
        while (Serial1.available() < 2 && millis() - t0 < 200) { delay(1); }
        if (Serial1.available() < 2) { Serial.println("[CAM] Timeout: no LEN"); return; }
        uint8_t lenH = Serial1.read();
        uint8_t lenL = Serial1.read();
        uint16_t dataLen = ((uint16_t)lenH << 8) | lenL;

        // 读取 DATA（大分片需要等待更长时间）
        uint8_t* frameData = nullptr;
        if (dataLen > 0) {
            frameData = (uint8_t*)malloc(dataLen);
            if (!frameData) {
                Serial.printf("[CAM] Malloc fail for %u bytes\n", dataLen);
                return;
            }
            uint16_t readSoFar = 0;
            unsigned long readStart = millis();
            while (readSoFar < dataLen && millis() - readStart < 2000) {
                int avail = Serial1.available();
                if (avail > 0) {
                    int toRead = ((dataLen - readSoFar) < (uint16_t)avail) ? (dataLen - readSoFar) : (uint16_t)avail;
                    Serial1.readBytes(frameData + readSoFar, toRead);
                    readSoFar += toRead;
                    readStart = millis();  // 有数据就重置超时
                } else {
                    delay(1);
                }
            }
            if (readSoFar < dataLen) {
                Serial.printf("[CAM] Data incomplete: %u/%u\n", readSoFar, dataLen);
                free(frameData);
                return;
            }
        }

        // 读取校验和
        while (!Serial1.available() && millis() - t0 < 200) { delay(1); }
        if (!Serial1.available()) { Serial.println("[CAM] Timeout: no checksum"); free(frameData); return; }
        uint8_t recvCs = Serial1.read();

        // 验证校验和
        uint8_t calcCs = cmd ^ lenH ^ lenL;
        if (frameData && dataLen > 0) calcCs ^= cam_xor_checksum(frameData, dataLen);
        if (calcCs != recvCs) {
            Serial.printf("[CAM] Checksum mismatch: calc=0x%02x recv=0x%02x\n", calcCs, recvCs);
            free(frameData);
            return;
        }

        // 分发处理
        switch (cmd) {
            case CAM_CMD_CHUNK:
                cam_handle_chunk(frameData, dataLen);
                break;
            case CAM_CMD_DONE:
                cam_handle_done(frameData, dataLen);
                break;
            case CAM_CMD_ERROR:
                cam_handle_error(frameData, dataLen);
                break;
            case CAM_CMD_MOTION_ALERT:
                cam_handle_motion_alert(frameData, dataLen);
                break;
            default:
                Serial.printf("[CAM] Unknown CMD: 0x%02x\n", cmd);
                break;
        }

        free(frameData);
        return;  // 每次只处理一帧
    }
}

// ===== 上传 JPEG 到后端 AI 分析 =====
// 返回 true 表示上传成功，resultJson 填入响应体
static bool cam_upload_jpeg(const char* apiBase, const char* token, String& resultJson) {
    if (jpegBufLen == 0 || !jpegBuf) {
        Serial.println("[CAM] No JPEG data to upload");
        return false;
    }

    // 用 WiFiClient 手工构造 HTTP multipart，避免 HTTPClient String 的 0x00 截断问题
    WiFiClient client;
    if (!client.connect("192.168.43.134", 8000)) {
        Serial.println("[CAM] TCP connect FAIL");
        return false;
    }
    client.setTimeout(30);

    String boundary = "DietAI" + String(millis());
    String head = "--" + boundary + "\r\n";
    head += "Content-Disposition: form-data; name=\"file\"; filename=\"food.jpg\"\r\n";
    head += "Content-Type: image/jpeg\r\n\r\n";
    String tail = "\r\n--" + boundary + "--\r\n";

    size_t totalLen = head.length() + jpegBufLen + tail.length();

    // 发 HTTP 头
    client.printf("POST /api/foods/upload-image HTTP/1.1\r\n");
    client.printf("Host: 192.168.43.134:8000\r\n");
    client.printf("Authorization: Bearer %s\r\n", token);
    client.printf("Content-Type: multipart/form-data; boundary=%s\r\n", boundary.c_str());
    client.printf("Content-Length: %u\r\n", totalLen);
    client.printf("Connection: close\r\n\r\n");

    // 发 multipart 头
    client.print(head);

    // 发 JPEG 二进制
    client.write(jpegBuf, jpegBufLen);

    // 发 multipart 尾
    client.print(tail);
    client.flush();

    Serial.printf("[CAM] Uploaded %u bytes, reading response...\n", totalLen);

    // 读响应
    String statusLine = client.readStringUntil('\n');
    Serial.printf("[CAM] Status: %s\n", statusLine.c_str());

    // 跳过响应头
    while (client.connected() || client.available()) {
        String line = client.readStringUntil('\n');
        if (line == "\r" || line.length() <= 1) break;
    }

    // 读响应体
    resultJson = client.readString();
    client.stop();

    if (statusLine.indexOf("200") > 0) {
        Serial.printf("[CAM] Upload OK, %d bytes\n", resultJson.length());
        return true;
    } else {
        Serial.printf("[CAM] Upload FAIL: %s\n", statusLine.c_str());
        Serial.printf("[CAM] Response: %s\n", resultJson.substring(0, 200).c_str());
        return false;
    }
}

// ===== 检查 JPEG 接收是否完成 =====
static bool cam_is_transfer_done() {
    return camTransferDone;
}

// ===== 获取已接收的 JPEG 数据和长度 =====
static uint8_t* cam_get_jpeg(uint32_t& outLen) {
    outLen = jpegBufLen;
    return jpegBuf;
}

// ===== 重置接收状态 =====
static void cam_reset() {
    jpegBufLen = 0;
    camReceiving = false;
    camTransferDone = false;
    camTransferTotal = 0;
}
