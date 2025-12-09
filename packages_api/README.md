# Packages Index API

基于 FastAPI 的 REST 服务，实时从 `ruyisdk/packages-index` 拉取数据，支持：
- 关键词模糊搜索（名称/描述）
- 按分类（kind）浏览并列出包
- 查看包的所有版本
- 查看指定版本的完整 manifest

返回字段覆盖常见需求：
1. 元数据：描述、供应商（metadata.desc / metadata.vendor）
2. 分发文件：文件名、大小、下载链接、限制规则（distfiles / restrict）
3. 校验和：sha256、sha512（distfiles.checksums）
4. 二进制信息：运行主机架构、关联的分发文件（binary.host / distfiles）
5. 工具链信息：目标架构、扩展、组件（toolchain.target / flavors / components）

## API 列表
- `GET /health`：健康检查
- `GET /kinds`：列出所有分类（例如 analyzer、board-image、toolchain…）
- `GET /kinds/{kind}/packages`：查看某分类下的全部包名
- `GET /packages`：列出包；可选参数：
  - `q`：关键词模糊匹配名称或描述
  - `kind`：按分类过滤
- `GET /packages/{kind}/{name}`：查看该包的所有版本
- `GET /packages/{kind}/{name}/{version}`：查看指定版本，返回解析后的字段

## 快速运行

### Linux/macOS
```bash
cd packages_api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 可选：避免 GitHub 匿名限流
export GITHUB_TOKEN=your_token

# 在仓库根目录启动（从 packages_api 的父目录）
cd ..
python -m uvicorn packages_api.app:app --reload --port 8000
```

### Windows
```powershell
cd packages_api
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# 可选：避免 GitHub 匿名限流
$env:GITHUB_TOKEN="your_token"

# 在仓库根目录启动（从 packages_api 的父目录）
cd ..
python -m uvicorn packages_api.app:app --reload --port 8000
```

打开 `http://127.0.0.1:8000/docs` 使用 Swagger UI；或直接调用：
```bash
# 列分类
curl http://127.0.0.1:8000/kinds
# 某分类下的包
curl http://127.0.0.1:8000/kinds/toolchain/packages
# 模糊搜索
curl "http://127.0.0.1:8000/packages?q=toolchain"
# 某包版本列表
curl http://127.0.0.1:8000/packages/toolchain/gnu-milkv-milkv-duo-elf-bin
# 某版本 manifest
curl http://127.0.0.1:8000/packages/toolchain/gnu-milkv-milkv-duo-elf-bin/0.20240731.0+git.67688c7335e7
```

## 说明
- **数据源**：GitHub 公共仓库 `ruyisdk/packages-index`（使用 tarball API 一次性下载，速度快）
- **缓存**：默认内存缓存 10 分钟
- **频率限制**：若出现 GitHub rate limit，设置 `GITHUB_TOKEN` 后重启服务即可
- **跨平台**：代码使用 `pathlib` 和标准库，Windows/Linux/macOS 均可运行
