/**
 * DietAI 智能宠物时钟 — 时钟+NTP+宠物+6按键+蜂鸣器+进度条
 * 功能：
 *   - NTP 同步北京时间
 *   - 屏幕顶部显示大号时钟+日期
 *   - 右下角宠物精灵（5种状态，按键触发变开心）
 *   - 6 按键：饮水/早餐/午餐/晚餐/加餐/夜宵
 *   - 蜂鸣器按键反馈（GPIO18）
 *   - 进度条显示饮水/热量
 *   - API 记录日期用真实日期
 */
#include <Arduino.h>
#include <LovyanGFX.hpp>
#include <WiFi.h>
#include <HTTPClient.h>
#include <time.h>
#include "bg_static.h"    // 静态背景
#include "pet_tiles.h"   // 宠物精灵动画
#include "weekday_cn.h"  // 中文星期
#include "cam_uart.h"    // ESP32-CAM 串口通信
#include "i2s_mic.h"    // INMP441 I2S 麦克风
#include "i2s_speaker.h" // MAX98357 I2S 功放

// ===== TFT 配置 =====
class LGFX : public lgfx::LGFX_Device {
    lgfx::Panel_ILI9488 _panel;
    lgfx::Bus_SPI _bus;
    lgfx::Light_PWM _light;
public:
    LGFX() {
        {
            auto cfg = _bus.config();
            cfg.spi_host = SPI2_HOST;
            cfg.spi_mode = 0;
            cfg.freq_write = 27000000;
            cfg.spi_3wire = true;
            cfg.use_lock = true;
            cfg.dma_channel = 1;
            cfg.pin_sclk = 12;
            cfg.pin_mosi = 11;
            cfg.pin_miso = -1;
            cfg.pin_dc = 13;
            _bus.config(cfg);
            _panel.setBus(&_bus);
        }
        {
            auto cfg = _panel.config();
            cfg.pin_cs = 10;
            cfg.pin_rst = 9;
            cfg.panel_width  = 320;   // ILI9488 原生竖屏
            cfg.panel_height = 480;
            cfg.memory_width  = 320;
            cfg.memory_height = 480;
            cfg.rgb_order = true;   // BGR
            _panel.config(cfg);
        }
        {
            auto cfg = _light.config();
            cfg.pin_bl = 7;
            _light.config(cfg);
            _panel.setLight(&_light);
        }
        setPanel(&_panel);
    }
};

LGFX tft;

// ===== WiFi & API =====
// WiFi 凭据放在本地私有文件 src/wifi_secrets.h（已被 .gitignore 排除，不会入库）。
// 没有该文件时回退到下面的占位符。注意 ESP32-S3 仅支持 2.4GHz。
#if __has_include("wifi_secrets.h")
#include "wifi_secrets.h"
#else
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"
#endif
// [本地联调] 暂指电脑本机后端。云端部署恢复后改回 http://124.223.212.106:9002/api
#define API_BASE "http://192.168.43.134:8000/api"
// 配对码模式: 不再硬编码用户名密码, 设备通过配对码绑定到用户

// ===== 按键 (V4 3键精简) =====
#define BTN_VOICE     4   // 🎤 语音/确认 (短按=进VOICE页, 长按=录音)
#define BTN_WATER     5   // 💧 饮水/播报 (短按=+250ml, 长按=每日播报)
#define BTN_BACK      15  // ↩ 返回/取消
// GPIO6, GPIO16, GPIO17 已释放 (原 午餐/加餐/夜宵 → 语音输入替代)

// ===== 蜂鸣器 =====
#define BUZZER_PIN 18

// ===== 状态 =====
String accessToken;
bool wifiOk = false;
bool ntpOk = false;       // NTP 是否同步成功

// V4 3键状态 (保留旧变量名兼容)
bool lastVoice = HIGH, lastWater = HIGH, lastBack = HIGH;

// 录音长按追踪
unsigned long voicePressStart = 0;
bool voiceLongDetected = false;  // 已触发长按, 避免松手时重复触发短按

String lastTimeStr = "";   // 用于检测时间是否变化，避免重复刷新
unsigned long lastNtpRetry = 0;  // NTP 重试计时

// 每餐热量
#define CAL_BREAKFAST 400
#define CAL_LUNCH     600
#define CAL_DINNER    700
#define CAL_SNACK     150
#define CAL_SUPPER    300

// ===== 健康数据 =====
int waterTotalMl = 0;
int waterGoalMl = 2000;
int calorieTotal = 0;
int calorieGoal = 1800;
unsigned long lastProgressUpdate = 0;

// ===== 首页展示数据 =====
String lastFoodName = "";       // 最近一条饮食记录-食物名
int lastFoodCal = 0;            // 最近一条饮食记录-卡路里
String lastFoodTime = "";       // 最近一条饮食记录-时间 HH:MM
int mealRecordedToday[5] = {0}; // 今日各餐次是否已记录[早餐,午餐,晚餐,加餐,夜宵]
unsigned long lastMealFetchMs = 0;

// ===== 饭点帧差监控调度 =====
// 饭点窗口：早餐 06:30-09:00 / 午餐 11:00-14:00 / 晚餐 17:00-20:00
// 仅在饭点窗口内开启 CAM 帧差检测，本窗口已拍照则不再开
static bool motionActive = false;
static bool photoTakenThisWindow = false;  // 本饭点窗口已拍照 → 不再开启监控
static unsigned long lastMealtimeCheck = 0;
#define MEALTIME_CHECK_MS  10000  // 每10秒检查一次是否在饭点

static bool isMealTime() {
    struct tm timeinfo;
    if (!getLocalTime(&timeinfo)) return false;
    int mins = timeinfo.tm_hour * 60 + timeinfo.tm_min;

    if (mins >= 6*60+30 && mins < 9*60)   return true;  // 早餐 06:30-09:00
    if (mins >= 11*60    && mins < 14*60)  return true;  // 午餐 11:00-14:00
    if (mins >= 17*60    && mins < 20*60)  return true;  // 晚餐 17:00-20:00
    return false;
}

// ===== 获取今日日期字符串 "YYYY-MM-DD" =====
String getTodayStr() {
    struct tm timeinfo;
    if (!getLocalTime(&timeinfo)) return "2026-06-19";  // NTP 未同步时的 fallback
    char buf[11];
    strftime(buf, sizeof(buf), "%Y-%m-%d", &timeinfo);
    return String(buf);
}

// ===== NTP 同步（北京时间 UTC+8）=====
void syncNTP() {
    Serial.println("Syncing NTP...");
    // UTC+8 = 8*3600 = 28800 秒，无夏令时
    configTime(8 * 3600, 0, "ntp.aliyun.com", "ntp1.aliyun.com", "pool.ntp.org");
    Serial.println("NTP config done, waiting for sync...");

    struct tm timeinfo;
    int retry = 0;
    while (!getLocalTime(&timeinfo) && retry < 30) {  // 最多等 15 秒
        delay(500);
        Serial.print(".");
        retry++;
    }

    if (getLocalTime(&timeinfo)) {
        ntpOk = true;
        char timeBuf[24];
        strftime(timeBuf, sizeof(timeBuf), "%Y-%m-%d %H:%M:%S", &timeinfo);
        Serial.printf("\nNTP OK: %s (UTC+8)\n", timeBuf);
    } else {
        ntpOk = false;
        Serial.println("\nNTP FAIL after retries");
    }
}

// ===== 设备配对 (替代旧 loginAPI) =====
#include <Preferences.h>
Preferences prefs;

String pairingCode = "";   // 当前显示的配对码

// 获取设备唯一标识 (MAC 地址)
String getDeviceKey() {
    return WiFi.macAddress();
}

// 从 NVS 加载已保存的 device_token
void loadDeviceToken() {
    prefs.begin("dietai", true);  // readonly
    accessToken = prefs.getString("device_token", "");
    prefs.end();
}

// 保存 device_token 到 NVS
void saveDeviceToken(const String& token) {
    prefs.begin("dietai", false);
    prefs.putString("device_token", token);
    prefs.end();
}

// 清除 NVS 中的 device_token
void clearDeviceToken() {
    prefs.begin("dietai", false);
    prefs.remove("device_token");
    prefs.end();
    accessToken = "";
}

