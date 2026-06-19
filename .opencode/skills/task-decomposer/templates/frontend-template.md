# 前端 / 小程序详细设计文档模板

> **内容**：Web 前端和微信小程序的详设文档模板，合并于同一文件。
> **加载时机**：Step 4 前加载，按端跳转对应 `##` 节。
> - Web 前端：跳转 `## Web 前端详细设计文档模板`（仅 LC-FE-001 ≠ 无时）
> - 微信小程序：跳转 `## 微信小程序详细设计文档模板`（仅 LC-MP-001 ≠ 无时）
> **框架分支说明**：第4/5/6节因 Vue3 与 React 实现模式不同，各有专属写法。根据 LC-FE-001 选择分支，不得混用。

---

## Web 前端详细设计文档模板

每个前端功能域对应一份详细设计文档，文件命名为 `前端_{页面域}.md`，保存到 `doc/detailed/` 目录。

---

## 模板正文（前端）

```markdown
# {项目名称} — 前端 {页面域} 详细设计文档

**文档编号**：FE-DES-YYYYMMDD-NNN
**版本**：v1.0.0
**状态**：🟡 草稿
**创建日期**：YYYY-MM-DD
**最后更新**：YYYY-MM-DD
**作者**：[姓名]
**前端框架**：{Vue3 | React}（来自 LC-FE-001）
**关联后端文档**：{对应后端详设文档路径}
**关联架构文档**：{架构设计文档路径}

---

## 1. 页面清单

| 页面名称 | 路由路径 | 权限要求 | 所属布局 | 说明 |
|---------|---------|---------|---------|------|
| {页面名} | {/path/to/page} | {PUBLIC \| ROLE_USER \| ROLE_ADMIN} | {DefaultLayout \| BlankLayout} | {简要说明} |

---

## 2. 页面交互规则

### 2.1 {页面名称}

**初始化行为**：
- 进入页面时执行：{如：调用 GET /api/xxx 加载列表数据，显示骨架屏}
- 权限不足时：{如：重定向到 /403 页面}

**用户操作 → 触发逻辑**：

| 操作 | 触发条件 | 执行逻辑 | 结果反馈 |
|-----|---------|---------|---------|
| 点击「提交」按钮 | 表单校验通过 | 调用 POST /api/xxx，按钮置为 loading | 成功：Toast 提示 + 跳转；失败：显示错误信息 |
| 点击「提交」按钮 | 表单校验失败 | 不发起请求 | 各字段显示校验错误提示 |

**表单校验规则**：

| 字段名 | 校验规则 | 错误提示文案 |
|-------|---------|------------|
| {字段} | {必填 \| 长度 \| 格式正则} | {提示文案} |

---

## 3. API 调用映射

> **契约来源**：所有 URL、HTTP 方法、请求/响应字段必须来自后端详设文档第3节 OpenAPI 定义，禁止自行发明。
>
> **⛔ 填写规则**：URL 从 `paths` 节点复制完整路径；参数从 `parameters[?in=='query'].name`（query）和 `requestBody.properties`（body）提取；响应字段从 `responses.200.properties` 提取。字段名大小写必须与 OpenAPI 完全一致。

| 页面/操作 | HTTP 方法 | URL | 请求参数/Body | 响应关键字段 | 调用时机 |
|---------|---------|-----|------------|-----------|---------|
| {页面名} 初始化 | GET | /api/{path} | {query: page, size} | {data.list, data.total} | onLoad |
| 提交表单 | POST | /api/{path} | {body: {field1, field2}} | {data.id} | 点击提交 |

---

## 4. 状态与存储

### 【Vue3 分支】（LC-FE-001 = Vue3）

**页面级组件状态**（组合式 API）：
```typescript
const loading = ref(false)
const list = ref<{类型}[]>([])
const total = ref(0)
const currentItem = ref<{类型} | null>(null)
const formData = reactive<{表单类型}>({ {field1}: '', {field2}: null })
```

**Pinia Store 全局状态** → `stores/{storeName}.ts`，用 `defineStore('{name}', () => { ref/computed/action })` 定义。

### 【React 分支】（LC-FE-001 = React）

同上，状态管理差异：`useState` 代替 `ref`/`reactive`，Zustand 代替 Pinia。
```typescript
const [loading, setLoading] = useState(false)
const [list, setList] = useState<{类型}[]>([])
const [formData, setFormData] = useState<{表单类型}>({ {field1}: '', {field2}: null })
```
Zustand Store → `stores/{storeName}.ts`，用 `create<{Name}State>((set, get) => ({...}))` 定义。

---

## 5. 组件拆分

### 【Vue3 分支】
| 组件名 | 文件路径 | 职责 | Props | Emits |
|-------|---------|-----|-------|-------|
| `{ComponentName}` | `components/{ComponentName}.vue` | {职责描述} | `{propName}: {类型}` | `{eventName}: ({参数类型}) => void` |

### 【React 分支】
| 组件名 | 文件路径 | 职责 | Props |
|-------|---------|-----|-------|
| `{ComponentName}` | `components/{ComponentName}.tsx` | {职责描述} | `{propName}: {类型}` |

---

## 6. 复用逻辑封装

### 【Vue3 分支】Composable（`composables/use{Name}.ts`）
```typescript
export function use{Name}({参数}: {类型}) {
  const loading = ref(false)
  const list = ref<{类型}[]>([])
  async function fetchList() { /* 调用 API，更新数据 */ }
  return { loading, list, fetchList }
}
```

### 【React 分支】Custom Hook（`hooks/use{Name}.ts`）
同上，用 `useState` + `useCallback` 替代 ref + function，其他逻辑相同。

---

## 7. 错误处理

| 错误场景 | 错误来源 | 处理方式 | 用户提示 |
|---------|---------|---------|---------|
| 未登录 / token 过期 | 接口返回 401 | 清除 token 和 userInfo，跳转登录页 | Toast: "登录已过期，请重新登录" |
| 无权限 | 接口返回 403 | 不跳转 | Toast: "暂无权限" |
| 网络超时 | axios timeout | 重试一次，仍失败则提示 | Toast: "网络连接超时，请重试" |
| 服务器错误 | 接口返回 500 | 不跳转 | Toast: "服务器繁忙，请稍后重试" |

---

## 变更记录

| 版本 | 日期 | 变更类型 | 变更内容摘要 | 变更人 |
|-----|------|---------|------------|--------|
| v1.0.0 | YYYY-MM-DD | 🆕 新建 | 初始版本 | [姓名] |
```

