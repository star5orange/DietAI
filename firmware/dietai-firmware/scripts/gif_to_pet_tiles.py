"""
宠物 GIF → JPEG tile(背景已烤进帧内) → C 字节数组

依据 硬件实测日志 §10.1/§10.3/§10.5:
  tile = 背景裁剪区 + 宠物叠加, 逐帧 drawJpg 覆盖, 无需重绘全屏、无闪烁

做法:
  1. 从 GIF 均匀采样 N 帧，正确处理 disposal + alpha composite
  2. 把宠物叠到【真实背景图裁剪区】上(scripts/bg_processed.png 的 PET 区)
     → 帧内背景与整屏背景来源一致, 无方框边缘、无接缝
  3. 整块 tile 做 R↔B 交换 (补偿 drawJpg 的 BGR888 假设, 见 §8.5)
  4. 存为 JPEG, 运行时 drawJpg 一次写入该区域

前置: 先跑 jpg_to_bg.py 生成背景与 bg_processed.png
      两者必须用同一张源图, 否则宠物区背景会与整屏不一致
"""
import os
from io import BytesIO
from PIL import Image

# ===== 配置 =====
GIF_PATH = r'F:\project\plan\桌宠\三花小猫\状态GIF图\自然状态.gif'  # 宠物 GIF
OUTPUT = os.path.join(os.path.dirname(__file__), '..', 'src', 'pet_tiles.h')
BG_CACHE = os.path.join(os.path.dirname(__file__), 'bg_processed.png')  # 由 jpg_to_bg.py 生成

PET_SIZE = 186        # 宠物精灵尺寸
PET_X = 10            # 与 main.cpp 一致
PET_Y = 108           # 与 main.cpp 一致
NUM_FRAMES = 8        # 均匀采样帧数
SPEED_FACTOR = 4.0    # 播放速度倍率 (>1=变慢, <1=变快)，4.0 约 6fps
SWAP_RB = True        # drawJpg 通路: 必须预交换 (与 jpg_to_bg.py 一致, 见 §8.5)
JPG_QUALITY = 90      # 与 jpg_to_bg.py 保持一致, 减少 tile 边缘接缝
NAME = "pet_normal"   # C 变量名前缀