// 请求配对码 (如果设备已绑定, 可能直接返回 device_token)
bool requestPairingCode() {
    HTTPClient http;
    http.begin(String(API_BASE) + "/device/request-pairing");
    http.addHeader("Content-Type", "application/json");
    String body = "{\"device_key\":\"" + getDeviceKey() + "\"}";
    int code = http.POST(body);
    if (code != 200) {
        Serial.printf("[Pairing] request-pairing HTTP %d\n", code);
        http.end();
        return false;
    }
    String resp = http.getString();
    http.end();

    // 检查是否已绑定 (服务端直接返回 device_token)
    if (resp.indexOf("\"bound\":true") >= 0) {
        int ts = resp.indexOf("\"device_token\":\"");
        if (ts >= 0) {
            ts += 16;
            int te = resp.indexOf("\"", ts);
            accessToken = resp.substring(ts, te);
            saveDeviceToken(accessToken);
            Serial.printf("[Pairing] Already bound! token len=%d\n", accessToken.length());
            return true;  // 已有 token, 直接可用
        }
    }

    // 解析 pairing_code
    int pc = resp.indexOf("\"pairing_code\":\"");
    if (pc < 0) return false;
    pc += 16;
    int pe = resp.indexOf("\"", pc);
    pairingCode = resp.substring(pc, pe);
    Serial.printf("[Pairing] code=%s\n", pairingCode.c_str());
    return true;
}

// 轮询配对状态, 绑定成功返回 true
bool pollPairing() {
    HTTPClient http;
    http.begin(String(API_BASE) + "/device/poll-pairing");
    http.addHeader("Content-Type", "application/json");
    String body = "{\"device_key\":\"" + getDeviceKey() + "\"}";
    int code = http.POST(body);
    if (code != 200) { http.end(); return false; }
    String resp = http.getString();
    http.end();
    // 检查 bound:true
    if (resp.indexOf("\"bound\":true") >= 0) {
        // 提取 device_token
        int ts = resp.indexOf("\"device_token\":\"");
        if (ts < 0) return false;
        ts += 16;
        int te = resp.indexOf("\"", ts);
        accessToken = resp.substring(ts, te);
        saveDeviceToken(accessToken);
        Serial.printf("[Pairing] Bound! token len=%d\n", accessToken.length());
        return true;
    }
    return false;
}

// 设备认证入口 (替代旧 loginAPI)
bool deviceAuth() {
    // 1. 尝试 NVS 中保存的 device_token
    if (accessToken.length() == 0) loadDeviceToken();

    if (accessToken.length() > 0) {
        // 验证 token 是否仍有效 (用任意 API 测试)
        HTTPClient http;
        http.begin(String(API_BASE) + "/users/me");
        http.addHeader("Authorization", "Bearer " + accessToken);
        int code = http.GET();
        http.end();
        if (code == 200) {
            Serial.println("[Auth] device_token OK");
            return true;
        }
        // 401 = token 过期/无效, 需要重新配对
        Serial.printf("[Auth] device_token HTTP %d, re-pairing\n", code);
        clearDeviceToken();
    }

    // 2. 请求配对码
    if (!requestPairingCode()) return false;

    // 3. 在主循环中显示配对码 + 轮询 (由 loop 驱动)
    return false;  // 返回 false, 主循环会进入配对码显示+轮询模式
}

// 兼容旧代码的 loginAPI: 配对模式下直接返回有无 token, 不重复请求配对码
bool loginAPI() {
    if (accessToken.length() > 0) return true;   // 有 token, OK
    if (pairingCode.length() > 0) return false;  // 正在配对中, 不要重新请求
    return deviceAuth();  // 首次, 走完整配对流程
}

// ===== API: 记录饮水 =====
bool recordWater(int ml) {
    if (!accessToken.length()) return false;
    HTTPClient http;
    http.begin(String(API_BASE) + "/water/records");
    http.addHeader("Content-Type", "application/json");
    http.addHeader("Authorization", "Bearer " + accessToken);
    int code = http.POST("{\"amount_ml\":" + String(ml) + ",\"drink_type\":\"water\"}");
    http.end();
    if (code == 401) { accessToken = ""; return false; }
    Serial.printf("recordWater code: %d\n", code);
    return (code == 200 || code == 201);
}

// ===== API: 记录餐食 (含卡路里) =====
bool recordMeal(int mealType, const char* mealName, int calories = 0) {
    if (!accessToken.length()) return false;
    HTTPClient http;
    http.begin(String(API_BASE) + "/foods/records/traditional");
    http.addHeader("Content-Type", "application/json");
    http.addHeader("Authorization", "Bearer " + accessToken);

    String today = getTodayStr();
    String body = "{\"record_date\":\"" + today + "\",";
    body += "\"meal_type\":" + String(mealType) + ",";
    body += "\"food_name\":\"" + String(mealName) + "\",";
    body += "\"recording_method\":1,";
    body += "\"estimated_calories\":" + String(calories) + "}";

    Serial.printf("recordMeal: %s\n", body.c_str());
    int code = http.POST(body);
    http.end();
    if (code == 401) { accessToken = ""; return false; }
    Serial.printf("recordMeal code: %d\n", code);
    return (code == 200 || code == 201);
}

// ===== 页面状态 (前向声明, connectWiFi 需要) =====
int currentPage = 0;  // 0=HOME, 1=VOICE, 2=PAIRING

// ===== WiFi =====
void connectWiFi() {
    Serial.printf("WiFi: %s\n", WIFI_SSID);
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    int a = 0;
    while (WiFi.status() != WL_CONNECTED && a < 20) { delay(500); Serial.print("."); a++; }
    wifiOk = (WiFi.status() == WL_CONNECTED);
    if (wifiOk) {
        Serial.printf("\nIP: %s\n", WiFi.localIP().toString().c_str());
        if (loginAPI()) {
            Serial.println("Login OK");
        } else if (pairingCode.length() > 0) {
            // 需要配对, 显示配对码页面
            currentPage = 2;
            Serial.println("Pairing required, showing code");
        } else {
            Serial.println("Login fail");
        }
        // WiFi 连上后立即同步 NTP
        syncNTP();
    } else {
        Serial.println("\nWiFi fail");
    }
}

// ===== API: 查询今日饮水进度 =====
bool fetchWaterProgress() {
    if (!accessToken.length()) {
        Serial.println("[WATER] No token, skip fetch");
        return false;
    }
    HTTPClient http;
    String today = getTodayStr();
    String url = String(API_BASE) + "/water/daily-summary/" + today;
    Serial.printf("[WATER] GET %s\n", url.c_str());
    http.begin(url);
    http.addHeader("Authorization", "Bearer " + accessToken);
    int code = http.GET();
    Serial.printf("[WATER] HTTP %d\n", code);
    if (code == 401) { accessToken = ""; http.end(); return false; }
    if (code != 200) {
        Serial.printf("[WATER] Body: %s\n", http.getString().c_str());
        http.end(); return false;
    }
    String resp = http.getString(); http.end();
    Serial.printf("[WATER] Resp(%d): %s\n", resp.length(), resp.substring(0, 120).c_str());

    // 解析 total_intake_ml 和 daily_goal_ml
    int ti = resp.indexOf("\"total_intake_ml\":");
    int dg = resp.indexOf("\"daily_goal_ml\":");
    if (ti < 0 || dg < 0) {
        Serial.println("[WATER] Key not found in JSON");
        return false;
    }
    ti += 18;  // len("\"total_intake_ml\":") = 18
    dg += 16;  // len("\"daily_goal_ml\":") = 16
    int tiEnd = resp.indexOf(',', ti);
    if (tiEnd < 0) tiEnd = resp.indexOf('}', ti);
    int dgEnd = resp.indexOf(',', dg);
    if (dgEnd < 0) dgEnd = resp.indexOf('}', dg);
    waterTotalMl = resp.substring(ti, tiEnd).toInt();
    waterGoalMl = resp.substring(dg, dgEnd).toInt();
    if (waterGoalMl <= 0) waterGoalMl = 2000;
    Serial.printf("[WATER] Parsed: %d/%d ml\n", waterTotalMl, waterGoalMl);
    return true;
}

