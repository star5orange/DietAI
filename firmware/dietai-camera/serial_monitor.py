"""
串口测试 v3 — 波特率扫描 + 持续读取
用法: python serial_monitor.py
"""
import serial
import time

PORT = "COM6"

# RTS=False, DTR=False → ESP32 正常启动
ser = serial.Serial(PORT, 115200, timeout=0.05)
ser.rts = False
ser.dtr = False

print("=" * 60)
print("保持 RTS=False, DTR=False，扫描波特率...")
print("=" * 60)

bauds = [9600, 19200, 38400, 57600, 74880, 115200, 128000, 230400, 256000, 460800, 921600]

for baud in bauds:
    ser.baudrate = baud
    time.sleep(1.0)  # 等 ESP32 启动

    buf = b""
    deadline = time.time() + 3.0  # 每个波特率读 3 秒
    while time.time() < deadline:
        chunk = ser.read(4096)
        if chunk:
            buf += chunk

    if buf:
        # 尝试解码
        try:
            text = buf.decode('utf-8', errors='replace')
            # 检查是否有应用层输出（非 ROM 信息）
            lines = text.strip().split('\r\n')
            app_lines = [l for l in lines if 'HELLO' in l or 'NO_SERIAL' in l or 'LOOP' in l or 'Test' in l or 'Alive' in l or 'DietAI' in l]
            if app_lines:
                print(f"\n★ 波特率 {baud}: 应用层数据! ★")
                print(text[:500])
                print("[...]")
            else:
                print(f"波特率 {baud}: 仅 ROM 数据 ({len(buf)} 字节)")
        except:
            print(f"波特率 {baud}: 原始数据 {len(buf)} 字节")
    else:
        print(f"波特率 {baud}: 无数据")

ser.close()

print("\n如果有 ★ 标记的行，用那个波特率打开监视器即可。")
print("如果全部无数据 → 硬件层面 GPIO1(TX) → CH340 RX 断路。")
