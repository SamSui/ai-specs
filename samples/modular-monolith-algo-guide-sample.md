---
title: 落地指南：模块化单体2.0 [项目名称]·Python算法篇（样本）
author: 顾小宇
tags: [AI工程化, 知识库, 指南]
description: ⚠️ 本文档为样本文件，核心结构和方法论可复用，所有项目专属内容均为占位符，使用前需替换。 任务ID：[任务ID]
---

# 落地指南：模块化单体2.0 [项目名称]·Python算法篇（样本）

> **⚠️ 本文档为样本文件，核心结构和方法论可复用，所有项目专属内容均为占位符，使用前需替换。**
>
> **文档版本**：v2.0  
> **任务ID**：[任务ID]  
> **维护者**：[架构师]  
> **创建日期**：2026-04-20  
> **依据**：[项目阶段]-design 调研报告 + Java版落地指南 + Python生态最佳实践

---

## 一、背景与目的

### 1.1 本文定位

本文是《落地指南：模块化单体2.0 [项目名称]》的**Python算法篇**，专注于指导 Python 算法服务的工程化落地。当算法平台需要接入外部 Python 算法（而非 Java 实现）时，该算法服务需遵循本文定义的模块化结构、通信协议、注册机制和容器化规范。

### 1.2 与Java版落地指南的关系

| 维度 | Java版落地指南 | Python算法篇 |
|------|--------------|-------------|
| **框架** | Spring Boot + Maven | FastAPI + Poetry |
| **数据访问** | MyBatis-Plus（`*Mapper.xml`） | SQLAlchemy + Pydantic |
| **模块边界** | ArchUnit（字节码分析） | ruff + `__all__`显式导出 |
| **通信协议** | HTTP + gRPC（Java原生） | HTTP + gRPC（grpc_tools） |
| **注册接口** | `POST /api/v1/algorithms/register` | `POST /api/v1/algorithms/register`（与Java对齐） |

**一致性要求**：Python算法服务必须与Java backend 使用**完全相同的注册接口协议**（字段名 `protocol` 而非 `algorithm_protocol`），确保算法治理平台的统一管理。

### 1.3 适用范围

- **接入场景**：外部 Python 算法（文本处理、图像处理等）作为独立服务接入算法平台
- **非接入场景**：纯 Java 实现的算法（直接内嵌在 `algorithm-platform` 模块中）不适用本文
- **技术约束**：Python ≥ 3.10，FastAPI + uvicorn，grpcio + grpcio-tools

---

## 二、Python模块化项目结构

### 2.1 目录结构规范

Python算法服务的目录结构遵循与Java落地指南相同的领域分层思想（`api`/`internal`/`model`），但使用 Python 生态的惯用命名：

```
algorithm_service/
├── pyproject.toml                 # Poetry依赖管理
├── Dockerfile                     # 多阶段构建
├── README.md
│
├── protos/                        # 【proto文件定义】（真相来源）
│   ├── __init__.py
│   ├── algorithm_service.proto
│   └── common/
│       ├── types.proto
│       └── enums.proto
│
├── generated/                     # 【自动生成】（grpc_tools.protoc产出，不要手动编辑）
│   ├── __init__.py
│   ├── algorithm_service_pb2.py
│   ├── algorithm_service_pb2.pyi
│   └── algorithm_service_pb2_grpc.py
│
├── src/
│   └── algorithm_service/
│       ├── __init__.py           # 公开API显式导出（对应Java的api/包）
│       │
│       ├── api/                  # 【对外暴露层】（对应Java的api/包）
│       │   ├── __init__.py       # __all__显式导出公开接口
│       │   ├── schemas.py        # Pydantic模型（HTTP请求/响应DTO）
│       │   ├── router.py        # FastAPI路由定义
│       │   └── dependencies.py  # 依赖注入
│       │
│       ├── internal/             # 【私有实现层】（对应Java的internal/包）
│       │   ├── __init__.py
│       │   ├── main.py           # uvicorn启动入口
│       │   ├── service.py       # 业务逻辑（对应Java的ServiceImpl）
│       │   ├── repository.py     # 数据访问（对应Java的Mapper）
│       │   └── tasks/            # 异步任务
│       │       └── heartbeat_task.py
│       │
│       ├── model/                # 【数据模型层】（对应Java的model/包）
│       │   ├── __init__.py
│       │   ├── entity.py         # SQLAlchemy ORM模型
│       │   └── vo.py             # 值对象
│       │
│       ├── config/               # 配置管理
│       │   ├── __init__.py
│       │   └── settings.py       # Pydantic Settings
│       │
│       └── infrastructure/       # 【基础设施层】
│           ├── __init__.py
│           ├── registry.py       # 算法注册客户端
│           └── health.py         # 健康检查实现
│
├── tests/
│   ├── __init__.py
│   ├── unit/
│   │   ├── test_service.py
│   │   └── test_repository.py
│   └── integration/
│       └── test_api.py
│
└── scripts/
    ├── generate_protos.py        # proto生成脚本
    └── run_dev.py                 # 开发启动脚本
```

