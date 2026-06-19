# 语言工程规则

> Step 5 生成项目规则时加载。含4种语言禁止项/必须实现项 + 通用质量/安全/性能规则。按 LC-001 跳转对应语言节。

## 5.1 Java 工程规则

### ER-FORBIDDEN：禁止使用项

| 禁止项 | 替代方案 |
|--------|---------|
| `new Date()` / `SimpleDateFormat` | `LocalDateTime.now()` / `DateUtil` |
| `System.out.println()` | `log.info()` / `log.error()` |
| `e.printStackTrace()` | `log.error("描述", e)` |
| `double`/`float` 用于金额 | `BigDecimal` |
| `MD5`/`SHA1` 用于密码存储 | `BCryptPasswordEncoder` |
| MyBatis XML 中 `${}` 拼接用户输入 | `#{}` 参数绑定 |
| `SELECT *` | 明确列出所需字段 |
| 循环内调用 Mapper | 批量查询 + Map 映射 |
| `@Transactional` 内调用 HTTP 接口 | 事务外执行或消息队列解耦 |
| 硬编码 IP / URL / 密钥 | 配置文件 + 环境变量 |

**ER-REQUIRED**：Service→入参日志/异常日志+堆栈/业务规则校验/不允许空catch | 写操作→@Transactional/状态校验/返回值检查 | Controller→@Valid/BaseResponse/Swagger/无业务逻辑

## 5.2 Python 工程规则

### ER-FORBIDDEN：禁止使用项

| 禁止项 | 替代方案 |
|--------|---------|
| `print()` 在业务代码中 | `logger.info()` / `logger.error()` |
| `except: pass` | 明确捕获异常类型 + 处理/日志 |
| `datetime.now()` 不带时区 | `django.utils.timezone.now()` |
| `float` 用于金额 | `Decimal` |
| 字符串拼接 SQL | SQLAlchemy 参数化查询 / raw SQL 的 `:param` |
| `SELECT *` | 明确列出所需字段 |
| `*args`/`**kwargs` 透传 DB 查询 | 明确参数名 |
| 循环内 DB 查询 | 批量查询 + dict 映射 |
| 在 View 中写业务逻辑 | 业务逻辑下沉到 Service |
| 硬编码 IP / URL / 密钥 | Django Settings / 环境变量 |

**ER-REQUIRED**：Service→入参日志/异常日志+堆栈/业务规则校验/不允许空except | 写操作→@transaction.atomic/状态校验/返回值检查 | View→serializer.is_valid/Response/无业务逻辑 | Model→__tablename__/Column/created_at、updated_at

## 5.3 Go 工程规则

### ER-FORBIDDEN：禁止使用项

| 禁止项 | 替代方案 |
|--------|---------|
| `fmt.Println` 在业务代码中 | `log.Info()` / `log.Error()` |
| `_ = err` 忽略 error | `if err != nil { return err }` |
| `time.Now()` 不带时区 | `time.Now().In(loc)` |
| `float64` 用于金额 | `int64`（分为单位）|
| 字符串拼接 SQL | GORM 参数化查询 |
| `SELECT *` | 明确列出所需字段 |
| 循环内 DB 查询 | 批量查询 + map 映射 |
| 全局变量存储请求状态 | `context.Context` 传递 |
| goroutine 泄漏（无退出机制） | context 取消或 WaitGroup |
| 硬编码 IP / URL / 密钥 | `viper` + 环境变量 |

**ER-REQUIRED**：Service→入参日志/异常日志/业务规则校验/不允许忽略error | 写操作→db.Transaction/状态校验/RowsAffected检查 | Handler→ShouldBindJSON+validator/BaseResponse/无业务逻辑 | Model→gorm.Model嵌入/TableName/字段tag

## 5.4 Node.js 工程规则

### ER-FORBIDDEN：禁止使用项

| 禁止项 | 替代方案 |
|--------|---------|
| `console.log()` 在业务代码中 | `logger.info()` / `logger.error()` |
| 未处理的 Promise rejection | `.catch()` 或 `try/await/catch` |
| `new Date()` 不带时区处理 | `dayjs().utc()` |
| `Number` 用于金额 | `decimal.js` / 整数分为单位 |
| 字符串拼接 SQL | TypeORM/Prisma 参数化查询 |
| `SELECT *` | 明确列出所需字段 |
| `any` 类型（TypeScript） | 明确类型或 `unknown` |
| 循环内 DB 查询 | 批量查询 + Map 映射 |
| 在 Controller 中写业务逻辑 | 业务逻辑下沉到 Service |
| 硬编码 IP / URL / 密钥 | `@nestjs/config` + 环境变量 |

**ER-REQUIRED**：Service→入参日志/异常日志+stack/业务规则校验/不允许空catch | 写操作→DataSource.transaction/状态校验/affected检查 | Controller→DTO校验/BaseResponse/Swagger/无业务逻辑 | Entity→@Entity/@PrimaryGeneratedColumn/createdAt、updatedAt、deleted/comment

## 5.5 通用工程规则

### ER-QUALITY：代码质量门槛

| 指标 | Java | Python / Go / Node.js | 超出时的处理 |
|------|------|-----------------------|-------------|
| 单个方法/函数行数 | ≤ 80 行 | ≤ 60 行 | 提取私有方法 |
| 单个类/文件行数 | ≤ 500 行 | ≤ 400 行 | 拆分职责/模块 |
| 嵌套层级 | ≤ 4 层 | ≤ 4 层 | 提前 return 或提取方法 |
| 相同代码块重复次数 | ≤ 2 次 | ≤ 2 次 | 提取公共方法 |
| 方法圈复杂度 | ≤ 10 | ≤ 10 | 拆分条件逻辑 |

### ER-SECURITY：安全强制要求

| 编号 | 要求 |
|------|------|
| ER-S-001 | 禁止字符串拼接构造 SQL，必须使用参数化查询 |
| ER-S-002 | 所有涉及用户数据的查询必须验证数据归属 |
| ER-S-003 | 日志中禁止出现密码、Token、完整手机号、身份证号 |
| ER-S-004 | 响应 DTO 中禁止包含密码哈希、内部 Token 等敏感字段 |
| ER-S-005 | 所有对外接口必须通过认证中间件/Guard，公开接口需显式配置白名单 |

### ER-PERFORMANCE：性能强制要求

| 编号 | 要求 |
|------|------|
| ER-P-001 | 分页查询必须使用框架分页机制，禁止全量加载后切片 |
| ER-P-002 | 单次查询结果集不超过 `{N}` 条（超出时必须分页）|
| ER-P-003 | 高频查询接口（TPS > `{N}`）必须有 Redis 缓存 |
| ER-P-004 | 缓存 key 格式：`{项目}:{模块}:{业务}:{唯一标识}` |
| ER-P-005 | 所有缓存必须设置 TTL，禁止永不过期 |

---
