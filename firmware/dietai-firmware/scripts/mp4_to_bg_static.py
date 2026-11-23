"""
MP4 → 单帧静态背景 C 代码 (BGR565 for ST7789 BGR order)
从视频中间取一帧作为静态背景
"""
import cv2
import os

VIDEO_PATH = r'F:\project\plan\hardware\小猫动画.mp4'
OUTPUT = os.path.join(os.path.dirname(__file__), '..', 'src', 'bg_static.h')
TARGET_W, TARGET_H = 240, 320

def bgr565(b, g, r):  # OpenCV BGR
    """BGR565 for ST7789 BGR order: BBBBBGGGGGGRRRRR"""
    return ((b & 0xF8) << 8) | ((g & 0xFC) << 3) | (r >> 3)

def main():
    cap = cv2.VideoCapture(VIDEO_PATH)
    if not cap.isOpened():
        print(f"ERROR: Cannot open {VIDEO_PATH}")
        return

    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    print(f"Video: {total} frames, {fps:.1f}fps")

    # 取中间偏后一点的帧（通常画面更完整）
    target_idx = int(total * 0.4)
    print(f"Extracting frame {target_idx}/{total}")

    cap.set(cv2.CAP_PROP_POS_FRAMES, target_idx)
    ret, frame = cap.read()
    cap.release()

    if not ret:
        print("ERROR: Cannot read frame")
        return

    # BGR → RGB, resize
    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    resized = cv2.resize(frame_rgb, (TARGET_W, TARGET_H),
                         interpolation=cv2.INTER_LANCZOS4)

    # → BGR565 array
    data = []
    for y in range(TARGET_H):
        for x in range(TARGET_W):
            r, g, b = resized[y, x]
            data.append(bgr565(b, g, r))

    # 保存预览图确认
    preview_path = os.path.join(os.path.dirname(__file__), 'bg_preview.png')
    cv2.imwrite(preview_path, cv2.cvtColor(resized, cv2.COLOR_RGB2BGR))
    print(f"Preview saved: {preview_path}")

    # 生成 C 头文件
    lines = []
    lines.append(f"""/**
 * 静态背景 — 取自动画第 {target_idx} 帧
 * 尺寸: {TARGET_W}×{TARGET_H}  BGR565 (ST7789 BGR order)
 * Flash: ~{TARGET_W * TARGET_H * 2 / 1024:.0f} KB
 */
#ifndef BG_STATIC_H
#define BG_STATIC_H
#include <stdint.h>

#define BG_W  {TARGET_W}
#define BG_H  {TARGET_H}

const uint16_t bg_static[{TARGET_H}][{TARGET_W}] PROGMEM = {{""")

    for y in range(TARGET_H):
        row = data[y * TARGET_W : (y + 1) * TARGET_W]
        vals = ",".join(f"0x{v:04X}" for v in row)
        comma = "," if y < TARGET_H - 1 else ""
        lines.append(f"    {vals}{comma}")

    lines.append("};\n#endif\n")

    with open(OUTPUT, 'w', encoding='utf-8') as f:
        f.write("\n".join(lines))

    file_kb = os.path.getsize(OUTPUT) / 1024
    print(f"\nOutput: {OUTPUT}")
    print(f"File size: {file_kb:.0f} KB")
    print(f"\n// 在 main.cpp 中使用:")
    print(f'#include "bg_static.h"')
    print(f'tft.pushImage(0, 0, BG_W, BG_H, bg_static[0]);')

if __name__ == '__main__':
    main()
