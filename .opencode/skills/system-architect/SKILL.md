---
name: system-architect
description: |
  系统架构设计。将 PRD 转化为架构建档（SAD）和技术栈清单。
  适用场景：
  - 从 PRD 新建 SAD
  - 定向升级特定章节（安全/数据库/API）
  - 合并多份架构文档
  - 补充前端/小程序端架构
  不适用场景（勿触发）：
  - 纯技术问答
  - 直接写代码（coding-executor）
  - 已有 SAD，需任务分解（task-decomposer）
---

## 记忆集成（跨会话上下文）

本 skill 利用 `ai_memory` MCP 工具实现跨会话上下文持久化。

### 加载上下文（每次启动时首先执行）

在 Step 1 之前执行：

```
memory_init_session(project_name="当前项目")
memory_search_summaries(module="当前模块", tags="arch", limit=5)
memory_search_summaries(module="当前模块", tags="prd", limit=3)
memory_related_decisions(project_name="当前项目", query="架构|技术选型", limit=10)
```

### 保存关键决策

在 Step 3（PRD 分析 + NFR 量化）结束后，调用：
```
memory_add_decision(
  session_id=session-{YYYYMMDD}-arch-{module},
  decision_type=技术方案,
  description="NFR 量化值/技术选型结果/关键架构决策",
  reasoning="基于PRD约束/团队经验/行业最佳实践"
)
```

在 Step 4（架构设计）技术选型完成后，调用：
```
memory_add_decision(
  session_id=session-{YYYYMMDD}-arch-{module},
  decision_type=架构选型,
  description="技术栈选型与组件选择决策",
  reasoning="6维度论证结果"
)
```

### 保存任务摘要

在 Step 4 全部生成完成后，调用：
```
memory_save_summary(
  session_id=session-{YYYYMMDD}-arch-{module},
  task_title="架构: {模块/项目名}",
  summary_content=架构设计摘要（包含技术栈/模块划分/NFR指标）、
  file_paths=doc/arch/下生成的SAD文件路径（逗号分隔）、
  project_name=当前项目名、
  tags=arch,架构,{模块名}、
  module={模块名}、
  status=completed、
  next_steps="进入详细设计阶段，使用 task-decomposer"
)
```

# 系统架构师

将 PRD 转化为生产级架构文档。输入：`doc/prd/`；输出：`doc/arch/`。

## 懒加载原则（Lazy Loading）

1. **必须按需加载**：未到使用阶段的文件不得提前加载
2. **用完即释放**：某文件不再需要后，不再作为后续上下文保留
3. **阶段文件**：reference 按阶段拆分，各在对应阶段加载
4. **端专属模板**：`end-specific.md` 按需跳转对应 `##` 节

## 合并原则（Merge, don't split）

1. **端模板合并为一个文件**：前端/小程序专属章节合并为 `end-specific.md`，禁止拆分为独立文件
2. **按 `##` 节跳转**：合并文件内用 `##` 节区分不同端，加载后跳转到对应节即可

## 参考文件（按需加载）

| 文件 | 加载时机 | 释放时机 | 行数 |
|------|---------|---------|------|
| `templates/common.md` | Step 4 前——SAD 通用骨架 | *全部分段生成结束后* | 295 |
| `templates/end-specific.md` | Step 4 前——端专属章节（按端跳转对应 `##` 节） | *全部分段生成结束后* | 159 |
| `templates/tech-stack.md` | Step 4 生成 tech-stack.json 前 | *生成完成后* | 147 |
| `resources/tech-selection.md` | Step 4 前——技术选型 + SAD 边界 | *技术栈章节完成后* | 123 |
| `resources/nfr-quantify.md` | Step 3 前——NFR 量化指标 | *Step 4 架构设计前* | 22 |
| `resources/db-security-integration.md` | Step 4 前——数据库/安全/特殊集成（按需跳转 `##` 节） | *对应章节完成后* | 134 |
| `resources/overlays.md` | Step 2 探测到语言后——跳转对应 `##` 语言节 | *安全设计章节完成后* | 471 |
| `resources/glossary.md` | 首次触发——术语/架构模式 | *全部分段生成结束后* | 111 |

## 工作流

### Step 1：模式识别

| 模式 | 触发条件 | 跳转 |
|------|---------|------|
| 新建设计 | 有PRD无SAD | → Step 2 |
| 定向升级 | 改进特定章节 | → Step 4 |
| 文档合并 | 多份SAD整合 | → Step 4(合并) |
| 补充端文档 | 已有后端SAD需补前端/小程序 | → Step 2(仅探端) |