// ===== API: 查询今日热量进度 =====
bool fetchCalorieProgress() {
    if (!accessToken.length()) {
        Serial.println("[CAL] No token, skip fetch");
        return false;
    }
    HTTPClient http;
    String today = getTodayStr();
    String url = String(API_BASE) + "/foods/daily-summary/" + today;
    Serial.printf("[CAL] GET %s\n", url.c_str());
    http.begin(url);
    http.addHeader("Authorization", "Bearer " + accessToken);
    int code = http.GET();
    Serial.printf("[CAL] HTTP %d\n", code);
    if (code == 401) { accessToken = ""; http.end(); return false; }
    if (code != 200) {
        Serial.printf("[CAL] Body: %s\n", http.getString().c_str());
        http.end(); return false;
    }
    String resp = http.getString(); http.end();
    Serial.printf("[CAL] Resp(%d): %s\n", resp.length(), resp.substring(0, 120).c_str());

    // 解析 total_calories
    int tc = resp.indexOf("\"total_calories\":");
    if (tc < 0) {
        Serial.println("[CAL] Key 'total_calories' not found in JSON");
        return false;
    }
    tc += 17;
    int tcEnd = resp.indexOf(',', tc);
    if (tcEnd < 0) tcEnd = resp.indexOf('}', tc);
    calorieTotal = resp.substring(tc, tcEnd).toInt();
    Serial.printf("[CAL] Parsed: %d/%d kcal\n", calorieTotal, calorieGoal);
    return true;
}

// ===== API: 查询最新饮食记录 + 今日各餐次状态 =====
bool fetchHomeData() {
    if (!accessToken.length()) return false;
    HTTPClient http;
    String today = getTodayStr();
    String url = String(API_BASE) + "/foods/records?record_date=" + today + "&page_size=20";
    http.begin(url);
    http.addHeader("Authorization", "Bearer " + accessToken);
    int code = http.GET();
    if (code == 401) { accessToken = ""; http.end(); return false; }
    if (code != 200) { http.end(); return false; }
    String resp = http.getString(); http.end();

    // 重置餐次状态
    for (int i = 0; i < 5; i++) mealRecordedToday[i] = 0;

    // 后端按时间倒序返回, records[0] 即最新记录 → 只解析第一条为"最近记录",
    // 其余记录仅统计餐次。以 "record_time":" 定位每条记录 (summary 中无该字段, 不会误匹配)。
    String latestName = "";
    int latestCal = 0;
    String latestTime = "";
    bool first = true;

    int pos = 0;
    while (true) {
        int rtPos = resp.indexOf("\"record_time\":\"", pos);
        if (rtPos < 0) break;

        // 本记录 meal_type (record_time 之后, food_name 之前)
        int mtPos = resp.indexOf("\"meal_type\":", rtPos);
        int mType = 0;
        if (mtPos >= 0) {
            int mtVal = mtPos + 12;
            int mtEnd = resp.indexOf(',', mtVal);
            if (mtEnd < 0) mtEnd = resp.indexOf('}', mtVal);
            mType = resp.substring(mtVal, mtEnd).toInt();
            if (mType >= 1 && mType <= 5) mealRecordedToday[mType - 1] = 1;
        }

        if (first) {
            // 第一条 = 最新记录
            // record_time: "2026-08-25T16:36:54" → "16:36"
            int rtVal = rtPos + 15;
            int rtEnd = resp.indexOf('"', rtVal);
            if (rtEnd > rtVal) {
                String rtFull = resp.substring(rtVal, rtEnd);
                int tPos = rtFull.indexOf('T');
                if (tPos >= 0) latestTime = rtFull.substring(tPos + 1, tPos + 6);
            }
            // food_name
            int fnPos = resp.indexOf("\"food_name\":\"", rtPos);
            if (fnPos >= 0) {
                fnPos += 13;
                int fnEnd = resp.indexOf('"', fnPos);
                if (fnEnd > fnPos) latestName = resp.substring(fnPos, fnEnd);
            }
            // calories: 仅取本记录 nutrition_detail 内的值 (analysis_result 的 calories 忽略)
            int nextRt = resp.indexOf("\"record_time\":\"", rtPos + 15);
            int ndPos = resp.indexOf("\"nutrition_detail\":", rtPos);
            if (ndPos >= 0 && (nextRt < 0 || ndPos < nextRt)) {
                int calPos = resp.indexOf("\"calories\":", ndPos);
                if (calPos >= 0 && (nextRt < 0 || calPos < nextRt)) {
                    calPos += 11;
                    int calEnd = resp.indexOf(',', calPos);
                    if (calEnd < 0) calEnd = resp.indexOf('}', calPos);
                    latestCal = resp.substring(calPos, calEnd).toInt();
                }
            }
            first = false;
        }
        pos = rtPos + 15;
    }

    if (latestName.length() > 0) {
        lastFoodName = latestName;
        lastFoodCal = latestCal;
        lastFoodTime = latestTime;
    }
    Serial.printf("[HOME] meals: %d/%d/%d/%d/%d  last=%s %dkcal %s\n",
        mealRecordedToday[0], mealRecordedToday[1], mealRecordedToday[2],
        mealRecordedToday[3], mealRecordedToday[4],
        lastFoodName.c_str(), lastFoodCal, lastFoodTime.c_str());
    return true;
}

// ===== 刷新所有进度 =====
void refreshProgress() {
    // 饮水：从 API 同步校正
    bool w = fetchWaterProgress();
    if (!w && !accessToken.length()) {
        if (loginAPI()) fetchWaterProgress();
    }
    // 热量：从 API 同步
    fetchCalorieProgress();
    // 首页数据：餐次状态 + 最近记录
    fetchHomeData();
}

// ===== 蜂鸣器 =====
// 短鸣一声（按键反馈）
void beepShort() {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(50);
    digitalWrite(BUZZER_PIN, LOW);
}

// 成功音（两声短鸣）
void beepSuccess() {
    digitalWrite(BUZZER_PIN, HIGH); delay(80);
    digitalWrite(BUZZER_PIN, LOW);  delay(60);
    digitalWrite(BUZZER_PIN, HIGH); delay(80);
    digitalWrite(BUZZER_PIN, LOW);
}

// 失败音（一声长鸣）
void beepFail() {
    digitalWrite(BUZZER_PIN, HIGH); delay(300);
    digitalWrite(BUZZER_PIN, LOW);
}

// 前向声明
void drawAll();
void drawStatusBar();
void drawClock();
void drawHomeProgress();
void drawVoicePage();
// 前向声明结束

// ===== 首页布局常量 =====
#define STATUS_H     20   // 状态栏高度
#define CLOCK_Y       20   // 时间起始Y
#define CLOCK_H       62   // 时间区高度
#define HOME_CONTENT_Y 67  // 内容区起始Y (对齐原宠物位置, 白底覆盖旧宠物残留)
#define PROGRESS_X    210  // 进度区起始X
#define PROGRESS_W    255  // 进度区宽度
#define PROGRESS_BAR_W 230 // 进度条宽度
#define PROGRESS_BAR_H 14  // 进度条高度
#define CLOCK_TRANSP 0xF81F  // 透明色键 (品红, R=B 对称 → 色序无关)
// 本板 ILI9488: tft.fillRect/setTextColor 等 API 由 LovyanGFX 内部处理 RGB→BGR,
// 直接写标准 RGB565 即可 (§8.3)。首页"今日进度"面板不做不透明卡片底,
// 改用背景 tile 还原该区背景 + 透明底文字, 使面板背景透明。

unsigned long lastClockCheck = 0;

void drawClock() {
    struct tm timeinfo;
    if (!getLocalTime(&timeinfo)) {
        if (lastTimeStr == "--:--") return;
        lastTimeStr = "--:--";
        LGFX_Sprite clockSpr(&tft);
        clockSpr.setColorDepth(16);
        if (!clockSpr.createSprite(480, 62)) return;
        clockSpr.fillScreen(CLOCK_TRANSP);
        clockSpr.setTextColor(TFT_DARKGREY, CLOCK_TRANSP);
        clockSpr.setTextSize(6);
        clockSpr.drawString("--:--", 165, 2);
        clockSpr.pushSprite(0, CLOCK_Y, CLOCK_TRANSP);
        clockSpr.deleteSprite();
        return;
    }

    char timeStr[6];
    strftime(timeStr, sizeof(timeStr), "%H:%M", &timeinfo);

    if (String(timeStr) == lastTimeStr) return;
    lastTimeStr = String(timeStr);

    // CAM 接收数据时跳过全屏重绘
    if (!camReceiving) {
        drawAll();
        drawStatusBar();
    }

    LGFX_Sprite clockSpr(&tft);
    clockSpr.setColorDepth(16);
    if (!clockSpr.createSprite(480, 62)) {
        Serial.println("Clock sprite OOM!");
        return;
    }
    clockSpr.fillScreen(CLOCK_TRANSP);

    // 时间 — 大字居中黑字 (size7≈56px, 5字符≈280px, x=(480-280)/2=100)
    clockSpr.setTextColor(TFT_BLACK, CLOCK_TRANSP);
    clockSpr.setTextSize(7);
    clockSpr.drawString(timeStr, 100, 0);

    clockSpr.pushSprite(0, CLOCK_Y, CLOCK_TRANSP);
    clockSpr.deleteSprite();
}

