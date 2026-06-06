---
name: prd-writer
description: |
  需求分析与 PRD 文档撰写。通过结构化需求访谈将模糊想法转化为专业 PRD。
  适用场景：
  - 从粗略想法生成正式 PRD
  - 需求边界不清晰，需要多轮澄清
  - 定义用户画像、业务流程、功能/非功能需求
  - 全栈/多端项目，需按端拆分 PRD
  不适用场景（勿触发）：
  - 纯技术问答
  - 已有 PRD，只需开发代码（coding-executor）
  - 需要架构设计（system-architect）
---

## 记忆集成（跨会话上下文）

本 skill 利用 `ai_memory` MCP 工具实现跨会话上下文持久化。

### 加载上下文（每次启动时首先执行）

在 Step 0 之前执行：

```
memory_init_session(project_name="当前项目")
memory_search_summaries(module="当前模块", tags="prd", limit=5)
memory_related_decisions(project_name="当前项目", query="PRD|需求", limit=10)
```

### 保存关键决策

在 Step 2（多轮澄清）结束后，调用 `memory_add_decision()` 记录需求定义：
```
memory_add_decision(
  session_id=session-{YYYYMMDD}-prd-{module},
  decision_type=需求定义,
  description="核心用户故事/AC/优先级决策摘要",
  reasoning="基于KANO模型/用户反馈/约束条件"
)
```

### 保存任务摘要

在 Step 3（PRD 生成）完成后，调用 `memory_save_summary()`：
```
memory_save_summary(
  session_id=session-{YYYYMMDD}-prd-{module},
  task_title="PRD: {模块/项目名}",
  summary_content=生成内容摘要（包含功能清单/AC数量/关键决策）、
  file_paths=doc/prd/下生成的PRD文件路径（逗号分隔）、
  project_name=当前项目名、
  tags=prd,需求,{模块名}、
  module={模块名}、
  status=completed、
  next_steps="进入架构设计阶段，使用 system-architect"
)
```

# PRD Writer

通过结构化需求访谈生成专业 PRD。扮演资深需求分析师：理解想法→多轮澄清→验证可落地→生成 PRD。

## 懒加载原则（Lazy Loading）

1. **必须按需加载**：未到使用阶段的文件不得提前加载
2. **用完即释放**：某文件不再需要后，不再作为后续上下文保留
3. **端专属模板**：只加载当前端类型对应的模板，不加载无关模板
4. **分步加载**：访谈框架与填写指南拆分为独立文件，各在对应阶段加载

## 合并原则（Merge, don't split）

1. **端模板合并为一个文件**：后端/前端/小程序专属章节合并为 `end-specific.md`，禁止拆分为独立文件
2. **按 `##` 节跳转**：合并文件内用 `##` 节区分不同端，加载后跳转到对应节即可

## 参考文件（按需加载）

| 文件 | 加载时机 | 释放时机 | 行数 |
|------|---------|---------|------|
| `resources/interview-framework.md` | Step 1 前——访谈与提问框架 | Step 3 生成 PRD 前 | 162 |
| `resources/filling-guide.md` | Step 3 前——PRD 填写指南与行业基准 | *全部分段生成结束后* | 222 |
| `resources/glossary.md` | Step 3 前——术语表/禁用词汇 | *全部分段生成结束后* | 53 |
| `templates/common.md` | Step 3 前——通用章节骨架（所有文档共享） | *全部分段生成结束后* | 329 |
| `templates/end-specific.md` | Step 3 前——端专属章节（按端类型跳转对应 `##` 节） | *全部分段生成结束后* | 388 |

> **所有资源**：加载时机未到不得加载；端专属模板只加载当前端对应的一个。

## 工作流

### Step 0：端类型识别与锁定（第一轮必执行）

**① 探测端类型：** 用户描述中已提及的端（Web/小程序/App/纯后端）→逐一列举不合并。未提及则询问。常见的"后台管理系统"和"前端管理系统"是两个不同端。

**② 拆分方案：** 纯后端→单文件；含Web前端→后端+前端；含小程序→后端+小程序；多端→后端+前端+小程序。

**③ 锁定：** 向用户列出待生成文件清单，确认后方可进入 Step 1。

### Step 1：初步理解

加载 `resources/interview-framework.md`。用 5W1H 框架复述理解+识别缺口+提 5~8 个问题。用户描述极度模糊时先锁端类型再问业务目标。

### Step 2：多轮澄清

每轮 5~8 个问题（继续使用 `resources/interview-framework.md` 中的框架）：边界澄清、用户与场景、异常边界、冲突处理、KANO 优先级、端专属问题。连续两轮用户无法回答则记录"待补充"继续。

> 释放提示：Step 2 结束时 `interview-framework.md` 不再需要，可释放上下文中不再保留。

### Step 3：PRD 生成

范围确认清单全部满足后执行。释放 `interview-framework.md`（如仍占用）。按 Step 0 锁定的端类型清单，按需加载以下文件：

**必加载（所有端类型都需）：**
- `resources/filling-guide.md`
- `resources/glossary.md`
- `templates/common.md`

**端模板（加载 `templates/end-specific.md`，按端类型跳转对应章节）：**
- 含"后端"端类型 → 跳转 `## 后端专属章节`
- 含"Web 前端"端类型 → 跳转 `## Web 前端专属章节`
- 含"小程序"端类型 → 跳转 `## 微信小程序专属章节`

**生成顺序：** 多端时先 `_概览.md`，再各端独立文档。`end-specific.md` 在一次 Step 3 中只需加载一次，每生成一份文档后跳转到下一个端对应的 `##` 节。

