"""
GIF → 完整C代码转换器
- 提取GIF全部帧（或按步长采样）
- 保留原始帧间隔时间
- 合成到指定背景色
- 缩放到目标尺寸
- 生成独立可用的 .h 文件 + 使用示例
"""
import os, sys
from PIL import Image

# ===== 配置 =====
GIF_PATH = r'F:\project\plan\桌宠\状态GIF图\自然状态.gif'
OUTPUT = os.path.join(os.path.dirname(__file__), '..', 'src', 'pet_anim.h')
TARGET_SIZE = 96          # 输出尺寸（像素）
SAMPLE_STEP = 5           # 每N帧取1帧（5=约50帧/242帧GIF）
BG_COLOR = (100, 180, 255)  # 合成背景色RGB（天蓝色），设 None 则为黑色
NAME = "pet_normal"       # C变量名前缀

def rgb565(r, g, b):
    return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)

def extract_all_frames(gif_path, sample_step, bg_rgb, target_size):
    """
    遍历GIF全部帧，处理透明+缩放，返回 [(delay_ms, rgb565_data), ...]
    """
    im = Image.open(gif_path)
    total = im.n_frames
    print(f"GIF: {total} frames, {im.size}")

    canvas = None
    prev_canvas = None
    prev_disposal = 0
    frames = []

    for i in range(total):
        im.seek(i)
        delay = im.info.get('duration', 100)  # ms

        if canvas is None:
            canvas = Image.new('RGBA', im.size, (0, 0, 0, 0))

        # 处理上一帧 disposal
        if prev_disposal == 2:
            canvas = Image.new('RGBA', im.size, (0, 0, 0, 0))
        elif prev_disposal == 3 and prev_canvas is not None:
            canvas = prev_canvas.copy()

        if im.disposal_method == 3:
            prev_canvas = canvas.copy()

        # 合成当前帧
        frame = im.convert('RGBA')
        canvas = Image.alpha_composite(canvas, frame)
        prev_disposal = im.disposal_method

        # 采样
        if i % sample_step == 0 or i == total - 1:
            # 合成到背景色
            if bg_rgb:
                bg = Image.new('RGBA', im.size, (*bg_rgb, 255))
            else:
                bg = Image.new('RGBA', im.size, (0, 0, 0, 255))
            result = Image.alpha_composite(bg, canvas)
            result = result.resize((target_size, target_size), Image.LANCZOS)

            # 转 RGB565
            pixels = result.load()
            data = []
            for y in range(target_size):
                for x in range(target_size):
                    r, g, b, a = pixels[x, y]
                    if a == 0:
                        data.append(0x0000)
                    else:
                        data.append(rgb565(r, g, b))
            frames.append((delay, data))

        # 进度
        if (i + 1) % 50 == 0:
            print(f"  processed {i+1}/{total}")

    print(f"  extracted {len(frames)} frames")
    return frames