### Step 2：双探测（新建设计必执行）

**A. 端类型（决定拆分）：** 纯后端→单文件；含Web→后端+前端；含小程序→后端+小程序；多端→后端+各端+概览。
**B. 目标语言（决定 Overlay）：** 优先用户指定→PRD约束→特征文件(`pom.xml`/`go.mod`/`package.json`)→询问。未回复则等待。

加载 `resources/overlays.md` 对应语言章节。

### Step 3：PRD 分析

加载 `resources/nfr-quantify.md`。识别业务功能/数据实体、NFR 指标量化、安全合规、特殊集成、技术约束。仅对 PRD 确实缺失的信息提问。

> 释放提示：Step 3 结束时 `nfr-quantify.md` 不再需要，可释放。

### Step 4：架构设计与文档生成

释放 `nfr-quantify.md`（如仍占用）。加载 `templates/common.md` + `templates/end-specific.md` + `templates/tech-stack.md` + `resources/tech-selection.md` + `resources/db-security-integration.md`。
- **技术选型：** 使用 `tech-selection.md` 技术选型节，6个维度论证
- **安全：** `db-security-integration.md` 安全节 + `overlays.md` 对应语言安全节。安全章节完成后可释放 `overlays.md`
- **数据库：** `db-security-integration.md` 数据库节 + `overlays.md` 对应语言数据库节
- **特殊集成：** 涉及区块链/支付/文件存储时加载 `db-security-integration.md` 特殊集成节
- **SAD 边界：** 使用 `tech-selection.md` SAD 边界节控制粒度
- **分批写入：** 每生成一份立即写入
- **文档合并：** 逐节对比增量修改，禁止整文件重写

`end-specific.md` 在一次 Step 4 中只需加载一次，多端时写完后跳转到下一个端对应的 `##` 节。

### Step 5：自动评审（跨会话独立上下文）

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
     评审模式: 架构评审
     DOC_PATHS: {逗号分隔的文档路径}
     你是独立评审者，不知道文档是谁写的，请严格按 review-expert 的子代理入口流程执行。
     ```

#### 步骤 B：解析结论

从 `task` 返回消息中提取最后几行的标记：

- `REVIEW_CONCLUSION: ✅` 或 `⚠️` → 运行 `bash scripts/gate.sh pass arch`，整个 Step 5 完成
- `REVIEW_CONCLUSION: ❌` → **不要询问用户，立即进入步骤 C**

#### 步骤 C：自动修复（不要问用户，直接执行）

1. 读取所有 `P0_BLOCKING:` 行的内容，每条是一个待修复问题
2. 打开对应的 SAD 文档，逐条修复（每条 `P0_BLOCKING` 对应文档中一个具体缺陷）
3. 更新文档版本号（v1.x → v1.x+1）和变更记录
4. 修复完成后，回到**步骤 A**，用修复后的文档路径重新评审

#### 超限处理

连续 3 轮评审都有 ❌ → 停止循环，输出以下信息后等待人工介入：

```
⛔ 经 3 轮修复仍存在 P0 阻断项，需人工介入。
评审报告见: doc/review/xxx_架构评审报告.md
```

## 核心原则

1. NFR 必须量化，不得用"高性能/高可用"模糊描述
2. SAD 层粒度：核心表+关键字段（不写 DDL），端点列表（不写 OpenAPI Schema）
3. 每组件记录：是什么/为什么选/不选其他/权衡
4. `tech-stack.json` 必须生成，不得遗漏

## 全局熔断

1. 语言未确认已要求生成 SAD→先明确
2. PRD 缺失核心 NFR→返回澄清
3. 文档写入失败→停止全部
4. 任务结束前 tech-stack.json 未生成→补充再结束

## 输出前检查

- [ ] 锁定端均已生成对应文档
- [ ] `tech-stack.json` 已生成，`primaryLanguage` 和 `totalComponents` 完整
- [ ] 头部元数据（编号/版本/状态/日期/作者/关联PRD）完整
- [ ] 版本与变更记录末行一致
- [ ] 变更记录存在含 `v1.0.0`
- [ ] NFR 已量化（并发/响应/可用性）
- [ ] 第6节每组件含选型论证
- [ ] 安全覆盖 `db-security-integration.md` 全部检查项
- [ ] 多端：概览已最先生成
- [ ] 数据库无完整DDL，API无完整OpenAPI Schema