def main():
    if not os.path.exists(GIF_PATH):
        print(f"ERROR: GIF not found: {GIF_PATH}")
        return
    if not os.path.exists(BG_CACHE):
        print(f"ERROR: background cache not found: {BG_CACHE}")
        print("       run  python jpg_to_bg.py <背景图>  first")
        return

    bg = Image.open(BG_CACHE).convert("RGB")
    if bg.size != (480, 320):
        print(f"ERROR: background cache is {bg.size}, expected 480x320")
        return
    bg_crop = bg.crop((PET_X, PET_Y, PET_X + PET_SIZE, PET_Y + PET_SIZE))
    print(f"Background cache: {bg.size}  pet region ({PET_X},{PET_Y}) {PET_SIZE}x{PET_SIZE}")

    im = Image.open(GIF_PATH)
    total = im.n_frames
    duration = im.info.get('duration', 100)
    print(f"GIF: {os.path.basename(GIF_PATH)}  {total} frames, duration={duration}ms")

    if NUM_FRAMES >= total:
        indices = set(range(total))
    else:
        step = (total - 1) / (NUM_FRAMES - 1) if NUM_FRAMES > 1 else 0
        indices = set(min(int(i * step), total - 1) for i in range(NUM_FRAMES))

    frames = []          # [(gif_idx, delay_ms, jpeg_bytes)]
    canvas = None        # 累积画布 (RGBA)
    prev_canvas = None
    prev_disposal = 0
    last_delay = duration

    for i in range(total):
        im.seek(i)
        delay = im.info.get('duration', duration)
        if delay > 0:
            last_delay = delay

        if canvas is None:
            canvas = Image.new('RGBA', im.size, (0, 0, 0, 0))

        # 处理上一帧 disposal
        if prev_disposal == 2:      # restore to background
            canvas = Image.new('RGBA', im.size, (0, 0, 0, 0))
        elif prev_disposal == 3 and prev_canvas is not None:
            canvas = prev_canvas.copy()

        if im.disposal_method == 3:
            prev_canvas = canvas.copy()

        canvas = Image.alpha_composite(canvas, im.convert('RGBA'))
        prev_disposal = im.disposal_method

        if i in indices:
            pet_rgba = canvas.resize((PET_SIZE, PET_SIZE), Image.LANCZOS)
            # 宠物叠到真实背景裁剪区上
            tile = Image.alpha_composite(bg_crop.convert('RGBA'), pet_rgba).convert('RGB')

            # R↔B 交换 (补偿 drawJpg 的 BGR888 假设, §8.5)
            if SWAP_RB:
                r, g, b = tile.split()
                tile = Image.merge("RGB", (b, g, r))

            buf = BytesIO()
            tile.save(buf, format="JPEG", quality=JPG_QUALITY)
            jpeg = buf.getvalue()

            d = int((delay if delay > 0 else last_delay) * SPEED_FACTOR)
            frames.append((i, d, jpeg))
            print(f"  Frame {i}/{total} delay={d}ms  jpeg={len(jpeg)}B")

        if (i + 1) % 50 == 0:
            print(f"  processed {i+1}/{total}...")

    im.close()

    if not frames:
        print("ERROR: No frames extracted!")
        return

    total_bytes = sum(len(f[2]) for f in frames)
    lines = [f"""/**
 * 宠物精灵动画 — JPEG tile, 背景已烤进帧内 (自动生成)
 * 源 GIF : {os.path.basename(GIF_PATH)}
 * 区域   : ({PET_X},{PET_Y}) {PET_SIZE}x{PET_SIZE}
 * 帧数   : {len(frames)}   格式: JPEG 字节数组 (PROGMEM), SWAP_RB={SWAP_RB}
 * 显示   : tft.drawJpg(petAnimFrame(a), petAnimFrameSize(a), PET_X, PET_Y, PET_W, PET_H)
 *          依据 §10.1/§10.5 (逐帧 drawJpg 覆盖, 帧内含背景, 无闪烁)
 * Flash  : ~{total_bytes / 1024:.0f} KB
 * 生成   : scripts/gif_to_pet_tiles.py
 */
#ifndef PET_TILES_H
#define PET_TILES_H

#include <stdint.h>

#define PET_X        {PET_X}
#define PET_Y        {PET_Y}
#define PET_W        {PET_SIZE}
#define PET_H        {PET_SIZE}
#define PET_FRAMES   {len(frames)}
"""]

    for idx, (gif_idx, delay, jpeg) in enumerate(frames):
        lines.append(f"// 帧 {idx} (GIF frame {gif_idx}, delay={delay}ms, {len(jpeg)}B)")
        lines.append(f"const uint8_t {NAME}_frame_{idx}[{len(jpeg)}] PROGMEM = {{")
        for i in range(0, len(jpeg), 20):
            chunk = jpeg[i:i + 20]
            vals = ",".join(f"0x{v:02X}" for v in chunk)
            lines.append(f"    {vals}" + ("," if i + 20 < len(jpeg) else ""))
        lines.append("};")
        lines.append("")

    lines.append("// 帧数据指针表")
    lines.append(f"const uint8_t* const {NAME}_frames[{len(frames)}] = {{")
    lines.append("    " + ",\n    ".join(f"{NAME}_frame_{i}" for i in range(len(frames))))
    lines.append("};")
    lines.append("")

    lines.append("// 帧字节长度表")
    lines.append(f"const uint32_t {NAME}_sizes[{len(frames)}] PROGMEM = {{")
    lines.append("    " + ",".join(str(len(f[2])) for f in frames))
    lines.append("};")
    lines.append("")

    lines.append("// 帧间隔表 (ms)")
    lines.append(f"const uint16_t {NAME}_delays[{len(frames)}] PROGMEM = {{")
    lines.append("    " + ",".join(str(f[1]) for f in frames))
    lines.append("};")
    lines.append("")

    lines.append(f"""// 动画播放器（在 main.cpp 中使用）
typedef struct {{
    const uint8_t** frames;      // 帧 JPEG 指针表
    const uint32_t* sizes;       // 帧字节长度表 (PROGMEM)
    const uint16_t* delays;      // 帧间隔表 ms (PROGMEM)
    uint8_t  total;              // 总帧数
    uint8_t  current;            // 当前帧索引
    uint32_t last_ms;            // 上次切帧时间戳
    bool     playing;
    bool     loop;
}} PetAnim;

// 全局实例
PetAnim {NAME}_anim = {{
    .frames  = (const uint8_t**){NAME}_frames,
    .sizes   = {NAME}_sizes,
    .delays  = {NAME}_delays,
    .total   = {len(frames)},
    .current = 0,
    .last_ms = 0,
    .playing = true,
    .loop    = true,
}};

// 推进动画 — 返回 true 表示帧已切换
static inline bool petAnimUpdate(PetAnim* p, uint32_t now) {{
    if (!p->playing || !p->frames) return false;
    uint16_t delay = p->delays[p->current];
    if (now - p->last_ms >= delay) {{
        p->current = (p->current + 1) % p->total;
        p->last_ms = now;
        if (p->current == 0 && !p->loop) p->playing = false;
        return true;
    }}
    return false;
}}

// 获取当前帧 JPEG 数据指针
static inline const uint8_t* petAnimFrame(PetAnim* p) {{
    return p->frames ? p->frames[p->current] : nullptr;
}}

// 获取当前帧 JPEG 字节长度
static inline uint32_t petAnimFrameSize(PetAnim* p) {{
    return p->sizes ? p->sizes[p->current] : 0;
}}

#endif // PET_TILES_H
""")

    with open(OUTPUT, 'w', encoding='utf-8') as f:
        f.write("\n".join(lines))

    print(f"\nDone! → {OUTPUT}")
    print(f"File size : {os.path.getsize(OUTPUT) / 1024:.0f} KB (text)")
    print(f"Frames    : {len(frames)}  Flash: ~{total_bytes / 1024:.0f} KB")


if __name__ == '__main__':
    main()
