# AI 编码门禁套件

将编码门禁注入任何 opencode 项目的零成本方案。一套统一 CLI + 两层 Plugin 防御。

## 一句话用法

```bash
bash scripts/gate.sh check prd              # 检查能否开始写 PRD
bash scripts/gate.sh pass arch              # 架构评审通过
bash scripts/gate.sh unpass detailed "字段类型不一致"  # 详设评审未通过
bash scripts/gate.sh status                 # 一看全貌
bash scripts/gate.sh diagnose               # 诊断门禁状态
bash scripts/gate.sh pre user doc/detailed/user.md  # 编码前验证
bash scripts/gate.sh post user 'biz=ok...'         # 编码后验证
```

**一个命令 `gate.sh`，8 个动词。**

## 文件结构

```
├── setup.sh                        # 安装/更新脚本
├── AGENTS.md                       # 本仓库说明（AI 开发时读取）
├── opencode.json                   # 门禁配置
├── coding-rules.md                 # AI 编码铁律
├── scripts/
│   ├── gate.sh                     # 统一门禁 CLI（推荐入口）
│   ├── doc-gate.sh                 # 文档阶段门禁
│   └── verify-coding.sh            # 编码验证门禁
├── .opencode/
│   ├── agent/
│   │   └── coding-executor.md      # 编码执行 agent
│   ├── plugin/
│   │   ├── stage-gate.js           # 阶段门禁插件
│   │   └── verify-gate.js          # 编码验证插件
│   └── skills/                     # 开发流程技能
│       ├── prd-writer/             # 需求分析
│       ├── system-architect/       # 架构设计
│       ├── task-decomposer/        # 详细设计
│       ├── code-reviewer/          # 代码评审
│       └── review-expert/          # 全流程评审
├── doc/
│   └── .gate/                      # 阶段标记目录
└── .verify/                        # 编码验证记录
```

## 安装

```bash
bash setup.sh                      # 自愈/安装
bash setup.sh /path/to/target      # 安装到其他项目
```

## 五个阶段

| 阶段 | 流程 | 门禁命令 |
|------|------|----------|
| PRD | prd-writer 产出 `doc/prd/` | `scripts/gate.sh pass prd` |
| 架构 | system-architect 产出 `doc/arch/` | `scripts/gate.sh pass arch` |
| 详细设计 | task-decomposer 产出 `doc/detailed/` | `scripts/gate.sh pass detailed` |
| 编码 | coding-executor 三阶段流程 | `scripts/gate.sh post` 自动标记 |
| 代码评审 | code-reviewer 归零 | `scripts/gate.sh pass review` |

> review-expert 为可选 skill，用于人工拉通评审。`gate.sh unpass` 可随时手动阻断。

## 防御层次

| 层 | 机制 | 作用 |
|----|------|------|
| Agent 指令 | coding-executor.md + coding-rules.md | 三阶段流程 + 零号铁律 |
| 文档门禁 | `gate.sh check/pass/unpass` | 按阶段推进 + 人工阻断 |
| 阶段门禁 Plugin | `stage-gate.js` | 无 detailed.pass 阻断代码编辑 |
| 编码门禁 Plugin | `verify-gate.js` | 无 .verify 记录阻断编辑 |