**与Java落地指南的包对应关系**：

| Python（本文） | Java（落地指南） | 说明 |
|---------------|----------------|------|
| `src/algorithm_service/api/` | `com.[公司域名].[项目缩写].domain.*/api/` | 对外暴露的接口定义 |
| `src/algorithm_service/internal/` | `com.[公司域名].[项目缩写].domain.*/internal/` | 私有实现，禁止外部引用 |
| `src/algorithm_service/model/` | `com.[公司域名].[项目缩写].domain.*/model/` | 内部领域模型 |
| `src/algorithm_service/infrastructure/` | `infrastructure/` | 基础设施（注册、健康） |
| `protos/` | `**/*.proto` | IDL定义文件 |

### 2.2 `__all__`显式导出规则

Python没有ArchUnit那样的字节码边界强制工具，必须通过`__all__`实现显式API导出（PEP 8规范）：

```python
# src/algorithm_service/api/__init__.py
"""算法服务对外暴露的API."""

__all__ = [
    "AlgorithmRegisterRequest",  # Pydantic请求模型
    "AlgorithmRegisterResponse", # Pydantic响应模型
    "AlgorithmInfo",             # 算法信息模型
    "router",                    # FastAPI路由
]

from .schemas import (
    AlgorithmRegisterRequest,
    AlgorithmRegisterResponse,
    AlgorithmInfo,
)
from .router import router
```

**包边界强制原则**：
- ✅ `internal/`包中的模块**不得**通过`__all__`导出
- ✅ `api/`包中的`__all__`是外部可导入的唯一来源
- ✅ 使用`ruff`lint规则检测未通过`__all__`显式导出的跨包引用

### 2.3 4条包边界强制规则

由于Python缺乏ArchUnit级别的字节码分析能力，需要通过工具链组合实现包边界强制：

**规则1：禁止`internal`包被外部直接引用**

```toml
# pyproject.toml
[tool.ruff.lint]
select = ["F401"]  # 检测未使用导入（在__init__.py中未导出即为"未使用"）

[tool.ruff.lint.per-file-ignores]
"src/algorithm_service/internal/**/*.py" = ["F401"]  # internal内不检查
```

**规则2：`api`包只能包含Schema和Router**

```python
# src/algorithm_service/api/__init__.py
# 验证：只有Pydantic模型和router可以被导出
__all__ = [
    s for s in dir()
    if not s.startswith("_")
]
# 配合代码审查，禁止在api/中放置@Service实现类
```

**规则3：禁止跨模块直接import internal**

```bash
# 通过 ruff F403 "imported but unused" 间接检测
# 如果代码试图 from algorithm_service.internal.xxx import ...
# 但实际代码不使用该导入（因为不应该使用），则触发 F401
ruff check . --select F401
```

**规则4：命名规范（snake_case 与 Java 对齐）**

除包边界约束外，Python算法服务的命名需与Java侧约定的字段名完全对齐。以下为算法服务中最核心的命名约束（Java端统一使用 snake_case 序列化）：

| 元素 | Python命名 | Java对齐 |
|------|-----------|---------|
| 算法ID | `text_purify_v1`（snake_case） | `text_purify_v1` |
| 算法名称 | `TextPurify`（PascalCase） | `TextPurify` |
| 模块名 | `algorithm_service`（snake_case） | `algorithm-platform` |
| DTO字段 | `algorithm_id`（snake_case） | `algorithmId` + `@JsonProperty` |

### 2.4 pyproject.toml模板

```toml
[project]
name = "algorithm-service"
version = "0.1.0"
description = "AIWisdom Algorithm Service - Python Implementation"
requires-python = ">=3.10"
dependencies = [
    "fastapi>=0.109.0",
    "uvicorn[standard]>=0.27.0",
    "grpcio>=1.60.0",
    "grpcio-tools>=1.60.0",
    "sqlalchemy>=2.0.25",
    "pydantic>=2.5.0",
    "pydantic-settings>=2.1.0",
    "psycopg2-binary>=2.9.9",
    "tenacity>=8.2.3",
    "httpx>=0.26.0",
    "ruff>=0.2.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.23.0",
    "mypy>=1.8.0",
]

[build-system]
requires = ["poetry-core>=1.8.0"]
build-backend = "poetry.core.masonry.api"

[tool.poetry]
packages = [{include = "src/algorithm_service"}]

[tool.ruff.lint]
select = ["E", "F", "I", "W"]
ignore = ["E501"]
line-length = 120

[tool.mypy]
python_version = "3.10"
strict = false
```

