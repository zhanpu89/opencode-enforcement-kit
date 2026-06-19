# 端专属章节

> Web 前端（F1-F6）和微信小程序（M1-M6）专属章节。通用骨架来自 `templates/common.md`。
> 多端时必须生成 `_SAD_概览.md`（≤ 500 字，含端类型声明、技术栈决策摘要、各端文档路径、跨端集成点说明）。

## Web 前端专属章节（F1-F6）

> **粒度**：SAD 层描述宏观 UI 端架构决策——框架选型、路由/页面结构、状态模块划分、组件分层策略、前后端契约原则。不写具体 URL、字段名或组件内部逻辑。

### F1. 前端技术栈
- **框架**：Vue3 / React（参见 `resources/tech-selection.md`）
- **构建工具**：Vite / Webpack / Rspack
- **UI 组件库**：Element Plus / Ant Design Vue / Naive UI
- **状态管理**：Pinia / Redux / Zustand
- **HTTP 客户端**：Axios / Fetch，封装策略
- **CSS 方案**：Tailwind CSS / CSS Modules / UnoCSS

### F2. 页面路由设计
核心页面清单，含路由路径、功能说明、权限要求：
| 页面名称 | 路由路径 | 功能说明 | 权限要求 |
|---------|---------|---------|---------|
| 首页 | `/` | 系统首页 | 公开 |
| 详情页 | `/detail/:id` | 单条记录详情 | 已登录 |
- **路由守卫**：未登录跳转 `/login`，无权限跳转 403
- **路由懒加载**：非首屏页面使用动态 `import()`

### F3. 状态管理方案
- **全局状态划分**：用户信息（userStore）、业务数据、UI 状态（uiStore）
- **Store 模块划分**：各 Store 名称及职责
- **持久化策略**：哪些状态持久化（localStorage / sessionStorage）

### F4. 组件拆分策略
- **公共组件**：布局（Header/Sidebar/Footer）、表单、表格、弹窗
- **业务组件**：各业务模块专属组件
- **通信规范**：Props / Emit / Provide-Inject / Store 的使用边界

### F5. 前后端契约
- **唯一事实来源**：以后端 OpenAPI 为准，前端 API URL 严格对应
- **API 层封装**：请求拦截器（Token 注入）、响应拦截器（错误处理、Token 刷新）
- **类型定义**：从 OpenAPI 生成或手动维护 TypeScript 类型

### F6. 前端安全与性能
**安全：** Token 存储选型、路由守卫、敏感操作二次确认
**性能：** 路由懒加载、首屏优化（骨架屏、预加载）、静态资源 CDN

---

## 微信小程序专属章节（M1-M6）

> **粒度**：SAD 层描述宏观架构决策——框架选型、页面结构、分包策略、微信能力集成方式。不写具体 URL、字段名或页面内部逻辑。

### M1. 小程序技术栈
- **开发框架**：原生 / Taro / uni-app（参见 `resources/tech-selection.md`）
- **UI 组件库**：WeUI / Vant Weapp / TDesign Mobile
- **状态管理**：原生 globalData / Pinia（Taro）/ Vuex（uni-app）
- **网络请求**：wx.request 封装层

### M2. 页面与 tabBar 设计
**tabBar 页面：**
| 页面名称 | 页面路径 | 图标 | 权限 |
|---------|---------|------|------|
| 首页 | `pages/index/index` | home | 公开 |
| 我的 | `pages/mine/mine` | user | 已登录 |
**非 tabBar 页面：**
| 页面名称 | 页面路径 | 功能说明 | 权限 |
|---------|---------|---------|------|
| 详情页 | `pages/detail/detail` | 单条记录详情 | 已登录 |

### M3. 分包策略
- **主包**：tabBar 页面 + 登录页（< 2MB）
- **分包划分**：按业务模块划分，列出各分包名称和包含页面
- **大小预估**：各分包预估大小

### M4. 微信能力集成
- **登录**：wx.login → code2session 流程
- **支付**：统一下单 → JSAPI → 回调处理
- **云开发**（按需）：云函数/云数据库使用范围
- **其他能力**：地图、相机、蓝牙等

### M5. 状态管理
- **全局状态**：用户信息、Token、全局配置存储
- **页面间通信**：URL 参数 / EventChannel / 全局状态边界
- **本地存储**：wx.setStorageSync 使用规范

### M6. 小程序安全与前后端契约
**安全：** Token 存储与过期刷新、敏感接口鉴权、用户隐私合规
**前后端契约：** wx.request 封装层 + 统一错误处理，OpenAPI 为唯一事实来源