生成后执行对应模板文件中的质量检查清单，不通过项立即修复再保存。

### Step 4：自动评审（跨会话独立上下文）

⚠️ **必须执行此步骤**，不要询问用户"是否继续"。文档生成后**立即**自动触发评审，阻断时**立即**自动修复。

**执行流程（上限 3 轮，每轮步骤相同）：**

#### 步骤 A：启动评审

1. 收集本次写入的文档路径列表，存入变量 DOC_PATHS
2. 调用 `task` 工具启动评审子代理：
   - description: `"评审: {文档名}"`
   - subagent_type: `"general"`
   - prompt: 填入以下内容（将占位符替换为实际值）：

     ```
     加载 review-expert skill（使用 skill 工具），以独立评审者身份执行：
     评审模式: 需求评审
     DOC_PATHS: {逗号分隔的文档路径}
     你是独立评审者，不知道文档是谁写的，请严格按 review-expert 的子代理入口流程执行。
     ```

#### 步骤 B：解析结论

从 `task` 返回消息中提取最后几行的标记：

- `REVIEW_CONCLUSION: ✅` 或 `⚠️` → 运行 `bash scripts/gate.sh pass prd`，整个 Step 4 完成
- `REVIEW_CONCLUSION: ❌` → **不要询问用户，立即进入步骤 C**

#### 步骤 C：自动修复（不要问用户，直接执行）

1. 读取所有 `P0_BLOCKING:` 行的内容，每条是一个待修复问题
2. 打开对应的 PRD 文档，逐条修复（每条 `P0_BLOCKING` 对应文档中一个具体缺陷）
3. 更新文档版本号（v1.x → v1.x+1）和变更记录
4. 修复完成后，回到**步骤 A**，用修复后的文档路径重新评审

#### 超限处理

连续 3 轮评审都有 ❌ → 停止循环，输出以下信息后等待人工介入：

```
⛔ 经 3 轮修复仍存在 P0 阻断项，需人工介入。
评审报告见: doc/review/xxx_需求评审报告.md
```

#### 步骤 D：轻量审计，查漏补缺

`gate.sh pass prd` 完成后，用轻量 `ls`/`cat` 审计各阶段状态。

**使用以下命令检查（不要加载其他 skill，不要扫描项目文件）：**

```bash
# 文档目录
ls doc/prd/*.md 2>/dev/null
ls doc/arch/*.md 2>/dev/null
ls doc/detailed/*.md 2>/dev/null
# 评审报告目录
ls doc/review/*需求评审报告*.md 2>/dev/null
ls doc/review/*架构评审报告*.md 2>/dev/null
ls doc/review/*详细设计评审报告*.md 2>/dev/null
# 门禁状态
cat doc/.gate/prd.pass 2>/dev/null || echo "prd 未通过"
cat doc/.gate/arch.pass 2>/dev/null || echo "arch 未通过"
cat doc/.gate/detailed.pass 2>/dev/null || echo "detailed 未通过"
```

**根据审计结果，逐阶段处理未完成的部分：**

| 阶段 | 有文档 | 有评审报告 | 门禁已通过 | 动作 |
|------|--------|-----------|-----------|------|
| 架构 | `ls doc/arch/*.md` | `ls doc/review/*架构评审报告*.md` | `doc/.gate/arch.pass` | 有缺则启动 task |
| 详细设计 | `ls doc/detailed/*.md` | `ls doc/review/*详细设计评审报告*.md` | `doc/.gate/detailed.pass` | 有缺则启动 task |

**启动 task 的规则（仅在实际有工作时才启动）：**

- 架构缺文档 → task → system-architect（生成 SAD + 评审 + pass）
- 架构有文档无评审 → task → review-expert（仅评审架构文档）
- 架构已通过 → 完全跳过，不启动任何 task
- 详细设计同理

**task prompt 模板（架构示例，详细设计同理替换）：**

```
description: "架构: {项目名}"
subagent_type: "general"
prompt: >
  加载 system-architect skill。
  doc/arch/ 缺 SAD 文档，请按工作流生成并写入，然后执行 Step 5 评审循环。
  完成后自动 gate.sh pass arch，然后执行 Step D 推进到详细设计。
```

或（仅缺评审）：

```
description: "评审架构: {项目名}"
subagent_type: "general"
prompt: >
  加载 review-expert skill。
  评审模式: 架构评审
  DOC_PATHS: doc/arch/ 下的 SAD 文档路径
```

**完成后输出总结：**

```
✅ 全链路审计完成
   PRD: ✅ 通过
   架构: ✅/⏳/❌ + 处理结果
   详细设计: ✅/⏳/❌ + 处理结果
```

## 核心原则

1. **业务语言优先** — 禁止技术术语，说"做什么/为什么"
2. **具体可衡量** — 避免"更好/更快"，M/S级功能有 Given/When/Then AC
3. **边界清晰** — 声明范围/范围外，记录假设和风险

## 全局熔断

1. 端类型未确认用户已要求生成→先确认清单
2. 范围清单未满足→返回澄清
3. 未解决的目标/功能冲突→暂缓相关章节
4. 质量检查发现技术性描述→原地修复

## 输出前门禁

- [ ] 端文档完整（锁定清单文件数=实际文件数）
- [ ] 无技术术语（R-001/R-002）
- [ ] AC无技术描述（R-003）
- [ ] 后端端无前端描述（R-004，仅后端时）
- [ ] Web前端只有业务交互行为（R-005，仅Web时）
- [ ] 小程序微信能力描述只有业务目的（R-006，仅小程序时）
- [ ] 元数据完整（编号/版本/状态/日期/作者）
- [ ] 多端时 `_概览.md` 已最先生成