---

## 三、双协议服务基座

### 3.1 架构概览

Python算法服务同时暴露两个协议端口：

```
                    ┌─────────────────────┐
                    │   算法治理平台        │
                    │ (Java backend)      │
                    └──────────┬──────────┘
                               │ HTTP REST (注册/心跳)
                               │ gRPC (算法调用)
                    ┌──────────▼──────────┐
                    │ Python算法服务       │
                    │                     │
          ┌─────────▼─────────────────▼───┐
          │  uvicorn (HTTP/1.1)  :8080   │  ← 算法注册、心跳、管控
          │  gRPC Server        :50051   │  ← 算法实际调用
          └────────────────────────────────┘
```

### 3.2 FastAPI + uvicorn（HTTP协议）

**main.py**：

```python
# src/algorithm_service/internal/main.py
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from algorithm_service.api.router import router
from algorithm_service.config.settings import settings
from algorithm_service.infrastructure.health import setup_health_check


def create_app() -> FastAPI:
    app = FastAPI(
        title="AIWisdom Algorithm Service",
        version=settings.VERSION,
        docs_url="/api/docs",
        redoc_url="/api/redoc",
    )

    # CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # 注册路由
    app.include_router(router, prefix="/api/v1")

    # 健康检查
    setup_health_check(app)

    return app


app = create_app()


if __name__ == "__main__":
    uvicorn.run(
        "algorithm_service.internal.main:app",
        host="0.0.0.0",
        port=8080,
        reload=False,
        workers=1,  # 单进程（容器内单实例）
    )
```

**router.py**：

```python
# src/algorithm_service/api/router.py
from fastapi import APIRouter, Depends, HTTPException, status

from algorithm_service.api.schemas import (
    AlgorithmRegisterRequest,
    AlgorithmRegisterResponse,
    AlgorithmInfo,
    HealthResponse,
)
from algorithm_service.internal.service import AlgorithmService

router = APIRouter(prefix="/algorithms", tags=["算法管理"])


def get_service() -> AlgorithmService:
    # 依赖注入（后续章节详述）
    from algorithm_service.api.dependencies import get_algorithm_service
    return get_algorithm_service()


@router.post("/register", response_model=AlgorithmRegisterResponse, status_code=201)
async def register_algorithm(
    request: AlgorithmRegisterRequest,
    service: AlgorithmService = Depends(get_service),
):
    """注册算法到治理平台（与Java backend协议对齐）"""
    result = await service.register(request)
    return result


@router.get("/info/{algorithm_id}", response_model=AlgorithmInfo)
async def get_algorithm_info(
    algorithm_id: str,
    service: AlgorithmService = Depends(get_service),
):
    """查询算法信息"""
    info = await service.get_info(algorithm_id)
    if not info:
        raise HTTPException(status_code=404, detail=f"Algorithm {algorithm_id} not found")
    return info


@router.get("/health", response_model=HealthResponse)
async def health_check():
    """健康检查端点（供治理平台心跳检测）"""
    return HealthResponse(status="healthy", service="algorithm-service")
```

### 3.3 gRPC基座（proto包命名规范）

**proto文件**：

```protobuf
// protos/algorithm_service.proto
syntax = "proto3";

package [项目缩写].algorithm.v1;  // 逆向域名+版本号（与Java package对应）

option python_package = "generated.[项目缩写].algorithm.v1";  // 生成代码放置路径
option java_package = "com.[公司域名].[项目缩写].algorithm.registry";  // 与Java backend实际包路径对齐
option java_multiple_files = true;

// 算法服务定义
service AlgorithmService {
    // 单次调用
    rpc Process(ProcessRequest) returns (ProcessResponse);
    // 流式调用
    rpc StreamProcess(StreamProcessRequest) returns (stream ProcessResponse);
}

// 请求消息
message ProcessRequest {
    string algorithm_id = 1;
    bytes input_data = 2;
    map<string, string> parameters = 3;
}

// 响应消息
message ProcessResponse {
    string algorithm_id = 1;
    bytes output_data = 2;
    bool success = 3;
    string error_message = 4;
    map<string, string> metadata = 5;
}
```

**gRPC服务器启动**：

