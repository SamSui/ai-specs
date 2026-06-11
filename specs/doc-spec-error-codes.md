---
title: 错误码编写规范
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 每个错误码必须包含以下四个字段： public enum GlobalErrorCode implements ErrorCode {
---

# 错误码编写规范

> **版本**: v1.0  
> **创建日期**: 2026-04-29  
> **适用范围**: 所有前后端分离的软件工程项目

---

## 1. 错误码格式

每个错误码必须包含以下四个字段：

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `int code` | int | 数字错误码 | `1701` |
| `String errorCode` | String | 字符串错误码，`ERROR_{MODULE}_{NAME}` | `"ERROR_TASK_NOT_FOUND"` |
| `String message` | String | 人类可读消息，支持 `{0}` 占位符 | `"任务不存在: {0}"` |
| `HttpStatus status` | HttpStatus | HTTP 状态码 | `HttpStatus.NOT_FOUND` |

### 枚举定义模板

```java
public enum GlobalErrorCode implements ErrorCode {
    // ✅ 正确：四参数构造函数
    ERROR_TASK_NOT_FOUND(1701, "ERROR_TASK_NOT_FOUND", "任务不存在: {0}", HttpStatus.NOT_FOUND),

    // ❌ 错误：混用 HttpStatus.value() 作为 int code
    ERROR_COMMON_VALIDATION_ERROR("E4003", "校验失败: {0}", HttpStatus.BAD_REQUEST),
}
```

---

## 2. 号段分配

| 号段 | 用途 | 说明 |
|------|------|------|
| **0** | 成功 | 所有成功响应统一 code = 0 |
| **400-599** | HTTP 标准错误 | 与 HttpStatus 值完全对齐 |
| **1100-1199** | 数据接入/适配 | 文件/数据库/存储 |
| **1200-1299** | 数据标准化 | 格式转换/编码处理 |
| **1300-1399** | 异常检测 | 质量检测/异常识别 |
| **1400-1499** | 去重处理 | 重复检测/合并 |
| **1500-1599** | 数据对比 | 差异分析/报告 |
| **1600-1699** | 数据集管理 | CRUD/元数据 |
| **1700-1799** | 任务管理 | 调度/执行/状态 |
| **1800-1899** | 算法平台 | 注册/调用/版本 |
| **1900-1999** | 用户管理 | 认证/授权/会话 |
| **2000-2099** | 系统配置 | 参数/版本/维护 |
| **6500-6599** | 共享实体/数据访问 | Repository 层通用错误 |
| **9999** | 未知错误 | 全局兜底 |

> **注意**：以上号段为示例分配，实际项目按模块数量调整。新增模块使用连续号段。

---

## 3. 设计原则

### 3.1 命名规范

- 枚举常量：`ERROR_{MODULE}_{NAME}` 全大写下划线
- 禁止混用 `HttpStatus` 枚举直接作为 `int code`

### 3.2 唯一性约束

- `int code` 必须全局唯一
- `String errorCode` 必须全局唯一
- 新增错误码前必须检查号段表，避免冲突

### 3.3 HttpStatus 一致性

- `int code` 与 `HttpStatus.value()` 完全一致（400→400, 500→500）
- `SUCCESS(0)` 和 `ERROR_UNKNOWN(9999)` 为例外，无对应 HTTP 状态

### 3.4 消息模板

- 使用 `{0}`, `{1}` 占位符，通过 `MessageFormat.format()` 填充
- 消息语言与项目约定一致（如简体中文）
- 模板示例：`"任务不存在: {0}"` → `"任务不存在: task-123"`

---

## 4. API 响应格式

所有 API 统一包装：

```json
{
  "code": 1701,
  "error": "ERROR_TASK_NOT_FOUND",
  "message": "任务不存在: task-123",
  "data": null,
  "timestamp": 1744896000000
}
```

成功响应：

```json
{
  "code": 0,
  "error": "SUCCESS",
  "message": "成功",
  "data": {...},
  "timestamp": 1744896000000
}
```

**关键约束**：
- `ApiResponse.success()` 必须显式设置 `.code(0)`
- 前端统一用 `code === 0` 判断成功
- 禁止依赖 Builder 默认值

---

## 5. 跨语言错误码传递

```
前端 → Java API → 内部服务/Python
                ↑ 统一错误码在此处转换
```

- Python/算法服务不得直接对前端返回错误码
- 所有错误经 Java API 层统一包装为 `GlobalErrorCode`
- 通过 `GlobalExceptionHandler` 统一返回 `ApiResponse`

---

## 6. 禁止事项

- ❌ 禁止在业务代码中直接使用 `int` 硬编码错误码
- ❌ 禁止跨服务直接暴露内部错误详情
- ❌ 禁止复用已分配的 `int code`
- ❌ 禁止在 `GlobalErrorCode` 中混用 `HttpStatus` 作为 `int code`
- ❌ 禁止 `ApiResponse.success()` 依赖默认值不显式设 `code`

---

## 7. 检查清单

- [ ] 新增错误码已检查号段表，无冲突
- [ ] `int code` 全局唯一
- [ ] `String errorCode` 全局唯一
- [ ] HTTP 状态码与业务语义匹配（4xx 客户端错误 / 5xx 服务端错误）
- [ ] 消息模板含必要上下文，便于排查
- [ ] 已同步更新 API 文档

---

*版本: v1.0 | 最后更新: 2026-04-29*
