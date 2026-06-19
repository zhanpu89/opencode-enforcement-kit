# 前端 / 小程序设计指南

> Step 4 生成前端/小程序详设前加载。设计指南按端合并于同一文件，按 `##` 节跳转。

## Web 前端设计指南

### 框架选择依据
根据 `项目规则.md` 中的 `LC-FE-001` 值决定使用哪套模式：

| LC-FE-001 值 | 使用模式 |
|------------|---------|
| `Vue3` | Vue3 Composition API + Pinia |
| `React` | React Hooks + Zustand |

## 第一章：Vue3 设计模式

### 1.1 组件结构规范
```vue
<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useXxxStore } from '@/stores/xxx'
import { useXxx } from '@/composables/useXxx'

const xxxStore = useXxxStore()
const { loading, list, fetchList } = useXxx()
const visible = ref(false)
const formData = reactive<XxxType>({ ... })
const isValid = computed(() => ...)
async function handleSubmit() { ... }
onMounted(() => { fetchList() })
</script>
```
### 1.2 状态管理（Pinia）
- 每个业务域对应一个 Store（`stores/useXxxStore.ts`）
- 使用 Composition API 风格（`defineStore(id, setup函数)`），不用 Options 风格
- Store 的 Action 调用 API 并更新 State；跨组件共享放 Store，页面内部临时状态用 `ref/reactive`
### 1.3 Composable 设计规范
```typescript
export function useXxx(options?: XxxOptions) {
  const loading = ref(false)
  async function fetchData() { ... }
  onMounted(fetchData)
  return { loading, fetchData }
}
```
命名规范：`use` + 业务名（驼峰），如 `useUserList`、`useOrderForm`
### 1.4 路由（Vue Router 4）
懒加载：`component: () => import('@/views/xxx/XxxPage.vue')`；meta：`title`、`requiresAuth`、`roles`、`keepAlive`

## 第二章：React 设计模式

### 2.1 组件结构规范
同Vue3模式，React Hooks写法代替Composition API（`useState`/`useEffect`/`useMemo`/`useCallback` 替代 `ref`/`onMounted`/`computed`）。
### 2.2 状态管理（Zustand）
同Vue3 Pinia 模式，Zustand 替代 Pinia；区别：使用 `immer` 中间件处理嵌套对象更新；避免在 Store 中存储派生数据，用 `useMemo` 在组件中计算。
### 2.3 Custom Hook 设计规范
同Vue3 Composable 模式，`useState`/`useCallback` 替代 `ref`/`async function`，`useEffect` 替代 `onMounted`。
### 2.4 路由（React Router 6）
```tsx
const XxxPage = lazy(() => import('@/pages/xxx/XxxPage'))
<Suspense fallback={<PageSkeleton />}><XxxPage /></Suspense>
<ProtectedRoute roles={['ROLE_ADMIN']}><XxxPage /></ProtectedRoute>
```

## 第三章：共同规范（Vue3 和 React 均适用）

### API 层封装
所有 API 调用封装在独立 API 模块中，不在组件中直接写 `axios.get`：
```typescript
export const xxxApi = {
  getList: (params: XxxListParams) => request.get<XxxListResponse>('/api/xxx', { params }),
  create: (data: CreateXxxDto) => request.post<{ id: string }>('/api/xxx', data),
  update: (id: string, data: Partial<CreateXxxDto>) => request.put(`/api/xxx/${id}`, data),
  delete: (id: string) => request.delete(`/api/xxx/${id}`),
}
```
### TypeScript 类型规范
- 与后端 DTO 字段名保持一致（来自后端详设第3节 OpenAPI 定义）
- `XxxVO`（后端返回视图对象）、`CreateXxxDto`（创建请求体）、`PageResult<T>`（分页结果）
### 错误处理统一拦截
在 `utils/request.ts` 的响应拦截器中统一处理 401/403/500，组件层只处理**业务特定错误**。

---

## 微信小程序设计指南