// ===== 界面：顶部状态栏 (480×20, 透明底) =====
unsigned long lastStatusUpdate = 0;

static void drawPillText(LGFX_Sprite& s, const String& t, int x, int y, uint16_t fg) {
    int tw = t.length() * 6;
    s.fillRect(x - 1, y - 1, tw + 2, 10, TFT_BLACK);
    s.setTextColor(fg, TFT_BLACK);
    s.drawString(t, x, y);
}

void drawStatusBar() {
    LGFX_Sprite barSpr(&tft);
    barSpr.setColorDepth(16);
    if (!barSpr.createSprite(480, 20)) {
        Serial.println("StatusBar sprite OOM!");
        return;
    }
    barSpr.fillScreen(CLOCK_TRANSP);
    barSpr.setTextSize(1);

    // 左侧：WiFi 信号条 + dBm
    int rssi = wifiOk ? WiFi.RSSI() : -100;
    int bars = 0;
    if (rssi > -50)      bars = 4;
    else if (rssi > -60) bars = 3;
    else if (rssi > -70) bars = 2;
    else if (rssi > -80) bars = 1;

    for (int i = 0; i < 4; i++) {
        int barH = 3 + i * 2;
        uint16_t color = (i < bars && wifiOk) ? TFT_GREEN : TFT_DARKGREY;
        barSpr.fillRect(3 + i * 6 - 1, 20 - barH - 3 - 1, 7, barH + 2, TFT_BLACK);
        barSpr.fillRect(3 + i * 6, 20 - barH - 3, 5, barH, color);
    }
    if (wifiOk) {
        drawPillText(barSpr, String(rssi) + "dBm", 30, 3, TFT_WHITE);
    } else {
        drawPillText(barSpr, "WiFi OFF", 30, 3, TFT_RED);
    }

    // 居中：日期+星期 (efontCN_16)
    struct tm timeinfo;
    if (getLocalTime(&timeinfo)) {
        char dateStr[20];
        snprintf(dateStr, sizeof(dateStr), "%s %d/%d",
                 weekdayCN(timeinfo.tm_wday),
                 timeinfo.tm_mon + 1, timeinfo.tm_mday);
        // efontCN_16: 每字符约16px宽, "周六 8/20" 约 5+1+4=10字符 ≈ 160px
        // 居中: (480-160)/2 = 160
        barSpr.setFont(&fonts::efontCN_16);
        barSpr.setTextSize(1);
        barSpr.setTextColor(TFT_WHITE, TFT_BLACK);
        barSpr.drawString(dateStr, 160, 2);
        barSpr.setFont(nullptr);
    }

    // 右侧：连接状态
    int rightX = 435;
    if (!wifiOk) {
        barSpr.fillRect(rightX + 2, 5, 6, 6, TFT_BLACK);
        barSpr.fillRect(rightX + 3, 6, 4, 4, TFT_RED);
        drawPillText(barSpr, "OFF", rightX + 12, 3, TFT_RED);
    } else if (!ntpOk) {
        barSpr.fillRect(rightX + 2, 5, 6, 6, TFT_BLACK);
        barSpr.fillRect(rightX + 3, 6, 4, 4, TFT_YELLOW);
        drawPillText(barSpr, "NTP..", rightX + 12, 3, TFT_YELLOW);
    } else {
        barSpr.fillRect(rightX + 2, 5, 6, 6, TFT_BLACK);
        barSpr.fillRect(rightX + 3, 6, 4, 4, TFT_GREEN);
        drawPillText(barSpr, "ON", rightX + 12, 3, TFT_GREEN);
    }

    barSpr.pushSprite(0, 0, CLOCK_TRANSP);
    barSpr.deleteSprite();
    lastStatusUpdate = millis();
}

// ===== 配对码轮询 =====
unsigned long lastPollTime = 0;
#define POLL_INTERVAL_MS 3000  // 每 3 秒轮询一次

// ===== VOICE 页状态 =====
#define VOICE_IDLE       0   // 等待按键说话
#define VOICE_RECORDING  1   // 录音中
#define VOICE_UPLOADING  2   // 上传识别中
#define VOICE_RESULT     3   // 显示识别结果
#define VOICE_PLAYING    4   // TTS 播报中
int voiceState = VOICE_IDLE;
unsigned long voiceRecStart = 0;   // 录音开始时间
unsigned long voiceRecDuration = 0; // 录音时长(ms)
String voiceResultText = "";       // 识别文字
#define VOICE_MAX_MS  15000       // 最长录音 15 秒
#define VOICE_X         0
#define VOICE_Y         0
#define VOICE_W       480
#define VOICE_H       320
#define VOICE_TITLE_H  28
#define VOICE_BOTTOM_H 36

// ===== 首页右侧：进度条 + 餐次状态 + 最近记录 (透明面板, 背景透出) =====
unsigned long lastHomeProgressUpdate = 0;

void drawHomeProgress() {
    // 透明面板: 先用背景 tile 还原该区草原背景(擦掉旧文字/进度条),
    // 再以透明底文字叠加 → 面板"背景透明", 与整页背景融合
    tft.drawJpg(progress_bg_jpg, sizeof(progress_bg_jpg),
                PROGRESS_X, HOME_CONTENT_Y, PROGRESS_W, 320 - HOME_CONTENT_Y);

    int y = HOME_CONTENT_Y + 6;

    // 标题 "今日进度"
    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);
    tft.setTextColor(0x39E7);  // 深灰绿
    tft.drawString("今日进度", PROGRESS_X + 12, y);
    tft.setFont(nullptr);
    y += 22;

    // --- 卡路里进度 ---
    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);
    tft.setTextColor(TFT_BLACK);
    tft.drawString("热量", PROGRESS_X + 8, y);
    tft.setFont(nullptr);
    y += 20;

    // 进度条背景
    tft.fillRect(PROGRESS_X + 8, y, PROGRESS_BAR_W, PROGRESS_BAR_H, TFT_LIGHTGREY);
    // 进度条填充
    int calPct = (calorieGoal > 0) ? (calorieTotal * PROGRESS_BAR_W / calorieGoal) : 0;
    if (calPct > PROGRESS_BAR_W) calPct = PROGRESS_BAR_W;
    if (calPct < 0) calPct = 0;
    uint16_t calColor = (calPct >= PROGRESS_BAR_W) ? 0x07E0 : 0xFD20;  // green : orange
    if (calPct > 0) tft.fillRect(PROGRESS_X + 8, y, calPct, PROGRESS_BAR_H, calColor);
    y += PROGRESS_BAR_H + 4;

    // 数字 "1360 / 2000 kcal"
    tft.setTextSize(2);
    tft.setTextColor(TFT_DARKGREY);
    tft.drawString(String(calorieTotal) + " / " + String(calorieGoal) + " kcal", PROGRESS_X + 8, y);
    y += 28;

    // --- 饮水进度 ---
    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);
    tft.setTextColor(TFT_BLACK);
    tft.drawString("饮水", PROGRESS_X + 8, y);
    tft.setFont(nullptr);
    y += 20;

    tft.fillRect(PROGRESS_X + 8, y, PROGRESS_BAR_W, PROGRESS_BAR_H, TFT_LIGHTGREY);
    int waterPct = (waterGoalMl > 0) ? (waterTotalMl * PROGRESS_BAR_W / waterGoalMl) : 0;
    if (waterPct > PROGRESS_BAR_W) waterPct = PROGRESS_BAR_W;
    if (waterPct < 0) waterPct = 0;
    if (waterPct > 0) tft.fillRect(PROGRESS_X + 8, y, waterPct, PROGRESS_BAR_H, 0xF800);  // BGR 屏红蓝反置: 0xF800 实际显示为蓝色
    y += PROGRESS_BAR_H + 4;

    tft.setTextSize(2);
    tft.setTextColor(TFT_DARKGREY);
    tft.drawString(String(waterTotalMl) + " / " + String(waterGoalMl) + " ml", PROGRESS_X + 8, y);
    y += 32;

    // --- 最近一条饮食记录 ---
    if (lastFoodName.length() > 0) {
        tft.setFont(&fonts::efontCN_16);
        tft.setTextSize(1);
        tft.setTextColor(TFT_DARKGREY);
        String lastStr = "上次: " + lastFoodName;
        if (lastFoodCal > 0) lastStr += " ~" + String(lastFoodCal) + "kcal";
        if (lastFoodTime.length() > 0) lastStr += " " + lastFoodTime;
        tft.drawString(lastStr, PROGRESS_X + 8, y + 2);
        tft.setFont(nullptr);
    }

    lastHomeProgressUpdate = millis();
}