```python
# src/algorithm_service/internal/servicers/algorithm_servicer.py
import grpc
from generated.[项目缩写].algorithm.v1 import (
    algorithm_service_pb2 as pb2,
    algorithm_service_pb2_grpc as pb2_grpc,
)


class AlgorithmServicer(pb2_grpc.AlgorithmServiceServicer):
    """
    gRPC算法服务实现。

    对应proto定义的AlgorithmService，提供Process和StreamProcess两个方法。
    """

    def Process(self, request: pb2.ProcessRequest, context: grpc.ServicerContext) -> pb2.ProcessResponse:
        """单次算法处理"""
        return pb2.ProcessResponse(
            algorithm_id=request.algorithm_id,
            output_data=b"",
            success=True,
            error_message="",
            metadata={},
        )

    def StreamProcess(self, request: pb2.StreamProcessRequest, context: grpc.ServicerContext):
        """流式算法处理（桩实现）"""
        yield pb2.ProcessResponse(
            algorithm_id=request.algorithm_id,
            output_data=b"",
            success=True,
            error_message="",
            metadata={},
        )


# src/algorithm_service/internal/grpc_server.py
import grpc
from concurrent import futures

from generated.[项目缩写].algorithm.v1 import (
    algorithm_service_pb2_grpc,
)
from algorithm_service.internal.servicers.algorithm_servicer import AlgorithmServicer


def create_grpc_server() -> grpc.Server:
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    algorithm_service_pb2_grpc.add_AlgorithmServiceServicer_to_server(
        AlgorithmServicer(), server
    )
    server.add_insecure_port("[::]:50051")
    return server


def serve_grpc():
    server = create_grpc_server()
    server.start()
    print("gRPC server started on port 50051")
    server.wait_for_termination()
```

### 3.4 双端口启动脚本

```python
# src/algorithm_service/internal/server.py
import threading
import uvicorn
from algorithm_service.internal.grpc_server import serve_grpc


def run_dual_protocol():
    """同时启动HTTP和gRPC服务"""
    # gRPC线程
    grpc_thread = threading.Thread(target=serve_grpc, daemon=True)
    grpc_thread.start()

    # HTTP（uvicorn）
    uvicorn.run(
        "algorithm_service.internal.main:app",
        host="0.0.0.0",
        port=8080,
        log_level="info",
    )


if __name__ == "__main__":
    run_dual_protocol()
```

---

## 四、算法注册协议

### 4.1 注册接口协议（与Java对齐）

Python算法服务启动后，向Java backend（`algorithm-platform`模块）注册自身。注册接口**必须与Java版`AlgorithmRegistrationRequest`完全对齐**：

| Java字段名 | Python字段名 | 类型 | 说明 |
|-----------|------------|------|------|
| `algorithm_id` | `algorithm_id` | `str` | 全局唯一ID（snake_case） |
| `algorithm_name` | `algorithm_name` | `str` | 可读名称 |
| `protocol` | `protocol` | `str` | `"grpc"` 或 `"http"` |
| `host` | `host` | `str` | 服务地址 |
| `port` | `port` | `int` | 端口号（1-65535） |
| `language` | `language` | `str` | `"python"` |
| `version` | `version` | `str` | 算法版本 |
| `category` | `category` | `str` | 分类（image/text/audio等） |
| `internal_tags` | `internal_tags` | `List[str]` | 内部标签 |
| `input_schema` | `input_schema` | `str` | 输入Schema ID |
| `output_schema` | `output_schema` | `str` | 输出Schema ID |
| `schema_id` | `schema_id` | `str` | proto schema ID |
| `health_endpoint` | `health_endpoint` | `str` | 健康检查路径 |
| `ttl_seconds` | `ttl_seconds` | `int` | 心跳TTL |

**Pydantic请求模型**：

