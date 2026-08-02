---
name: test-case-generator
description: |
  生成Excel格式测试用例文档。当用户需要创建测试用例、设计测试点、生成测试用例表格、或将测试需求整理为Excel文件时使用此技能。适用于软件测试工程师、QA人员、产品经理等需要编写和整理测试用例的场景。
---

# 测试用例生成器

此技能用于从需求文档或功能描述中提取测试点，生成标准化的Excel测试用例文档。

## 核心能力

1. 需求分析 - 深度挖掘显性和隐性需求
2. 测试点提炼 - 使用等价类、边界值、场景法等设计测试用例
3. Excel生成 - 使用Python openpyxl库生成规范的xlsx文件

## 使用流程

### Step 1: 收集需求文档

阅读用户提供的所有相关文档（需求文档、UI设计稿、功能说明等），理解：
- 系统功能模块划分
- 业务流程和数据流
- 用户角色和权限
- 界面元素和交互逻辑

### Step 2: 提炼测试点

根据需求文档内容，按以下维度设计测试用例：

| 测试类型 | 覆盖内容 |
|----------|----------|
| 功能测试 | 核心功能、辅助功能、数据正确性 |
| 界面测试 | 布局展示、元素显示、状态变化 |
| 交互测试 | 按钮点击、表单提交、弹窗操作 |
| 边界测试 | 长度边界、数量边界、时间边界 |
| 异常测试 | 空值、错误值、网络异常 |
| 权限测试 | 角色权限、数据归属 |

### Step 3: 生成Excel文档（Python openpyxl方式）

**重要**: 使用Python openpyxl库生成Excel，这种方式更稳定，适合大量数据。

#### 3.1 使用脚本生成

调用 `scripts/generate_test_cases.py` 脚本：

```python
from openpyxl import Workbook
from openpyxl.styles import Font, Alignment, Border, Side, PatternFill

# 创建工作簿
wb = Workbook()
ws = wb.active
ws.title = "测试用例"

# 创建样式
header_font = Font(bold=True, size=11)
header_fill = PatternFill(start_color="D9EAD3", end_color="D9EAD3", fill_type="solid")
header_alignment = Alignment(horizontal='center', vertical='center', wrap_text=True)
cell_border = Border(
    left=Side(style='thin'), right=Side(style='thin'),
    top=Side(style='thin'), bottom=Side(style='thin')
)
cell_alignment = Alignment(vertical='top', wrap_text=True)

# 写入表头
headers = ["序号", "测试点标题", "所属模块", "二级模块", "前置条件", "操作步骤", "测试数据", "预期结果", "实际结果", "备注", "版本", "是否废止"]
for col, header in enumerate(headers, 1):
    cell = ws.cell(row=1, column=col, value=header)
    cell.font = header_font
    cell.fill = header_fill
    cell.border = cell_border
    cell.alignment = header_alignment

# 写入数据
for row_idx, row_data in enumerate(test_cases, 2):
    for col_idx, value in enumerate(row_data, 1):
        cell = ws.cell(row=row_idx, column=col_idx, value=value)
        cell.border = cell_border
        cell.alignment = cell_alignment

# 设置列宽
column_widths = {'A': 8, 'B': 28, 'C': 16, 'D': 18, 'E': 30, 'F': 45, 'G': 35, 'H': 45, 'I': 15, 'J': 20, 'K': 10, 'L': 10}
for col, width in column_widths.items():
    ws.column_dimensions[col].width = width

# 冻结首行
ws.freeze_panes = 'A2'

# 保存
wb.save(output_path)
```

#### 3.2 直接用Python命令生成

```bash
python scripts/generate_test_cases.py output.xlsx 100
```
参数说明：
- `output.xlsx` - 输出文件路径
- `100` - 可选，生成示例数据条数

### Step 4: 输出结果

生成完成后，输出以下信息：
- 文件路径
- 测试用例总数
- 各模块覆盖情况
- 关键测试设计要点

## 模板格式

| 序号 | 测试点标题 | 所属模块 | 二级模块 | 前置条件 | 操作步骤 | 测试数据 | 预期结果 | 实际结果 | 备注 | 版本 | 是否废止 |
|------|------------|----------|----------|----------|----------|----------|-----------|----------|------|------|----------|

## 字段填写规范

- **测试点标题**: 简洁明了，控制在20字以内
- **所属模块**: 按需求文档的顶级模块划分
- **二级模块**: 模块的子功能
- **前置条件**: 测试前需满足的状态
- **操作步骤**: 使用"1. 2. 3."格式，每步换行
- **预期结果**: 描述用户可见的反馈，避免技术术语

## 参考资源

- `references/test_design_guide.md` - 测试用例设计方法详细指南
