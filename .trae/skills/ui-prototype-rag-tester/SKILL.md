---
name: ui-prototype-rag-tester
description: |
  UI原型分析、知识库构建与测试用例生成一体化编排技能。
  当用户上传UI截图或需求文档并需要：1)分析生成页面文档；2)构建知识库；3)生成测试用例时触发此技能。
  完整流程：ui-prototype-analyzer（支持图片+需求文档）→ rag-implementation → test-case-generator
---

# UI原型分析-知识库构建-测试用例生成编排技能

本技能编排三个子技能，形成从UI原型/需求文档到测试用例的完整自动化流程。

## 输入材料

本技能支持两种输入材料（可单独使用或组合使用）：
- 📷 **UI原型设计图**：PNG、JPG 等图片格式
- 📄 **需求文档**：Markdown、TXT、Word、PDF 等文本格式

## 工作流程编排

### 第一阶段：UI原型分析
调用 `ui-prototype-analyzer` skill 分析上传的UI截图和需求文档。

**执行步骤：**
1. 使用 `use_skill("ui-prototype-analyzer")` 加载技能
2. 扫描工作空间，识别需求文档（*.md, *.txt, *.docx, *.pdf）
3. 解析需求文档内容（业务场景、功能模块、字段定义、业务规则）
4. 分析用户上传的图片文件，识别页面元素和布局
5. 融合分析：将需求文档与UI图片的信息进行交叉验证和补充
6. 生成结构化的页面分析文档（包含：页面名称、功能模块、交互元素、操作流程、业务规则）
7. 保存分析结果为 `.md` 文件

**输出文件命名规范：** `{项目名}_{页面名称}_页面分析.md`

### 第二阶段：知识库构建
调用 `rag-implementation` skill 将页面文档向量化存入知识库。

**执行步骤：**
1. 使用 `use_skill("rag-implementation")` 加载技能
2. 读取第一阶段生成的页面分析文档
3. 调用 `RAG_search` 工具存入知识库（知识库名称：`ui_pages`）
4. 按功能模块分类存储，便于后续检索

**知识库存储结构：**
```
知识库: ui_pages
├── 页面信息 (页面名称、URL路由)
├── 功能元素 (按钮、表单、列表、弹窗等)
├── 交互逻辑 (用户操作流程)
└── 业务规则 (业务逻辑说明)
```

### 第三阶段：测试用例生成
调用 `test-case-generator` skill 基于知识库生成测试用例。

**执行步骤：**
1. 使用 `use_skill("test-case-generator")` 加载技能
2. 从 `ui_pages` 知识库检索相关页面信息
3. 结合测试用例设计方法（等价类、边界值、场景法）
4. 使用Python脚本（openpyxl）生成Excel测试用例文档

**输出文件命名规范：** `{项目名}_测试用例_{日期}.xlsx`

## 编排执行示例

### 示例一：仅上传UI图片
```
用户上传: 护理计划单页面截图.png

执行流程:
1. ui-prototype-analyzer → 护理计划单_页面分析.md
2. rag-implementation → 存入 ui_pages 知识库
3. test-case-generator → 护理系统_测试用例_20260517.xlsx
```

### 示例二：仅上传需求文档
```
用户上传: 随访管理需求文档.md

执行流程:
1. ui-prototype-analyzer → 解析需求文档 → 生成页面分析文档
2. rag-implementation → 存入 ui_pages 知识库
3. test-case-generator → 随访系统_测试用例_20260519.xlsx
```

### 示例三：同时上传UI图片和需求文档（推荐）
```
用户上传: 
  - 随访管理需求文档.md
  - 随访首页截图.png
  - 随访任务截图.png
  - 新建任务弹窗截图.png

执行流程:
1. ui-prototype-analyzer → 融合分析 → 生成页面分析文档
2. rag-implementation → 存入 ui_pages 知识库
3. test-case-generator → 随访系统_测试用例_20260519.xlsx
```

## 关键文件路径

| 阶段 | 输入 | 输出 |
|------|------|------|
| UI分析 | `{workspace}/*.png`, `*.md`, `*.pdf`, `*.docx` | `{workspace}/*_页面分析.md` |
| 知识库 | `*_页面分析.md` | ui_pages 知识库 |
| 测试用例 | ui_pages 知识库 | `{workspace}/*_测试用例_*.xlsx` |

## 注意事项

- 确保图片和文档文件可访问，路径使用绝对路径
- 同时提供图片和需求文档时，分析结果更完整准确
- 知识库检索时使用 `knowledgeBaseNames: "ui_pages"`
- 测试用例优先使用Python openpyxl直接生成.xlsx文件
