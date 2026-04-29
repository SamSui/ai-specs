---
title: 后端项目骨架（Spring Boot 3.x + 模块化单体）
author: 顾小宇
tags: [样本, 范例, 后端, Java, Spring Boot]
description: 基于 Spring Boot 3.x + Maven 的模块化单体后端项目标准骨架，包含目录结构、模块划分、依赖管理和关键配置文件模板。
---

# 后端项目骨架（Spring Boot 3.x + 模块化单体）

> **⚠️ 本文档为样本文件，核心结构和方法论可复用，所有项目专属内容均为占位符，使用前需替换。**

---

## 技术栈

| 层级 | 技术选型 | 版本 |
|------|---------|------|
| 框架 | Spring Boot | 3.x |
| ORM | MyBatis-Plus | 3.5.x |
| 数据库 | PostgreSQL | 15+ |
| 构建工具 | Maven | 3.9+ |
| JDK | OpenJDK | 21 |
| 容器 | Docker | 最新稳定版 |

---

## 目录结构

```
[项目根目录]/
├── pom.xml                          # 父 POM，统一依赖版本
├── app-bootstrap/                   # 启动入口模块
│   ├── src/main/java/
│   │   └── com.[公司域名].[项目缩写]/
│   │       └── BootstrapApplication.java
│   └── pom.xml
│
├── module-core/                     # 核心基础设施模块
│   ├── src/main/java/
│   │   └── com.[公司域名].[项目缩写].core/
│   │       ├── config/              # 全局配置
│   │       ├── exception/           # 全局异常处理
│   │       ├── response/            # 统一响应封装
│   │       └── util/                # 通用工具类
│   └── pom.xml
│
├── module-domain-[业务域A]/          # 业务域模块（可复制多个）
│   ├── api/                         # 对外暴露的接口定义
│   │   ├── src/main/java/
│   │   │   └── com.[公司域名].[项目缩写].domain.[业务域A].api/
│   │   │       ├── dto/             # 数据传输对象
│   │   │       ├── vo/              # 视图对象
│   │   │       └── service/         # 接口定义（Feign/内部调用）
│   │   └── pom.xml
│   ├── internal/                    # 私有实现
│   │   ├── src/main/java/
│   │   │   └── com.[公司域名].[项目缩写].domain.[业务域A].internal/
│   │   │       ├── controller/      # REST API 控制器
│   │   │       ├── service/         # 业务逻辑实现
│   │   │       ├── mapper/          # MyBatis-Plus Mapper
│   │   │       └── entity/          # 实体类
│   │   └── pom.xml
│   ├── model/                       # 内部领域模型
│   │   ├── src/main/java/
│   │   │   └── com.[公司域名].[项目缩写].domain.[业务域A].model/
│   │   │       └── enums/           # 枚举定义
│   │   └── pom.xml
│   └── pom.xml
│
├── module-domain-[业务域B]/          # 第二个业务域模块（示例）
│   ├── api/
│   ├── internal/
│   ├── model/
│   └── pom.xml
│
└── Dockerfile                       # 多阶段构建（见 tech/tech-spec-docker.md）
```

---

## 关键文件模板

### 父 POM（pom.xml）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.[公司域名].[项目缩写]</groupId>
    <artifactId>[项目缩写]-parent</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>pom</packaging>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.4.x</version>
    </parent>

    <modules>
        <module>app-bootstrap</module>
        <module>module-core</module>
        <module>module-domain-[业务域A]</module>
        <module>module-domain-[业务域B]</module>
    </modules>

    <properties>
        <java.version>21</java.version>
        <mybatis-plus.version>3.5.16</mybatis-plus.version>
        <postgresql.version>42.7.x</postgresql.version>
    </properties>

    <dependencyManagement>
        <dependencies>
            <!-- 内部模块版本统一管理 -->
            <dependency>
                <groupId>com.[公司域名].[项目缩写]</groupId>
                <artifactId>module-core</artifactId>
                <version>${project.version}</version>
            </dependency>
            <!-- ... -->
        </dependencies>
    </dependencyManagement>
</project>
```

### 启动类（BootstrapApplication.java）

```java
package com.[公司域名].[项目缩写];

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = "com.[公司域名].[项目缩写]")
public class BootstrapApplication {
    public static void main(String[] args) {
        SpringApplication.run(BootstrapApplication.class, args);
    }
}
```

---

## 快速开始

```bash
# 1. 编译
mvn clean package -DskipTests

# 2. 本地启动（需 PostgreSQL）
cd app-bootstrap
mvn spring-boot:run

# 3. 容器构建
docker build -t [项目缩写]-backend:latest .
```

---

## 相关规范

- [MyBatis-Plus 规范](../tech/tech-spec-mybatis-plus.md)
- [PostgreSQL + JSONB 规范](../tech/tech-spec-postgresql-jsonb.md)
- [Spring Boot 项目结构规范](../tech/tech-spec-spring-boot.md)
- [错误码规范](../specs/doc-spec-error-codes.md)
