#!/usr/bin/env python3
"""Split a registered MLGS art sheet into validated, transparent final assets."""

from __future__ import annotations

import argparse
import json
import math
from collections import deque
from datetime import datetime, timezone
from pathlib import Path

try:
    from PIL import Image, ImageFilter
except ImportError as exc:
    raise SystemExit("缺少 Pillow。请先安装：python -m pip install Pillow") from exc


def resolve_project_path(root: Path, relative: str) -> Path:
    candidate = (root / relative).resolve() if not Path(relative).is_absolute() else Path(relative).resolve()
    try:
        candidate.relative_to(root.resolve())
    except ValueError as exc:
        raise ValueError(f"路径越出项目目录：{relative}") from exc
    return candidate


def parse_hex_color(value: str) -> tuple[int, int, int]:
    text = value.lstrip("#")
    if len(text) != 6:
        raise ValueError(f"matteColor 必须是 #RRGGBB：{value}")
    return tuple(int(text[index : index + 2], 16) for index in (0, 2, 4))


def rectangles_overlap(left: list[int], right: list[int]) -> bool:
    lx, ly, lw, lh = left
    rx, ry, rw, rh = right
    return lx < rx + rw and lx + lw > rx and ly < ry + rh and ly + lh > ry


def remove_connected_matte(image: Image.Image, matte: tuple[int, int, int], tolerance: int) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = list(rgba.getdata())
    background = bytearray(width * height)
    queued = bytearray(width * height)
    queue: deque[int] = deque()

    def similar(index: int) -> bool:
        red, green, blue, _ = pixels[index]
        distance = math.sqrt((red - matte[0]) ** 2 + (green - matte[1]) ** 2 + (blue - matte[2]) ** 2)
        return distance <= tolerance

    border_indices = set()
    for x in range(width):
        border_indices.add(x)
        border_indices.add((height - 1) * width + x)
    for y in range(height):
        border_indices.add(y * width)
        border_indices.add(y * width + width - 1)
    for index in border_indices:
        if similar(index):
            queue.append(index)
            queued[index] = 1

    while queue:
        index = queue.popleft()
        background[index] = 1
        x = index % width
        y = index // width
        for neighbour in (index - 1, index + 1, index - width, index + width):
            if neighbour < 0 or neighbour >= width * height or queued[neighbour]:
                continue
            nx = neighbour % width
            ny = neighbour // width
            if abs(nx - x) + abs(ny - y) != 1 or not similar(neighbour):
                continue
            queued[neighbour] = 1
            queue.append(neighbour)

    output = []
    for index, (red, green, blue, alpha) in enumerate(pixels):
        output.append((red, green, blue, 0 if background[index] else alpha))
    rgba.putdata(output)
    return rgba


def significant_components(alpha: Image.Image, minimum_ratio: float = 0.003) -> tuple[int, list[int]]:
    width, height = alpha.size
    foreground = bytearray(1 if value > 8 else 0 for value in alpha.tobytes())
    occupied = sum(foreground)
    if occupied == 0:
        return 0, []
    minimum_area = max(16, int(occupied * minimum_ratio))
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
                if neighbour < 0 or neighbour >= width * height or foreground[neighbour] == 0:
                    continue
                nx = neighbour % width
                ny = neighbour // width
                if abs(nx - x) + abs(ny - y) != 1:
                    continue
                foreground[neighbour] = 0
                queue.append(neighbour)
        if area >= minimum_area:
            areas.append(area)
    areas.sort(reverse=True)
    return len(areas), areas


