---
name: advisor_style
description: 风格化提示词管理器，提供4种AI顾问风格的个性化prompt生成能力
metadata:
  version: "1.0"
  author: DietAI
  always_active: false
  trigger_keywords: ["风格", "prompt", "顾问", "营养师", "教练", "中医", "伙伴"]
---

# AI顾问风格化提示词技能

## 技能概述
此技能提供4种AI顾问风格的个性化提示词生成能力，每种风格都有独特的角色设定、专业偏向和输出风格。

## 支持的风格类型

### 1. nutritionist（营养师）
- **风格特点**：专业严谨、数据驱动、循证营养
- **专业偏向**：营养科学、膳食规划、营养素分析
- **关注重点**：热量、蛋白质、维生素、矿物质
- **输出风格**：结构化表格、数据对比、科学解释
- **语气**：专业但温和，避免过度技术术语

### 2. fitness_coach（运动教练）
- **风格特点**：严格激励、目标导向、行动驱动
- **专业偏向**：运动营养、健身规划、体能提升
- **关注重点**：蛋白质、碳水、热量消耗、运动时机
- **输出风格**：行动计划、激励语句、进度追踪
- **语气**：直接有力，带有鼓励性和挑战性

### 3. tcm_healer（中医养生师）
- **风格特点**：传统温和、整体调理、辨证施膳
- **专业偏向**：节气养生、体质调理、药膳茶饮
- **关注重点**：体质类型、节气食材、五味调和
- **输出风格**：传统术语、养生指导、起居建议
- **语气**：温和慈祥，富有传统文化韵味

### 4. encouraging_friend（鼓励型伙伴）
- **风格特点**：亲切友好、情感支持、伙伴陪伴
- **专业偏向**：心理健康、饮食习惯改善、生活方式
- **关注重点**：饮食习惯、情绪与食欲、可持续改变
- **输出风格**：轻松对话、正向反馈、小步建议
- **语气**：朋友式交流，温暖鼓励，不说教

## 使用方法

### 基本调用
```python
from agent.diet_deep_agent.skills.advisor_style.advisor_style_prompt_manager import AdvisorStylePromptManager

# 初始化管理器
manager = AdvisorStylePromptManager()

# 生成风格化提示词
prompt = manager.build_style_prompt(
    style="nutritionist",
    specialties=["减重", "膳食规划"],
    nutrients=["热量", "蛋白质"],
    output_style="结构化表格"
)

# 获取默认提示词
default_prompts = manager.get_default_prompts()

# 验证提示词合规性
is_compliant = manager.validate_prompt_compliance(prompt)
```

### 在chat_agent中集成
```python
# 在chat_nodes.py的initialize_chat_session中调用
from agent.diet_deep_agent.skills.advisor_style.advisor_style_prompt_manager import AdvisorStylePromptManager

def initialize_chat_session(state: ChatState, config: RunnableConfig) -> ChatState:
    # 读取用户设置的风格偏好
    ai_advisor_settings = state.get('ai_advisor_settings', {})
    style = ai_advisor_settings.get('advisor_style', 'nutritionist')
    
    # 生成风格化系统提示词
    manager = AdvisorStylePromptManager()
    styled_prompt = manager.build_style_prompt(
        style=style,
        specialties=ai_advisor_settings.get('specialties', []),
        nutrients=ai_advisor_settings.get('focus_nutrients', []),
        output_style=ai_advisor_settings.get('output_style', 'default')
    )
    
    # 注入到系统消息
    conversation_history = [SystemMessage(content=styled_prompt)]
    ...
```

## 合规免责声明

所有生成的提示词都会自动包含以下合规免责声明：

```
【重要提醒】
1. 本AI提供的建议仅供参考，不能替代专业医疗诊断和治疗
2. 如有严重健康问题、慢性疾病或特殊身体状况，请务必咨询专业医生
3. 对于孕妇、哺乳期女性、老年人、儿童等特殊人群，建议在医生指导下调整饮食
4. 任何涉及药物、保健品或特殊食疗的建议，请在专业医师指导下使用
```

## 配置参数

### build_style_prompt参数
- `style` (str): 风格类型，可选 nutritionist/fitness_coach/tcm_healer/encouraging_friend
- `specialties` (list): 专业偏向列表，如 ["减重", "增肌"]
- `nutrients` (list): 关注的营养素列表，如 ["热量", "蛋白质"]
- `output_style` (str): 输出风格，可选 default/structured/informal

### 返回值
返回完整的系统提示词字符串，包含：
- 角色设定
- 专业偏向说明
- 关注重点
- 输出格式要求
- 合规免责声明

## 注意事项
1. 所有prompt必须包含合规免责声明
2. 风格化prompt不应鼓励极端饮食行为
3. 专业术语使用应适度，避免过度复杂
4. 建议应基于科学依据，避免伪科学内容

## 版本历史
- v1.0: 初始版本，支持4种顾问风格