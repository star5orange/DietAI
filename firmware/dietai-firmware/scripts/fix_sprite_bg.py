"""
修复精灵帧白边+彩边问题 v2：
1. 洪水填充：从四边出发，把所有连到边缘的"近白色"像素替换为 0x0000
2. 彩边侵蚀：迭代 3 轮，把与背景相邻的残余近白像素也吃掉
3. 保留身体内部孤立的白色特征（眼睛、高光等）

v2 修复：洪水填充目标从 ==0xFFFF 改为 >NEAR_WHITE_THRESHOLD
因为 GIF 抗锯齿边缘不是纯白，而是 0xF7DE 等近白色，v1 的洪水填充无法启动。
"""
import os
from collections import deque

HEADER = os.path.join(os.path.dirname(__file__), '..', 'src', 'pet_frames.h')
OUTPUT = HEADER
BACKUP = HEADER + '.bak'

# 近白色阈值：RGB565 各通道都高于此值则视为"近白色"
# R>=24/31, G>=48/63, B>=24/31 => 0xC618
NEAR_WHITE_THRESHOLD = 0xC618

def rgb565_components(val):
    """返回 (r, g, b) 各通道值，范围 0-31, 0-63, 0-31"""
    r = (val >> 11) & 0x1F
    g = (val >> 5) & 0x3F
    b = val & 0x1F
    return r, g, b

def is_near_white(val):
    """判断 RGB565 值是否接近白色（抗锯齿边缘或背景）"""
    if val == 0x0000:  # 已经是黑色背景
        return False
    return val > NEAR_WHITE_THRESHOLD

def parse_frame_data(text, start_pos):
    """解析一个 96x96 RGB565 数组，返回 (rows, end_pos)"""
    eq_pos = text.index('=', start_pos)
    brace_pos = text.index('{', eq_pos)

    values = []
    current_val = ""
    i = brace_pos + 1

    while i < len(text):
        ch = text[i]
        if ch == '{':
            i += 1
            continue
        elif ch == '}':
            if current_val.strip():
                val_str = current_val.strip()
                if val_str.startswith('0x') or val_str.startswith('0X'):
                    values.append(int(val_str, 16))
            i += 1
            break
        elif ch == ',' or ch == '\n' or ch == '\r':
            if current_val.strip():
                val_str = current_val.strip()
                if val_str.startswith('0x') or val_str.startswith('0X'):
                    values.append(int(val_str, 16))
            current_val = ""
            i += 1
            continue
        else:
            current_val += ch
            i += 1

    expected = 96 * 96
    if len(values) < expected:
        print(f"  WARNING: Expected {expected} values, got {len(values)}")

    rows = []
    for r in range(96):
        row = values[r * 96 : min((r + 1) * 96, len(values))]
        while len(row) < 96:
            row.append(0x0000)
        rows.append(row)

    return rows, i


def flood_fill_near_white(rows):
    """从四边 BFS，标记所有连到边缘的近白色像素（>NEAR_WHITE_THRESHOLD）。
    返回需要替换为 0x0000 的坐标集合。
    """
    h, w = 96, 96
    visited = [[False] * w for _ in range(h)]
    to_replace = set()
    q = deque()

    # 四边入队：只入队近白色像素
    for col in range(w):
        if is_near_white(rows[0][col]):
            q.append((0, col))
            visited[0][col] = True
        if is_near_white(rows[h-1][col]):
            q.append((h-1, col))
            visited[h-1][col] = True
    for row in range(1, h-1):
        if is_near_white(rows[row][0]):
            q.append((row, 0))
            visited[row][0] = True
        if is_near_white(rows[row][w-1]):
            q.append((row, w-1))
            visited[row][w-1] = True

    while q:
        r, c = q.popleft()
        to_replace.add((r, c))
        for dr, dc in [(-1,0), (1,0), (0,-1), (0,1)]:
            nr, nc = r + dr, c + dc
            if 0 <= nr < h and 0 <= nc < w and not visited[nr][nc]:
                if is_near_white(rows[nr][nc]):
                    visited[nr][nc] = True
                    q.append((nr, nc))

    return to_replace


def erode_fringe(rows, bg_mask, iterations=3):
    """对已标记的背景像素，向外侵蚀近白色的抗锯齿边缘。
    返回扩展后的 mask。
    """
    h, w = 96, 96
    mask = set(bg_mask)

    for it in range(iterations):
        added = set()
        for (r, c) in mask:
            for dr, dc in [(-1,0), (1,0), (0,-1), (0,1)]:
                nr, nc = r + dr, c + dc
                if 0 <= nr < h and 0 <= nc < w:
                    if (nr, nc) not in mask and is_near_white(rows[nr][nc]):
                        added.add((nr, nc))
        mask |= added
        if added:
            print(f"    Erosion iter {it+1}: added {len(added)} fringe pixels")

    return mask


def main():
    with open(HEADER, 'r', encoding='utf-8') as f:
        content = f.read()

    # 备份
    with open(BACKUP, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Backup: {BACKUP}")

    import re
    pattern = r'const uint16_t (pet_\w+_frame)\[96\]\[96\] PROGMEM'
    matches = list(re.finditer(pattern, content))
    print(f"Found {len(matches)} frames\n")

    if not matches:
        print("No frames found!")
        return

    modifications = []
    for m in matches:
        name = m.group(1)
        start = m.start()
        rows, end = parse_frame_data(content, start)

        total_nw = sum(1 for row in rows for v in row if is_near_white(v))
        total_ffff = sum(1 for row in rows for v in row if v == 0xFFFF)

        # 第 1 步：洪水填充近白色背景
        to_replace = flood_fill_near_white(rows)
        print(f"  {name}:")
        print(f"    Pure white (0xFFFF): {total_ffff}")
        print(f"    Near-white (>0x{NEAR_WHITE_THRESHOLD:04X}): {total_nw}")
        print(f"    Flood-filled from edge: {len(to_replace)}")

        # 应用第 1 步替换到 rows
        for (r, c) in to_replace:
            rows[r][c] = 0x0000

        # 第 2 步：侵蚀彩边
        all_replace = erode_fringe(rows, to_replace, iterations=3)

        # 统计最终保留的近白像素
        preserved_nw = sum(1 for row in rows for v in row if is_near_white(v))
        print(f"    Total replaced: {len(all_replace)}")
        print(f"    Near-white preserved (interior): {preserved_nw}")

        modifications.append((name, start, end, rows, all_replace))

    # 从后往前替换
    modifications.reverse()
    for name, start, end, rows, all_replace in modifications:
        lines = [f"const uint16_t {name}[96][96] PROGMEM = {{"]
        for r in range(96):
            row_vals = []
            for c in range(96):
                val = rows[r][c]
                if (r, c) in all_replace:
                    val = 0x0000
                row_vals.append(f"0x{val:04X}")
            line = "    " + ",".join(row_vals)
            if r < 95:
                line += ","
            lines.append(line)
        lines.append("};")
        new_text = "\n".join(lines)
        content = content[:start] + new_text + content[end:]

    with open(OUTPUT, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"\nDone! Modified {len(modifications)} frames. Backup: {BACKUP}")


if __name__ == '__main__':
    main()
