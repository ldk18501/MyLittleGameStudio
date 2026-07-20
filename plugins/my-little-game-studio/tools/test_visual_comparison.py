#!/usr/bin/env python3
"""Deterministic visual comparison evidence for MLGS art gates.

The metrics are intentionally transparent and local. They detect broad palette,
value, layout, edge-density and contrast drift; they do not replace Art Director
or QA judgment.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    from PIL import Image, ImageFilter, ImageStat
except ImportError as exc:
    raise SystemExit("缺少 Pillow。请先安装：python -m pip install Pillow") from exc


SAMPLE_SIZE = (256, 256)
ALGORITHM = "mlgs-pillow-v1"


def resolve_project_path(root: Path, relative: str) -> Path:
    candidate = (root / relative).resolve() if not Path(relative).is_absolute() else Path(relative).resolve()
    try:
        candidate.relative_to(root.resolve())
    except ValueError as exc:
        raise ValueError(f"路径越出项目目录：{relative}") from exc
    return candidate


def clamp_score(value: float) -> int:
    return max(0, min(100, int(round(value))))


def byte_similarity(left: Image.Image, right: Image.Image) -> float:
    left_bytes = left.tobytes()
    right_bytes = right.tobytes()
    if len(left_bytes) != len(right_bytes) or not left_bytes:
        return 0.0
    error = sum(abs(a - b) for a, b in zip(left_bytes, right_bytes)) / len(left_bytes)
    return max(0.0, 100.0 * (1.0 - error / 255.0))


def histogram_similarity(left: Image.Image, right: Image.Image) -> float:
    left_hist = left.histogram()
    right_hist = right.histogram()
    left_total = max(1, sum(left_hist))
    right_total = max(1, sum(right_hist))
    overlap = sum(min(a / left_total, b / right_total) for a, b in zip(left_hist, right_hist))
    return max(0.0, min(100.0, overlap * 100.0))


def scalar_similarity(left: float, right: float, scale: float) -> float:
    return max(0.0, 100.0 * (1.0 - abs(left - right) / max(scale, 1e-6)))


def image_metrics(target: Image.Image, candidate: Image.Image) -> dict[str, int]:
    target_rgb = target.convert("RGB").resize(SAMPLE_SIZE, Image.Resampling.LANCZOS)
    candidate_rgb = candidate.convert("RGB").resize(SAMPLE_SIZE, Image.Resampling.LANCZOS)
    target_gray = target_rgb.convert("L")
    candidate_gray = candidate_rgb.convert("L")
    target_blocks = target_gray.resize((24, 24), Image.Resampling.BILINEAR)
    candidate_blocks = candidate_gray.resize((24, 24), Image.Resampling.BILINEAR)
    target_edges = target_gray.filter(ImageFilter.FIND_EDGES)
    candidate_edges = candidate_gray.filter(ImageFilter.FIND_EDGES)

    composition = byte_similarity(target_blocks, candidate_blocks)
    palette = histogram_similarity(target_rgb, candidate_rgb)
    value = histogram_similarity(target_gray, candidate_gray)
    material = histogram_similarity(target_edges, candidate_edges)

    target_edge_mean = ImageStat.Stat(target_edges).mean[0]
    candidate_edge_mean = ImageStat.Stat(candidate_edges).mean[0]
    detail = scalar_similarity(target_edge_mean, candidate_edge_mean, 255.0)
    target_contrast = ImageStat.Stat(target_gray).stddev[0]
    candidate_contrast = ImageStat.Stat(candidate_gray).stddev[0]
    readability = scalar_similarity(target_contrast, candidate_contrast, 128.0)
    pixel = byte_similarity(target_rgb, candidate_rgb)
    target_match = (
        composition * 0.30
        + palette * 0.20
        + value * 0.15
        + material * 0.10
        + detail * 0.10
        + readability * 0.05
        + pixel * 0.10
    )
    return {
        "targetMatch": clamp_score(target_match),
        "composition": clamp_score(composition),
        "palette": clamp_score(palette),
        "value": clamp_score(value),
        "material": clamp_score(material),
        "detail": clamp_score(detail),
        "readability": clamp_score(readability),
    }


def scene_scores(asset_scores: dict[str, int]) -> dict[str, int]:
    return {
        "targetMatch": asset_scores["targetMatch"],
        "composition": asset_scores["composition"],
        "spatialLayout": asset_scores["composition"],
        "depthLighting": asset_scores["value"],
        "materialLanguage": asset_scores["material"],
        "detailDensity": asset_scores["detail"],
        "diegeticIntegration": clamp_score((asset_scores["composition"] + asset_scores["readability"]) / 2),
        "readability": asset_scores["readability"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="生成 MLGS 可复现的视觉对比报告。")
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--mode", choices=("asset", "scene"), default="asset")
    parser.add_argument("--target-match", type=int)
    parser.add_argument("--dimension-min", type=int)
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()
    try:
        target_path = resolve_project_path(project_root, args.target)
        candidate_path = resolve_project_path(project_root, args.candidate)
        report_path = resolve_project_path(project_root, args.report)
        target = Image.open(target_path)
        candidate = Image.open(candidate_path)
        asset = image_metrics(target, candidate)
        scores = asset if args.mode == "asset" else scene_scores(asset)
        target_min = args.target_match if args.target_match is not None else (80 if args.mode == "asset" else 85)
        dimension_min = args.dimension_min if args.dimension_min is not None else (70 if args.mode == "asset" else 80)
        thresholds = {name: (target_min if name == "targetMatch" else dimension_min) for name in scores}
        verdict = "pass" if all(scores[name] >= thresholds[name] for name in scores) else "fail"
        report = {
            "schemaVersion": "1.0",
            "mode": args.mode,
            "targetImage": args.target,
            "candidateImage": args.candidate,
            "algorithm": ALGORITHM,
            "generatedAt": datetime.now(timezone.utc).astimezone().isoformat(),
            "scores": scores,
            "thresholds": thresholds,
            "verdict": verdict,
            "limitations": [
                "Deterministic pixel, histogram, layout, edge-density and contrast checks only.",
                "Does not replace semantic, style, animation, diegetic or in-game Art Director/QA review.",
            ],
        }
    except Exception as exc:
        report = {
            "schemaVersion": "1.0",
            "mode": args.mode,
            "targetImage": args.target,
            "candidateImage": args.candidate,
            "algorithm": ALGORITHM,
            "generatedAt": datetime.now(timezone.utc).astimezone().isoformat(),
            "scores": {},
            "thresholds": {},
            "verdict": "error",
            "limitations": [str(exc)],
        }

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"report": args.report, "mode": args.mode, "verdict": report["verdict"], "scores": report["scores"]}, ensure_ascii=False))
    return 0 if report["verdict"] == "pass" else 19


if __name__ == "__main__":
    sys.exit(main())
