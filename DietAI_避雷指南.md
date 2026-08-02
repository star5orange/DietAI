# DietAI 常见问题与避雷指南

> 供新对话快速了解项目坑点，避免重复踩坑。

---

## 1. Flutter API 地址配置

**文件**: `frontend_flutter/lib/core/constants/api_config.dart`

**核心机制**: `_getDevBaseUrl()` 是实际生效的方法，不是 `devBaseUrl` / `devLocalNetworkUrl` 本身。

**避雷**:
- 本地调试时 `_getDevBaseUrl()` 必须返回 `devBaseUrl`（localhost），不能返回 `devLocalNetworkUrl`
- MinIO 的 `_getDevMinioUrl()` 对应返回 `devMinioUrl`（9000端口），**不要写成 `devBaseUrl`**
- **改动后必须完全重建 Flutter**：静态方法改动不生效于 hot reload/restart，必须 `flutter clean → flutter pub get → flutter run`

---

## 2. 数据库密码重置

PostgreSQL 中用户密码是 bcrypt 哈希，`$2b$` 前缀。**用 PowerShell SQL 命令重置密码会出错**——PowerShell 把 `$` 解析为变量导致截断。

**正确做法**：用 Python 脚本操作：
```python
from passlib.context import CryptContext
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
hashed = pwd_context.hash("新密码")
# 然后 UPDATE users SET hashed_password = ? WHERE id = ?
```

---

## 3. 后端端口冲突

`uvicorn --reload` 模式会创建子进程。如果 kill 父进程（Ctrl+C），子进程可能继续占用端口。

**症状**: `[winerror 10048] 端口被占用`

**解决**:
```powershell
netstat -ano | findstr :8000    # 找到 PID
taskkill /F /PID <PID>          # 杀掉所有占用进程
# 然后重启
```

---

## 4. 轻断食功能

### 完成率计算
- **16:8**: 分母用天数（连续打卡制），显示"连续打卡 X 天"
- **5:2 / 基础断食**: 分母用 `expected_fasting_days`（整个计划周期内的断食日总数，不是已过天数），公式 `completed_count ÷ expected_fasting_days × 100`
- 5:2 和基础断食 **不显示"连续打卡"和"本周打卡"指标**

### 术语统一
- "基础辟谷" → "基础断食"（全部9个文件已改）
- "基础断食"标签固定，不与"辟谷"混用

### 断食日判定
- 前端 weekday（1=周一~7=周日）需要 `+1` 对齐 Python `weekday()`（0=周一）
- 打卡按钮只在断食日可点击，非断食日显示"今日非断食日"

### 默认时长
- 16:8 = 30天，5:2 = 56天，基础断食 = 7天

### 免责声明
- 创建计划后端强制校验 `disclaimer_accepted = True`
- 前端弹出1次即可

### 5:2 天数选择
- 至少选2天，基础断食选1-2天
- 对话框使用 toggle 行为（点击选中、再点取消）

---

## 5. 热量来源分析

### 首页环形图
- 图例百分比必须用**热量加权**计算：`(蛋白质g×4 + 碳水g×4 + 脂肪g×9)` 为分母，各类热量÷总热量
- **不能用克重直接算百分比**，否则与环形图 arc 长度不一致
- `显示值` 直接取 `totalCalories`，不要用宏量反推
- SSE 和传统食物记录端点都必须调用 `update_daily_nutrition_summary`

---

## 6. 宠物功能

### pet_service.dart 陷阱
- `rename` 方法需确保 `try { ... } catch (e) { ... }` 完整配对
- 方法名：`petFeed()`, `petInteract(action: 'water')`, `petTouch()`
- `CircularProgressIndicator` 用 `color` 参数（Flutter 3.x 废弃了 `progressColor`）
- `PetState` 用 `currentStreak` 不用 `streak`

### 数据库字段
- `pet_avatars.url` 字段需 `VARCHAR(2000)`（DashScope 签名图片 URL 很长）

### 数据隔离
- 宠物 AI 对话 `session_type = 6`，不能注入人的数据
- AI 上下文必须包含 `pet_id` + 宠物品种/年龄/体重/饮食记录 + 安全准则 + 兽医免责声明

### 疫苗记录
- 疫苗名必须是**物种特异性下拉选项** + "其他（自定义）"
- 含红色 `*` 标记必填
- 保存需 loading 状态 + 明确反馈

---

## 7. 首页布局

- 今日饮水和运动记录 **分两行**（各占整行宽度）
- 饮水只有水量输入 + 快捷 ml 按钮，**无饮品类型和时间段**
- 热量目标优先读取用户自定义的 `targetCalories`

---

## 8. Flask→Flutter 前后端对接

### BaseResponse 包装
所有 API 返回统一格式：`{success: true, data: ...}`，不能返回裸数组/对象

### 前端 List 转换
Flutter 中 API 返回的 List 可能被序列化为 `List<dynamic>`，涉及 Map 操作时需 `_safeList()` 兜底

### 日期字段
- 前端 `date.split('-')` 取 `parts[1]` 是月份，`parts[0]` 是年份
- JSON 字段（如 `recommended_foods`）可能是字符串格式的 JSON，需 `_parse_json()` 解析

---

## 9. 性能问题

- PageView 的 item 重构应尽量少，考虑依赖分离
- `Future.wait()` 并行请求需用 per-request `try-catch`，一个失败不影响其他
- AI 服务不可用时需实现数据库 fallback 逻辑

---

## 10. 快速诊断

| 症状 | 排查方向 |
|------|----------|
| Flutter 连接超时 | API 地址是否正确？`flutter clean` 重建了没？后端在跑吗？ |
| 登录后页面数据全空 | 检查 `onboarding_completed` 是否为 true、Profile 表是否被删 |
| 端口被占用 | 杀残留 uvicorn 子进程 |
| AI 不响应 | LangGraph 服务（2024端口）是否启动？ |
| 饮食记录保存后首页不更新 | 对应的 API 端点是否调用了 `update_daily_nutrition_summary` |
| 宠物 AI 获取不到体重 | `chat_nodes.py` 是否查询了 `PetWeightRecord` 表 |
| 5:2 打卡1次显示100% | 完成率分母是否用了总断食日数而非已过天数 |

---

## 11. 测试方案相关

参考文件: `DietAI_验收测试大纲.md`、`DietAI_人工测试方案.html`

测试方案 HTML 文件中用例通过 `testCases` 数组定义，重新编号时需确保 TC-001 到 TC-N 连续无间断。
