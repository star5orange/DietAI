"""
图片 → 480×320 JPG → C 字节数组
含饱和度+对比度增强，适配 LovyanGFX drawJpg 1:1 显示
"""
import sys
import os
from io import BytesIO
from PIL import Image, ImageEnhance

TARGET_W, TARGET_H = 480, 320
BRIGHTNESS = 1.1       # 亮度倍率（轻微补偿）
SATURATION = 1.4       # 饱和度倍率
CONTRAST = 1.2         # 对比度倍率
JPEG_QUALITY = 90
OUTPUT = os.path.join(os.path.dirname(__file__), '..', 'src', 'bg_static.h')

def main():
    src = sys.argv[1] if len(sys.argv) > 1 else None
    if not src or not os.path.exists(src):
        print(f"Usage: python img_to_bg_raw.py <image_path>")
        return

    img = Image.open(src).convert("RGB")
    print(f"Source: {os.path.basename(src)}  {img.width}x{img.height}")

    # Resize
    img = img.resize((TARGET_W, TARGET_H), Image.LANCZOS)
    print(f"Resized: {TARGET_W}x{TARGET_H}")

    # 亮度 + 饱和度 + 对比度增强（补偿屏幕偏暗）
    img = ImageEnhance.Brightness(img).enhance(BRIGHTNESS)
    img = ImageEnhance.Color(img).enhance(SATURATION)
    img = ImageEnhance.Contrast(img).enhance(CONTRAST)
    print(f"Enhanced: brightness×{BRIGHTNESS}, sat×{SATURATION}, contrast×{CONTRAST}")

    # Swap R↔B: LovyanGFX draw_jpg expects BGR888 from decoder,
    # but TJpgDec outputs RGB888. Pre-swapping compensates.
    r, g, b = img.split()
    img = Image.merge("RGB", (b, g, r))
    print("R<->B swapped for LovyanGFX BGR888 pipeline")

    # Save as JPG to memory
    buf = BytesIO()
    img.save(buf, format="JPEG", quality=JPEG_QUALITY)
    data = buf.getvalue()

    size_kb = len(data) / 1024
    print(f"JPG size: {len(data)} bytes ({size_kb:.1f} KB)")

    lines = []
    lines.append(f"""/**
 * 静态背景 — 预缩放 raw JPG (LovyanGFX drawJpg 1:1 解码)
 * 源: {os.path.basename(src)}  {TARGET_W}x{TARGET_H}
 * JPG: {len(data)} bytes (~{size_kb:.0f} KB)
 */
#ifndef BG_STATIC_H
#define BG_STATIC_H
#include <stdint.h>

#define BG_W  {TARGET_W}
#define BG_H  {TARGET_H}

const uint8_t bg_jpg[{len(data)}] PROGMEM = {{""")

    # 每行 20 字节
    for i in range(0, len(data), 20):
        chunk = data[i:i+20]
        vals = ",".join(f"0x{b:02X}" for b in chunk)
        comma = "," if i + 20 < len(data) else ""
        lines.append(f"    {vals}{comma}")

    lines.append("};\n#endif\n")

    with open(OUTPUT, 'w', encoding='utf-8') as f:
        f.write("\n".join(lines))

    file_kb = os.path.getsize(OUTPUT) / 1024
    print(f"Output: {OUTPUT}  ({file_kb:.0f} KB)")
    print(f"Done!")

if __name__ == '__main__':
    main()
