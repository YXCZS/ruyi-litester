"""
Simple REST API to browse ruyisdk/packages-index.

What it does
- 列分类 /kinds
- 按分类列包 /kinds/{kind}/packages
- 模糊搜索/按分类列包 /packages?q=xxx&kind=toolchain
- 看包的版本 /packages/{kind}/{name}
- 看某版本 manifest（含 raw TOML） /packages/{kind}/{name}/{version}

Anti-rate-limit
- 读取环境变量 GITHUB_TOKEN，自动带上 Authorization: token <PAT>
- 若未设置或 token 无效，命中限流会返回 502 并提示
"""

from __future__ import annotations

import asyncio
import os
import time
import tempfile
import tarfile
from dataclasses import dataclass
import json
from pathlib import Path as PathLib
from typing import Dict, List, Optional

import httpx
from fastapi import FastAPI, HTTPException, Query, Path
from fastapi.responses import JSONResponse, Response

try:  # Python 3.11+
    import tomllib  # type: ignore
except ModuleNotFoundError:  # pragma: no cover
    import tomli as tomllib  # type: ignore


GITHUB_API_BASE = "https://api.github.com/repos/ruyisdk/packages-index/contents"
GITHUB_RAW_BASE = "https://raw.githubusercontent.com/ruyisdk/packages-index/main"
GITHUB_TARBALL_URL = "https://api.github.com/repos/ruyisdk/packages-index/tarball/main"

CACHE_TTL_SECONDS = 600  # 10 minutes


@dataclass
class PackageManifest:
    kind: str
    name: str
    version: str
    path: str  # path under repo, e.g. manifests/analyzer/foo/1.0.toml
    metadata: Dict
    distfiles: List[Dict]
    distfiles_checksums: List[Dict]
    binary: List[Dict]
    toolchain: Dict
    emulator: Dict
    raw_toml: str

    @property
    def id(self) -> str:
        return f"{self.kind}/{self.name}/{self.version}"