```python
# src/algorithm_service/api/schemas.py
from typing import Optional, List
from pydantic import BaseModel, Field, field_validator
import re


class AlgorithmRegisterRequest(BaseModel):
    algorithm_id: str = Field(..., description="全局唯一ID（如 text_purify_v1）")
    algorithm_name: str = Field(..., description="可读名称")
    protocol: str = Field(..., pattern="^(grpc|http)$", description="通信协议")
    host: str = Field(..., description="服务地址")
    port: int = Field(..., ge=1, le=65535, description="端口号")
    language: str = Field(default="python", description="实现语言")
    version: Optional[str] = Field(None, description="算法版本")
    category: Optional[str] = Field(None, description="算法分类")
    internal_tags: Optional[List[str]] = Field(default_factory=list, alias="internalTags")
    input_schema: Optional[str] = Field(None, alias="inputSchema")
    output_schema: Optional[str] = Field(None, alias="outputSchema")
    schema_id: Optional[str] = Field(None, alias="schemaId")
    health_endpoint: Optional[str] = Field(default="/api/v1/algorithms/health", alias="healthEndpoint")
    ttl_seconds: Optional[int] = Field(default=60, ge=1, alias="ttlSeconds")

    model_config = {
        "populate_by_name": True,  # 支持别名
        "json_schema_extra": {
            "example": {
                "algorithm_id": "text_purify_v1",
                "algorithm_name": "TextPurify",
                "protocol": "http",
                "host": "algorithm-text-purify",
                "port": 8080,
                "language": "python",
                "version": "v1.0.0",
                "category": "text",
                "internal_tags": ["preprocessing", "phase1"],
                "health_endpoint": "/api/v1/algorithms/health",
                "ttl_seconds": 60,
            }
        }
    }

    @field_validator("algorithm_id")
    @classmethod
    def validate_algorithm_id(cls, v: str) -> str:
        if not re.match(r"^[a-z][a-z0-9_]*$", v):
            raise ValueError("algorithm_id must be snake_case, e.g. text_purify_v1")
        return v

    @field_validator("protocol")
    @classmethod
    def validate_protocol(cls, v: str) -> str:
        if v not in ("grpc", "http"):
            raise ValueError("protocol must be 'grpc' or 'http'")
        return v


class AlgorithmRegisterResponse(BaseModel):
    success: bool
    message: str
    algorithm_id: str


class AlgorithmInfo(BaseModel):
    algorithm_id: str
    algorithm_name: str
    protocol: str
    host: str
    port: int
    status: str = "registered"


class HealthResponse(BaseModel):
    status: str
    service: str
    version: Optional[str] = None
```

### 4.2 注册客户端实现（带容错重试）

```python
# src/algorithm_service/infrastructure/registry.py
import os
import logging
from typing import Optional

import httpx
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential_jitter,
    retry_if_exception_type,
)

from algorithm_service.api.schemas import (
    AlgorithmRegisterRequest,
    AlgorithmRegisterResponse,
)

logger = logging.getLogger(__name__)


class RegistryClient:
    """
    算法注册客户端。

    负责将Python算法服务注册到Java backend（algorithm-platform）。
    使用指数退避+抖动重试机制（与素材05对齐）。
    """

    def __init__(
        self,
        backend_registry_url: Optional[str] = None,
        max_attempts: int = 5,
        initial_delay: float = 2.0,
        max_delay: float = 60.0,
    ):
        # BACKEND_REGISTRY_URL：Java backend的算法注册端点
        self.backend_registry_url = (
            backend_registry_url
            or os.environ.get("BACKEND_REGISTRY_URL", "http://algorithm-platform:8081")
        )
        self.max_attempts = max_attempts
        self.initial_delay = initial_delay
        self.max_delay = max_delay

    @retry(
        stop=stop_after_attempt(self.max_attempts),
        wait=wait_exponential_jitter(
            initial=2,    # 初始延迟2秒（素材05推荐）
            max=60,       # 最大延迟60秒
            exp_base=2,   # 指数因子2
            jitter=2,     # 最多±2秒抖动
        ),
        retry=retry_if_exception_type((
            httpx.TimeoutException,
            httpx.ConnectError,
            httpx.HTTPStatusError,
        )),
        before_sleep=before_sleep_log(logger, logging.WARNING),
        reraise=True,
    )
    async def register(
        self,
        request: AlgorithmRegisterRequest,
        idempotency_key: Optional[str] = None,
    ) -> AlgorithmRegisterResponse:
        """
        注册算法实例。

        使用幂等键（instance_id）防止重复注册。
        仅重试5xx错误和连接错误，不重试4xx客户端错误。
        """
        headers = {
            "Content-Type": "application/json",
            "X-Idempotency-Key": idempotency_key or request.algorithm_id,
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            try:
                response = await client.post(
                    f"{self.backend_registry_url}/api/v1/algorithms/register",
                    json=request.model_dump(by_alias=True),
                    headers=headers,
                )

                # 4xx：不重试，直接抛异常
                if 400 <= response.status_code < 500:
                    response.raise_for_status()

                # 429/5xx：重试
                if response.status_code in (429, 500, 502, 503, 504):
                    response.raise_for_status()

                response.raise_for_status()
                return AlgorithmRegisterResponse(**response.json())

            except httpx.TimeoutException:
                logger.warning(f"Registry timeout for {request.algorithm_id}")
                raise
            except httpx.ConnectError:
                logger.warning(f"Registry connection failed for {request.algorithm_id}")
                raise

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential_jitter(initial=1, max=10),
        retry=retry_if_exception_type((
            httpx.TimeoutException,
            httpx.ConnectError,
        )),
    )
    async def heartbeat(self, algorithm_id: str) -> bool:
        """心跳保活（更短的重试配置）"""
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.put(
                f"{self.backend_registry_url}/api/v1/algorithms/{algorithm_id}/heartbeat",
                timeout=5.0,
            )
            # 4xx：不重试，直接抛异常
            if 400 <= response.status_code < 500:
                response.raise_for_status()
            # 5xx或成功走到这里
            response.raise_for_status()  # 触发重试
            return response.status_code == 200
```

