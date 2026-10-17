"""Clean main.cpp: remove old layout, keep only bg + clock + bottom bar"""
import re

path = r'f:\project\DietAI\firmware\dietai-firmware\src\main.cpp'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

changes = []

# 1. Remove pet_frames.h include
content = content.replace('#include "pet_frames.h"   // 宠物帧动画数据\n', '')
changes.append('Removed pet_frames.h include')

# 2. Remove pet state variables block
content = content.replace(
    '// ===== 宠物精灵 =====\n'
    '// PetStateIndex 枚举定义在 pet_frames.h 中\n'
    '\n'
    'PetStateIndex petState = PET_NORMAL;\n'
    'unsigned long petStateTime = 0;   // 状态切换时间戳（用于自动恢复）\n'
    'const unsigned long PET_HAPPY_DURATION = 3000;  // 开心状态持续 3 秒\n'
    'int petFrameIdx = 0;                    // 当前动画帧索引\n'
    'unsigned long lastPetFrameTime = 0;     // 上次帧切换时间\n'
    'const unsigned long PET_FRAME_INTERVAL = 150;  // 帧间隔 ms（5帧循环）\n',
    ''
)
changes.append('Removed pet state variables')

# 3. Remove 6 counter variables
content = content.replace(
    'int countWater = 0;\n'
    'int countBreakfast = 0;\n'
    'int countLunch = 0;\n'
    'int countDinner = 0;\n'
    'int countSnack = 0;\n'
    'int countSupper = 0;\n',
    ''
)
changes.append('Removed counter variables')

# 4. Remove CAL_ defines
content = content.replace(
    '#define CAL_BREAKFAST 400\n'
    '#define CAL_LUNCH     600\n'
    '#define CAL_DINNER    700\n'
    '#define CAL_SNACK     150\n'
    '#define CAL_SUPPER    300\n',
    ''
)
changes.append('Removed CAL_ defines')

# 5. Simplify progress data section
content = content.replace(
    '// ===== 进度数据 =====\n'
    'int waterTotalMl = 0;       // 今日饮水总量\n'
    'int waterGoalMl = 2000;     // 饮水目标\n'
    'int calorieTotal = 0;       // 今日热量总量（本地累加）\n'
    'int calorieGoal = 1800;     // 热量目标\n'
    'unsigned long lastProgressUpdate = 0;  // 进度刷新计时\n',
    '// ===== 健康数据 =====\n'
    'int waterTotalMl = 0;\n'
    'int waterGoalMl = 2000;\n'
    'int calorieTotal = 0;\n'
    'int calorieGoal = 1800;\n'
    'unsigned long lastProgressUpdate = 0;\n'
)
changes.append('Simplified progress vars')

# 6. Remove drawCounters()
idx = content.find('// ===== 界面：绘制按键计数区')
if idx >= 0:
    end = content.find('\n\n', content.find('}\n', idx))
    if end < 0:
        end = content.find('\n// ====', content.find('}\n', idx))
    old = content[idx:end+2]
    content = content.replace(old, '')
    changes.append(f'Removed drawCounters() ({len(old)} chars)')
else:
    changes.append('drawCounters: NOT FOUND')

# 7. Remove drawProgressBar + drawProgress
idx = content.find('// ===== 界面：绘制进度条')
if idx < 0:
    idx = content.find('void drawProgressBar')
    if idx > 0:
        idx = content.rfind('\n', 0, idx) + 1
if idx >= 0:
    dp = content.find('void drawProgress()')
    end = content.find('\n\n', content.find('}\n', dp))
    if end < 0:
        end = content.find('\n// ====', content.find('}\n', dp))
    old = content[idx:end+2]
    content = content.replace(old, '')
    changes.append(f'Removed drawProgress section ({len(old)} chars)')
else:
    changes.append('drawProgress: NOT FOUND')

# 8. Remove pet drawing code (defines + drawPet + petAnimate + petSetState)
idx = content.find('// ===== 界面：绘制宠物精灵')
if idx < 0:
    idx = content.find('#define PET_X')
    if idx > 0:
        idx = content.rfind('\n', 0, idx) + 1
if idx >= 0:
    pss = content.find('void petSetState')
    end = content.find('\n\n', content.find('}\n', pss))
    if end < 0:
        end = content.find('\n// ====', content.find('}\n', pss))
    old = content[idx:end+2]
    content = content.replace(old, '')
    changes.append(f'Removed pet drawing code ({len(old)} chars)')
else:
    changes.append('pet drawing: NOT FOUND')