class PackagesIndex:
    def __init__(self) -> None:
        self._cache_ts: float = 0
        self._cache: List[PackageManifest] = []
        self._lock = asyncio.Lock()

    async def get_all(self) -> List[PackageManifest]:
        async with self._lock:
            if time.time() - self._cache_ts < CACHE_TTL_SECONDS and self._cache:
                return self._cache
            self._cache = await self._load_from_github()
            self._cache_ts = time.time()
            return self._cache

    async def _make_client(self) -> httpx.AsyncClient:
        headers = {"User-Agent": "packages-index-api"}
        token = os.getenv("GITHUB_TOKEN")
        if token:
            headers["Authorization"] = f"token {token}"
        return httpx.AsyncClient(timeout=15.0, headers=headers)

    async def _load_from_github(self) -> List[PackageManifest]:
        """使用 tarball API 一次性下载整个仓库，比逐个文件请求快得多"""
        manifests: List[PackageManifest] = []
        
        async with await self._make_client() as client:
            # 下载 tarball
            resp = await client.get(GITHUB_TARBALL_URL, follow_redirects=True)
            if resp.status_code == 403 and "rate limit" in resp.text.lower():
                raise HTTPException(
                    status_code=502,
                    detail="GitHub API rate limit. 请设置 GITHUB_TOKEN 后重启服务。",
                )
            if resp.status_code != 200:
                raise HTTPException(
                    status_code=502,
                    detail=f"GitHub tarball fetch error: {resp.status_code} {resp.text[:200]}",
                )
            
            # 保存到临时文件并解压
            with tempfile.NamedTemporaryFile(delete=False, suffix=".tar.gz") as tmp_file:
                tmp_file.write(resp.content)
                tmp_path = tmp_file.name
            
            try:
                # 解压到临时目录
                with tempfile.TemporaryDirectory() as tmp_dir:
                    with tarfile.open(tmp_path, "r:gz") as tar:
                        # 解压所有文件
                        tar.extractall(tmp_dir)
                        
                        # 找到解压后的根目录（通常是 packages-index-<hash>）
                        extracted_root = None
                        for item in PathLib(tmp_dir).iterdir():
                            if item.is_dir() and "packages-index" in item.name:
                                extracted_root = item
                                break
                        
                        if not extracted_root:
                            raise HTTPException(
                                status_code=500,
                                detail="无法找到解压后的仓库根目录",
                            )
                        
                        # 遍历 manifests 目录
                        manifests_dir = extracted_root / "manifests"
                        if not manifests_dir.exists():
                            raise HTTPException(
                                status_code=500,
                                detail="仓库中未找到 manifests 目录",
                            )
                        
                        # 读取所有 TOML 文件
                        for kind_dir in manifests_dir.iterdir():
                            if not kind_dir.is_dir():
                                continue
                            kind = kind_dir.name
                            
                            for pkg_dir in kind_dir.iterdir():
                                if not pkg_dir.is_dir():
                                    continue
                                pkg_name = pkg_dir.name
                                
                                for toml_file in pkg_dir.glob("*.toml"):
                                    version = toml_file.stem
                                    try:
                                        raw_toml = toml_file.read_text(encoding="utf-8")
                                        data = tomllib.loads(raw_toml)
                                        manifests.append(
                                            PackageManifest(
                                                kind=kind,
                                                name=pkg_name,
                                                version=version,
                                                path=f"manifests/{kind}/{pkg_name}/{toml_file.name}",
                                                metadata=data.get("metadata", {}),
                                                distfiles=data.get("distfiles", []),
                                                distfiles_checksums=data.get("distfiles.checksums", []),
                                                binary=data.get("binary", []),
                                                toolchain=data.get("toolchain", {}),
                                                emulator=data.get("emulator", {}),
                                                raw_toml=raw_toml,
                                            )
                                        )
                                    except Exception as e:
                                        # 跳过无法解析的文件
                                        print(f"警告: 无法解析 {toml_file}: {e}")
                                        continue
            finally:
                # 清理临时文件
                try:
                    os.unlink(tmp_path)
                except:
                    pass
        
        return manifests

    async def _list_dir(self, client: httpx.AsyncClient, path: str) -> List[Dict]:
        url = f"{GITHUB_API_BASE}/{path}"
        resp = await client.get(url)
        if resp.status_code == 403 and "rate limit" in resp.text.lower():
            raise HTTPException(
                status_code=502,
                detail="GitHub API rate limit. 请设置 GITHUB_TOKEN 后重启服务。",
            )
        if resp.status_code != 200:
            raise HTTPException(status_code=502, detail=f"GitHub API error: {resp.text}")
        return resp.json()

    async def _fetch_raw(self, client: httpx.AsyncClient, path: str) -> str:
        url = f"{GITHUB_RAW_BASE}/{path}"
        resp = await client.get(url)
        if resp.status_code == 403 and "rate limit" in resp.text.lower():
            raise HTTPException(
                status_code=502,
                detail="GitHub raw rate limit. 请设置 GITHUB_TOKEN 后重启服务。",
            )
        if resp.status_code != 200:
            raise HTTPException(status_code=502, detail=f"GitHub raw fetch error: {resp.text}")
        return resp.text


index = PackagesIndex()
app = FastAPI(title="Packages Index API", version="0.1.0")


def _json_response(payload, pretty: bool = True, status_code: int = 200) -> Response:
    if not pretty:
        return JSONResponse(payload, status_code=status_code)
    body = json.dumps(payload, ensure_ascii=False, indent=2)
    return Response(content=body, media_type="application/json", status_code=status_code)


@app.get("/health", description="健康检查接口，用于检查服务是否正常运行")
async def health() -> dict:
    return {"status": "ok"}


@app.get("/kinds", description="列出所有可用的包分类。返回所有不同的包分类列表，例如 toolchain、analyzer、board-image 等。")
async def list_kinds() -> JSONResponse:
    manifests = await index.get_all()
    kinds = sorted({m.kind for m in manifests})
    return _json_response(kinds)


@app.get("/kinds/{kind}/packages", description="查看指定分类下的所有包名。返回该分类下所有包的名称列表。")
async def list_packages_by_kind(
    kind: str = Path(..., description="包的分类，例如 toolchain、analyzer 等"),
) -> JSONResponse:
    manifests = await index.get_all()
    packages = sorted({m.name for m in manifests if m.kind == kind})
    if not packages:
        raise HTTPException(status_code=404, detail="Kind not found or no packages")
    return _json_response(packages)


