# 语言技术栈特化规则（Overlays）

> 本文件合并了 Java、Python、Go、Node.js 四种语言的技术栈特化规则。
>
> **加载时机**：Step 2 探测到目标语言后加载本文件，后续安全/数据库/技术栈内容均使用对应语言章节。
> - 目标语言为 Java → 使用「Part 1：Java Overlay」
> - 目标语言为 Python → 使用「Part 2：Python Overlay」
> - 目标语言为 Go → 使用「Part 3：Go Overlay」
> - 目标语言为 Node.js/TypeScript → 使用「Part 4：Node.js Overlay」

---

# Part 1：Java 技术栈特化规则

## 安全设计

### 安全要点

| 检查项 | Java 实现方式 |
|--------|-------------|
| Token 机制 | `io.jsonwebtoken:jjwt` 或 `com.auth0:java-jwt`；双 Token 方案：Access Token（15min）+ Refresh Token（7d） |
| 密码哈希 | `BCryptPasswordEncoder`（cost = 12），Spring Security 内置 |
| PII 字段加密 | `AES-256-GCM`，使用 `javax.crypto.Cipher`；推荐封装为 `AesEncryptUtil` |

## 数据库设计

### ORM 框架选型

| 场景 | 推荐方案 |
|------|---------|
| 标准 CRUD + 复杂查询 | **MyBatis + MyBatis-Plus**（推荐，灵活可控） |
| 高性能 + 精细控制 | **MyBatis** 原生 XML + 手写 SQL |
| 代码生成 | MyBatis-Plus `AutoGenerator` |

### MyBatis-Plus 实体规范

```java
@Data
@TableName("t_{entity}")
public class {Entity}DO {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String {entity}Id;          // UUID 业务主键
    // ... 业务字段 ...
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private String createdBy;
    private String updatedBy;
    @TableLogic
    private Integer deleted;            // 0=正常, 1=已删除
}
```

### 命名规范

| 规范项 | 规则 |
|--------|------|
| 表前缀 | `t_`（如 `t_user`、`t_order`） |
| 主键 | 自增 `id BIGINT` + UUID `{entity}_id VARCHAR(36)` 并存 |
| 软删除 | `deleted TINYINT NOT NULL DEFAULT 0`，加 `@TableLogic` |
| 时间戳 | `created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`，`updated_at ON UPDATE CURRENT_TIMESTAMP` |
| 状态字段 | `TINYINT`，COMMENT 中列出所有枚举值 |
| Java 字段 | `camelCase`，MyBatis-Plus 自动映射 `snake_case` |

## 技术栈推荐

| 组件 | 推荐选型 |
|------|---------|
| Web 框架 | Spring Boot |
| 数据访问 | MyBatis-Plus |
| 安全框架 | Spring Security |
| 缓存 | Spring Data Redis + Lettuce |
| 消息队列 | Spring AMQP（RabbitMQ）/ Spring Kafka |
| 工具库 | Hutool |
| 参数校验 | jakarta.validation（Spring Boot 内置） |
| 分页 | PageHelper |
| API 文档 | SpringDoc OpenAPI |
| 对象映射 | MapStruct |

### 分层模型

```
Controller（接口层）→ DTO（Request/Response）
Service（业务逻辑层）→ DO（数据对象）
Mapper（数据访问层）→ MyBatis XML
Database（MySQL / PostgreSQL）
```

### 项目结构

```
backend/
└── src/main/java/{base-package}/
    ├── controller/          # REST 控制器
    ├── service/impl/        # 业务逻辑实现
    ├── mapper/              # MyBatis Mapper 接口
    ├── entity/              # 数据库实体（DO）
    ├── dto/request/         # 请求 DTO
    ├── dto/response/        # 响应 DTO
    ├── config/              # 配置类
    ├── exception/           # 自定义异常
    ├── enums/               # 枚举类
    └── util/                # 工具类
```

## 编码规范要点

- 禁止 `System.out.println()`，使用 `@Slf4j` + `log.info/warn/error`
- 禁止 MyBatis XML 中 `${}` 拼接用户输入，使用 `#{}`
- 写操作必须加 `@Transactional(rollbackFor = Exception.class)`

---

# Part 2：Python 技术栈特化规则

## 安全设计

### 安全要点

| 检查项 | Python 实现方式 |
|--------|---------------|
| Token 机制 | `python-jose` 或 `PyJWT`；双 Token 方案：Access Token（15min）+ Refresh Token（7d） |
| 密码哈希 | `passlib[bcrypt]`（`bcrypt` rounds = 12）或 `argon2-cffi` |
| PII 字段加密 | `cryptography` 库，`AES-256-GCM`；封装为 `AesEncryptUtil` |

