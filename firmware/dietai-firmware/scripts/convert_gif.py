"""
从原始 GIF 重新转换精灵帧数据。
- 使用 GIF 透明通道正确合成到黑色背景
- 缩放到 96x96
- 输出 RGB565 格式
- 每个状态选 5 帧做动画循环
"""
import os
from PIL import Image

GIF_DIR = r'F:\project\plan\桌宠\状态GIF图'
OUTPUT = os.path.join(os.path.dirname(__file__), '..', 'src', 'pet_frames.h')
TARGET_SIZE = 96
FRAMES_PER_STATE = 5

STATES = [
    ('pet_normal',   '自然状态.gif'),
    ('pet_happy',    '开心状态.gif'),
    ('pet_hungry',   '饥饿状态.gif'),
    ('pet_anxious',  '焦虑状态.gif'),
    ('pet_weak',     '虚弱状态.gif'),
]

def rgb565(r, g, b):
    return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)


def extract_frames(gif_path, num_frames):
    """单次遍历 GIF，在均匀间隔的帧处捕获画面"""
    im = Image.open(gif_path)
    total = im.n_frames
    print(f"  Total frames: {total}")

    if num_frames >= total:
        indices = set(range(total))
    else:
        step = (total - 1) / (num_frames - 1) if num_frames > 1 else 0
        indices = set(min(int(i * step), total - 1) for i in range(num_frames))

    frames = []
    canvas = None
    prev_canvas = None
    prev_disposal = 0  # 上一帧的 disposal，在当前帧渲染前处理

    for i in range(total):
        im.seek(i)

        if canvas is None:
            canvas = Image.new('RGBA', im.size, (0, 0, 0, 0))

        # 1. 处理上一帧的 disposal
        if prev_disposal == 2:  # restore to background
            canvas = Image.new('RGBA', im.size, (0, 0, 0, 0))
        elif prev_disposal == 3 and prev_canvas is not None:  # restore to previous
            canvas = prev_canvas.copy()

        # 保存副本（当前帧 disposal=3 时需要）
        if im.disposal_method == 3:
            prev_canvas = canvas.copy()

        # 2. 合成当前帧
        frame = im.convert('RGBA')
        canvas = Image.alpha_composite(canvas, frame)

        # 3. 是否捕获？
        if i in indices:
            bg = Image.new('RGBA', im.size, (0, 0, 0, 255))
            result = Image.alpha_composite(bg, canvas)
            result = result.resize((TARGET_SIZE, TARGET_SIZE), Image.LANCZOS)
            pixels = result.load()
            data = []
            for y in range(TARGET_SIZE):
                for x in range(TARGET_SIZE):
                    r, g, b, a = pixels[x, y]
                    if a == 0:
                        data.append(0x0000)
                    else:
                        data.append(rgb565(r, g, b))
            frames.append(data)
            print(f"    Captured frame {i}/{total}")

        # 4. 保存当前 disposal 供下一帧使用
        prev_disposal = im.disposal_method

    return frames, sorted(indices)


def format_frame_data(name, idx, data):
    """格式化为 C 数组字符串"""
    lines = [f"const uint16_t {name}_frame_{idx}[{TARGET_SIZE}][{TARGET_SIZE}] PROGMEM = {{"]
    for r in range(TARGET_SIZE):
        row_vals = [f"0x{v:04X}" for v in data[r * TARGET_SIZE : (r + 1) * TARGET_SIZE]]
        line = "    " + ",".join(row_vals)
        if r < TARGET_SIZE - 1:
            line += ","
        lines.append(line)
    lines.append("};")
    return "\n".join(lines)


def main():
    header = """/**
 * DietAI 像素小猫精灵数据
 * 从原始 GIF 重新转换 — 透明通道正确合成到黑色背景
 * 尺寸: 96x96 RGB565
 * 每个状态 5 帧，均匀采样
 */
#ifndef PET_FRAMES_H
#define PET_FRAMES_H

#include <stdint.h>

#define PET_FRAME_SIZE 96
#define PET_FRAMES_PER_STATE 5

"""
    parts = [header]

    all_frames = {}

    for name, filename in STATES:
        gif_path = os.path.join(GIF_DIR, filename)
        print(f"\nProcessing {filename} → {name}...")
        frames, indices = extract_frames(gif_path, FRAMES_PER_STATE)

        all_frames[name] = (frames, indices)

        for i, data in enumerate(frames):
            parts.append(format_frame_data(name, i, data))
            parts.append("")

    # 生成帧指针表
    parts.append("// 每状态 5 帧的指针数组")
    parts.append("const uint16_t* const pet_state_frames[5][PET_FRAMES_PER_STATE] = {")
    for i, (name, _) in enumerate(STATES):
        ptrs = ", ".join(f"{name}_frame_{j}[0]" for j in range(FRAMES_PER_STATE))
        parts.append(f"    {{ {ptrs} }}," + ("" if i == len(STATES) - 1 else ""))
    parts.append("};")
    parts.append("")

    # 状态索引枚举
    parts.append("enum PetStateIndex {")
    parts.append("    PET_NORMAL,")
    parts.append("    PET_HAPPY,")
    parts.append("    PET_HUNGRY,")
    parts.append("    PET_ANXIOUS,")
    parts.append("    PET_WEAK,")
    parts.append("};")
    parts.append("")
    parts.append("#endif // PET_FRAMES_H")

    with open(OUTPUT, 'w', encoding='utf-8') as f:
        f.write("\n".join(parts))

    print(f"\nDone! Output: {OUTPUT}")


if __name__ == '__main__':
    main()