// ===== VOICE 页：语音录音界面 =====
// 四个子状态：IDLE / RECORDING / UPLOADING / RESULT
// 注意：ESP32 字体不含 emoji，所有图标用手绘形状 + 纯文字

// ---- 手绘小图标 ----

// 麦克风图标: 圆角矩形机身 + 底部横条 + 支架
static void drawMicIcon(int cx, int cy, uint16_t color) {
    tft.fillRoundRect(cx-5, cy-7, 10, 13, 4, color);  // 机身
    tft.fillRect(cx-7, cy+6, 14, 3, color);            // 底部横条
    tft.fillRect(cx-1, cy+9, 2, 5, color);             // 支架
}

// 对勾图标 (✓) : 两条相交短线
static void drawCheckIcon(int cx, int cy, uint16_t color) {
    for (int t = -1; t <= 1; t++) {
        tft.drawLine(cx-5, cy+t, cx, cy+5+t, color);
        tft.drawLine(cx, cy+5+t, cx+7, cy-4+t, color);
    }
}

// 叉号图标 (✕) : X 形
static void drawXIcon(int cx, int cy, uint16_t color) {
    for (int t = -1; t <= 1; t++) {
        tft.drawLine(cx-5+t, cy-5, cx+5+t, cy+5, color);
        tft.drawLine(cx+5+t, cy-5, cx-5+t, cy+5, color);
    }
}

// ---- 标题栏 (纯文字, 不用 emoji) ----
static void drawVoiceTitle(const char* title, uint16_t bgColor) {
    tft.fillRect(VOICE_X, VOICE_Y, VOICE_W, VOICE_TITLE_H, bgColor);
    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);
    tft.setTextColor(TFT_WHITE, bgColor);
    tft.drawString(title, 8, 6);
    tft.setFont(nullptr);
}

// ---- IDLE: 等待说话 ----
void drawVoiceIdle() {
    drawVoiceTitle("语音记录", TFT_BLACK);

    // 中央白底
    tft.fillRect(0, VOICE_TITLE_H, VOICE_W, VOICE_H - VOICE_TITLE_H - VOICE_BOTTOM_H, TFT_WHITE);

    // 手绘大麦克风
    int cx = VOICE_W / 2, cy = 125;
    tft.fillCircle(cx, cy-10, 16, TFT_DARKGREY);        // 圆形头部
    tft.fillRect(cx-14, cy-10, 28, 24, TFT_DARKGREY);  // 机身
    tft.fillRoundRect(cx-14, cy-10, 28, 24, 6, TFT_DARKGREY);
    tft.fillRect(cx-18, cy+14, 36, 6, TFT_DARKGREY);   // 底部横条
    tft.fillRect(cx-2, cy+20, 4, 10, TFT_DARKGREY);    // 支架

    // 提示文字
    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);
    tft.setTextColor(TFT_BLACK, TFT_WHITE);
    tft.drawString("按住 [语音键] 开始说话", 135, 175);

    tft.setTextColor(TFT_DARKGREY, TFT_WHITE);
    tft.drawString("最长可录制 15 秒, 松手自动识别", 115, 200);

    tft.setFont(nullptr);

    // 底部栏
    tft.fillRect(0, VOICE_H - VOICE_BOTTOM_H, VOICE_W, VOICE_BOTTOM_H, TFT_DARKGREY);
    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);
    tft.setTextColor(TFT_WHITE, TFT_DARKGREY);
    tft.drawString("[返回]", 12, VOICE_H - VOICE_BOTTOM_H + 10);
    tft.setFont(nullptr);
}

// ---- RECORDING: 录音中 ----
void drawVoiceRecording() {
    drawVoiceTitle("正在录音...", 0xCC0000);   // 深红标题栏

    tft.fillRect(0, VOICE_TITLE_H, VOICE_W, VOICE_H - VOICE_TITLE_H - VOICE_BOTTOM_H, TFT_WHITE);

    // 脉冲红点
    int pulseR = (millis() / 400) % 2 == 0 ? 18 : 12;
    tft.fillCircle(VOICE_W / 2, 115, pulseR, TFT_RED);

    // 录音进度条
    int barY = 170, barX = 50, barW = 380, barH = 10;
    tft.drawRect(barX, barY, barW, barH, TFT_DARKGREY);
    unsigned long elapsed = millis() - voiceRecStart;
    if (elapsed > VOICE_MAX_MS) elapsed = VOICE_MAX_MS;
    int fillW = (int)(barW * elapsed / VOICE_MAX_MS);
    if (fillW > 0) {
        uint16_t barColor = (elapsed > VOICE_MAX_MS - 3000) ? TFT_RED : 0x07E0;
        tft.fillRect(barX + 1, barY + 1, fillW - 2, barH - 2, barColor);
    }

    // 时间文字
    char timeStr[20];
    snprintf(timeStr, sizeof(timeStr), "%d:%02d / 0:15", (int)elapsed / 1000 / 60, (int)(elapsed / 1000) % 60);
    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);
    tft.setTextColor(TFT_BLACK, TFT_WHITE);
    tft.drawString(timeStr, VOICE_W / 2 - 40, barY + 18);

    // 提示
    tft.setTextColor(TFT_DARKGREY, TFT_WHITE);
    tft.drawString("\"请说出食物名称和份量...\"", 120, 220);

    tft.setFont(nullptr);

    // 底部提示
    tft.fillRect(0, VOICE_H - VOICE_BOTTOM_H, VOICE_W, VOICE_BOTTOM_H, TFT_DARKGREY);
    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);
    tft.setTextColor(TFT_WHITE, TFT_DARKGREY);
    tft.drawString("[松手停止]", VOICE_W / 2 - 40, VOICE_H - VOICE_BOTTOM_H + 10);
    tft.setFont(nullptr);
}

// ---- UPLOADING: 上传识别中 ----
void drawVoiceUploading() {
    drawVoiceTitle("正在识别...", TFT_BLACK);

    tft.fillRect(0, VOICE_TITLE_H, VOICE_W, VOICE_H - VOICE_TITLE_H - VOICE_BOTTOM_H, TFT_WHITE);

    // 旋转点动画: 3 个圆点循环亮起
    int active = (millis() / 250) % 3;
    for (int i = 0; i < 3; i++) {
        int r = (i == active) ? 5 : 3;
        uint16_t c = (i == active) ? 0x07E0 : TFT_DARKGREY;  // 绿色活动点
        tft.fillCircle(VOICE_W / 2 - 16 + i * 16, 115, r, c);
    }

    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);
    tft.setTextColor(TFT_BLACK, TFT_WHITE);
    tft.drawString("正在上传并识别语音...", 145, 170);
    tft.setTextColor(TFT_DARKGREY, TFT_WHITE);
    tft.drawString("请稍候，约需 1-3 秒", 150, 195);
    tft.setFont(nullptr);

    tft.fillRect(0, VOICE_H - VOICE_BOTTOM_H, VOICE_W, VOICE_BOTTOM_H, TFT_DARKGREY);
}

