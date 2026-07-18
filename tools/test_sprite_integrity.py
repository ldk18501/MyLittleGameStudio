#!/usr/bin/env python3
"""MLGS Sprite 完整性门禁。只验证结构完整性，不代替美术总监的游戏内验收。"""

from __future__ import annotations

import argparse
import json
import sys
from collections import deque
from datetime import datetime, timezone
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:
    raise SystemExit("缺少 Pillow。请先安装：python -m pip install Pillow") from exc


STATUS_ORDER = ["planned", "prompt-ready", "generated", "selected", "processed", "imported", "referenced", "approved"]
RASTER_SUFFIXES = {".png", ".webp", ".tga"}


def resolve_project_path(root: Path, relative: str) -> Path:
    candidate = (root / relative).resolve() if not Path(relative).is_absolute() else Path(relative).resolve()
    try:
        candidate.relative_to(root.resolve())
    except ValueError as exc:
        raise ValueError(f"路径越出项目目录：{relative}") from exc
    return candidate


def alpha_bounds(alpha: Image.Image, threshold: int) -> tuple[int, int, int, int] | None:
    mask = alpha.point(lambda value: 255 if value > threshold else 0)
    return mask.getbbox()


def significant_component_count(alpha: Image.Image, threshold: int, ratio: float) -> tuple[int, list[int]]:
    width, height = alpha.size
    pixels = alpha.tobytes()
    foreground = bytearray(1 if value > threshold else 0 for value in pixels)
    occupied = sum(foreground)
    if occupied == 0:
        return 0, []
    minimum_area = max(16, int(occupied * ratio))
    areas: list[int] = []
    for start in range(width * height):
        if foreground[start] == 0:
            continue
        foreground[start] = 0
        queue = deque([start])
        area = 0
        while queue:
            index = queue.popleft()
            area += 1
            x = index % width
            y = index // width
            for neighbour in (index - 1, index + 1, index - width, index + width):
                if neighbour < 0 or neighbour >= width * height:
                    continue
                nx = neighbour % width
                ny = neighbour // width
                if abs(nx - x) + abs(ny - y) != 1 or foreground[neighbour] == 0:
                    continue
                foreground[neighbour] = 0
                queue.append(neighbour)
        if area >= minimum_area:
            areas.append(area)
    areas.sort(reverse=True)
    return len(areas), areas