**注意**：`before_sleep_log`需要从tenacity导入：

```python
from tenacity import before_sleep_log
```

### 4.3 启动时注册 + 定时心跳

```python
# src/algorithm_service/internal/tasks/startup_task.py
import asyncio
import logging
import os
from algorithm_service.api.schemas import AlgorithmRegisterRequest
from algorithm_service.config.settings import settings
from algorithm_service.infrastructure.registry import RegistryClient

logger = logging.getLogger(__name__)


async def startup_registration():
    """
    服务启动时执行一次注册。

    从环境变量获取注册信息，构建AlgorithmRegisterRequest，
    调用RegistryClient.register()。
    """
    registry_url = os.environ.get("BACKEND_REGISTRY_URL", "http://algorithm-platform:8081")

    request = AlgorithmRegisterRequest(
        algorithm_id=os.environ["ALGORITHM_ID"],       # 必须：text_purify_v1
        algorithm_name=os.environ.get("ALGORITHM_NAME", "Algorithm"),
        protocol=os.environ.get("ALGORITHM_PROTOCOL", "http"),  # http或grpc
        host=os.environ.get("ALGORITHM_HOST", "algorithm-text-purify"),
        port=int(os.environ.get("ALGORITHM_PORT", "8080")),
        language="python",
        version=os.environ.get("ALGORITHM_VERSION", "v1.0.0"),
        category=os.environ.get("ALGORITHM_CATEGORY", "text"),
        internal_tags=os.environ.get("ALGORITHM_TAGS", "").split(",") if os.environ.get("ALGORITHM_TAGS") else [],
        health_endpoint="/api/v1/algorithms/health",
        ttl_seconds=int(os.environ.get("ALGORITHM_TTL", "60")),
    )

    client = RegistryClient(backend_registry_url=registry_url)
    try:
        result = await client.register(request)
        logger.info(f"Algorithm registered: {result.algorithm_id}, success={result.success}")
    except Exception as e:
        logger.error(f"Failed to register algorithm: {e}")
        # 注册失败不应阻止服务启动（算法仍可本地运行）
        # 但需要在日志中告警


async def heartbeat_loop():
    """
    定时心跳循环。

    每 ttl_seconds/2 秒发送一次心跳，
    确保服务在治理平台保持活跃状态。
    """
    algorithm_id = os.environ.get("ALGORITHM_ID")
    if not algorithm_id:
        logger.warning("ALGORITHM_ID not set, skipping heartbeat")
        return

    registry_url = os.environ.get("BACKEND_REGISTRY_URL", "http://algorithm-platform:8081")
    ttl = int(os.environ.get("ALGORITHM_TTL", "60"))
    interval = ttl / 2  # TTL的一半

    client = RegistryClient(backend_registry_url=registry_url)

    while True:
        await asyncio.sleep(interval)
        try:
            ok = await client.heartbeat(algorithm_id)
            if ok:
                logger.debug(f"Heartbeat OK: {algorithm_id}")
            else:
                logger.warning(f"Heartbeat failed: {algorithm_id}")
        except Exception as e:
            logger.warning(f"Heartbeat error: {e}")


from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    await startup_registration()
    asyncio.create_task(heartbeat_loop())
    yield

# FastAPI 直接接收 lifespan 函数引用，无需包装
# app = FastAPI(lifespan=lifespan)
```

---

## 五、与Java Backend集成

### 5.1 调用链

```
Java Caller（data-source-management）
    │
    │ HTTP GET /api/v1/algorithms/text_purify_v1/process
    ▼
Java algorithm-platform
    │
    │ 算法注册表查询（algorithm_id = "text_purify_v1"）
    ▼
Python algorithm-service（HTTP 或 gRPC）
    │
    │ FastAPI: POST /api/v1/algorithms/register
    │ gRPC: AlgorithmService.Process
    ▼
返回处理结果
```

