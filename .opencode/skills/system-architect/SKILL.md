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

## 上下文记忆
init_session + search_summaries(tags="arch", limit=3) + related_decisions(query="架构|技术选型")
完成时 add_decision(reasoning="含被否方案和约束条件") + save_summary(next_steps="进入详细设计阶段")

# 系统架构师

将 PRD 转化为生产级架构文档。输入：`doc/prd/`；输出：`doc/arch/`。

## 参考文件（按需加载）

| 文件 | 加载时机 | 释放时机 |
|------|---------|---------|
| `templates/common.md` | Step 4 前——SAD 通用骨架 | *全部分段生成结束后* |
| `templates/end-specific.md` | Step 4 前——端专属章节（按端跳转对应 `##` 节） | *全部分段生成结束后* |
| `templates/tech-stack.md` | Step 4 生成 tech-stack.json 前 | *生成完成后* |
| `resources/tech-selection.md` | Step 4 前——技术选型 + SAD 边界 | *技术栈章节完成后* |
| `resources/nfr-quantify.md` | Step 3 前——NFR 量化指标 | *Step 4 架构设计前* |
| `resources/db-security-integration.md` | Step 4 前——数据库/安全/特殊集成（按需跳转 `##` 节） | *对应章节完成后* |
| `resources/overlays.md` | Step 2 探测到语言后——跳转对应 `##` 语言节 | *安全设计章节完成后* |
| `resources/glossary.md` | 首次触发——术语/架构模式 | *全部分段生成结束后* |

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

按参考文件表加载。

### Step 3：PRD 分析

按参考文件表加载。识别业务功能/数据实体、NFR 指标量化、安全合规、特殊集成、技术约束。仅对 PRD 确实缺失的信息提问。


### Step 4：架构设计与文档生成

按参考文件表加载。
- **技术选型：** 使用 `tech-selection.md` 技术选型节，6个维度论证
- **安全：** `db-security-integration.md` 安全节 + `overlays.md` 对应语言安全节。
- **数据库：** `db-security-integration.md` 数据库节 + `overlays.md` 对应语言数据库节
- **特殊集成：** 涉及区块链/支付/文件存储时加载特殊集成节
- **SAD 边界：** 使用 `tech-selection.md` SAD 边界节控制粒度
- **分批写入：** 每生成一份立即写入
- **文档合并：** 逐节对比增量修改，禁止整文件重写

端专属模板在一次 Step 4 中只需加载一次，多端时写完后跳转到下一个端对应的 `##` 节。

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
