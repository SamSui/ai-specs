---
title: FastAPI Python 服务开发规范
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: 关联规范: [Docker 容器化规范](tech-spec-docker.md) {algorithm_service}/
---

# FastAPI Python 服务开发规范

> **版本**: v1.0  
> **创建日期**: 2026-04-29  
> **适用范围**: 使用 FastAPI 构建独立 Python 服务的项目  
> **关联规范**: [Docker 容器化规范](tech-spec-docker.md)

---

## 1. 项目结构

### 1.1 六层目录结构

```
{algorithm_service}/
├── pyproject.toml / requirements.txt   # 依赖管理
├── Dockerfile                          # 多阶段构建
├── README.md
│
├── api/                                # 【对外暴露层】
│   ├── __init__.py                     # __all__ 显式导出
│   ├── schemas.py                      # Pydantic 模型（DTO）
│   └── router.py                       # FastAPI 路由定义
│
├── internal/                           # 【私有实现层】
│   ├── __init__.py                     # __all__ = []（禁止对外暴露）
│   ├── service.py                      # 业务逻辑
│   ├── repository.py                   # 数据访问
│   └── tasks/                          # 异步任务
│       └── heartbeat_task.py
│
├── model/                              # 【数据模型层】
│   ├── __init__.py
│   └── entity.py                       # 领域实体（dataclass）
│
├── infrastructure/                     # 【基础设施层】
│   ├── protocol/
│   │   ├── http_server.py              # FastAPI 应用工厂
│   │   └── proto/                      # .proto 定义（如使用 gRPC）
│   └── registry/                       # 服务注册客户端
│
├── config/                             # 【配置层】
│   └── base.yml                        # 基础配置
│
└── tests/                              # 【测试层】
    ├── __init__.py
    └── test_internal/                  # 与 internal/ 镜像结构
```

### 1.2 层级职责

| 层级 | 职责 | 可见性 |
|------|------|--------|
| `api/` | 定义抽象接口、Pydantic DTO | 对外公开 |
| `internal/` | 实现业务逻辑 | 仅本模块内可见 |
| `model/` | 数据实体、值对象 | 纯数据定义，不依赖其他层 |
| `infrastructure/` | 框架启动、注册心跳、协议实现 | 禁止放业务逻辑 |
| `config/` | YAML 配置文件 | 按环境/算法分离 |
| `tests/` | 单元测试 | 与 `internal/` 镜像结构 |

---

## 2. 显式导出规范

所有 `__init__.py` 必须声明 `__all__`：

```python
# api/__init__.py
__all__ = ["TextPurifyService", "TextPurifyRequest", "TextPurifyResponse"]
from .service import TextPurifyService
from .dto import TextPurifyRequest, TextPurifyResponse

# internal/__init__.py
__all__ = []  # 禁止对外暴露任何符号

# internal/text/__init__.py
__all__ = ["TextPurifyServiceImpl"]
from .service_impl import TextPurifyServiceImpl
```

**规则**：
- 禁止 `from . import *`
- `internal/__init__.py` 的 `__all__ = []`
- 骨架占位文件（未实现模块）同样 `__all__ = []` + TODO 注释

---

## 3. Pydantic 模型规范

### 3.1 请求/响应 DTO

```python
from pydantic import BaseModel, Field

class TextPurifyRequest(BaseModel):
    text: str = Field(..., min_length=1, description="待处理文本")
    options: PurifyOptions = Field(default_factory=PurifyOptions)

class TextPurifyResponse(BaseModel):
    status: str = Field(..., pattern="^(ok|error)$")
    data: PurifyResult | None = None
    message: str | None = None
```

### 3.2 与 Java 后端对齐

- Python 返回字段使用 **snake_case**
- Java 后端消费时映射为 **camelCase**
- 禁止直接把 Python 响应 JSON 原样塞进 Java 的 JSONB 字段

---

## 4. FastAPI 路由规范

### 4.1 路由组织

```python
from fastapi import APIRouter, Depends

router = APIRouter(prefix="/api/v1/text", tags=["Text Processing"])

@router.post("/purify", response_model=TextPurifyResponse)
async def purify_text(request: TextPurifyRequest):
    result = await text_service.purify(request.text, request.options)
    return TextPurifyResponse(status="ok", data=result)
```

### 4.2 依赖注入

```python
# 在 http_server.py 工厂函数中完成 DI
from fastapi import FastAPI

def create_app() -> FastAPI:
    app = FastAPI(title="[服务名]")
    app.include_router(router)
    return app
```

---

## 5. 服务注册（Registry）

如果 Python 服务需要被 Java 后端动态发现：

```python
from registry_client import RegistryClient

client = RegistryClient(endpoint="http://backend:8080/api/v1/registry")
client.register(
    name="[algorithm_name]_v1",
    version="v1",
    endpoint="http://[service_host]:[port]",
    capabilities=["capability_1", "capability_2"]
)
client.start_heartbeat()  # 启动心跳保活
```

**约束**：
- 注册接口协议与 Java 后端保持一致
- 字段名使用 camelCase（与 Java 对齐）
- 禁止硬编码后端地址，使用环境变量

---

## 6. 测试规范

### 6.1 测试结构

```
tests/
├── test_internal/
│   ├── test_service.py       # 与 internal/service.py 对应
│   └── test_repository.py    # 与 internal/repository.py 对应
└── conftest.py               # 共享 fixture
```

### 6.2 测试框架

```python
# 使用 pytest + pytest-asyncio
import pytest

@pytest.mark.asyncio
async def test_purify_service():
    result = await service.purify("test", options)
    assert result.encoding_detected == "UTF-8"
```

---

## 7. gRPC 预留（可选）

如项目计划使用 gRPC：

- `.proto` 文件放在 `infrastructure/protocol/proto/`
- 使用 `grpc_tools.protoc` 生成代码到 `generated/`
- **禁止手动编辑 `generated/` 目录**
- 当期不实现 gRPC 时，`grpc_server.py` 返回 `NotImplementedError`，不影响 HTTP 服务上线

---

## 8. 检查清单

- [ ] 六层目录结构完整，各层职责清晰
- [ ] 所有 `__init__.py` 声明 `__all__`
- [ ] Pydantic 模型有字段校验和类型注解
- [ ] 路由使用 `APIRouter` 组织，前缀统一
- [ ] 服务注册使用环境变量配置后端地址
- [ ] 测试目录与 `internal/` 镜像结构
- [ ] gRPC 预留目录已创建（如需要）

---

*版本: v1.0 | 最后更新: 2026-04-29*