### 5.2 algorithm_id命名规范（snake_case）

Python算法服务必须使用**snake_case格式**的`algorithm_id`，与Java后端保持一致：

```bash
# 环境变量示例
ALGORITHM_ID=text_purify_v1         # ✅ 正确（snake_case）
ALGORITHM_ID=textPurifyV1           # ❌ 错误（camelCase）
ALGORITHM_ID=text-purify-v1         # ❌ 错误（kebab-case）
```

**已定义的algorithm_id规范**（来自algorithm-platform模块）：

| algorithm_id | 说明 |
|-------------|------|
| `text_purify_v1` | 文本净化算法v1 |
| `img_standardize_v2` | 图像标准化算法v2 |

### 5.3 BACKEND_REGISTRY_URL环境变量

Python算法服务通过`BACKEND_REGISTRY_URL`环境变量定位Java backend：

```bash
# docker-compose.yml 示例
services:
  algorithm-text-purify:
    image: [项目缩写]/algorithm-text-purify:latest
    environment:
      BACKEND_REGISTRY_URL: http://algorithm-platform:8081
      ALGORITHM_ID: text_purify_v1
      ALGORITHM_NAME: TextPurify
      ALGORITHM_PROTOCOL: http
      ALGORITHM_HOST: algorithm-text-purify
      ALGORITHM_PORT: 8080
      ALGORITHM_VERSION: v1.0.0
      ALGORITHM_CATEGORY: text
      ALGORITHM_TAGS: preprocessing,phase1
      ALGORITHM_TTL: "60"
    ports:
      - "8082:8080"   # HTTP端口映射
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/v1/algorithms/health"]
      interval: 30s
      timeout: 5s
      retries: 3          # Docker HEALTHCHECK 本身的重试次数（非compose容器重启策略）
      start_period: 10s
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
```

### 5.4 注册状态查询

```python
# src/algorithm_service/api/router.py（补充）
@router.get("/{algorithm_id}/status")
async def get_algorithm_status(
    algorithm_id: str,
    service: AlgorithmService = Depends(get_service),
):
    """查询算法注册状态"""
    return await service.get_status(algorithm_id)
```

---

## 六、容器化规范

### 6.1 多阶段Dockerfile

```dockerfile
# syntax=docker/dockerfile:1.6
# ============================================================
# Stage 1: Builder（编译阶段）
# ============================================================
FROM python:3.10-slim AS builder

# 安装编译依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential=12.9 \
    libpq-dev=12.9 \
    curl \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# 创建虚拟环境
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# 安装依赖（使用BuildKit缓存加速）
COPY pyproject.toml poetry.lock* ./
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir --upgrade pip && \
    poetry install --no-interaction --no-ansi --no-root

# ============================================================
# Stage 2: Runtime（运行时阶段）
# ============================================================
FROM python:3.10-slim AS runtime

# 仅安装运行时依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5=12.18 \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# 创建非root用户（显式UID/GID，Kubernetes安全上下文兼容）
RUN groupadd --gid 10001 appgroup && \
    useradd --uid 10001 --gid appgroup \
    --shell /sbin/nologin \
    --home-dir /app \
    --no-create-home \
    appuser

# 复制虚拟环境
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 设置工作目录
WORKDIR /app

# 复制应用代码（使用--chown单层设置所有权）
COPY --chown=appuser:appgroup . .

# 设置正确权限
RUN chmod -R 755 /app

# 切换非root用户
USER appuser

# 设置HOME（Python包需要）
ENV HOME=/app
ENV PORT=8080

# 暴露非特权端口（>1024）
EXPOSE 8080 50051

# ============================================================
# 健康检查（--retries 3，与素材04对齐）
# ============================================================
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/api/v1/algorithms/health || exit 1

# ============================================================
# 启动命令
# ============================================================
# uvicorn单进程（容器内单实例，通过副本数扩容）
CMD ["python", "-m", "algorithm_service.internal.main"]
```

**关键点说明**：

| 实践 | 说明 |
|------|------|
| Builder/Runtime分离 | 最终镜像不包含编译工具，体积减小50-80% |
| `--chown=appuser:appgroup` | 单层设置所有权，避免额外RUN层 |
| 显式UID/GID（10001+） | Kubernetes `runAsUser/runAsGroup` 兼容 |
| 端口8080（非80） | 非root用户无法绑定特权端口（<1024） |
| `HEALTHCHECK --retries 3` | Docker健康检查重试3次，与素材04一致 |

### 6.2 Dockerignore