// ---- RESULT: 显示识别+分析结果 ----
void drawVoiceResult() {
    // 标题栏 (复用已验证的 drawVoiceTitle)
    drawVoiceTitle("识别结果", 0x0580);  // 适中暗绿

    // 内容白底
    int contentY = VOICE_TITLE_H;
    int contentH = VOICE_H - VOICE_TITLE_H - VOICE_BOTTOM_H;
    tft.fillRect(0, contentY, VOICE_W, contentH, TFT_WHITE);

    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);

    int y = contentY + 16;

    // --- ASR 原文 ---
    String asrText = voiceResultText;
    int nl = asrText.indexOf('\n');
    if (nl > 0) asrText = asrText.substring(0, nl);
    tft.setTextColor(TFT_BLACK, TFT_WHITE);
    tft.drawString(asrText, 24, y);
    y += 30;

    // --- 分隔线 ---
    tft.drawLine(30, y, VOICE_W - 30, y, TFT_LIGHTGREY);
    y += 16;

    if (mic_food_items.length() > 0 || mic_food_cal > 0) {
        // --- 食物名 (加粗效果: 画两遍偏移1px) ---
        tft.setTextColor(TFT_BLACK, TFT_WHITE);
        String items = mic_food_items;
        tft.drawString(items, 25, y);
        y += 28;

        // --- 热量: 大字 ---
        if (mic_food_cal > 0) {
            tft.setFont(nullptr);
            tft.setTextSize(2);
            tft.setTextColor(0xCC4400, TFT_WHITE);
            tft.drawString(String(mic_food_cal) + " kcal", 24, y);
            tft.setTextSize(1);
            tft.setFont(&fonts::efontCN_16);
            y += 38;
        }

        // --- 短评: 每27字换行 ---
        if (mic_food_comment.length() > 0 && y < contentY + contentH - 24) {
            y += 4;
            tft.drawLine(60, y, VOICE_W - 60, y, TFT_LIGHTGREY);
            y += 14;
            tft.setTextColor(0x666666, TFT_WHITE);
            int cpl = 81;  // 27中文×3字节, UTF-8 substring 按字节截取
            for (int i = 0; i < (int)mic_food_comment.length() && y < contentY + contentH - 16; i += cpl) {
                tft.drawString(mic_food_comment.substring(i, i + cpl), 24, y);
                y += 22;
            }
        }
    } else {
        tft.setTextColor(TFT_DARKGREY, TFT_WHITE);
        tft.drawString("(等待 AI 分析...)", 24, y);
    }

    // --- 底部操作栏 (三按钮: 确认 | TTS播报 | 取消) ---
    tft.fillRect(0, VOICE_H - VOICE_BOTTOM_H, VOICE_W, VOICE_BOTTOM_H, TFT_BLACK);
    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);
    // 左: [语音] 确认记录 (绿色)
    tft.setTextColor(0x07E0, TFT_BLACK);
    tft.drawString("[语音] 确认记录", 14, VOICE_H - VOICE_BOTTOM_H + 10);
    // 中: [饮水] TTS播报 (蓝色)
    tft.setTextColor(0x06BF, TFT_BLACK);
    tft.drawString("[饮水] TTS播报", 188, VOICE_H - VOICE_BOTTOM_H + 10);
    // 右: [返回] 取消 (白色)
    tft.setTextColor(TFT_WHITE, TFT_BLACK);
    tft.drawString("[返回] 取消", VOICE_W - 140, VOICE_H - VOICE_BOTTOM_H + 10);
    tft.setFont(nullptr);
}

// ---- PLAYING: TTS 播报中 ----
void drawVoicePlaying() {
    drawVoiceTitle("正在播报...", 0x0660);  // 深青色标题栏

    int contentY = VOICE_TITLE_H;
    int contentH = VOICE_H - VOICE_TITLE_H - VOICE_BOTTOM_H;
    tft.fillRect(0, contentY, VOICE_W, contentH, TFT_WHITE);

    // 喇叭图标 + 动画声波
    int cx = VOICE_W / 2 - 20, cy = 115;
    // 喇叭机身
    tft.fillRect(cx-10, cy-12, 20, 16, TFT_DARKGREY);
    tft.fillTriangle(cx-10, cy-12, cx-10, cy+4, cx-20, cy-8, TFT_DARKGREY);
    // 脉冲声波 (3个右括号形状, 交替闪烁)
    int phase = (millis() / 300) % 3;
    for (int i = 0; i < 3; i++) {
        int x = cx + 14 + i * 10;
        uint16_t col = (i == phase) ? 0x07E0 : TFT_LIGHTGREY;
        int h = 8 + i * 6;
        // 画竖线模拟声波
        tft.drawLine(x, cy - h/2, x, cy + h/2, col);
        if (i == phase) {
            tft.drawLine(x+1, cy - h/2 + 2, x+1, cy + h/2 - 2, col);
        }
    }

    // 播报文字
    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);
    tft.setTextColor(TFT_BLACK, TFT_WHITE);
    String ttsPreview = mic_food_items;
    if (ttsPreview.length() > 54) ttsPreview = ttsPreview.substring(0, 51) + "...";
    tft.drawString("播报: " + ttsPreview, 30, 165);

    tft.setTextColor(TFT_DARKGREY, TFT_WHITE);
    tft.drawString("播放中, 请稍候...", 175, 192);
    tft.setFont(nullptr);

    // 底部栏
    tft.fillRect(0, VOICE_H - VOICE_BOTTOM_H, VOICE_W, VOICE_BOTTOM_H, TFT_BLACK);
    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);
    tft.setTextColor(0xCC0000, TFT_BLACK);
    tft.drawString("[返回] 停止播报", VOICE_W / 2 - 56, VOICE_H - VOICE_BOTTOM_H + 10);
    tft.setFont(nullptr);
}

void drawVoicePage() {
    switch (voiceState) {
        case VOICE_IDLE:      drawVoiceIdle();      break;
        case VOICE_RECORDING: drawVoiceRecording(); break;
        case VOICE_UPLOADING: drawVoiceUploading(); break;
        case VOICE_RESULT:    drawVoiceResult();    break;
        case VOICE_PLAYING:   drawVoicePlaying();   break;
    }
}

// 刷新当前页面的热量显示（HOME→底部栏）
void refreshCalorieDisplay() {
    drawHomeProgress();
}

// ===== 宠物绘制 =====
// 每帧 tile 已把背景裁剪区烤进帧内, 用 drawJpg 覆盖该区域:
// 帧自带背景 → 无需重绘全屏、无精灵/透明键 → 无缝、不闪帧 (§10.1/§10.5)
// 注意: 不能用 pushImage 传 PROGMEM 指针 (§8.2 DMA 读不到 Flash → 花屏)
void drawPetFrame() {
    tft.drawJpg(petAnimFrame(&pet_normal_anim),
                petAnimFrameSize(&pet_normal_anim),
                PET_X, PET_Y, PET_W, PET_H);
}

// ===== 全量重绘 =====
void drawAll() {
    // 整屏背景图 (草原) — drawJpg 从 Flash 直解, §8.5 已预交换 R↔B
    tft.drawJpg(bg_jpg, sizeof(bg_jpg), 0, 0, BG_W, BG_H);
    // 绘制宠物第一帧
    drawPetFrame();
}

// ===== 配对码页面 (480x320) =====
void drawPairingPage() {
    tft.fillScreen(TFT_BLACK);

    // --- 标题: 中文用 efontCN ---
    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);
    tft.setTextColor(TFT_WHITE, TFT_BLACK);
    // 手动居中: "设备配对" 4个中文字约64px宽, x=(480-64)/2=208
    tft.drawString("设备配对", 208, 15);

    // --- 副标题 ---
    // "请在App中输入配对码" 约10字≈160px, x=(480-160)/2=160
    tft.drawString("请在App中输入配对码", 160, 55);

    // --- 6 位配对码: 用默认字体放大, 数字更清晰 ---
    tft.setFont(nullptr);         // 恢复默认内置字体
    tft.setTextSize(6);           // 6倍放大, 每个数字约 36px 宽
    tft.setTextColor(0x07FF, TFT_BLACK);  // 青色
    if (pairingCode.length() == 6) {
        // 分 3+3 两组, 间距 = 半个数字宽(18px)
        // 左组: 3数字=108px, 右组: 3数字=108px, 间距18px, 总=234px
        // 起始x = (480-234)/2 = 123
        String left3 = pairingCode.substring(0, 3);
        String right3 = pairingCode.substring(3, 6);
        tft.drawString(left3.c_str(), 123, 100);
        tft.drawString(right3.c_str(), 123 + 108 + 18, 100);  // 249
    } else {
        int16_t w = tft.textWidth(pairingCode.c_str());
        tft.drawString(pairingCode.c_str(), (480 - w) / 2, 100);
    }

    // --- 操作提示: 恢复中文字体 ---
    tft.setFont(&fonts::efontCN_16);
    tft.setTextSize(1);
    tft.setTextColor(TFT_YELLOW, TFT_BLACK);
    // "打开App-我的-设备绑定" 约11字≈176px, x=(480-176)/2=152
    tft.drawString("打开App - 我的 - 设备绑定", 130, 200);
    // "输入上方配对码完成绑定" 约11字≈176px
    tft.drawString("输入上方配对码完成绑定", 152, 225);

    // --- MAC 地址: 右下角 ---
    tft.setTextColor(0x8410, TFT_BLACK);  // 灰色
    String macStr = "MAC:" + getDeviceKey();
    int16_t macW = tft.textWidth(macStr.c_str());
    tft.drawString(macStr.c_str(), 475 - macW, 300);

    // 恢复默认字体
    tft.setFont(nullptr);
    tft.setTextSize(1);
}

