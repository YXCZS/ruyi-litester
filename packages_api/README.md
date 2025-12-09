# Packages Index API 项目文档

## 目录

- [项目简介](#项目简介)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [API 接口文档](#api-接口文档)
- [使用示例](#使用示例)
- [架构设计](#架构设计)
- [注意事项](#注意事项)

---

## 项目简介

Packages Index API 是基于 Python 和 FastAPI 的 REST API 服务，用于查询 `ruyisdk/packages-index` 仓库中的软件包信息。

主要功能：
- 分类浏览：按包的类型浏览所有包
- 关键词搜索：在包名和描述中模糊搜索
- 版本查看：查看指定包的所有版本
- 详细信息：获取包的完整 manifest 信息
- 实时数据：从 GitHub 实时拉取最新数据
- 智能缓存：10 分钟内存缓存

截图位置 1：项目 GitHub 仓库首页

---

## 技术栈

- FastAPI (0.115.0) - Web 框架，自动生成 API 文档
- Uvicorn (0.30.6) - ASGI 服务器
- httpx (0.27.2) - 异步 HTTP 客户端
- tomli (2.0.1) - TOML 解析库

技术特点：
- 异步编程，支持高并发
- 类型提示，提升可维护性
- 自动生成 Swagger UI 文档
- 跨平台支持

截图位置 2：requirements.txt 文件内容

---

## 项目结构

```
packages_api/
├── app.py              # 核心应用代码
├── requirements.txt    # 依赖包列表
├── start.sh           # 启动脚本
├── README.md          # 使用指南
└── DOCUMENTATION.md   # 本文档
```

截图位置 3：项目目录结构

---

## 快速开始

### 使用启动脚本（Linux/macOS）

```bash
cd packages_api
bash start.sh
```

截图位置 4：运行 start.sh 的终端输出

### 手动启动

Windows:
```powershell
cd packages_api
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
cd ..
python -m uvicorn packages_api.app:app --host 0.0.0.0 --port 8000
```

Linux/macOS:
```bash
cd packages_api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd ..
python -m uvicorn packages_api.app:app --host 0.0.0.0 --port 8000
```

访问地址：
- API 文档：http://127.0.0.1:8000/docs
- 健康检查：http://127.0.0.1:8000/health

截图位置 5：服务启动后的终端输出

---

## API 接口文档

### 1. 健康检查

GET /health

检查服务是否正常运行。

请求示例：
```bash
curl http://127.0.0.1:8000/health
```

响应：
```json
{
  "status": "ok"
}
```

### 2. 列出所有分类

GET /kinds

返回所有包分类列表。

请求示例：
```bash
curl http://127.0.0.1:8000/kinds
```

响应：
```json
["analyzer", "board-image", "emulator", "toolchain"]
```

### 3. 查看分类下的包

GET /kinds/{kind}/packages

返回指定分类下的所有包名。

路径参数：
- kind: 包的分类，如 toolchain、analyzer

请求示例：
```bash
curl http://127.0.0.1:8000/kinds/toolchain/packages
```

响应：
```json
["gnu-milkv-milkv-duo-elf-bin", "gnu-plct-xthead-elf-bin", ...]
```

### 4. 搜索和列出包

GET /packages

列出所有包，支持关键词搜索和分类过滤。

查询参数：
- q: 关键词，在包名或描述中搜索
- kind: 分类过滤

请求示例：
```bash
# 列出所有包
curl http://127.0.0.1:8000/packages

# 关键词搜索
curl "http://127.0.0.1:8000/packages?q=toolchain"

# 分类过滤
curl "http://127.0.0.1:8000/packages?kind=toolchain"

# 组合查询
curl "http://127.0.0.1:8000/packages?q=milkv&kind=toolchain"
```

响应：
```json
[
  {
    "id": "toolchain/gnu-milkv-milkv-duo-elf-bin/0.20240731.0+git.67688c7335e7",
    "kind": "toolchain",
    "name": "gnu-milkv-milkv-duo-elf-bin",
    "version": "0.20240731.0+git.67688c7335e7",
    "desc": "GNU toolchain for Milk-V Duo",
    "vendor": {...},
    "distfiles": [...]
  }
]
```

### 5. 查看包的所有版本

GET /packages/{kind}/{name}

返回指定包的所有版本列表。

路径参数：
- kind: 包的分类
- name: 包的名称

请求示例：
```bash
curl http://127.0.0.1:8000/packages/toolchain/gnu-milkv-milkv-duo-elf-bin
```

响应：
```json
[
  {
    "id": "toolchain/gnu-milkv-milkv-duo-elf-bin/0.20240731.0+git.67688c7335e7",
    "version": "0.20240731.0+git.67688c7335e7",
    "desc": "GNU toolchain for Milk-V Duo",
    "vendor": {...}
  }
]
```

### 6. 获取包的完整信息

GET /packages/{kind}/{name}/{version}

返回指定包的指定版本的完整 manifest 信息。

路径参数：
- kind: 包的分类
- name: 包的名称
- version: 包的版本号

请求示例：
```bash
curl http://127.0.0.1:8000/packages/toolchain/gnu-milkv-milkv-duo-elf-bin/0.20240731.0+git.67688c7335e7
```

响应：
```json
{
  "id": "toolchain/gnu-milkv-milkv-duo-elf-bin/0.20240731.0+git.67688c7335e7",
  "kind": "toolchain",
  "name": "gnu-milkv-milkv-duo-elf-bin",
  "version": "0.20240731.0+git.67688c7335e7",
  "desc": "GNU toolchain for Milk-V Duo",
  "vendor": {...},
  "distfiles": [
    {
      "name": "toolchain.tar.gz",
      "url": "https://...",
      "size": 12345678,
      "checksums": {
        "sha256": "...",
        "sha512": "..."
      }
    }
  ],
  "binary": [...],
  "toolchain": {...},
  "emulator": {...}
}
```

截图位置 6：Swagger UI 文档页面（http://127.0.0.1:8000/docs）

截图位置 7：在 Swagger UI 中测试接口的请求和响应

---

## 使用示例

### 示例 1：浏览工具链包

```bash
# 查看所有分类
curl http://127.0.0.1:8000/kinds

# 查看 toolchain 分类下的包
curl http://127.0.0.1:8000/kinds/toolchain/packages

# 查看包的详细信息
curl http://127.0.0.1:8000/packages/toolchain/gnu-milkv-milkv-duo-elf-bin/0.20240731.0+git.67688c7335e7
```

### 示例 2：搜索包

```bash
# 搜索包含 "milkv" 的包
curl "http://127.0.0.1:8000/packages?q=milkv"

# 搜索 toolchain 分类中包含 "gnu" 的包
curl "http://127.0.0.1:8000/packages?q=gnu&kind=toolchain"
```

### 示例 3：Python 调用

```python
import requests

base_url = "http://127.0.0.1:8000"

# 获取所有分类
response = requests.get(f"{base_url}/kinds")
kinds = response.json()
print("所有分类:", kinds)

# 搜索包
response = requests.get(f"{base_url}/packages", params={"q": "toolchain"})
packages = response.json()
print(f"找到 {len(packages)} 个相关包")

# 获取包的详细信息
if packages:
    package_id = packages[0]["id"]
    kind, name, version = package_id.split("/")
    response = requests.get(f"{base_url}/packages/{kind}/{name}/{version}")
    manifest = response.json()
    print("包详细信息:", manifest)
```

截图位置 8：使用 curl 或 Python 调用 API 的终端输出

---

## 架构设计

### 系统架构

```
客户端
  │
  │ HTTP Request
  ▼
FastAPI 应用层
  │
  │ API 路由处理
  │ - /health
  │ - /kinds
  │ - /packages
  │
  │ PackagesIndex 类
  │ - 缓存管理 (10分钟TTL)
  │ - 数据加载逻辑
  │
  │
  ▼
GitHub API
  - Tarball 下载
  - TOML 解析
```

### 数据流程

1. 客户端请求 → FastAPI 接收 HTTP 请求
2. 路由匹配 → 路由到对应的处理函数
3. 缓存检查 → 检查内存缓存是否有效（10 分钟 TTL）
4. 数据加载 → 缓存失效时从 GitHub 下载 tarball 并解析
5. 数据处理 → 根据请求参数进行搜索、过滤
6. 响应返回 → 返回 JSON 格式的响应数据

### 核心组件

PackagesIndex 类：
- 缓存机制：内存缓存，10 分钟有效期
- 数据源：GitHub tarball API
- 数据格式：TOML 文件解析为结构化数据
- 并发控制：使用 asyncio.Lock 确保线程安全

截图位置 9：代码架构图或代码结构视图

---

## 注意事项

### GitHub API 限流

未设置 GITHUB_TOKEN 时，GitHub 对匿名请求有频率限制。

解决方案：
1. 设置 GITHUB_TOKEN 环境变量
2. 获取 Token：GitHub Settings → Developer settings → Personal access tokens → Generate new token

设置方法：
```bash
# Linux/macOS
export GITHUB_TOKEN=your_token_here

# Windows PowerShell
$env:GITHUB_TOKEN="your_token_here"
```

### 缓存策略

- 默认缓存时间为 10 分钟
- 缓存存储在内存中，服务重启后需要重新加载
- 如需立即获取最新数据，重启服务即可

### 错误处理

- GitHub API 返回错误时，服务返回 502 状态码
- 详细错误信息包含在响应中

截图位置 10：接口返回的完整 JSON 数据

截图位置 11：设置 GITHUB_TOKEN 后服务启动的提示信息

截图位置 12：GitHub 仓库页面（如果已发布）

---

## 参考资源

- FastAPI 官方文档：https://fastapi.tiangolo.com/
- GitHub API 文档：https://docs.github.com/en/rest
- packages-index 仓库：https://github.com/ruyisdk/packages-index
