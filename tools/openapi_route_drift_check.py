#!/usr/bin/env python3
"""
Backend (Gin routes) <-> OpenAPI drift check.

Inputs:
  - A route dump with lines: "METHOD /path"
  - go_backend_rmt/openapi.yaml

Output:
  - implemented routes missing from OpenAPI
  - OpenAPI routes missing from implementation

Notes:
  - OpenAPI 'servers' base URL is applied to all paths.
  - Per-path 'servers' override is supported (e.g. /health served at '/').
  - Gin params ':id' and OpenAPI params '{id}' are normalized to a common token.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

import yaml


@dataclass(frozen=True)
class Route:
    method: str
    path: str


_GIN_PARAM_RE = re.compile(r":[A-Za-z_][A-Za-z0-9_]*")
_OPENAPI_PARAM_RE = re.compile(r"\{[^}]+\}")
_MULTISLASH_RE = re.compile(r"/{2,}")


def _normalize_path(p: str) -> str:
    p = p.strip()
    if not p.startswith("/"):
        p = "/" + p
    p = _MULTISLASH_RE.sub("/", p)
    if len(p) > 1:
        p = p.rstrip("/")
    return p


def _normalize_params(p: str) -> str:
    p = _GIN_PARAM_RE.sub("{}", p)
    p = _OPENAPI_PARAM_RE.sub("{}", p)
    # gin wildcard params (e.g. /*filepath)
    p = re.sub(r"/\*[^/]+", "/{}", p)
    return p


def _server_base_to_path(url: str) -> str:
    url = (url or "").strip()
    if not url:
        return ""
    if "://" in url:
        return urlparse(url).path or ""
    return url


def _join_base_and_path(base: str, path: str) -> str:
    base = _server_base_to_path(base)
    if base in ("", "/"):
        return _normalize_path(path)
    return _normalize_path(base.rstrip("/") + "/" + path.lstrip("/"))


def read_route_dump(path: Path) -> set[Route]:
    routes: set[Route] = set()
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) != 2:
            continue
        method, p = parts[0].upper(), parts[1]
        if method not in {"GET", "POST", "PUT", "DELETE", "PATCH"}:
            continue
        routes.add(Route(method=method, path=_normalize_params(_normalize_path(p))))
    return routes


def dump_routes_via_go(repo_root: Path) -> str:
    cmd = [
        "go",
        "run",
        "./cmd/route_dump",
        "--in",
        "internal/routes/routes.go",
    ]
    proc = subprocess.run(
        cmd,
        cwd=str(repo_root / "go_backend_rmt"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"route dump failed: exit {proc.returncode}")
    return proc.stdout


def read_openapi_routes(openapi_yaml: Path) -> set[Route]:
    doc = yaml.safe_load(openapi_yaml.read_text(encoding="utf-8"))
    global_servers = doc.get("servers") or [{"url": ""}]
    paths = doc.get("paths") or {}

    routes: set[Route] = set()
    for raw_path, ops in paths.items():
        if not isinstance(ops, dict):
            continue

        servers = ops.get("servers") or global_servers
        server_urls = [s.get("url", "") for s in servers if isinstance(s, dict)]
        if not server_urls:
            server_urls = [""]

        for method, op in ops.items():
            if method.lower() not in {"get", "post", "put", "delete", "patch"}:
                continue
            for base in server_urls:
                full_path = _join_base_and_path(base, raw_path)
                routes.add(
                    Route(
                        method=method.upper(),
                        path=_normalize_params(full_path),
                    )
                )
    return routes


def format_routes(routes: set[Route]) -> list[str]:
    return [f"{r.method} {r.path}" for r in sorted(routes, key=lambda r: (r.path, r.method))]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--openapi", default="go_backend_rmt/openapi.yaml", help="Path to OpenAPI YAML")
    ap.add_argument(
        "--routes",
        default="",
        help="Path to route dump file. If omitted, runs the Go route dump command.",
    )
    ap.add_argument("--out", default="", help="Write report markdown to this path")
    args = ap.parse_args()

    repo_root = Path.cwd()
    openapi_yaml = Path(args.openapi)

    if args.routes:
        implemented_dump = Path(args.routes).read_text(encoding="utf-8", errors="ignore")
    else:
        implemented_dump = dump_routes_via_go(repo_root)

    tmp_routes = repo_root / ".tmp_implemented_routes.txt"
    tmp_routes.write_text(implemented_dump, encoding="utf-8")
    implemented = read_route_dump(tmp_routes)
    tmp_routes.unlink(missing_ok=True)

    openapi = read_openapi_routes(openapi_yaml)

    missing_in_openapi = implemented - openapi
    missing_in_impl = openapi - implemented

    lines: list[str] = []
    lines.append("# Backend <-> OpenAPI Route Drift Report")
    lines.append("")
    lines.append(f"- Implemented route+method pairs: **{len(implemented)}**")
    lines.append(f"- OpenAPI route+method pairs: **{len(openapi)}**")
    lines.append("")

    lines.append("## Implemented routes missing from OpenAPI")
    if not missing_in_openapi:
        lines.append("- None")
    else:
        for row in format_routes(missing_in_openapi):
            lines.append(f"- `{row}`")
    lines.append("")

    lines.append("## OpenAPI routes missing from implementation")
    if not missing_in_impl:
        lines.append("- None")
    else:
        for row in format_routes(missing_in_impl):
            lines.append(f"- `{row}`")
    lines.append("")

    report = "\n".join(lines).rstrip() + "\n"
    print(report)
    if args.out:
        Path(args.out).write_text(report, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