// ===== 按键检测 =====
bool checkButton(int pin, bool &lastState) {
    bool cur = digitalRead(pin);
    if (lastState == HIGH && cur == LOW) {
        delay(30);
        if (digitalRead(pin) == LOW) {
            lastState = cur;
            return true;
        }
    }
    lastState = cur;
    return false;
}

// ===== Setup =====
void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("\n===== DietAI Clock + NTP + 3-Btn =====");

    tft.init();
    tft.setRotation(1);   // 横屏：480×320
    tft.setBrightness(255);

    pinMode(BTN_VOICE, INPUT_PULLUP);
    pinMode(BTN_WATER, INPUT_PULLUP);
    pinMode(BTN_BACK, INPUT_PULLUP);
    // GPIO6/16/17 已释放 (V4 语音替代餐食按键)

    // 蜂鸣器初始化
    pinMode(BUZZER_PIN, OUTPUT);
    digitalWrite(BUZZER_PIN, LOW);
    beepShort();  // 上电提示音

    // 启动界面（480×320 横屏居中）
    tft.fillScreen(TFT_BLACK);
    tft.setTextColor(TFT_WHITE);
    tft.setTextSize(2);
    tft.drawString("DietAI Booting...", 144, 140);
    tft.setTextSize(1);
    tft.drawString("Connecting WiFi...", 186, 170);

    // 初始化 CAM 串口通信
    if (cam_init()) {
        Serial.println("[CAM] UART1 init OK");
    } else {
        Serial.println("[CAM] UART1 init FAIL");
    }

    // 初始化 INMP441 I2S 麦克风
    if (i2s_mic_init()) {
        Serial.println("[MIC] I2S init OK");
    } else {
        Serial.println("[MIC] I2S init FAIL");
    }

    // MAX98357 I2S 功放: 延迟初始化, 使用时才启动 (避免空闲噪声)

    connectWiFi();
    if (wifiOk && currentPage != 2) refreshProgress();  // 连上后立即拉一次进度 (非配对模式)
    if (currentPage == 2) {
        drawPairingPage();  // 配对码页面
    } else {
        drawAll();
        drawStatusBar();                // 状态栏叠在背景上方
        drawClock();                    // 时间展示 (状态栏下方左侧)
        drawHomeProgress();                // 底部状态栏 (饮水+热量+Home)
    }
    Serial.println("Ready!");
}

