"""
任意图片 → 静态背景 JPEG C 字节数组 (LovyanGFX drawJpg 1:1 显示)
用法: python jpg_to_bg.py <输入图片路径>

依据 硬件实测日志:
  §8.2  pushImage 传 PROGMEM 指针会因 DMA 读不到 Flash 而显示垃圾数据
        → 静态资源必须走 drawJpg, 不能用 pushImage
  §8.3  结论: pushImage 不适合从 Flash 加载静态资源
  §8.5  drawJpg 内部假设解码器输出 BGR888 而实际输出 RGB888
        → Python 端必须先交换 R↔B, 否则画面整体偏蓝
  §8.4  drawJpg 不做缩放, 必须在 Python 端预缩放到目标尺寸

亮度/饱和度/对比度增强 (Brightness×1.1, Sat×1.4, Contrast×1.2):
  沿用原 scripts/img_to_bg_raw.py 的调校值, 用于补偿屏幕偏暗, 不可省略

同时输出 scripts/bg_processed.png (真实色彩, 未交换, 已增强), 供宠物 tile 裁剪,
保证 tile 内背景与整屏背景来源一致。
"""
import sys
import os
from io import BytesIO
from PIL import Image, ImageEnhance

TARGET_W, TARGET_H = 480, 320
SWAP_RB = True          # drawJpg 通路: 必须预交换 R↔B (§8.5, 与原 img_to_bg_raw.py 一致)
BRIGHTNESS = 1.1        # 亮度倍率 (补偿屏幕偏暗)
SATURATION = 1.4        # 饱和度倍率
CONTRAST = 1.2          # 对比度倍率
JPG_QUALITY = 90        # 与原 img_to_bg_raw.py 一致
NAME = "bg_jpg"
OUTPUT = os.path.join(os.path.dirname(__file__), '..', 'src', 'bg_static.h')
CACHE = os.path.join(os.path.dirname(__file__), 'bg_processed.png')


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else None
    if not src or not os.path.exists(src):
        print("Usage: python jpg_to_bg.py <image_path>")
        print(f"ERROR: file not found: {src}")
        return

    img = Image.open(src).convert("RGB")
    ow, oh = img.size
    print(f"Source: {os.path.basename(src)}  {ow}x{oh}")

    # cover: 按目标比例放大后居中裁剪, 铺满且不变形
    scale = max(TARGET_W / ow, TARGET_H / oh)
    nw, nh = int(round(ow * scale)), int(round(oh * scale))
    img = img.resize((nw, nh), Image.LANCZOS)
    left, top = (nw - TARGET_W) // 2, (nh - TARGET_H) // 2
    img = img.crop((left, top, left + TARGET_W, top + TARGET_H))
    print(f"Resized(cover): {nw}x{nh} -> {TARGET_W}x{TARGET_H}")

    # 亮度 + 饱和度 + 对比度增强 (补偿屏幕偏暗, 沿用原 img_to_bg_raw.py 调校值)
    img = ImageEnhance.Brightness(img).enhance(BRIGHTNESS)
    img = ImageEnhance.Color(img).enhance(SATURATION)
    img = ImageEnhance.Contrast(img).enhance(CONTRAST)
    print(f"Enhanced: brightness×{BRIGHTNESS}, sat×{SATURATION}, contrast×{CONTRAST}")

    # 缓存真实色彩图(已增强), 供 gif_to_pet_tiles.py 裁剪宠物区
    img.save(CACHE)

    # 首页"今日进度"区背景 tile — 让面板背景"透明": 重绘前先用本 tile 还原
    # 该区草原背景(擦掉旧文字/进度条), 再以透明底叠加文字
    PROG_X, PROG_Y, PROG_W, PROG_H = 210, 67, 255, 253   # 与 main.cpp PROGRESS_X/HOME_CONTENT_Y 一致
    prog = img.crop((PROG_X, PROG_Y, PROG_X + PROG_W, PROG_Y + PROG_H))
    if SWAP_RB:
        pr, pg, pb = prog.split()
        prog = Image.merge("RGB", (pb, pg, pr))
    pbuf = BytesIO()
    prog.save(pbuf, format="JPEG", quality=JPG_QUALITY)
    pdata = pbuf.getvalue()
    print(f"Progress tile: ({PROG_X},{PROG_Y}) {PROG_W}x{PROG_H}  JPEG {len(pdata)} bytes")

    # R↔B 交换后存 JPEG (补偿 drawJpg 的 BGR888 假设)
    if SWAP_RB:
        r, g, b = img.split()
        img = Image.merge("RGB", (b, g, r))
    buf = BytesIO()
    img.save(buf, format="JPEG", quality=JPG_QUALITY)
    data = buf.getvalue()
    print(f"JPEG : {len(data)} bytes (~{len(data) / 1024:.1f} KB)  quality={JPG_QUALITY} SWAP_RB={SWAP_RB}")
    print(f"Cache: {CACHE}")

    lines = [f"""/**
 * 静态背景 — {os.path.basename(src)}
 * 尺寸: {TARGET_W}x{TARGET_H}  JPEG {len(data)} bytes (LovyanGFX drawJpg 1:1)
 * 生成: scripts/jpg_to_bg.py  (SWAP_RB={SWAP_RB}, quality={JPG_QUALITY})
 * 依据: 硬件实测日志 §8.2/§8.3/§8.5 (pushImage 不可用于 Flash 静态资源)
 */
#ifndef BG_STATIC_H
#define BG_STATIC_H
#include <stdint.h>

#define BG_W  {TARGET_W}
#define BG_H  {TARGET_H}

const uint8_t {NAME}[{len(data)}] PROGMEM = {{"""]

    for i in range(0, len(data), 20):
        chunk = data[i:i + 20]
        vals = ",".join(f"0x{v:02X}" for v in chunk)
        lines.append(f"    {vals}" + ("," if i + 20 < len(data) else ""))

    lines.append("};")
    lines.append("")
    lines.append('// 首页"今日进度"区背景 tile — 透明面板重绘前还原该区背景(与整屏底图同源同质量)')
    lines.append(f"const uint8_t progress_bg_jpg[{len(pdata)}] PROGMEM = {{")
    for i in range(0, len(pdata), 20):
        chunk = pdata[i:i + 20]
        vals = ",".join(f"0x{v:02X}" for v in chunk)
        lines.append(f"    {vals}" + ("," if i + 20 < len(pdata) else ""))
    lines.append("};")
    lines.append("")
    lines.append("#endif")
    lines.append("")

    with open(OUTPUT, 'w', encoding='utf-8') as f:
        f.write("\n".join(lines))

    print(f"Output: {OUTPUT}")
    print("Done!")


if __name__ == '__main__':
    main()
