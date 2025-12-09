#!/bin/bash
# Packages Index API 一键启动脚本 (Linux/macOS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================="
echo "Packages Index API 启动脚本"
echo "=========================================="

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到 python3，请先安装 Python 3.8+"
    exit 1
fi

# 创建虚拟环境（如果不存在）
if [ ! -d "$VENV_DIR" ]; then
    echo "创建虚拟环境..."
    python3 -m venv "$VENV_DIR"
fi

# 激活虚拟环境
echo "激活虚拟环境..."
source "$VENV_DIR/bin/activate"

# 升级 pip
echo "升级 pip..."
pip install --upgrade pip -q

# 安装依赖
echo "安装依赖..."
pip install -r "$SCRIPT_DIR/requirements.txt" -q

# 检查 GITHUB_TOKEN
if [ -z "$GITHUB_TOKEN" ]; then
    echo ""
    echo "提示: 未设置 GITHUB_TOKEN，可能会遇到 GitHub API 限流"
    echo "      如需设置，请运行: export GITHUB_TOKEN=your_token"
    echo ""
else
    echo "已检测到 GITHUB_TOKEN"
fi

# 启动服务
echo ""
echo "启动服务..."
echo "访问地址: http://127.0.0.1:8000"
echo "API 文档: http://127.0.0.1:8000/docs"
echo ""
echo "按 Ctrl+C 停止服务"
echo "=========================================="
echo ""

cd "$REPO_ROOT"
python -m uvicorn packages_api.app:app --host 0.0.0.0 --port 8000