// ===== Loop =====
void loop() {

    // --- 配对码模式: 轮询绑定状态 ---
    if (currentPage == 2 && wifiOk && pairingCode.length() > 0) {
        if (millis() - lastPollTime > POLL_INTERVAL_MS) {
            lastPollTime = millis();
            if (pollPairing()) {
                // 绑定成功! 回到首页
                pairingCode = "";
                currentPage = 0;
                drawAll();
                drawStatusBar();
                drawClock();
                drawHomeProgress();
                refreshProgress();
                Serial.println("[Pairing] -> HOME");
            } else {
                Serial.println("[Pairing] polling...");
            }
        }
    }

    // 处理 I2S 麦克风数据 (no-op 当未录音时)
    i2s_mic_poll();

    // 处理 I2S 功放播放 (no-op 当未播放时)
    if (spk_playing) {
        i2s_speaker_poll();
        // 播放完毕 → 自动返回 RESULT 页
        if (!spk_playing && voiceState == VOICE_PLAYING) {
            voiceState = VOICE_RESULT;
            drawVoicePage();
            Serial.println("[VOICE] TTS playback finished");
        }
    }

    // 处理 CAM 串口数据（JPEG 分片接收等）
    cam_process_incoming();

    // JPEG 传输完成后自动上传后端
    if (cam_is_transfer_done()) {
        Serial.println("[CAM] JPEG ready, uploading...");
        String resultJson;
        bool ok = cam_upload_jpeg(API_BASE, accessToken.c_str(), resultJson);
        // Token 过期 → 重登录 + 重试一次
        if (!ok && resultJson.indexOf("Not authenticated") >= 0) {
            if (loginAPI()) {
                Serial.println("[CAM] Re-login OK, retrying upload...");
                ok = cam_upload_jpeg(API_BASE, accessToken.c_str(), resultJson);
            }
        }
        if (ok) {
            Serial.printf("[CAM] AI result: %s\n", resultJson.substring(0, 200).c_str());
            // 上传成功 → 标记本饭点窗口已拍照 → 关 CAM 监控
            photoTakenThisWindow = true;
            cam_set_motion(false);
            Serial.println("[AUTO] Photo uploaded - motion disabled for this meal window");
            beepSuccess();
        } else {
            Serial.println("[CAM] Upload failed");
            beepFail();
        }
        cam_reset();
    }

    // 宠物动画更新 (仅 HOME 页，CAM 接收数据时跳过)
    if (currentPage == 0 && !camReceiving && petAnimUpdate(&pet_normal_anim, millis())) {
        drawPetFrame();
    }

    // 状态栏定时刷新 (每 3 秒，仅 HOME 页)
    if (currentPage == 0 && millis() - lastStatusUpdate > 3000) {
        drawStatusBar();
    }

    // 底部栏定时刷新 (每 5 秒，仅 HOME 页)
    if (currentPage == 0 && millis() - lastHomeProgressUpdate > 5000) {
        drawHomeProgress();
    }

    // 时钟每秒检测更新 (仅 HOME 页)
    if (currentPage == 0 && millis() - lastClockCheck > 1000) {
        lastClockCheck = millis();
        drawClock();
    }

    // WiFi 断线重连
    if (wifiOk && WiFi.status() != WL_CONNECTED) {
        wifiOk = false; ntpOk = false; accessToken = "";
        connectWiFi(); drawAll(); drawStatusBar(); drawHomeProgress();
    }

    // 后台重试 NTP（每 30 秒重试一次，直到成功）
    if (!ntpOk && wifiOk && millis() - lastNtpRetry > 30000) {
        lastNtpRetry = millis();
        Serial.println("Retrying NTP...");
        syncNTP();
        // NTP synced successfully
    }

    // 每 30 秒自动刷新进度（非阻塞）
    if (wifiOk && ntpOk && millis() - lastProgressUpdate > 30000) {
        lastProgressUpdate = millis();
        refreshProgress();
        if (currentPage == 0) drawHomeProgress();  // 进度更新后刷新底部栏（仅首页）
    }

    // 饭点帧差监控调度：饭点到且本窗口未拍照 → 开启CAM监控；饭点过/已拍照 → 关闭
    if (wifiOk && ntpOk && millis() - lastMealtimeCheck > MEALTIME_CHECK_MS) {
        lastMealtimeCheck = millis();
        static bool wasMealTime = false;
        bool nowMealTime = isMealTime();

        // 刚进入饭点窗口 → 重置拍照标记
        if (nowMealTime && !wasMealTime) {
            photoTakenThisWindow = false;
            Serial.println("[AUTO] Entering meal window, photo flag reset");
        }
        wasMealTime = nowMealTime;

        if (nowMealTime && !motionActive && !photoTakenThisWindow) {
            cam_set_motion(true);
            motionActive = true;
            Serial.println("[AUTO] Meal time - motion ON");
        } else if ((!nowMealTime || photoTakenThisWindow) && motionActive) {
            cam_set_motion(false);
            motionActive = false;
            Serial.println(photoTakenThisWindow
                ? "[AUTO] Photo already taken this window - motion OFF"
                : "[AUTO] Non-meal time - motion OFF");
        }
    }

    // ===== 按键处理（分页面）=====

    // ---------- HOME 页 (V4 3键) ----------
    if (currentPage == 0) {

        // 🎤 语音键 (GPIO4): 短按→VOICE页, 长按→直接录音
        if (checkButton(BTN_VOICE, lastVoice)) {
            if (!voiceLongDetected) {
                Serial.println("BTN -> VOICE");
                beepShort();
                currentPage = 1;   // 1=VOICE 页（原误写为 2=PAIRING，导致 VOICE 页按键无响应）
                voiceState = VOICE_IDLE;
                voiceResultText = "";
                drawVoicePage();
            }
            voiceLongDetected = false;
        }

        // 💧 饮水键 (GPIO5): +250ml 饮水
        if (checkButton(BTN_WATER, lastWater)) {
            Serial.println("BTN WATER +250");
            beepShort();
            waterTotalMl += 250;
            bool ok = recordWater(250);
            if (!ok && !accessToken.length()) {
                if (loginAPI()) ok = recordWater(250);
            }
            if (ok) {
                beepSuccess();
                drawHomeProgress();
            } else {
                Serial.println("Water FAIL");
                waterTotalMl -= 250;
                beepFail();
            }
        }

        // ↩ 返回键 (GPIO15): HOME 页无操作（预留长按回主页）
        // (短按在 HOME 页不触发任何操作)
        checkButton(BTN_BACK, lastBack);  // 消耗按键事件, 避免积压

    // ---------- VOICE 页 ----------
    } else if (currentPage == 1) {

        // --- 实时轮询 BTN_VOICE (GPIO4) 按下/松开状态 (录音控制) ---
        bool voicePressed = (digitalRead(BTN_VOICE) == LOW);

        if (voiceState == VOICE_IDLE) {
            // 等待按下开始录音
            if (voicePressed) {
                voicePressStart = millis();
                voiceState = VOICE_RECORDING;
                voiceRecStart = millis();
                i2s_mic_start();      // ★ 启动真实 I2S 录音
                drawVoicePage();
                Serial.println("[VOICE] Recording started");
            }
            // [返回键] 返回 HOME
            if (checkButton(BTN_BACK, lastBack)) {
                beepShort();
                currentPage = 0;
                voiceState = VOICE_IDLE;
                drawAll();
                drawStatusBar();
                drawClock();
                drawHomeProgress();
            }

        } else if (voiceState == VOICE_RECORDING) {
            // ★ 从 I2S DMA 拉取数据 + RMS 静音检测
            i2s_mic_poll();

            // 更新进度条 (每 100ms)
            static unsigned long lastRecDraw = 0;
            if (millis() - lastRecDraw > 100) {
                lastRecDraw = millis();
                unsigned long elapsed = i2s_mic_elapsed();  // ★ 真实录音时长
                if (elapsed > VOICE_MAX_MS) elapsed = VOICE_MAX_MS;

                int barY = 170, barX = 50, barW = 380, barH = 10;
                int fillW = (int)(barW * elapsed / VOICE_MAX_MS);
                if (fillW > 0) {
                    uint16_t barColor = (elapsed > VOICE_MAX_MS - 3000) ? TFT_RED : 0x07E0;
                    tft.fillRect(barX + 1, barY + 1, fillW - 2, barH - 2, barColor);
                }
                char timeStr[20];
                snprintf(timeStr, sizeof(timeStr), "%d:%02d / 0:15",
                         (int)elapsed / 1000 / 60, (int)(elapsed / 1000) % 60);
                tft.fillRect(VOICE_W / 2 - 45, barY + 16, 90, 20, TFT_WHITE);
                tft.setFont(&fonts::efontCN_16);
                tft.setTextSize(1);
                tft.setTextColor(TFT_BLACK, TFT_WHITE);
                tft.drawString(timeStr, VOICE_W / 2 - 40, barY + 18);
                tft.setFont(nullptr);
            }

            // 停止条件: 松手 / 超时 15s / 静音 3s / 缓冲满
            unsigned long elapsed = i2s_mic_elapsed();
            bool stopped = false;
            if (!voicePressed) {
                Serial.println("[VOICE] Button released");
                stopped = true;
            } else if (elapsed >= VOICE_MAX_MS) {
                Serial.println("[VOICE] Timeout 15s");
                stopped = true;
            } else if (i2s_mic_silence()) {
                Serial.println("[VOICE] Silence 3s");
                stopped = true;
            } else if (i2s_mic_full()) {
                Serial.println("[VOICE] Buffer full");
                stopped = true;
            }

            if (stopped) {
                i2s_mic_stop();            // ★ 停止 I2S 录音
                voiceRecDuration = elapsed;
                voiceState = VOICE_UPLOADING;
                drawVoicePage();

                // ★ 真实上传到后端语音识别
                bool ok = false;
                if (wifiOk) {
                    ok = i2s_mic_upload(API_BASE, accessToken.c_str(), voiceResultText);
                    if (!ok && accessToken.length() > 0) {
                        if (loginAPI()) {
                            ok = i2s_mic_upload(API_BASE, accessToken.c_str(), voiceResultText);
                        }
                    }
                }

                if (ok) {
                    // ★ ASR 成功 → 调用 Agent 分析食物 (不重试, 避免重复提交)
                    String asrText = voiceResultText;
                    bool analyzed = false;
                    if (wifiOk) {
                        analyzed = i2s_mic_analyze(API_BASE, accessToken.c_str(), asrText);
                    }
                    // 构建显示文本: 识别 + 分析结果
                    String display = asrText;
                    if (analyzed) {
                        display += "\n";
                        display += String(mic_food_cal) + " kcal";
                        if (mic_food_comment.length() > 0) {
                            display += "\n" + mic_food_comment;
                        }
                    }
                    voiceResultText = display;
                } else {
                    voiceResultText = "(识别失败, 请重试)";
                    Serial.println("[VOICE] ASR failed");
                }

                voiceState = VOICE_RESULT;
                drawVoicePage();
                voiceLongDetected = true;  // 防止松手触发短按
            }

            // [返回键] 取消录音
            if (checkButton(BTN_BACK, lastBack)) {
                beepShort();
                i2s_mic_stop();            // ★ 停止 I2S
                voiceState = VOICE_IDLE;
                currentPage = 0;
                drawAll();
                drawStatusBar();
                drawClock();
                drawHomeProgress();
                Serial.println("[VOICE] Cancelled");
            }

        } else if (voiceState == VOICE_RESULT) {
            // [返回键] 取消, 返回 HOME
            if (checkButton(BTN_BACK, lastBack)) {
                beepShort();
                voiceState = VOICE_IDLE;
                voiceResultText = "";
                currentPage = 0;
                drawAll();
                drawStatusBar();
                drawClock();
                drawHomeProgress();
                Serial.println("[VOICE] Result cancelled");
            }
            // [语音键] 确认记录
            if (checkButton(BTN_VOICE, lastVoice)) {
                beepShort();
                // 分析失败时禁止提交, 防止把 "(识别失败, 请重试)" 等占位文字存成饮食记录
                if (mic_food_items.length() == 0) {
                    voiceResultText = "(分析失败, 请重新录音)";
                    drawVoicePage();
                    Serial.println("[VOICE] Analyze failed, confirm blocked");
                } else {
                    String foodName = mic_food_items;
                    int foodCal = (mic_food_cal > 0) ? mic_food_cal : CAL_BREAKFAST;

                    calorieTotal += foodCal;
                    bool ok = recordMeal(1, foodName.c_str(), foodCal);
                    if (!ok && !accessToken.length()) {
                        if (loginAPI()) ok = recordMeal(1, foodName.c_str(), foodCal);
                    }
                    if (ok) {
                        beepSuccess();
                    } else {
                        calorieTotal -= foodCal;
                        beepFail();
                    }
                    voiceState = VOICE_IDLE;
                    voiceResultText = "";
                    currentPage = 0;
                    drawAll();
                    drawStatusBar();
                    drawClock();
                    drawHomeProgress();
                    Serial.println("[VOICE] Confirmed and recorded");
                }
            }
            // [饮水键] TTS 播报
            if (checkButton(BTN_WATER, lastWater)) {
                beepShort();
                // 构建播报文字
                String ttsText = "你吃了";
                if (mic_food_items.length() > 0) {
                    ttsText += mic_food_items;
                } else {
                    ttsText += voiceResultText;
                }
                if (mic_food_cal > 0) {
                    ttsText += "，大约" + String(mic_food_cal) + "千卡";
                }
                ttsText += "。";
                if (mic_food_comment.length() > 0) {
                    ttsText += mic_food_comment;
                }

                Serial.printf("[VOICE] TTS text: %s\n", ttsText.c_str());

                // 下载 TTS 音频
                if (wifiOk && i2s_speaker_fetch_tts(API_BASE, accessToken.c_str(), ttsText)) {
                    i2s_speaker_start();
                    voiceState = VOICE_PLAYING;
                    drawVoicePage();
                    Serial.println("[VOICE] TTS playback started");
                } else {
                    if (!wifiOk) {
                        Serial.println("[VOICE] TTS: WiFi not connected");
                    }
                    beepFail();
                    // 失败后留在 RESULT 页不变
                }
            }

        } else if (voiceState == VOICE_PLAYING) {
            // [返回键] 停止播报, 返回 RESULT
            if (checkButton(BTN_BACK, lastBack)) {
                beepShort();
                i2s_speaker_stop();
                voiceState = VOICE_RESULT;
                drawVoicePage();
                Serial.println("[VOICE] TTS stopped by user");
            }
        }
    }

}