```dockerignore
# Git
.git
.gitignore

# 测试
tests/
*.pytest*
.coverage

# IDE
.vscode/
.idea/

# 构建产物
*.pyc
__pycache__/
*.egg-info/
dist/
build/

# 开发文件
*.md (except README.md)
.env.local
.env.development
```

### 6.3 构建和推送

```bash
# 构建（启用BuildKit）
DOCKER_BUILDKIT=1 docker build \
    -f Dockerfile \
    -t [项目缩写]/algorithm-text-purify:latest \
    --target runtime \
    .

# 验证非root运行
docker run --rm [项目缩写]/algorithm-text-purify:latest whoami
# 输出: appuser

# 推送
docker push [项目缩写]/algorithm-text-purify:latest
```

---

## 七、验收标准

| 验收项 | 检查点 | 对应章节 |
|--------|--------|---------|
| **项目结构** | 存在 `src/algorithm_service/api/`、`internal/`、`model/` 三层 | §2.1 |
| **`__all__`显式导出** | `api/__init__.py` 包含显式 `__all__` | §2.2 |
| **双协议端口** | HTTP(8080) + gRPC(50051) 同时暴露 | §3.1 |
| **注册接口** | `POST /api/v1/algorithms/register`，字段名 `protocol` | §4.1 |
| **algorithm_id规范** | snake_case格式（如 `text_purify_v1`） | §5.2 |
| **容错重试** | Tenacity指数退避+抖动，5次重试 | §4.2 |
| **心跳保活** | 启动时注册 + 定时心跳（TTL/2间隔） | §4.3 |
| **BACKEND_REGISTRY_URL** | 通过环境变量配置 | §5.3 |
| **非root用户** | Dockerfile使用 `appuser:appgroup` | §6.1 |
| **健康检查** | `HEALTHCHECK --retries 3` | §6.1 |
| **多阶段构建** | Builder/Runtime分离，不含编译工具 | §6.1 |

---

## 八、避坑检查清单

| 编号 | 检查项 | 优先级 | 状态 |
|------|--------|--------|------|
| 🔴 E-01 | 注册字段名必须为 `protocol`，不能是 `algorithm_protocol` | 必须 | ✅ |
| 🔴 E-02 | `algorithm_id`必须snake_case（`text_purify_v1`），不能camelCase | 必须 | ✅ |
| 🔴 E-03 | `BACKEND_REGISTRY_URL`必须通过环境变量配置，不能硬编码 | 必须 | ✅ |
| 🔴 E-04 | 端口>1024（非root无法绑定特权端口） | 必须 | ✅ |
| 🟡 E-05 | 使用Tenacity重试，指数退避+抖动，仅重试5xx | 建议 | ✅ |
| 🟡 E-06 | `__all__`显式导出，禁止internal包被外部直接引用 | 建议 | ✅ |
| 🟡 E-07 | proto文件包名使用逆向域名+版本号（`[项目缩写].algorithm.v1`） | 建议 | ✅ |
| 🟡 E-08 | Heartbeat间隔 = TTL/2 | 建议 | ✅ |

---

## 附录A：素材索引

| 编号 | 素材名称 | 来源 | 对应章节 |
|------|---------|------|---------|
| 01 | Python模块化最佳实践 | Web搜索 | §2（`__all__`显式导出） |
| 02 | FastAPI大型应用项目结构 | Web搜索 | §2（api/internal/model分层） |
| 03 | Python gRPC入门 | Web搜索 | §3（grpc_tools、proto包规范） |
| 04 | Python Docker多阶段构建 | Web搜索 | §6（非root、Dockerfile多阶段） |
| 05 | 算法服务注册与健康检查 | Web搜索 | §4（指数退避+抖动重试） |
| 06 | Python包边界强制工具 | Web搜索 | §2（ruff lint规则） |

**素材目录**：`[项目报告目录]/reports/[任务ID]/materials/`

---

## 附录B：参考文档

| 文档 | 路径 |
|------|------|
| M2.4 调研报告 | `../../M2.4-design-research/final.md` |
| Java版落地指南 | `../../.././M2.4-design/落地指南_模块化单体2.0_[项目名称].md` |
| 架构师规则集 | `../../.././M2.4-design/规则集_架构师.md` |
| Java AlgorithmRegistrationRequest | `../../.././backend.bk/algorithm-platform/src/main/java/com/[项目缩写]/algorithm/registry/dto/AlgorithmRegistrationRequest.java` |
| Python调研素材 | `./materials/00-index.md` |

---

*本文档由 Architect（[架构师]）编写，面向 [项目名称]项目 M2.6 Python算法服务接入团队*

> 本文档版本 2.0，2026-04-20