@app.get("/packages", description="列出所有包，支持关键词搜索和按分类过滤。可以搜索包名或描述中包含指定关键词的包，也可以按分类（如 toolchain、analyzer 等）进行过滤。")
async def list_packages(
    q: Optional[str] = Query(default=None, description="关键词：在包名或描述中搜索包含此关键词的包"),
    kind: Optional[str] = Query(default=None, description="分类过滤：按包的分类进行过滤，例如 toolchain、analyzer、board-image 等"),
) -> JSONResponse:
    manifests = await index.get_all()
    results = []
    for m in manifests:
        if kind and m.kind != kind:
            continue
        if q:
            needle = q.lower()
            if needle not in m.name.lower() and needle not in m.metadata.get("desc", "").lower():
                continue
        results.append(
            {
                "id": m.id,
                "kind": m.kind,
                "name": m.name,
                "version": m.version,
                "desc": m.metadata.get("desc", ""),
                "vendor": m.metadata.get("vendor", {}),
                "distfiles": m.distfiles,
            }
        )
    return _json_response(results)


@app.get("/packages/{kind}/{name}", description="查看指定包的所有可用版本。返回该包的所有版本列表，包括版本号、描述和供应商信息。")
async def list_versions(
    kind: str = Path(..., description="包的分类，例如 toolchain、analyzer 等"),
    name: str = Path(..., description="包的名称"),
) -> JSONResponse:
    manifests = await index.get_all()
    versions = [
        {
            "id": m.id,
            "version": m.version,
            "desc": m.metadata.get("desc", ""),
            "vendor": m.metadata.get("vendor", {}),
        }
        for m in manifests
        if m.kind == kind and m.name == name
    ]
    if not versions:
        raise HTTPException(status_code=404, detail="Package not found")
    versions.sort(key=lambda x: x["version"])
    return _json_response(versions)


def _summarize_manifest(m: PackageManifest) -> Dict:
    """Pick commonly-used fields from a manifest."""
    meta = m.metadata or {}
    distfiles = m.distfiles or []
    # distfiles.checksums may appear as a sibling list; merge by name if needed
    distfile_checksums: Dict[str, Dict] = {}
    for chk in m.distfiles_checksums or []:
        distfile_checksums[chk.get("name", "")] = chk

    def attach_checksum(df: Dict) -> Dict:
        name = df.get("name", "")
        extra = distfile_checksums.get(name, {})
        merged = {**df}
        # some manifests already carry checksums inline; only enrich when missing
        if extra and "checksums" not in merged:
            merged["checksums"] = {k: v for k, v in extra.items() if k.startswith("sha")}
        return merged

    binaries = m.binary or []
    toolchain = m.toolchain or {}
    emulator = m.emulator or {}

    return {
        "id": m.id,
        "kind": m.kind,
        "name": m.name,
        "version": m.version,
        "desc": meta.get("desc", ""),
        "vendor": meta.get("vendor", {}),
        "distfiles": [attach_checksum(df) for df in distfiles],
        "binary": binaries,
        "toolchain": toolchain,
        "emulator": emulator,
    }


@app.get("/packages/{kind}/{name}/{version}", description="获取指定包的指定版本的完整 manifest 信息。包括元数据、分发文件、校验和、二进制信息、工具链信息等所有详细信息。")
async def get_manifest(
    kind: str = Path(..., description="包的分类，例如 toolchain、analyzer 等"),
    name: str = Path(..., description="包的名称"),
    version: str = Path(..., description="包的版本号"),
) -> JSONResponse:
    manifests = await index.get_all()
    for m in manifests:
        if m.kind == kind and m.name == name and m.version == version:
            return _json_response(_summarize_manifest(m))
    raise HTTPException(status_code=404, detail="Manifest not found")


if __name__ == "__main__":  # pragma: no cover
    import uvicorn

    uvicorn.run("packages_api.app:app", host="0.0.0.0", port=8000, reload=True)