def inspect_asset(project_root: Path, asset: dict, alpha_threshold: int, component_ratio: float) -> dict:
    asset_id = str(asset.get("id", "<missing-id>"))
    findings: list[str] = []
    output_path = str(asset.get("outputPath", ""))
    integrity = asset.get("integrity")
    if not isinstance(integrity, dict):
        return {"assetId": asset_id, "verdict": "fail", "findings": ["缺少 integrity 合同。"]}

    source_layout = str(integrity.get("sourceLayout", ""))
    extraction_mode = str(integrity.get("extractionMode", ""))
    if extraction_mode == "fixed-grid" and source_layout != "registered-sheet":
        findings.append("fixed-grid 只能用于已注册且验证过分隔线/留白的 registered-sheet。")
    if source_layout == "unverified-sheet":
        findings.append("未验证拼版不能进入正式资源处理。")

    try:
        path = resolve_project_path(project_root, output_path)
    except ValueError as exc:
        return {"assetId": asset_id, "verdict": "fail", "findings": [str(exc)]}
    if not path.exists():
        return {"assetId": asset_id, "verdict": "fail", "findings": [f"输出文件不存在：{output_path}"]}

    try:
        image = Image.open(path).convert("RGBA")
    except Exception as exc:  # Pillow 提供具体格式错误
        return {"assetId": asset_id, "verdict": "fail", "findings": [f"无法读取图片：{exc}"]}

    alpha = image.getchannel("A")
    bounds = alpha_bounds(alpha, alpha_threshold)
    if bounds is None:
        findings.append("图片没有有效前景像素。")
        margins = None
    else:
        left, top, right, bottom = bounds
        margins = {"left": left, "top": top, "right": image.width - right, "bottom": image.height - bottom}
        minimum_margin = int(integrity.get("minimumTransparentMargin", 0))
        if min(margins.values()) < minimum_margin:
            findings.append(f"透明安全边距不足：要求 >= {minimum_margin}px，实际 {margins}。")

    expected_frames = max(1, int(integrity.get("expectedFrames", 1)))
    maximum_components = max(1, int(integrity.get("maxSignificantComponents", 1)))
    frame_results: list[dict] = []
    if expected_frames > 1:
        if image.width % expected_frames != 0:
            findings.append(f"宽度 {image.width} 不能整除预期帧数 {expected_frames}。")
        else:
            frame_width = image.width // expected_frames
            frame_margin = int(integrity.get("minimumFrameMargin", 1))
            for frame_index in range(expected_frames):
                frame_alpha = alpha.crop((frame_index * frame_width, 0, (frame_index + 1) * frame_width, image.height))
                frame_bounds = alpha_bounds(frame_alpha, alpha_threshold)
                if frame_bounds is None:
                    findings.append(f"第 {frame_index + 1} 帧为空。")
                    frame_results.append({"index": frame_index, "bounds": None})
                    continue
                fl, ft, fr, fb = frame_bounds
                frame_margins = {"left": fl, "top": ft, "right": frame_width - fr, "bottom": image.height - fb}
                if min(frame_margins.values()) < frame_margin:
                    findings.append(f"第 {frame_index + 1} 帧安全边距不足：要求 >= {frame_margin}px，实际 {frame_margins}。")
                frame_component_count, frame_component_areas = significant_component_count(frame_alpha, alpha_threshold, component_ratio)
                if frame_component_count > maximum_components:
                    findings.append(f"第 {frame_index + 1} 帧检测到 {frame_component_count} 个显著连通对象，合同最多允许 {maximum_components} 个。")
                frame_results.append({
                    "index": frame_index,
                    "bounds": list(frame_bounds),
                    "margins": frame_margins,
                    "significantComponents": frame_component_count,
                    "componentAreas": frame_component_areas,
                })

    component_count = 0
    component_areas: list[int] = []
    if expected_frames == 1:
        component_count, component_areas = significant_component_count(alpha, alpha_threshold, component_ratio)
        if component_count > maximum_components:
            findings.append(f"检测到 {component_count} 个显著连通对象，合同最多允许 {maximum_components} 个；可能混入相邻角色、建筑或道具。")

    return {
        "assetId": asset_id,
        "outputPath": output_path,
        "size": [image.width, image.height],
        "bounds": list(bounds) if bounds else None,
        "margins": margins,
        "significantComponents": component_count,
        "componentAreas": component_areas,
        "expectedFrames": expected_frames,
        "frames": frame_results,
        "verdict": "pass" if not findings else "fail",
        "findings": findings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="验证 MLGS 正式 Sprite 的裁切、边距、异物和逐帧完整性。")
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--manifest", default="production/assets/asset-manifest.json")
    parser.add_argument("--report", default="production/qa/evidence/sprite-integrity.json")
    parser.add_argument("--alpha-threshold", type=int, default=8)
    parser.add_argument("--component-ratio", type=float, default=0.003)
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()
    manifest_path = resolve_project_path(project_root, args.manifest)
    report_path = resolve_project_path(project_root, args.report)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))

    results: list[dict] = []
    for asset in manifest.get("assets", []):
        status = str(asset.get("status", "planned"))
        output = str(asset.get("outputPath", ""))
        if Path(output).suffix.lower() not in RASTER_SUFFIXES:
            continue
        if status not in STATUS_ORDER or STATUS_ORDER.index(status) < STATUS_ORDER.index("processed"):
            continue
        results.append(inspect_asset(project_root, asset, args.alpha_threshold, args.component_ratio))

    failed = [item for item in results if item["verdict"] != "pass"]
    report = {
        "schemaVersion": "1.0",
        "generatedAt": datetime.now(timezone.utc).astimezone().isoformat(),
        "projectRoot": str(project_root),
        "manifestPath": args.manifest,
        "checkedAssets": len(results),
        "passedAssets": len(results) - len(failed),
        "failedAssets": len(failed),
        "verdict": "pass" if results and not failed else "fail",
        "scope": "仅验证结构完整性；不代替风格一致性、Unity 游戏内效果和 Art Director/QA 验收。",
        "assets": results,
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("checkedAssets", "passedAssets", "failedAssets", "verdict")}, ensure_ascii=False))
    return 0 if report["verdict"] == "pass" else 12


if __name__ == "__main__":
    sys.exit(main())
