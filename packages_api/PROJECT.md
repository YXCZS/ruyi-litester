## Packages Index API 后端说明

本工程基于 FastAPI 提供对 `ruyisdk/packages-index` 的 REST 查询服务，启动后实时从 GitHub 拉取 manifest，并做 10 分钟内存缓存，支持按分类浏览、关键词搜索、版本查看以及直接返回原始 TOML。

### 目录
- `packages_api/app.py`：核心实现（httpx 拉取 + TOML 解析 + 缓存 + 5 个 API）
- `packages_api/requirements.txt`：依赖声明
- `docs/architecture.svg`：数据流与组件示意图
- `packages_api/README.md`：快速启动与接口简述

### 运行
```bash
cd packages_api
python -m venv .venv
# Windows: .venv\Scripts\Activate.ps1
# Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt

# 可选：避免 GitHub 匿名限流
set GITHUB_TOKEN=your_token          # PowerShell/CMD
# export GITHUB_TOKEN=your_token     # bash/zsh

uvicorn packages_api.app:app --reload --port 8000
# 浏览 http://127.0.0.1:8000/docs 查看 Swagger
```

### API 速览
- `GET /health`：健康检查
- `GET /kinds`：列出分类
- `GET /kinds/{kind}/packages`：某分类下的包名
- `GET /packages`：模糊搜索（参数 `q`）与按 `kind` 过滤
- `GET /packages/{kind}/{name}`：列出该包的所有版本
- `GET /packages/{kind}/{name}/{version}`：返回解析字段与 `raw_toml`

> 返回字段涵盖常见需求（metadata.desc/vendor、distfiles + checksums、binary/toolchain 信息等），详见 `packages_api/app.py`。

### 架构与数据流
![Architecture](../docs/architecture.svg)

流程：客户端 → FastAPI 路由 → PackagesIndex loader（缓存） → GitHub `contents`/`raw` 接口 → 回写搜索/过滤后的 JSON 响应。

### 发布到个人 GitHub 公仓的步骤
1) 在 GitHub 创建公开仓库（示例名 `packages-index-api`）。  
2) 本地初始化：  
   ```bash
   git init
   git remote add origin git@github.com:<your-username>/packages-index-api.git
   git checkout -b main
   ```  
3) 将本目录内容提交：  
   ```bash
   git add packages_api docs README.md README_zh.md LICENSE
   git commit -m "Add packages-index FastAPI backend"
   git push -u origin main
   ```  
4) 在仓库页面开启 GitHub Pages（如需托管文档），或直接贴出 `packages_api/README.md`、`packages_api/PROJECT.md` 供使用者查看。  
5) 推荐在仓库 README 中附上运行命令与 Swagger 链接，提醒使用者配置 `GITHUB_TOKEN` 以避免限流。

### 后续可拓展点
- 增加本地持久缓存/Redis 缓存，降低 GitHub 请求量
- 增加 ETag/If-None-Match 支持，进一步节流
- 增加分页与排序（按时间或版本号）
- 添加单元测试（使用 httpx.MockTransport + 预置 TOML）

