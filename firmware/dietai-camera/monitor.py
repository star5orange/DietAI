"""
DietAI Camera 专用串口监视器
用法: python monitor.py

快捷键:
  C / capture    → 发送拍照指令 (CMD 0x01)
  M / motion     → 开启帧差检测 (CMD 0x06)
  S / stop       → 关闭帧差检测 (CMD 0x07)
  hex:AA 55 ...  → 发送原始十六进制字节
"""
import serial
import time
import threading
import sys

PORT = "COM6"
BAUD = 921600  # 与固件一致

def make_frame(cmd, data=None):
    """构建二进制协议帧 [AA 55 CMD LEN_H LEN_L DATA... XOR]"""
    if data is None:
        data = b''
    length = len(data)
    header = bytes([0xAA, 0x55, cmd, (length >> 8) & 0xFF, length & 0xFF])
    cs = cmd ^ header[3] ^ header[4]
    for b in data:
        cs ^= b
    return header + data + bytes([cs])

def send_hex(ser, hex_str):
    """发送十六进制字符串，如 'AA 55 01 00 00 01'"""
    try:
        hex_str = hex_str.replace(' ', '').replace('\n', '').replace('\r', '')
        data = bytes.fromhex(hex_str)
        ser.write(data)
        print(f"[发送] {len(data)} bytes: {data.hex(' ').upper()}")
    except ValueError as e:
        print(f"[错误] 十六进制解析失败: {e}")

print(f"=== DietAI Camera Monitor ===")
print(f"连接 {PORT} @ {BAUD}...")

ser = serial.Serial(PORT, BAUD, timeout=0.05)
ser.rts = False
ser.dtr = False
time.sleep(2.0)

print("快捷键:")
print("  C / capture  → 拍照")
print("  M / motion   → 开启帧差检测")
print("  S / stop     → 关闭帧差检测")
print("  hex:AA 55..  → 发送原始十六进制")
print("  Ctrl+C       → 退出")
print("-" * 50)

stop_reader = False
def reader():
    while not stop_reader:
        try:
            data = ser.read(4096)
            if data:
                # 尝试当文本显示（ASCII），否则显示 hex
                try:
                    text = data.decode('utf-8')
                    sys.stdout.write(text)
                except:
                    sys.stdout.write(f"[HEX] {data.hex(' ').upper()}\n")
                sys.stdout.flush()
        except:
            break

t = threading.Thread(target=reader, daemon=True)
t.start()

try:
    while True:
        ch = input()
        line = ch.strip()
        if not line:
            continue

        upper = line.upper()

        if upper in ('C', 'CAPTURE'):
            frame = make_frame(0x01)
            ser.write(frame)
            print(f"[发送] 拍照 {frame.hex(' ').upper()}")

        elif upper in ('M', 'MOTION'):
            frame = make_frame(0x06)
            ser.write(frame)
            print(f"[发送] 开启帧差 {frame.hex(' ').upper()}")

        elif upper in ('S', 'STOP'):
            frame = make_frame(0x07)
            ser.write(frame)
            print(f"[发送] 关闭帧差 {frame.hex(' ').upper()}")

        elif upper.startswith('HEX:') or upper.startswith('0X'):
            hex_part = line.split(':', 1)[1] if ':' in line else line
            send_hex(ser, hex_part)

        elif len(line) >= 3 and all(c in '0123456789ABCDEFabcdef ' for c in line):
            # 自动识别：纯十六进制字符串 → 当 hex 发送
            send_hex(ser, line)

        else:
            # 普通文本
            ser.write(line.encode())

except KeyboardInterrupt:
    print("\n关闭...")
    stop_reader = True
    ser.close()
    print("已断开")