def main():
    bg_rgb = BG_COLOR
    frames = extract_all_frames(GIF_PATH, SAMPLE_STEP, bg_rgb, TARGET_SIZE)

    if not frames:
        print("No frames extracted!")
        return

    # 生成 C 头文件
    total_pixels = TARGET_SIZE * TARGET_SIZE
    total_bytes = len(frames) * total_pixels * 2

    header = f"""/**
 * GIF动画数据 — 自动生成
 * 源文件: {os.path.basename(GIF_PATH)}
 * 帧数: {len(frames)}
 * 尺寸: {TARGET_SIZE}x{TARGET_SIZE} RGB565
 * 背景色: RGB({bg_rgb[0]},{bg_rgb[1]},{bg_rgb[2]}) (天蓝)
 * 估算Flash占用: {total_bytes / 1024:.0f} KB
 */
#ifndef PET_ANIM_H
#define PET_ANIM_H

#include <stdint.h>

#define {NAME.upper()}_SIZE      {TARGET_SIZE}
#define {NAME.upper()}_FRAMES    {len(frames)}

// 帧数据: [{NAME}_frame_N][{TARGET_SIZE}][{TARGET_SIZE}]
"""

    parts = [header]

    for idx, (delay, data) in enumerate(frames):
        lines = [f"const uint16_t {NAME}_frame_{idx}[{TARGET_SIZE}][{TARGET_SIZE}] PROGMEM = {{"]
        for r in range(TARGET_SIZE):
            row = data[r * TARGET_SIZE : (r + 1) * TARGET_SIZE]
            vals = ",".join(f"0x{v:04X}" for v in row)
            comma = "," if r < TARGET_SIZE - 1 else ""
            lines.append(f"    {vals}{comma}")
        lines.append("};")
        parts.append("\n".join(lines))
        parts.append("")

    # 帧指针表
    parts.append(f"// 帧指针表")
    parts.append(f"const uint16_t* const {NAME}_frames[{len(frames)}] = {{")
    ptrs = ",\n    ".join(f"{NAME}_frame_{i}[0]" for i in range(len(frames)))
    parts.append(f"    {ptrs}")
    parts.append("};")
    parts.append("")

    # 帧间隔表 (ms)
    parts.append(f"// 帧间隔表 (ms)")
    parts.append(f"const uint16_t {NAME}_delays[{len(frames)}] PROGMEM = {{")
    delay_str = ",".join(str(f[0]) for f in frames)
    parts.append(f"    {delay_str}")
    parts.append("};")
    parts.append("")

    # 便捷播放器结构
    parts.append(f"""// 动画播放器
typedef struct {{
    const uint16_t** frames;     // 帧指针表
    const uint16_t* delays;      // 帧间隔表 (PROGMEM)
    uint16_t total_frames;       // 总帧数
    uint8_t  current_frame;      // 当前帧索引
    uint32_t last_frame_time;    // 上次切帧时间戳
    bool     playing;            // 是否播放中
    bool     loop;               // 是否循环
}} GIFPlayer;

// 全局播放器实例（在 main.cpp 中使用）
GIFPlayer {NAME}_player = {{
    .frames       = (const uint16_t**){NAME}_frames,
    .delays       = {NAME}_delays,
    .total_frames = {len(frames)},
    .current_frame = 0,
    .last_frame_time = 0,
    .playing      = true,
    .loop         = true,
}};

// 推进动画（每个 loop() 调用一次）
// 返回 true 表示帧已切换（需要重绘）
static inline bool gifPlayerUpdate(GIFPlayer* p, uint32_t now) {{
    if (!p->playing || !p->frames) return false;
    uint16_t delay = p->delays[p->current_frame];
    if (now - p->last_frame_time >= delay) {{
        p->current_frame = (p->current_frame + 1) % p->total_frames;
        p->last_frame_time = now;
        if (p->current_frame == 0 && !p->loop) p->playing = false;
        return true;
    }}
    return false;
}}

// 获取当前帧数据指针
static inline const uint16_t* gifPlayerFrame(GIFPlayer* p) {{
    return p->frames ? p->frames[p->current_frame] : nullptr;
}}

#endif // PET_ANIM_H
""")

    with open(OUTPUT, 'w', encoding='utf-8') as f:
        f.write("\n".join(parts))

    print(f"\nDone! → {OUTPUT}")
    print(f"Frames: {len(frames)}, ~{total_bytes/1024:.0f} KB flash")
    print(f"\n使用方法:")
    print(f'  #include "pet_anim.h"')
    print(f"  // 在 loop() 中:")
    print(f"  if (gifPlayerUpdate(&{NAME}_player, millis())) {{")
    print(f"      tft.pushImage(x, y, {NAME.upper()}_SIZE, {NAME.upper()}_SIZE,")
    print(f"                    gifPlayerFrame(&{NAME}_player));")
    print(f"  }}")

if __name__ == '__main__':
    main()
