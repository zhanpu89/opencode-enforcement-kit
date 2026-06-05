# AI 编码门禁套件

将编码门禁注入任何 opencode 项目的零成本方案。一套统一 CLI + 两层 Plugin 防御。

## 一句话用法

```bash
bash gate.sh check prd              # 检查能否开始写 PRD
bash gate.sh pass arch              # 架构评审通过
bash gate.sh unpass detailed "字段类型不一致"  # 详设评审未通过
bash gate.sh status                 # 一看全貌
bash gate.sh pre user doc/detailed/user.md  # 编码前验证
bash gate.sh post user 'biz=ok...'         # 编码后验证
```

**一个命令 `gate.sh`，7 个动词。**

## 文件结构

```
├── setup.sh                        # 安装/更新脚本
├── opencode.json                   # 门禁配置
├── coding-rules.md                 # AI 编码铁律
├── scripts/
│   ├── gate.sh                     # 统一门禁 CLI（推荐入口）
│   ├── doc-gate.sh                 # 文档阶段门禁
│   └── verify-coding.sh            # 编码验证门禁
├── .opencode/
│   ├── agent/
│   │   └── coding-executor.md      # 编码执行 agent
│   └── plugin/
│       ├── stage-gate.js           # 阶段门禁插件
│       └── verify-gate.js          # 编码验证插件
└── doc/
    └── .gate/                      # 阶段标记目录
```

## 安装

```bash
bash setup.sh                      # 自愈/安装
bash setup.sh /path/to/target      # 安装到其他项目
```

## 六个阶段

| 阶段 | 流程 | 门禁命令 |
|------|------|----------|
| PRD | prd-writer → review-expert → 通过则 pass，否则 unpass 回退 | `gate.sh pass/unpass prd` |
| 架构 | system-architect → review-expert → 同上 | `gate.sh pass/unpass arch` |
| 详细设计 | task-decomposer → review-expert → 同上 | `gate.sh pass/unpass detailed` |
| 编码 | coding-executor 三阶段流程 | `gate.sh post` 自动标记 |
| 测试 | tester → review-expert → 同上 | `gate.sh pass/unpass test` |
| 代码评审 | code-reviewer → coding-executor 修复 → 归零 | `gate.sh pass review` |

## 防御层次

| 层 | 机制 | 作用 |
|----|------|------|
| Agent 指令 | coding-executor.md + coding-rules.md | 三阶段流程 + 零号铁律 |
| 文档门禁 | `gate.sh check/pass/unpass` | 按阶段顺序推进 |
| 阶段门禁 Plugin | `stage-gate.js` | 无 detailed.pass 阻断代码编辑 |
| 编码门禁 Plugin | `verify-gate.js` | 无 .verify 记录阻断编辑 |
