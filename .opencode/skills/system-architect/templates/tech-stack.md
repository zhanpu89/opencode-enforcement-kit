# 技术栈 JSON Schema

每份架构文档必须同步生成 `tech-stack.json`（与架构 Markdown 同目录）。

## JSON Schema

```json
{
  "project": "项目名称",
  "version": "1.0",
  "generatedAt": "YYYY-MM-DD",
  "techStack": {
    "backend": [
      {
        "name": "技术名称",
        "version": "版本号（未知时用最新稳定版）",
        "category": "分类：framework/orm/security/messaging",
        "purpose": "该技术在本项目中的用途",
        "rationale": "选择原因（对照 tech-selection.md 六大维度）",
        "officialUrl": "官方文档或仓库 URL"
      }
    ],
    "frontend": [{ "name": "", "version": "", "category": "framework/ui-library/build-tool/state-management", "purpose": "", "rationale": "", "officialUrl": "" }],
    "miniapp": [{ "name": "", "version": "", "category": "framework/ui-library/state-management", "purpose": "", "rationale": "", "officialUrl": "" }],
    "database": [{ "name": "", "version": "", "category": "relational/cache/search/queue", "purpose": "", "rationale": "", "officialUrl": "" }],
    "infrastructure": [{ "name": "", "version": "", "category": "container/proxy/monitoring/ci-cd", "purpose": "", "rationale": "", "officialUrl": "" }],
    "blockchain": [{ "name": "", "version": "", "category": "platform/sdk/smart-contract/consensus", "purpose": "", "rationale": "", "officialUrl": "" }],
    "devops": [{ "name": "", "version": "", "category": "ci-cd/containerization/deployment/testing", "purpose": "", "rationale": "", "officialUrl": "" }]
  },
  "summary": {
    "totalComponents": 0, "openSourceCount": 0, "commercialCount": 0,
    "primaryLanguage": "主要编程语言", "deploymentTarget": "Docker/K8s/Cloud/On-Premise"
  }
}
```

## 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `project` | string | 项目名称 |
| `version` | string | 文档版本，默认 `"1.0"` |
| `generatedAt` | string | 生成日期 `YYYY-MM-DD` |
| `techStack.*` | array | 各分组的技术列表 |
| `name` / `version`（条目） | string | 技术名称 / 版本号 |
| `category` | string | 分组内子分类 |
| `purpose` / `rationale` | string | 作用 / 选择原因 |
| `officialUrl` | string | 官方文档或仓库 URL |
| `summary.totalComponents` | number | 所有分组条目总数 |
| `summary.openSourceCount` / `commercialCount` | number | 开源 / 商业技术数量 |
| `summary.primaryLanguage` / `deploymentTarget` | string | 主要语言 / 部署目标 |

## 分组规则

| 分组 | 包含条件 |
|------|---------|
| `backend` / `frontend` / `miniapp` | 有服务端 / Web UI / 小程序端 |
| `database` / `infrastructure` | 有数据存储 / 容器/代理/消息队列/监控 |
| `blockchain` / `devops` | 涉及区块链 / 有 CI/CD 或容器化 |

不相关的分组直接省略，不要包含空数组。

## 注意事项

- **标识性字段**（`name`、`version`、`category`、`officialUrl`、`primaryLanguage`、`deploymentTarget`）用**英文**填写。
- **描述性字段**（`purpose`、`rationale`）可用中文。
- `totalComponents` = 所有分组条目总和；`openSourceCount` + `commercialCount` = `totalComponents`。
- `blockchain` 为可选项，仅在涉及区块链时出现。
