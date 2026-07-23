---
name: pet-avatar
description: AI生成宠物卡通形象，支持拍照或文字描述输入，输出带情绪变体的形象图
metadata:
  version: "1.0"
  author: DietAI
---

# 宠物形象生成技能

## 触发条件
- 用户点击「生成专属形象」按钮
- 用户上传宠物照片请求生成卡通形象
- 用户描述宠物外观特征请求生成

## 执行流程

### 1. 输入方式选择
- **拍照上传**：调用设备摄像头拍摄宠物照片
- **描述输入**：用户描述宠物外观特征（如"橘猫，白手套，绿眼睛，胖嘟嘟"）

### 2. 形象生成（通义万相API）
```
POST https://dashscope.aliyuncs.com/api/v1/services/aigc/image-generation/generation
{
  "model": "wanx-v2",
  "input": {
    "prompt": "卡通风格的宠物形象，{用户描述}，可爱，Q版，柔和色调",
    "negative_prompt": "照片，真实，恐怖，暴力"
  },
  "parameters": {
    "style": "<cartoon>",
    "size": "512*512"
  }
}
```

### 3. 背景抠图（rembg）
使用 rembg 库移除背景，生成透明PNG：
```python
from rembg import remove
from PIL import Image

input_image = Image.open("original.png")
output_image = remove(input_image)
output_image.save("transparent.png")
```

### 4. 情绪变体生成
基于基础形象，生成4种情绪状态：
- `happy` - 开心（眯眼笑、摇尾巴）
- `normal` - 正常（标准表情）
- `hungry` - 饿了（期待眼神、流口水）
- `weak` - 生病/虚弱（无精打采）

实现方式：
1. 向API发送额外prompt变体请求
2. 或使用本地图像处理添加表情元素（更省成本）

### 5. 存储与返回
- 基础形象存储至 MinIO（路径：`pet-avatars/{user_id}/{pet_id}/base.png`）
- 情绪变体存储至 MinIO（路径：`pet-avatars/{user_id}/{pet_id}/{emotion}.png`）
- 返回所有图片URL给前端

## 输出格式
```json
{
  "task_id": "gen_123_20260716",
  "status": "completed",
  "pet_id": 123,
  "base_image_url": "https://minio.../base.png",
  "emotions": {
    "happy": "https://minio.../happy.png",
    "normal": "https://minio.../normal.png",
    "hungry": "https://minio.../hungry.png",
    "weak": "https://minio.../weak.png"
  },
  "generation_time_seconds": 12
}
```

## 前端伪动画
前端展示时实现伪动画效果：
- **呼吸**：scale 1.0 → 1.02 → 1.0，循环3秒
- **眨眼**：每5秒触发一次眨眼（opacity动画）
- **摇尾巴**：rotation动画（仅狗）

## 成本估算
- 通义万相API：约 0.05元/张
- 单次完整生成（基础+4情绪）：约 0.25元

## 可用工具
- `generate_pet_avatar` - 调用通义万相生成形象
- `remove_background` - rembg抠图
- `generate_emotion_variants` - 生成情绪变体
- `upload_to_minio` - 上传至MinIO存储