# 9. Rewrite drawAll + add drawBottomBar
old_drawall = (
    'void drawAll() {\n'
    '    // 先画背景动画（如果播放器就绪），否则黑底\n'
    '    if (bg_player.frames) {\n'
    '        tft.pushImage(0, 0, BG_W, BG_H, animFrame(&bg_player));\n'
    '    } else {\n'
    '        tft.fillScreen(TFT_BLACK);\n'
    '    }\n'
    '    drawStatus();\n'
    '    drawClock();\n'
    '    drawCounters();\n'
    '    drawProgress();\n'
    '    drawPet();\n'
    '}'
)
new_code = (
    '// ===== 底部状态汇总 =====\n'
    'void drawBottomBar() {\n'
    '    tft.fillRect(0, 290, 240, 30, TFT_BLACK);\n'
    '    tft.setTextSize(1);\n'
    '    tft.setTextColor(TFT_WHITE);\n'
    '    tft.setCursor(5, 297);\n'
    '    tft.printf("H2O %d/%dml", waterTotalMl, waterGoalMl);\n'
    '    tft.drawLine(130, 294, 130, 316, 0x528A);\n'
    '    tft.setCursor(138, 297);\n'
    '    tft.printf("CAL %d/%d", calorieTotal, calorieGoal);\n'
    '}\n'
    '\n'
    '// ===== 全量重绘 =====\n'
    'void drawAll() {\n'
    '    if (bg_player.frames) {\n'
    '        tft.pushImage(0, 0, BG_W, BG_H, animFrame(&bg_player));\n'
    '    } else {\n'
    '        tft.fillScreen(TFT_BLACK);\n'
    '    }\n'
    '    drawStatus();\n'
    '    drawClock();\n'
    '    drawBottomBar();\n'
    '}'
)
if old_drawall in content:
    content = content.replace(old_drawall, new_code)
    changes.append('Rewrote drawAll() + drawBottomBar()')
else:
    changes.append('drawAll: NOT FOUND')

# 10. Remove petAnimate call from loop
content = content.replace(
    '    // 宠物帧动画推进（每 200ms 切一帧）\n'
    '    petAnimate();\n',
    ''
)
changes.append('Removed petAnimate() call')

# 11. Remove progress refresh timer's drawProgress call
content = content.replace(
    '        refreshProgress();\n'
    '        drawProgress();\n'
    '    }\n'
    '\n'
    '    bool changed = false;',
    '        refreshProgress();\n'
    '    }'
)
changes.append('Removed drawProgress() from refresh timer')

# 12. Remove pet state auto-revert
old_revert = (
    '    // 开心/焦虑状态自动恢复\n'
    '    if (petState == PET_HAPPY && millis() - petStateTime > PET_HAPPY_DURATION) {\n'
    '        petSetState(PET_NORMAL);\n'
    '    }\n'
    '    if (petState == PET_ANXIOUS && millis() - petStateTime > PET_HAPPY_DURATION) {\n'
    '        petSetState(PET_NORMAL);\n'
    '    }\n'
)
if old_revert in content:
    content = content.replace(old_revert, '')
    changes.append('Removed pet state auto-revert')
else:
    changes.append('pet revert: NOT FOUND')

# 13. Clean button handlers
# Remove petSetState calls
for state in ['PET_HAPPY', 'PET_ANXIOUS']:
    old = f'            petSetState({state});\n'
    count = content.count(old)
    content = content.replace(old, '')
    if count:
        changes.append(f'Removed {count}x petSetState({state})')

# Remove counter increments
for counter in ['countWater', 'countBreakfast', 'countLunch', 'countDinner', 'countSnack', 'countSupper']:
    old = f'            {counter}++;\n'
    count = content.count(old)
    content = content.replace(old, '')
    if count:
        changes.append(f'Removed {count}x {counter}++')

# Remove Serial.printf for counters
for label in ['Water', 'Breakfast', 'Lunch', 'Dinner', 'Snack', 'Supper']:
    pattern = f'            Serial.printf("{label} OK'
    while pattern in content:
        idx = content.find(pattern)
        linestart = content.rfind('\n', 0, idx) + 1
        lineend = content.find('\n', idx)
        old = content[linestart:lineend+1]
        content = content.replace(old, '')
        changes.append(f'Removed Serial.printf for {label}')

# Remove refreshProgress/drawProgress pairs in button handlers
for old in ['            refreshProgress();  // API 同步校正\n            drawProgress();\n',
            '            refreshProgress();  // API 同步校正\n',
            '            drawProgress();\n']:
    count = content.count(old)
    content = content.replace(old, '')
    if count:
        changes.append(f'Removed {count}x progress refresh in buttons')

# Remove changed variable
content = content.replace('    bool changed = false;\n\n', '')
content = content.replace('    bool changed = false;\n', '')
content = content.replace('        changed = true;\n', '')
content = content.replace('    if (changed) drawCounters();\n', '')
changes.append('Removed changed variable + drawCounters()')

# 14. Remove the extra blank lines left behind
while '\n\n\n\n' in content:
    content = content.replace('\n\n\n\n', '\n\n\n')
while '\n\n\n' in content:
    content = content.replace('\n\n\n', '\n\n')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

for c in changes:
    print(f'  [OK] {c}')
print(f'\nDone: {len(changes)} changes applied')
