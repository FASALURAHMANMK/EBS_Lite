#!/usr/bin/env python3
"""
API parity checker between:
  - Flutter app usage (Dio calls in `flutter_app/lib`)
  - Backend OpenAPI spec (`go_backend_rmt/openapi.yaml`)

This is intentionally heuristic (regex-based) but very helpful for catching:
  - Flutter calling endpoints not present in OpenAPI
  - OpenAPI endpoints not used by Flutter (potentially unimplemented UI)
  - Method mismatches (e.g., Flutter uses PUT but OpenAPI only has GET)
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

import yaml


@dataclass(frozen=True)
class FlutterCall:
    method: str
    path: str
    file: str


_DIO_CALL_RE = re.compile(
    # Heuristic: treat any identifier that ends with "dio" (case-sensitive),
    # plus the common `_dio`/`dio` names, as a Dio instance.
    #
    # This catches patterns like:
    #   _dio.get('/customers')
    #   dio.post("/auth/login", ...)
    #   refreshDio.post(
    #       '/auth/refresh-token',
    #       data: {...},
    #   )
    #
    # Note: This is intentionally regex-based and may have false positives if
    # another object uses `.get/.post` with a literal path. The "endswith dio"
    # filter keeps the noise low in this repo.
    r"\b([A-Za-z_][A-Za-z0-9_]*(?:Dio|dio)|_dio|dio)\.(get|post|put|delete|patch)\(\s*['\"]([^'\"]+)['\"]",
    re.MULTILINE,
)

_FILE_TRANSFER_DOWNLOAD_RE = re.compile(
    r"\bFileTransfer\.downloadBytes\(\s*[^,]+,\s*'([^']+)'",
    re.MULTILINE,
)

_NAMED_ENDPOINT_LITERAL_RE = re.compile(
    # Catch helper patterns like:
    #   _downloadAndShare(endpoint: '/customers/export', ...)
    #   someFn(endpoint: "/inventory/import-template")
    r"\bendpoint\s*:\s*['\"]([^'\"]+)['\"]",
    re.MULTILINE,
)


def _norm_path_param_syntax(path: str) -> str:
    # Normalize both OpenAPI `{id}` and Dart `$id` / `${id}` to a common token.
    path = re.sub(r"\$\{[^}]+\}", "{}", path)
    # If earlier transforms produce an empty interpolation like `${}`, normalize it too.
    path = path.replace("${}", "{}")
    path = re.sub(r"\{[^}]+\}", "{}", path)
    path = re.sub(r"\$[A-Za-z_][A-Za-z0-9_]*", "{}", path)
    return path


def _norm_flutter_path(path: str) -> str:
    # Flutter stores baseUrl as .../api/v1; call sites are typically '/customers'.
    # Still normalize any accidental '/api/v1' prefix to avoid false positives.
    path = re.sub(r"^/api/v\d+", "", path)
    return _norm_path_param_syntax(path)


def _norm_openapi_path(path: str) -> str:
    return _norm_path_param_syntax(path)


def read_flutter_calls(flutter_lib_dir: Path) -> list[FlutterCall]:
    calls: list[FlutterCall] = []
    for dart_file in flutter_lib_dir.rglob("*.dart"):
        text = dart_file.read_text(encoding="utf-8", errors="ignore")
        for m in _DIO_CALL_RE.finditer(text):
            method = m.group(2).upper()
            raw_path = m.group(3)
            calls.append(
                FlutterCall(
                    method=method,
                    path=_norm_flutter_path(raw_path),
                    file=str(dart_file.as_posix()),
                )
            )
        # Also detect endpoints called via shared download helper (exports).
        for m in _FILE_TRANSFER_DOWNLOAD_RE.finditer(text):
            raw_path = m.group(1)
            calls.append(
                FlutterCall(
                    method="GET",
                    path=_norm_flutter_path(raw_path),
                    file=str(dart_file.as_posix()),
                )
            )
        # Also detect literal endpoints passed into helper methods.
        for m in _NAMED_ENDPOINT_LITERAL_RE.finditer(text):
            raw_path = m.group(1)
            calls.append(
                FlutterCall(
                    method="GET",
                    path=_norm_flutter_path(raw_path),
                    file=str(dart_file.as_posix()),
                )
            )
    return calls


def read_openapi(openapi_yaml: Path) -> dict[str, set[str]]:
    doc = yaml.safe_load(openapi_yaml.read_text(encoding="utf-8"))
    paths: dict[str, set[str]] = {}
    for raw_path, ops in (doc.get("paths") or {}).items():
        norm_path = _norm_openapi_path(raw_path)
        methods = {m.upper() for m in (ops or {}).keys() if m.lower() in {"get", "post", "put", "delete", "patch"}}
        paths[norm_path] = methods
    return paths


def build_report(calls: list[FlutterCall], openapi: dict[str, set[str]]) -> str:
    flutter_methods_by_path: dict[str, set[str]] = {}
    for c in calls:
        flutter_methods_by_path.setdefault(c.path, set()).add(c.method)

    flutter_paths = set(flutter_methods_by_path.keys())
    openapi_paths = set(openapi.keys())

    missing_paths = sorted(flutter_paths - openapi_paths)
    unused_paths = sorted(openapi_paths - flutter_paths)

    method_mismatches: list[str] = []
    for path in sorted(flutter_paths & openapi_paths):
        flutter_methods = flutter_methods_by_path.get(path, set())
        openapi_methods = openapi.get(path, set())
        missing_methods = sorted(flutter_methods - openapi_methods)
        if missing_methods:
            method_mismatches.append(f"- `{path}` missing methods in OpenAPI: {', '.join(missing_methods)}")

    lines: list[str] = []
    lines.append("# API Parity Report (Flutter <-> OpenAPI)")
    lines.append("")
    lines.append(f"- Flutter unique paths: **{len(flutter_paths)}**")
    lines.append(f"- OpenAPI unique paths: **{len(openapi_paths)}**")
    lines.append("")

    lines.append("## Flutter paths missing from OpenAPI")
    if not missing_paths:
        lines.append("- None")
    else:
        for p in missing_paths:
            lines.append(f"- `{p}`")
    lines.append("")

    lines.append("## Method mismatches (Flutter uses method not in OpenAPI)")
    if not method_mismatches:
        lines.append("- None")
    else:
        lines.extend(method_mismatches)
    lines.append("")

    lines.append("## OpenAPI paths unused by Flutter")
    lines.append("(Often means the UI is still a placeholder, or endpoints can be removed if truly not needed.)")
    if not unused_paths:
        lines.append("- None")
    else:
        for p in unused_paths:
            lines.append(f"- `{p}`")
    lines.append("")

    # Provide a quick "where used" index for missing paths
    if missing_paths:
        lines.append("## Where Flutter calls missing paths")
        by_path: dict[str, list[FlutterCall]] = {}
        for c in calls:
            if c.path in missing_paths:
                by_path.setdefault(c.path, []).append(c)
        for p in missing_paths:
            lines.append(f"### `{p}`")
            for c in sorted(by_path.get(p, []), key=lambda x: (x.method, x.file)):
                lines.append(f"- {c.method} `{c.file}`")
            lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--flutter-lib", default="flutter_app/lib", help="Path to Flutter lib directory")
    ap.add_argument("--openapi", default="go_backend_rmt/openapi.yaml", help="Path to backend OpenAPI yaml")
    ap.add_argument("--out", default="", help="Write report markdown to this path")
    args = ap.parse_args()

    flutter_lib = Path(args.flutter_lib)
    openapi_yaml = Path(args.openapi)

    calls = read_flutter_calls(flutter_lib)
    openapi = read_openapi(openapi_yaml)
    report = build_report(calls, openapi)

    print(report)
    if args.out:
        Path(args.out).write_text(report, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
