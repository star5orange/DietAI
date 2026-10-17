"""
DietAI 像素小猫图整合工具
读取 5 个 .h 文件（每个 96x96 RGB565），合并成 pet_frames.h
- 白色背景 (0xFFFF) 替换为黑色 (0x0000)，融入黑屏
- 每个状态单帧（非动画），用代码叠加动作
"""
import os
import re

# ===== 配置 =====
INPUT_DIR = r"f:\project\plan\hardware\小猫\代码"
OUTPUT_H = r"f:\project\DietAI\firmware\dietai-firmware\src\pet_frames.h"

# 状态映射: 枚举名 -> 文件名
STATE_MAP = {
    "PET_NORMAL":  "自然状态.h",
    "PET_HAPPY":   "开心状态.h",
    "PET_HUNGRY":  "饥饿.h",
    "PET_ANXIOUS": "焦虑状态.h",
    "PET_WEAK":    "虚弱状态.h",
}

SIZE = 96
WHITE_565 = 0xFFFF   # 白色
BLACK_565 = 0x0000   # 黑色
SKY_565 = 0x45EF     # 蓝天色（RGB565: R=4,G=31,B=15，浅蓝）

# ===== 解析 .h 文件，提取像素数据 =====
def parse_h_file(filepath):
    """从 .h 文件提取 uint8_t 数组，转成 uint16_t 像素列表"""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # 提取 { } 之间的十六进制数据
    match = re.search(r'\{([^}]+)\}', content)
    if not match:
        raise ValueError(f"无法在 {filepath} 中找到数组数据")

    hex_data = match.group(1)
    # 提取所有 0xXX
    bytes_list = re.findall(r'0x([0-9A-Fa-f]{2})', hex_data)
    bytes_list = [int(b, 16) for b in bytes_list]

    # 两字节组合成 RGB565（Big Endian: 高字节在前）
    pixels = []
    for i in range(0, len(bytes_list), 2):
        high = bytes_list[i]
        low = bytes_list[i + 1]
        val = (high << 8) | low
        # 白色背景转蓝天色（融入天空背景）
        if val == WHITE_565:
            val = SKY_565
        pixels.append(val)

    expected = SIZE * SIZE
    if len(pixels) != expected:
        raise ValueError(f"{filepath}: 像素数 {len(pixels)} != {expected}")

    return pixels

# ===== 格式化成 C 数组 =====
def format_array(pixels, var_name, indent="    "):
    """格式化成 uint16_t 二维数组"""
    result = f"const uint16_t {var_name}[{SIZE}][{SIZE}] PROGMEM = {{\n"
    for y in range(SIZE):
        result += indent
        for x in range(SIZE):
            val = pixels[y * SIZE + x]
            result += f"0x{val:04X},"
        result += "\n"
    result += "};\n"
    return result

# ===== 主流程 =====
def main():
    print("DietAI 像素小猫整合工具")
    print(f"目标尺寸: {SIZE}x{SIZE} RGB565")
    print(f"白底(0xFFFF) -> 黑底(0x0000)")
    print()

    header = f"""/**
 * DietAI 像素小猫精灵数据
 * 自动生成，请勿手动修改
 * 尺寸: {SIZE}x{SIZE} RGB565
 * 白色背景已转为黑色，融入黑屏
 * 每个状态单帧，动作由代码叠加
 */
#ifndef PET_FRAMES_H
#define PET_FRAMES_H

#include <stdint.h>

#define PET_FRAME_SIZE {SIZE}
#define PET_FRAMES_PER_STATE 1   // 单帧，动作由代码控制

"""

    for state_name, h_file in STATE_MAP.items():
        filepath = os.path.join(INPUT_DIR, h_file)
        if not os.path.exists(filepath):
            print(f"[跳过] {h_file} 不存在")
            continue

        print(f"处理: {h_file} -> {state_name}")
        pixels = parse_h_file(filepath)

        # 统计白底转蓝天色的数量
        sky_count = sum(1 for p in pixels if p == SKY_565)
        print(f"  像素数: {len(pixels)}, 蓝天(背景)像素: {sky_count}")

        var_name = f"{state_name.lower()}_frame"
        header += format_array(pixels, var_name)
        print(f"  转换完成: {var_name}")

    # 状态指针表
    header += "\n// 状态帧表：通过 PetState 枚举索引\n"
    header += "enum PetStateIndex {\n"
    for state_name in STATE_MAP.keys():
        header += f"    {state_name},\n"
    header += "};\n\n"

    header += "// 每个状态单帧，pet_state_frames[state][0] 取该帧\n"
    header += "const uint16_t* const pet_state_frames[] = {\n"
    for state_name in STATE_MAP.keys():
        var_name = f"{state_name.lower()}_frame"
        header += f"    {var_name}[0],\n"
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