### 框架选择说明
| LC-MP-001 值 | 框架 | 说明 |
|---|-----|-----|
| `MiniApp-Native` | 原生小程序 | WXML/WXSS/JS/JSON，性能最优 |
| `MiniApp-Taro` | Taro 3.x | React 语法，编译为小程序 |
| `MiniApp-UniApp` | uni-app | Vue 语法，编译为小程序 |

## 目录结构规范（原生小程序）
```
miniprogram/
├── app.js / app.json / app.wxss
├── pages/{domain}/{page}/        # 主包页面
├── package{A}/pages/             # 分包
├── components/                   # 公共组件
└── utils/
    ├── request.js                # 网络请求封装
    ├── auth.js                   # 登录/token 管理
    └── cache.js                  # 缓存工具（含过期机制）
```

## 登录流程规范
```
App.onLaunch：wx.getStorageSync('token')
    ├─ token 存在 → 调用后端 /api/auth/verify 验证 token 有效性
    │       ├─ 有效 → 正常进入
    │       └─ 无效（401）→ 清除 token，进入静默登录流程
    └─ token 不存在 → 进入静默登录流程

静默登录流程：
    wx.login() → 获取 code
    → 调用后端 POST /api/auth/miniapp/login（body: { code }）
    → 后端返回 token + userInfo
    → wx.setStorageSync('token', token) + wx.setStorageSync('userInfo', userInfo)
```

## 页面跳转规范
| 场景 | API | 说明 |
|-----|-----|-----|
| 普通页面跳转（可返回） | `wx.navigateTo` | 保留当前页面，最多10层 |
| 替换当前页面（不可返回） | `wx.redirectTo` | 关闭当前页面 |
| 跳转 tabBar 页面 | `wx.switchTab` | 关闭所有非 tabBar 页面 |
| 返回上一页 | `wx.navigateBack` | `delta` 参数控制返回层数 |
**跨页面传参**：简单参数用 URL 拼接；复杂对象用 `EventChannel`；返回时传值用 `EventChannel.emit`，不用 `globalData`。

## 性能优化规范
**setData 使用约束**：
- 合并为一次 `setData`，禁止在循环中频繁调用
- 单次 `setData` 数据量不超过 **1MB**
- 更新列表单条数据用路径语法：`this.setData({ 'list[0].status': newStatus })`
**长列表优化**：超过 **50条** 的列表使用虚拟列表；每页不超过 **20条**。

## 微信支付设计规范
```
用户点击「支付」
    ↓
前端调用后端 POST /api/order/prepay（body: { orderId }）
    ↓
后端调用微信统一下单 API，返回支付参数
    ↓
前端调用 wx.requestPayment(payParams)
    ├─ 成功 → 调用后端 GET /api/order/{id}/status 查询最终状态（不信任前端回调）
    └─ 失败
        ├─ fail cancel → 用户取消，Toast 提示，不报错
        └─ 其他失败 → wx.showModal 显示原因，提供重试按钮
```
支付安全：支付结果以后端查询为准；支付参数（sign）由后端生成；订单金额在后端校验。

## 分包设计决策树
```
该页面是否在 tabBar 中？
    ├─ 是 → 必须放主包
    └─ 否 → 是否在首屏加载路径上？
                ├─ 是 → 放主包
                └─ 否 → 是否被多个分包共同依赖？
                            ├─ 是 → 放主包
                            └─ 否 → 放对应功能域的分包
```
主包目标：**< 1MB**（为后续迭代留出空间）。

## 错误边界与降级设计
| 场景 | 降级方案 |
|-----|---------|
| 接口请求失败 | 显示空状态组件 + 重试按钮，不白屏 |
| 图片加载失败 | `binderror` 事件替换为默认占位图 |
| 微信 API 不支持（低版本） | `wx.canIUse` 检测，不支持时隐藏功能入口 |
| 分包加载失败 | 捕获 `wx.navigateTo` 的 fail 回调，提示用户重试 |

---
