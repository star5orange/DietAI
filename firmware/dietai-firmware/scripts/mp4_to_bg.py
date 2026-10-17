"""
MP4 视频 → ESP32 全屏背景动画 C 代码
使用 OpenCV 抽帧 → resize 240×320 → RGB565
"""
import cv2
import os

VIDEO_PATH = r'F:\project\plan\hardware\小猫动画.mp4'
OUTPUT = os.path.join(os.path.dirname(__file__), '..', 'src', 'bg_anim.h')
TARGET_W, TARGET_H = 240, 320
SAMPLE_STEP = 6  # 每6帧取1帧（原24fps→4fps效果）

def rgb565(b, g, r):  # OpenCV 返回 BGR
    return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)


def main():
    cap = cv2.VideoCapture(VIDEO_PATH)
    if not cap.isOpened():
        print(f"ERROR: Cannot open {VIDEO_PATH}")
        return

    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    print(f"Video: {total} frames, {fps:.1f}fps")
    print(f"Sample step: {SAMPLE_STEP} → ~{total//SAMPLE_STEP} frames output")

    frames = []
    idx = 0
    while True:
        ret, frame = cap.read()
        if not ret:
            break

        if idx % SAMPLE_STEP == 0 or idx == total - 1:
            # BGR → RGB, resize to 240×320
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            resized = cv2.resize(frame_rgb, (TARGET_W, TARGET_H),
                                 interpolation=cv2.INTER_LANCZOS4)

            # → RGB565 array
            data = []
            for y in range(TARGET_H):
                for x in range(TARGET_W):
                    r, g, b = resized[y, x]
                    data.append(rgb565(b, g, r))  # pass as BGR order for our helper
            frames.append(data)

            if len(frames) % 10 == 0:
                print(f"  extracted {len(frames)} frames (frame {idx}/{total})")

        idx += 1

    cap.release()
    n = len(frames)
    per_frame_kb = TARGET_W * TARGET_H * 2 / 1024
    total_kb = n * per_frame_kb
    print(f"\nDone: {n} frames, ~{total_kb:.0f} KB flash ({total_kb/1024:.1f} MB)")

    # 帧间隔：原视频帧率 / 采样步长 的倒数
    effective_interval = int(SAMPLE_STEP / fps * 1000)  # ms
    print(f"Frame interval: {effective_interval}ms (~{1000/effective_interval:.1f}fps)")

    # ======== 生成 C 头文件 ========
    name = "bg_anim"
    lines = []
    lines.append(f"""/**
 * 全屏背景动画 — 自动生成
 * 源: {os.path.basename(VIDEO_PATH)}
 * 帧数: {n}  尺寸: {TARGET_W}×{TARGET_H} RGB565
 * Flash: ~{total_kb:.0f} KB  帧间隔: {effective_interval}ms
 */
#ifndef BG_ANIM_H
#define BG_ANIM_H
#include <stdint.h>

#define BG_FRAMES      {n}
#define BG_W           {TARGET_W}
#define BG_H           {TARGET_H}
#define BG_DELAY_MS    {effective_interval}
""")

    # 帧数据
    for i, data in enumerate(frames):
        lines.append(f"const uint16_t bg_frame_{i}[{TARGET_H}][{TARGET_W}] PROGMEM = {{")
        for y in range(TARGET_H):
            row = data[y * TARGET_W : (y + 1) * TARGET_W]
            vals = ",".join(f"0x{v:04X}" for v in row)
            comma = "," if y < TARGET_H - 1 else ""
            lines.append(f"    {vals}{comma}")
        lines.append("};")
        lines.append("")

    # 帧指针表
    lines.append(f"const uint16_t* const bg_frames[{n}] = {{")
    ptrs = ",\n    ".join(f"bg_frame_{i}[0]" for i in range(n))
    lines.append(f"    {ptrs}")
    lines.append("};")
    lines.append("")

    # 播放器结构（与 pet_anim.h 相同接口，方便统一）
    lines.append(f"""typedef struct {{
    const uint16_t** frames;
    uint16_t total;
    uint16_t delay_ms;
    uint16_t current;
    uint32_t last_ms;
}} AnimPlayer;

static AnimPlayer bg_player = {{
    .frames  = (const uint16_t**)bg_frames,
    .total   = {n},
    .delay_ms = {effective_interval},
    .current = 0,
    .last_ms = 0,
}};

static inline bool animUpdate(AnimPlayer* p, uint32_t now) {{
    if (now - p->last_ms >= p->delay_ms) {{
        p->current = (p->current + 1) % p->total;
        p->last_ms = now;
        return true;
    }}
    return false;
}}

static inline const uint16_t* animFrame(AnimPlayer* p) {{
    return p->frames[p->current];
}}

#endif
""")

    with open(OUTPUT, 'w', encoding='utf-8') as f:
        f.write("\n".join(lines))

    # 统计文件大小
    file_kb = os.path.getsize(OUTPUT) / 1024
    print(f"\nOutput: {OUTPUT}")
    print(f"File size: {file_kb:.0f} KB")

    # 简短示例
    print(f"""
// === 在 main.cpp 中使用 ===
#include "bg_anim.h"

// setup() 中
bg_player.current = 0;
bg_player.last_ms = millis();

// loop() 中 — 在绘制其他元素之前
if (animUpdate(&bg_player, millis())) {{
    tft.pushImage(0, 0, BG_W, BG_H, animFrame(&bg_player));
}}

// 或者逐行绘制（避免全屏刷新时闪烁）
const uint16_t* bg = animFrame(&bg_player);
tft.pushImage(0, 0, BG_W, BG_H, bg);
""")

if __name__ == '__main__':
    main()
