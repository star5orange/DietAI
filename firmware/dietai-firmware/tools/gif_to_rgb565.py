"""
DietAI GIF 转 RGB565 C 数组工具
把 5 个状态的 GIF 抽取 5 帧，缩放到 96x96，转成 RGB565 数组
输出: pet_frames.h
"""
import os
from PIL import Image

# ===== 配置 =====
GIF_DIR = r"f:\project\DietAI\状态GIF图"
OUTPUT_H = r"f:\project\DietAI\firmware\dietai-firmware\src\pet_frames.h"

# 目标尺寸
SIZE = 96
# 每个状态抽几帧
FRAMES_PER_STATE = 5

# 状态映射: 枚举名 -> GIF 文件名
STATE_MAP = {
    "PET_NORMAL":  "自然状态.gif",   # 正常
    "PET_HAPPY":   "开心状态.gif",   # 开心
    "PET_HUNGRY":  "饥饿状态.gif",   # 饥饿
    "PET_ANXIOUS": "焦虑状态.gif",   # 焦虑
    "PET_WEAK":    "虚弱状态.gif",   # 虚弱
}

# ===== RGB565 转换 =====
def rgb888_to_rgb565(r, g, b):
    """RGB888 转 RGB565（高字节在前，匹配 ESP32 大端发送）"""
    # RGB565: RRRR RGGG GGGB BBBB
    rgb565 = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)
    return rgb565

def image_to_rgb565_array(img):
    """把 PIL Image 转成 RGB565 数组字符串"""
    img = img.convert("RGBA")
    pixels = img.load()
    w, h = img.size
    lines = []
    for y in range(h):
        row = []
        for x in range(w):
            r, g, b, a = pixels[x, y]
            # 透明像素用白色填充（避免黑底）
            if a < 128:
                r, g, b = 255, 255, 255
            val = rgb888_to_rgb565(r, g, b)
            row.append(val)
        lines.append(row)
    return lines

def format_array(data, var_name, indent="    "):
    """格式化成 C 数组"""
    result = f"const uint16_t {var_name}[{SIZE}][{SIZE}] PROGMEM = {{\n"
    for y, row in enumerate(data):
        if y % 8 == 0:
            result += indent
        # 每行 8 个像素
        for x, val in enumerate(row):
            result += f"0x{val:04X},"
        if (y + 1) % 8 == 0 or y == len(data) - 1:
            result += "\n"
        else:
            result += " "
    result += "};\n"
    return result

# ===== 主流程 =====
def main():
    print(f"DietAI GIF -> RGB565 转换工具")
    print(f"目标尺寸: {SIZE}x{SIZE}")
    print(f"每状态帧数: {FRAMES_PER_STATE}")
    print()

    header = f"""/**
 * DietAI 宠物精灵帧动画数据
 * 自动生成，请勿手动修改
 * 尺寸: {SIZE}x{SIZE} RGB565
 * 每状态 {FRAMES_PER_STATE} 帧
 */
#ifndef PET_FRAMES_H
#define PET_FRAMES_H

#include <stdint.h>

#define PET_FRAME_SIZE {SIZE}
#define PET_FRAMES_PER_STATE {FRAMES_PER_STATE}

"""

    for state_name, gif_file in STATE_MAP.items():
        gif_path = os.path.join(GIF_DIR, gif_file)
        if not os.path.exists(gif_path):
            print(f"[跳过] {gif_file} 不存在")
            continue

        print(f"处理: {gif_file} -> {state_name}")
        im = Image.open(gif_path)
        total_frames = im.n_frames
        print(f"  总帧数: {total_frames}")

        # 抽取帧的索引（均匀分布）
        indices = [int(i * (total_frames - 1) / (FRAMES_PER_STATE - 1)) for i in range(FRAMES_PER_STATE)]
        print(f"  抽取帧: {indices}")

        for i, frame_idx in enumerate(indices):
            im.seek(frame_idx)
            frame = im.convert("RGBA")
            # 缩放到目标尺寸（用 LANCZOS 保持质量）
            frame = frame.resize((SIZE, SIZE), Image.LANCZOS)

            data = image_to_rgb565_array(frame)
            var_name = f"{state_name.lower()}_frame_{i}"
            header += format_array(data, var_name)
            print(f"  帧 {i} (idx={frame_idx}) 转换完成")

        # 帧指针数组
        header += f"\nconst uint16_t* const {state_name.lower()}_frames[{FRAMES_PER_STATE}] = {{\n"
        for i in range(FRAMES_PER_STATE):
            header += f"    {state_name.lower()}_frame_{i}[0],\n"
        header += "};\n\n"

    # 状态指针表
    header += "// 状态帧表：通过 PetState 枚举索引\n"
    header += "enum PetStateIndex {\n"
    for state_name in STATE_MAP.keys():
        header += f"    {state_name},\n"
    header += "};\n\n"

    header += "const uint16_t* const* const pet_state_frames[] = {\n"
    for state_name in STATE_MAP.keys():
        header += f"    {state_name.lower()}_frames,\n"
    header += "};\n\n"

    header += "#endif // PET_FRAMES_H\n"

    # 写入文件
    with open(OUTPUT_H, "w", encoding="utf-8") as f:
        f.write(header)

    file_size = os.path.getsize(OUTPUT_H)
    print(f"\n完成！输出: {OUTPUT_H}")
    print(f"文件大小: {file_size/1024:.1f} KB")

if __name__ == "__main__":
    main()
