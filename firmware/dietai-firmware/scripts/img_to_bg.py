"""
任意图片 → 静态背景 C 代码 (BGR565 for ST7789 BGR order)
用法: python img_to_bg.py <输入图片路径>
"""
import sys
import os
from PIL import Image

TARGET_W, TARGET_H = 240, 320
OUTPUT = os.path.join(os.path.dirname(__file__), '..', 'src', 'bg_static.h')

def rgb565(r, g, b):
    """Standard RGB565: RRRRRGGGGGGBBBBB (LovyanGFX handles BGR swap via rgb_order)"""
    return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)

def main():
    src = sys.argv[1] if len(sys.argv) > 1 else None
    if not src or not os.path.exists(src):
        print(f"Usage: python img_to_bg.py <image_path>")
        print(f"ERROR: file not found: {src}")
        return

    img = Image.open(src).convert("RGB")
    ow, oh = img.size
    print(f"Source: {os.path.basename(src)}  {ow}x{oh}")

    img = img.resize((TARGET_W, TARGET_H), Image.LANCZOS)
    pixels = img.load()

    lines = []
    lines.append(f"""/**
 * 静态背景 — {os.path.basename(src)}
 * 尺寸: {TARGET_W}×{TARGET_H}  RGB565 (LovyanGFX rgb_order handles BGR swap)
 * Flash: ~{TARGET_W * TARGET_H * 2 / 1024:.0f} KB
 */
#ifndef BG_STATIC_H
#define BG_STATIC_H
#include <stdint.h>

#define BG_W  {TARGET_W}
#define BG_H  {TARGET_H}

const uint16_t bg_static[{TARGET_H}][{TARGET_W}] PROGMEM = {{""")

    for y in range(TARGET_H):
        vals = []
        for x in range(TARGET_W):
            r, g, b = pixels[x, y]
            vals.append(f"0x{rgb565(r, g, b):04X}")
        row = ",".join(vals)
        comma = "," if y < TARGET_H - 1 else ""
        lines.append(f"    {row}{comma}")

    lines.append("};\n#endif\n")

    with open(OUTPUT, 'w', encoding='utf-8') as f:
        f.write("\n".join(lines))

    file_kb = os.path.getsize(OUTPUT) / 1024
    print(f"Output: {OUTPUT}")
    print(f"Size: {file_kb:.0f} KB")
    print(f"Done!")

if __name__ == '__main__':
    main()