---

## 质量检查清单（前端）

- [ ] 第3节所有 API URL 和字段名来自后端详设第3节 OpenAPI 定义，无自行发明
- [ ] 第3节已纳入 `_PROGRESS.md` 中相关后端模块「补充接口（Step 2.5）」列表的所有接口
- [ ] 第2节每个页面的交互规则覆盖了正常流程、校验失败、加载态、空状态
- [ ] 第7节覆盖了 401/403/500/网络超时四类错误
- [ ] 文档中无 `{...}` 占位符残留
- [ ] 文件保存路径为 `doc/detailed/前端_{页面域}.md`

---

## 微信小程序详细设计文档模板

每个小程序功能域对应一份详细设计文档，文件命名为 `小程序_{页面域}.md`，保存到 `doc/detailed/` 目录。

---

## 模板正文（小程序）

```markdown
# {项目名称} — 小程序 {页面域} 详细设计文档

**文档编号**：MP-DES-YYYYMMDD-NNN
**版本**：v1.0.0
**状态**：🟡 草稿
**创建日期**：YYYY-MM-DD
**最后更新**：YYYY-MM-DD
**作者**：[姓名]
**小程序框架**：原生小程序 / Taro / uni-app（来自 LC-MP-001）
**关联后端文档**：{对应后端详设文档路径}
**关联架构文档**：{架构设计文档路径}

---

## 1. 页面清单

| 页面名称 | 页面路径 | 所属分包 | tabBar 归属 | 权限要求 | 说明 |
|---------|---------|---------|-----------|---------|------|
| {页面名} | pages/{domain}/{page}/{page} | {主包 \| 分包名} | {无 \| tabBar项名称} | {无需登录 \| 需要登录} | {简要说明} |

---

## 2. 页面交互规则

### 2.1 {页面名称}

**生命周期行为**：

| 生命周期 | 执行操作 | 说明 |
|---------|---------|------|
| onLoad(options) | {如：从 options 获取 id，调用接口加载详情} | {说明} |
| onShow | {如：从其他页面返回时刷新列表数据} | {说明} |
| onPullDownRefresh | {如：重置分页，重新加载列表} | 需在 .json 中开启 enablePullDownRefresh |
| onReachBottom | {如：加载下一页数据} | 需配置 onReachBottomDistance |

**用户操作 → 触发逻辑**：

| 操作 | 触发条件 | 执行逻辑 | 结果反馈 |
|-----|---------|---------|---------|
| 点击「提交」按钮 | 表单校验通过 | 调用 POST /api/xxx | 成功：wx.showToast + 跳转；失败：wx.showModal 显示错误 |
| 点击「提交」按钮 | 表单校验失败 | 不发起请求 | wx.showToast 提示具体错误 |

---

## 3. API 调用映射

> **契约来源**：所有 URL、方法、字段必须来自后端详设第3节 OpenAPI 定义，禁止自行发明。填写规则与 Web 前端相同。

| 页面/操作 | HTTP 方法 | URL | 请求参数/Body | 响应关键字段 | 调用时机 |
|---------|---------|-----|------------|-----------|---------|
| {页面名} 初始化 | GET | /api/{path} | {query: page, size} | {data.list, data.total} | onLoad |
| 提交表单 | POST | /api/{path} | {body: {field1, field2}} | {data.id} | 点击提交 |

**统一请求封装**：`utils/request.js`（封装 `wx.request`），请求头带 `Authorization: Bearer {token}`，401→跳转登录页，500→wx.showToast。

---

## 4. 状态与存储

**页面 data 字段定义**：
```javascript
Page({
  data: {
    loading: false, list: [], total: 0, page: 1, pageSize: 20,
    hasMore: true, currentItem: null,
    formData: { {field1}: '', {field2}: null },
  },
})
```

**globalData 全局状态**（`app.js`）：`userInfo`(Object, null)、`token`(String, '')，登录成功后设置。

**Storage 持久化**：

| Key | 类型 | 存储内容 | 写入时机 | 失效策略 |
|-----|------|---------|---------|---------|
| `token` | String | 登录 token | 登录成功 | 主动退出或 401 时清除 |

---

## 5. 微信能力使用

| 微信 API | 调用时机 | 权限要求 | 失败处理 |
|---------|---------|---------|---------|
| `wx.login` | App.onLaunch / 登录页 onLoad | 无需授权 | 重试3次，仍失败提示用户 |
| `wx.getUserProfile` | 用户点击「授权登录」 | 需用户主动触发 | 用户拒绝时提示功能受限 |
| `wx.requestPayment` | 用户点击「立即支付」 | 需商户配置 | 支付失败显示具体原因 |

---

## 6. 生命周期钩子

```javascript
Page({
  onLoad(options) { /* 获取参数，加载数据 */ },
  onShow() { /* 检查登录状态；从其他页面返回时刷新 */ },
  onPullDownRefresh() { /* 重置分页，重新加载，wx.stopPullDownRefresh() */ },
  onReachBottom() { /* 判断 hasMore，加载下一页 */ },
  onShareAppMessage() { return { title: '{分享标题}', path: '...', imageUrl: '...' } },
})
```

---

## 7. 错误处理

| 错误场景 | 错误来源 | 处理方式 | 用户提示 |
|---------|---------|---------|---------|
| 未登录 / token 过期 | 接口返回 401 | 清除 token，跳转登录页 | wx.showToast: "登录已过期，请重新登录" |
| 无权限 | 接口返回 403 | 不跳转 | wx.showToast: "暂无权限" |
| 网络超时 | wx.request timeout | 重试一次 | wx.showToast: "网络连接超时，请重试" |
| 服务器错误 | 接口返回 500 | 不跳转 | wx.showToast: "服务器繁忙，请稍后重试" |
| 支付失败 | wx.requestPayment fail | 显示失败原因 | wx.showModal 展示具体原因 + 重试按钮 |

---

## 8. 分包策略

| 页面 | 归属 | 理由 |
|-----|-----|------|
| {页面名} | {主包 \| 分包A} | {理由} |

**分包配置**（`app.json` subpackages 节）：
```json
{
  "subpackages": [{ "root": "packageA", "name": "{分包名称}", "pages": ["{domain}/{page}/{page}"] }],
  "preloadRule": { "{触发页面路径}": { "network": "all", "packages": ["{分包名称}"] } }
}
```

---

## 9. 缓存策略

| 缓存 Key | 缓存内容 | 缓存时长 | 写入时机 | 读取时机 | 失效/清除时机 |
|---------|---------|---------|---------|---------|------------|
| `cache_{domain}_list` | {列表数据} | {5分钟} | 接口返回成功后 | onLoad 时先读缓存 | 超时 \| 用户主动刷新 |

---

## 10. 测试要点

| 测试场景 | 前置条件 | 操作步骤 | 预期结果 | 测试工具 |
|---------|---------|---------|---------|---------|
| 下拉刷新 | 列表有数据 | 下拉页面触发刷新 | 数据重新加载，刷新动画消失 | 微信开发者工具 |
| 上拉加载更多 | 列表数据 > 1页 | 滚动到底部 | 加载下一页数据，追加到列表 | 微信开发者工具 |
| 未登录访问 | 未登录状态 | 直接进入需登录页面 | 跳转到登录页 | 微信开发者工具 |
| 网络断开 | 关闭网络 | 触发任意接口请求 | Toast 提示网络错误，不白屏 | 真机测试 |

---

## 变更记录

| 版本 | 日期 | 变更类型 | 变更内容摘要 | 变更人 |
|-----|------|---------|------------|--------|
| v1.0.0 | YYYY-MM-DD | 🆕 新建 | 初始版本 | [姓名] |
```

---

## 质量检查清单（小程序）

- [ ] 第3节所有 API URL 和字段名来自后端详设第3节 OpenAPI 定义，无自行发明
- [ ] 第3节已纳入 `_PROGRESS.md` 中相关后端模块「补充接口（Step 2.5）」列表的所有接口
- [ ] 第2节每个页面的交互规则覆盖了正常流程、校验失败、加载态、空状态
- [ ] 第5节列出了所有使用的微信 API 及其权限要求和失败处理
- [ ] 第6节每个页面的 onLoad/onShow/onPullDownRefresh/onReachBottom 均有明确操作描述
- [ ] 第8节明确了每个页面的分包归属
- [ ] 第7节覆盖了 401/403/500/网络超时/授权拒绝/支付失败六类错误（支付功能不涉及时可标注"不适用"）
- [ ] 文档中无 `{...}` 占位符残留
- [ ] 文件保存路径为 `doc/detailed/小程序_{页面域}.md`