def fit_to_canvas(image: Image.Image, output_size: tuple[int, int], padding: int) -> tuple[Image.Image, float]:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("去底后没有有效前景像素。")
    subject = image.crop(bounds)
    available_width = output_size[0] - 2 * padding
    available_height = output_size[1] - 2 * padding
    if available_width <= 0 or available_height <= 0:
        raise ValueError("safePadding 大于最终画布可用空间。")
    scale = min(1.0, available_width / subject.width, available_height / subject.height)
    resized_size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    if resized_size != subject.size:
        subject = subject.resize(resized_size, Image.Resampling.LANCZOS).filter(ImageFilter.SHARPEN)
    canvas = Image.new("RGBA", output_size, (0, 0, 0, 0))
    offset = ((output_size[0] - subject.width) // 2, (output_size[1] - subject.height) // 2)
    canvas.alpha_composite(subject, offset)
    return canvas, scale


def main() -> int:
    parser = argparse.ArgumentParser(description="拆分并验证 MLGS registered-sheet 美术拼版。")
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--plan", required=True)
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()
    plan_path = resolve_project_path(project_root, args.plan)
    plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    report_path = resolve_project_path(project_root, str(plan.get("reportPath", "")))
    findings: list[str] = []
    results: list[dict] = []
    prepared: list[tuple[Path, Image.Image]] = []

    try:
        if str(plan.get("schemaVersion")) != "1.0":
            findings.append("art batch schemaVersion 必须是 1.0。")
        if str(plan.get("sourceLayout")) != "registered-sheet":
            findings.append("只有 registered-sheet 可以使用自动拆分工具。")
        items = list(plan.get("items", []))
        if len(items) < 2:
            findings.append("批量拼版至少需要两个独立资源。")
        canvas_size = tuple(int(value) for value in plan.get("canvasSize", []))
        if len(canvas_size) != 2:
            raise ValueError("canvasSize 必须包含宽和高。")
        source_path = resolve_project_path(project_root, str(plan.get("sourceImage", "")))
        source = Image.open(source_path).convert("RGBA")
        if source.size != canvas_size:
            findings.append(f"源图尺寸 {source.size} 与注册画布 {canvas_size} 不一致。")
        matte = parse_hex_color(str(plan.get("matteColor", "")))
        tolerance = int(plan.get("matteTolerance", 0))
        minimum_margin = int(plan.get("minimumCellMargin", 0))

        rectangles: list[list[int]] = []
        for item in items:
            rect = [int(value) for value in item.get("rect", [])]
            if len(rect) != 4:
                findings.append(f"{item.get('assetId', '<missing>')}: rect 必须是 [x,y,width,height]。")
                continue
            x, y, width, height = rect
            if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > source.width or y + height > source.height:
                findings.append(f"{item.get('assetId', '<missing>')}: rect 越出源图。")
            for previous in rectangles:
                if rectangles_overlap(rect, previous):
                    findings.append(f"{item.get('assetId', '<missing>')}: rect 与其他注册格重叠。")
            rectangles.append(rect)

        if not findings:
            for item in items:
                asset_id = str(item.get("assetId", "<missing>"))
                x, y, width, height = [int(value) for value in item["rect"]]
                crop = source.crop((x, y, x + width, y + height))
                if bool(item.get("removeMatte", True)):
                    crop = remove_connected_matte(crop, matte, tolerance)
                bounds = crop.getchannel("A").getbbox()
                item_findings: list[str] = []
                margins = None
                if bounds is None:
                    item_findings.append("注册格为空或去底后无前景。")
                else:
                    left, top, right, bottom = bounds
                    margins = {
                        "left": left,
                        "top": top,
                        "right": crop.width - right,
                        "bottom": crop.height - bottom,
                    }
                    if min(margins.values()) < minimum_margin:
                        item_findings.append(f"对象触及注册格安全区：要求 >= {minimum_margin}px，实际 {margins}。")
                component_count, component_areas = significant_components(crop.getchannel("A"))
                maximum_components = int(item.get("maxSignificantComponents", 1))
                if component_count > maximum_components:
                    item_findings.append(f"检测到 {component_count} 个显著对象，最多允许 {maximum_components} 个。")
                output_size = tuple(int(value) for value in item.get("finalSize", []))
                if len(output_size) != 2:
                    item_findings.append("finalSize 必须包含宽和高。")
                    output_size = (1, 1)
                output_path = resolve_project_path(project_root, str(item.get("outputPath", "")))
                scale = 0.0
                if not item_findings:
                    final, scale = fit_to_canvas(crop, output_size, int(item.get("safePadding", 0)))
                    prepared.append((output_path, final))
                results.append(
                    {
                        "assetId": asset_id,
                        "rect": [x, y, width, height],
                        "sourceBounds": list(bounds) if bounds else None,
                        "sourceMargins": margins,
                        "significantComponents": component_count,
                        "componentAreas": component_areas,
                        "outputPath": str(item.get("outputPath", "")),
                        "outputSize": list(output_size),
                        "scale": round(scale, 6),
                        "verdict": "pass" if not item_findings else "fail",
                        "findings": item_findings,
                    }
                )
                findings.extend(f"{asset_id}: {message}" for message in item_findings)
    except Exception as exc:
        findings.append(str(exc))

    verdict = "pass" if not findings and results else "fail"
    if verdict == "pass":
        for output_path, image in prepared:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            image.save(output_path, "PNG")
    report = {
        "schemaVersion": "1.0",
        "batchId": str(plan.get("id", "")),
        "planPath": args.plan,
        "sourceImage": str(plan.get("sourceImage", "")),
        "generatedAt": datetime.now(timezone.utc).astimezone().isoformat(),
        "verdict": verdict,
        "findings": findings,
        "items": results,
        "limitations": [
            "Requires explicit non-overlapping registered rectangles; it never guesses an AI sheet grid.",
            "Connected matte removal only removes border-connected pixels near the declared matte color.",
            "Art Director and Unity in-game review remain required after structural splitting passes.",
        ],
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"report": str(plan.get("reportPath", "")), "items": len(results), "verdict": verdict}, ensure_ascii=False))
    return 0 if verdict == "pass" else 23


if __name__ == "__main__":
    raise SystemExit(main())