## 数据库设计

### ORM 框架选型

| 场景 | 推荐方案 |
|------|---------|
| FastAPI + 异步 | **SQLAlchemy（async）+ asyncpg/aiomysql** |
| Django 项目 | Django ORM（内置） |
| 轻量脚本 | `peewee` 或原生 `psycopg2/pymysql` |

### 命名规范

同Java数据库命名规范, Python 字段使用 `snake_case`

### 实体规范 / 分层模型 / 项目结构

同Java模式, 语法差异见对应框架文档

## 技术栈推荐

| 组件 | 推荐选型 |
|------|---------|
| Web 框架 | FastAPI / Django |
| 数据访问 | SQLAlchemy |
| 数据校验 | Pydantic |
| 缓存 | `redis-py`（async：`redis.asyncio`） |
| 消息队列 | `celery` + Redis/RabbitMQ |
| 日志 | `loguru` |
| 分页 | `fastapi-pagination` |

## 编码规范要点

- 禁止裸 `except:`，使用具体异常类型
- 异步函数必须使用 `async def`
- 禁止密码使用 `hashlib.md5/sha1`，使用 `passlib.bcrypt`

---

# Part 3：Go 技术栈特化规则

## 安全设计

### 安全要点

| 检查项 | Go 实现方式 |
|--------|-----------|
| Token 机制 | `github.com/golang-jwt/jwt/v5`；双 Token 方案：Access Token（15min）+ Refresh Token（7d） |
| 密码哈希 | `golang.org/x/crypto/bcrypt`（cost = 12） |
| PII 字段加密 | `crypto/aes` + `crypto/cipher`（GCM 模式）；封装为 `pkg/crypto/aes.go` |

## 数据库设计

### ORM 框架选型

| 场景 | 推荐方案 |
|------|---------|
| 标准 CRUD + 复杂查询 | **GORM**（推荐，功能完整） |
| 高性能 + 精细控制 | `sqlx` + 原生 SQL |
| 代码生成 | `sqlc`（从 SQL 生成类型安全的 Go 代码） |

### 实体规范 / 分层模型 / 项目结构

同Java模式, 语法差异见对应框架文档

## 技术栈推荐

| 组件 | 推荐选型 |
|------|---------|
| Web 框架 | Gin / Echo |
| 数据访问 | GORM |
| 缓存 | `go-redis/redis` |
| 配置管理 | `spf13/viper` |
| 日志 | `uber-go/zap` |
| 参数校验 | `go-playground/validator` |
| API 文档 | `swaggo/swag` |

## 编码规范要点

- 禁止忽略 `error` 返回值，必须处理或显式忽略并注释原因
- 禁止密码使用 `crypto/md5`，使用 `golang.org/x/crypto/bcrypt`
- 禁止金额使用 `float64`，使用 `shopspring/decimal`

---

# Part 4：Node.js 技术栈特化规则

## 安全设计

### 安全要点

| 检查项 | Node.js 实现方式 |
|--------|----------------|
| Token 机制 | `jsonwebtoken`；双 Token 方案：Access Token（15min）+ Refresh Token（7d） |
| 密码哈希 | `bcrypt`（rounds = 12）或 `argon2` |
| PII 字段加密 | Node.js 内置 `crypto` 模块，`AES-256-GCM`；封装为 `src/utils/crypto.ts` |

## 数据库设计

### ORM 框架选型

| 场景 | 推荐方案 |
|------|---------|
| NestJS + TypeScript | **TypeORM**（推荐）或 **Prisma** |
| Express + 灵活查询 | **Prisma**（类型安全，推荐）或 `knex.js` |
| 轻量项目 | `sequelize` |

### 实体规范 / 分层模型 / 项目结构

同Java模式, 语法差异见对应框架文档

## 技术栈推荐

| 组件 | 推荐选型 |
|------|---------|
| Web 框架 | NestJS / Express |
| 数据访问 | TypeORM / Prisma |
| 缓存 | `ioredis` |
| 消息队列 | `@nestjs/bull`（Bull + Redis）/ `amqplib`（RabbitMQ） |
| 日志 | `winston` |
| 参数校验 | `class-validator` + `class-transformer` |
| API 文档 | `@nestjs/swagger`（基于 OpenAPI 3.0） |

## 编码规范要点

- 禁止 `any` 类型（TypeScript），使用具体类型或 `unknown`
- 配置通过 `@nestjs/config` 从环境变量读取，禁止硬编码
- 禁止密码使用 `crypto.createHash('md5')`，使用 `bcrypt`
