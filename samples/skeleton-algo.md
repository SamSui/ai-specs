---
title: 算法服务骨架（FastAPI + Python）
author: 顾小宇
tags: [样本, 范例, 算法, Python, FastAPI]
description: 基于 FastAPI + Python 的标准算法服务骨架，包含 gRPC 接口定义、算法注册机制、模块目录结构和容器化配置。
---

# 算法服务骨架（FastAPI + Python）

> **⚠️ 本文档为样本文件，核心结构和方法论可复用，所有项目专属内容均为占位符，使用前需替换。**

---

## 技术栈

| 层级 | 技术选型 | 版本 |
|------|---------|------|
| Web 框架 | FastAPI | 0.115+ |
| gRPC | grpcio + grpcio-tools | 1.68+ |
| 数据验证 | Pydantic | 2.x |
| 算法框架 | NumPy / Pandas / scikit-learn / PyTorch（按需） | 最新稳定版 |
| 容器 | Docker | 最新稳定版 |
| 包管理 | uv / pip | 最新稳定版 |
| Python | CPython | 3.11+ |

---

## 目录结构

```
[项目根目录]/
├── pyproject.toml                   # 项目配置（依赖、脚本、元数据）
├── uv.lock / requirements.txt       # 锁定依赖版本
├── Dockerfile                       # 多阶段构建
├── docker-compose.yml               # 本地开发编排
│
├── src/
│   ├── algorithm_service/           # 算法服务主包
│   │   ├── __init__.py
│   │   ├── main.py                  # FastAPI 应用入口
│   │   ├── config.py                # 配置管理（Pydantic Settings）
│   │   └── dependencies.py          # 依赖注入定义
│   │
│   ├── api/                         # HTTP REST API 层
│   │   ├── __init__.py
│   │   ├── routers/
│   │   │   ├── __init__.py
│   │   │   ├── health.py            # 健康检查
│   │   │   └── [业务域].py          # 业务路由
│   │   └── schemas/
│   │       ├── __init__.py
│   │       ├── common.py            # 通用响应/分页模型
│   │       └── [业务域].py          # 业务请求/响应模型
│   │
│   ├── internal/                    # 私有实现（禁止外部引用）
│   │   ├── __init__.py
│   │   ├── algorithms/              # 算法实现
│   │   │   ├── __init__.py
│   │   │   ├── base.py              # 算法基类（接口定义）
│   │   │   └── [algorithm_name].py  # 具体算法实现
│   │   ├── models/                  # 领域模型
│   │   │   └── [domain_model].py
│   │   ├── services/                # 业务逻辑层
│   │   │   └── [service].py
│   │   └── utils/                   # 工具函数
│   │       └── [util].py
│   │
│   ├── grpc_server/                 # gRPC 服务端（如需要）
│   │   ├── __init__.py
│   │   ├── servicers/
│   │   │   └── [servicer].py
│   │   └── interceptors/
│   │       └── [interceptor].py
│   │
│   └── proto/                       # Protocol Buffer 定义
│       ├── [service].proto
│       └── generated/               # protoc 生成的 Python 代码
│           └── __init__.py
│
├── tests/
│   ├── __init__.py
│   ├── conftest.py                  # pytest 共享 fixture
│   ├── unit/                        # 单元测试
│   │   └── test_[module].py
│   ├── integration/                 # 集成测试
│   │   └── test_[endpoint].py
│   └── fixtures/                    # 测试数据
│       └── [data].json
│
└── scripts/
    ├── generate_proto.sh            # 生成 gRPC 代码
    ├── run_dev.sh                   # 本地开发启动
    └── run_tests.sh                 # 运行测试套件
```

---

## 关键文件模板

### 算法基类（src/internal/algorithms/base.py）

```python
from abc import ABC, abstractmethod
from typing import Any, Dict

class BaseAlgorithm(ABC):
    """算法基类：所有算法必须实现此接口"""

    @property
    @abstractmethod
    def name(self) -> str:
        """算法唯一标识名"""
        pass

    @property
    @abstractmethod
    def version(self) -> str:
        """算法版本号（语义化版本）"""
        pass

    @abstractmethod
    def execute(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """执行算法
        
        Args:
            input_data: 输入数据字典
            
        Returns:
            输出结果字典
        """
        pass

    @abstractmethod
    def validate_input(self, input_data: Dict[str, Any]) -> bool:
        """验证输入数据格式"""
        pass
```

### FastAPI 入口（src/algorithm_service/main.py）

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routers import health

app = FastAPI(
    title="[项目缩写] Algorithm Service",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境需限制
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(health.router, prefix="/health", tags=["Health"])
# app.include_router(...)

@app.on_event("startup")
async def startup():
    """服务启动时初始化（加载算法、连接数据库等）"""
    pass

@app.on_event("shutdown")
async def shutdown():
    """服务关闭时清理资源"""
    pass
```

### Dockerfile（多阶段构建）

```dockerfile
# ---- Builder 阶段 ----
FROM python:3.11-slim AS builder

WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN pip install uv && uv sync --no-dev

# ---- Runtime 阶段 ----
FROM python:3.11-slim

WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY src/ ./src/

ENV PATH="/app/.venv/bin:$PATH"
ENV PYTHONPATH="/app/src"

CMD ["uvicorn", "algorithm_service.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

---

## 快速开始

```bash
# 1. 安装依赖
uv sync

# 2. 生成 gRPC 代码（如需要）
bash scripts/generate_proto.sh

# 3. 本地启动
uvicorn src.algorithm_service.main:app --reload --port 8080

# 4. 运行测试
pytest tests/ -v

# 5. 容器构建
docker build -t [项目缩写]-algo:latest .
```

---

## 算法注册规范

算法服务启动时必须向算法平台注册自身：

```python
# startup 时调用
async def register_algorithm():
    registration = {
        "algorithm_name": "[算法名]",
        "version": "1.0.0",
        "endpoint": "http://[服务地址]:8080",
        "input_schema": {...},      # JSON Schema
        "output_schema": {...},     # JSON Schema
        "capabilities": [...],      # 能力标签列表
    }
    # POST 到算法平台注册接口
```

---

## 相关规范

- [FastAPI 项目结构规范](../tech/tech-spec-fastapi.md)
- [Docker 容器化规范](../tech/tech-spec-docker.md)
- [API 文档编写规范](../specs/doc-spec-api.md)
