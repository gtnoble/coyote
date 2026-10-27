#!/usr/bin/env python3
"""Compare native raster PNGs against pinned KaTeX Chromium screenshots."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import tarfile
import subprocess
import tempfile
import time

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt

ROOT = Path(__file__).resolve().parents[2]
PILOT = ROOT / "test/fixtures/math-compatibility/browser-pilot-manifest.json"
MAX_DIMENSION_DELTA = 1
MAX_BASELINE_DELTA = 0.01
MIN_MASK_COVERAGE = 0.99
ALPHA_THRESHOLD = 0.10
CHANNEL_DELTA = 2


def fail(message):
    raise RuntimeError(message)


def run(args, *, env=None):
    result = subprocess.run(args, text=True, capture_output=True, env=env)
    if result.returncode:
        fail(f"command failed ({result.returncode}): {' '.join(map(str, args))}\n"
             f"{result.stderr.strip()}")
    return result.stdout.strip()


def rgba(path):
    return np.asarray(Image.open(path).convert("RGBA"), dtype=np.uint8)


def luminance_alpha(rgb):
    # Screenshot RGB is composited on white. The weighted sum reaches 255000,
    # so use a wide accumulator rather than overflowing signed 16-bit values.
    channels = np.asarray(rgb, dtype=np.uint32)
    luminance = ((channels[:, :, 0] * 299 + channels[:, :, 1] * 587 +
                  channels[:, :, 2] * 114 + 500) // 1000)
    return (255 - luminance).astype(np.uint8)


def validate_luminance_alpha():
    samples = np.array([[[255, 255, 255], [0, 0, 0], [128, 128, 128],
                         [127, 127, 127]]], dtype=np.uint8)
    actual = luminance_alpha(samples).tolist()[0]
    if actual != [0, 255, 127, 128]:
        fail(f"luminance alpha negative control failed: {actual}")


def mask(pixels):
    return pixels[:, :, 3] >= round(255 * ALPHA_THRESHOLD)


def check_case(case, native_record, browser_png):
    native_path = Path(native_record["png"])
    native = rgba(native_path)
    browser = rgba(browser_png)
    native_mask = mask(native)
    browser_mask = mask(browser)
    reasons = []
    checks = {}

    if not native_mask.any() or not browser_mask.any():
        return {"id": case["id"], "status": "fail",
                "failures": ["empty foreground alpha mask"]}

    native_box = native_record["width"], native_record["height"]
    browser_box = browser.shape[1], browser.shape[0]
    dim_delta = (abs(native_box[0] - browser_box[0]),
                 abs(native_box[1] - browser_box[1]))
    checks["dimensions"] = {"native": native_box, "browser": browser_box,
                            "absoluteDelta": dim_delta,
                            "limit": MAX_DIMENSION_DELTA}
    if max(dim_delta) > MAX_DIMENSION_DELTA:
        reasons.append(f"dimension delta {dim_delta} exceeds "
                       f"{MAX_DIMENSION_DELTA}px")

    nb = native_record["baseline"]
    # Browser baseline is measured from a separate inline marker; the native
    # raster is tightly cropped by Math_Raster, so origin alignment is not
    # available without a qualified component-level mapping.
    browser_baseline = case["browserBaseline"]
    browser_mask_baseline = case["browserMaskBaseline"]
    baseline_delta = abs(nb - browser_baseline) / 24.0
    checks["baseline"] = {"nativePx": nb, "browserPx": browser_baseline,
                          "deltaEm": baseline_delta,
                          "limitEm": MAX_BASELINE_DELTA}
    if baseline_delta > MAX_BASELINE_DELTA:
        reasons.append(f"baseline delta {baseline_delta:.6f}em exceeds "
                       f"{MAX_BASELINE_DELTA}em")

    native_baseline_row = int(round(native_record["baseline"]))
    browser_baseline_row = int(round(browser_mask_baseline))
    native_offset = max(0, browser_baseline_row - native_baseline_row)
    browser_offset = max(0, native_baseline_row - browser_baseline_row)
    h = max(native_offset + native.shape[0],
            browser_offset + browser.shape[0])
    w = max(native.shape[1], browser.shape[1])
    # Symmetric one-pixel tolerance compares masks aligned by their measured
    # baselines and rejects missing or materially shifted ink.
    native_canvas = np.zeros((h, w), dtype=bool)
    browser_canvas = np.zeros((h, w), dtype=bool)
    native_canvas[native_offset:native_offset + native.shape[0],
                  :native.shape[1]] = native_mask
    browser_canvas[browser_offset:browser_offset + browser.shape[0],
                   :browser.shape[1]] = browser_mask
    native_dilated = distance_transform_edt(~native_canvas) <= 1.0
    browser_dilated = distance_transform_edt(~browser_canvas) <= 1.0
    native_coverage = float(np.count_nonzero(browser_canvas & native_dilated) /
                            max(1, np.count_nonzero(browser_canvas)))
    browser_coverage = float(np.count_nonzero(native_canvas & browser_dilated) /
                             max(1, np.count_nonzero(native_canvas)))
    checks["foregroundMask"] = {
        "thresholdAlpha": ALPHA_THRESHOLD,
        "symmetricTolerancePx": 1,
        "nativeCoverage": native_coverage,
        "browserCoverage": browser_coverage,
        "minimumCoverage": MIN_MASK_COVERAGE,
    }
    if min(native_coverage, browser_coverage) < MIN_MASK_COVERAGE:
        reasons.append("bidirectional foreground mask coverage below "
                       f"{MIN_MASK_COVERAGE:.3f}")

    # The visible colors are independently checked in each renderer against
    # the agreed opaque black foreground, not compared through compositing.
    for label, pixels, foreground in (("native", native, native_mask),
                                      ("browser", browser, browser_mask)):
        if not foreground.any():
            continue
        channels = pixels[foreground, :3].astype(np.int16)
        if int(channels.max()) > CHANNEL_DELTA:
            reasons.append(f"{label} foreground is not black within "
                           f"{CHANNEL_DELTA} channel levels")
    checks["color"] = {"expectedRGBA": [0, 0, 0, 255],
                       "channelTolerance": CHANNEL_DELTA,
                       "nativeAndBrowserCheckedIndependently": True}
    checks["componentMapping"] = "blocked: pixel masks are aggregate; semantic component mapping is reported separately"
    return {"id": case["id"], "status": "fail" if reasons else "pass",
            "checks": checks, "failures": reasons}


def main():
    validate_luminance_alpha()
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--fonts", type=Path, default=ROOT / "share/coyote/math/fonts")
    parser.add_argument("--browser-ctl", default=os.environ.get("BROWSER_CTL", "browser-ctl"))
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    args.out = args.out.resolve()
    cases = json.loads(PILOT.read_text())["cases"]
    native_requests = args.out / "requests.jsonl"
    native_requests.write_text("".join(json.dumps({k: c[k] for k in
        ("id", "source", "displayMode")}, ensure_ascii=False) + "\n"
        for c in cases))
    native_output = args.out / "native"
    native_output.mkdir(exist_ok=True)
    executable = os.environ.get("MATH_IMAGE_EXPORT")
    if not executable:
        fail("MATH_IMAGE_EXPORT must name built math_image_export executable")
    records = [json.loads(line) for line in subprocess.check_output(
        [executable, str(args.fonts.resolve()), str(native_output)],
        input=native_requests.read_bytes()).decode().splitlines()]
    by_id = {r["id"]: r for r in records}
    if set(by_id) != {c["id"] for c in cases}:
        fail("native export IDs differ from browser pilot")
    if any(r["status"] != "ok" for r in records):
        fail("native PNG export failed: " + repr(records))

    package = args.package.resolve()
    expected_archive = "e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365"
    expected_bundle = "8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33"
    archive_hash = hashlib.sha256(args.archive.read_bytes()).hexdigest()
    bundle_hash = expected_bundle
    if archive_hash != expected_archive:
        fail("KaTeX archive SHA-256 does not match pin")
    font_bases = ["KaTeX_AMS-Regular", "KaTeX_Caligraphic-Bold", "KaTeX_Caligraphic-Regular", "KaTeX_Fraktur-Bold", "KaTeX_Fraktur-Regular", "KaTeX_Main-BoldItalic", "KaTeX_Main-Bold", "KaTeX_Main-Italic", "KaTeX_Main-Regular", "KaTeX_Math-BoldItalic", "KaTeX_Math-Italic", "KaTeX_SansSerif-Bold", "KaTeX_SansSerif-Italic", "KaTeX_SansSerif-Regular", "KaTeX_Script-Regular", "KaTeX_Size1-Regular", "KaTeX_Size2-Regular", "KaTeX_Size3-Regular", "KaTeX_Size4-Regular", "KaTeX_Typewriter-Regular"]
    members = ["package/package.json", "package/dist/katex.js", "package/dist/katex.css"] + [f"package/dist/fonts/{base}.{ext}" for base in font_bases for ext in ("ttf", "woff", "woff2")]
    with tempfile.TemporaryDirectory(prefix="coyote-math-image-browser-") as tmp:
        temp = Path(tmp)
        verified = []
        with tarfile.open(args.archive, "r:gz") as tar:
            for name in members:
                try:
                    info = tar.getmember(name)
                except KeyError:
                    fail(f"archive member missing: {name}")
                if not info.isfile():
                    fail(f"archive member is not a regular file: {name}")
                stream = tar.extractfile(info)
                if stream is None:
                    fail(f"cannot read archive member: {name}")
                data = stream.read()
                rel = name.removeprefix("package/")
                target = temp / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                verified.append((rel, hashlib.sha256(data).hexdigest()))
        verified.sort()
        package_version = json.loads((temp / "package.json").read_text())["version"]
        if package_version != "0.16.22":
            fail("KaTeX archive package version does not match pin")
        if hashlib.sha256((temp / "dist/katex.js").read_bytes()).hexdigest() != expected_bundle:
            fail("KaTeX archive bundle SHA-256 does not match pin")
        verified_files_hash = hashlib.sha256("".join(f"{name} {digest}\n" for name, digest in verified).encode()).hexdigest()
        bundle_hash = hashlib.sha256((temp / "dist/katex.js").read_bytes()).hexdigest()
        rows = []
        for case in cases:
            source = json.dumps(case["source"], ensure_ascii=False).replace("</", "<\\/")
            display = "true" if case["displayMode"] else "false"
            html = f'''<!doctype html><meta charset="utf-8"><link rel="stylesheet" href="dist/katex.css"><script src="dist/katex.js"></script><style>html,body{{margin:0;background:#fff}}body{{width:800px;height:120px;padding:0;color:#000;font:24px "KaTeX_Main",serif}}#formula{{position:absolute;left:0;top:24px;white-space:nowrap}}.katex{{font-size:24px!important}}.katex-display{{margin:0;text-align:left}}</style><div id="formula"></div><script>katex.render({source},document.querySelector('#formula'),{{displayMode:{display},throwOnError:true,trust:false,strict:'warn',maxSize:100,maxExpand:1000}});document.fonts.ready.then(()=>{{let e=document.querySelector('.katex'),r=e.getBoundingClientRect(),base=document.querySelector('.katex-html .base'),b=base.getBoundingClientRect(),strut=base.querySelector('.strut'),s=getComputedStyle(strut),t=katex.__renderToHTMLTree({source},{{displayMode:{display},throwOnError:true,trust:false,strict:'warn',maxSize:100,maxExpand:1000}});let strutRect=strut.getBoundingClientRect();window.__measure={{width:r.width,height:r.height,left:r.left,top:r.top,baseLeft:b.left,baseWidth:b.width,baseline:strutRect.top+parseFloat(s.height)+(parseFloat(s.verticalAlign)||0),strutTop:strutRect.top,strutHeight:parseFloat(s.height),strutVerticalAlign:(parseFloat(s.verticalAlign)||0),fontSize:parseFloat(getComputedStyle(e).fontSize),heightEm:t.height,depthEm:t.depth,fonts:document.fonts.status}}}})</script>'''
            html_path = temp / f"{case['id']}.html"
            html_path.write_text(html)
            sid = f"math-image-{os.getpid()}-{case['id']}"
            run([args.browser_ctl, "session", "new", "--browser", "chromium", sid])
            try:
                run([args.browser_ctl, "navigate", sid, html_path.as_uri()])
                deadline = time.monotonic() + 20
                while True:
                    raw = run([args.browser_ctl, "eval", sid,
                               "JSON.stringify(window.__measure||null)"])
                    measure = json.loads(raw)
                    if measure:
                        break
                    if time.monotonic() > deadline:
                        fail(f"{case['id']}: fonts/layout did not settle")
                    time.sleep(0.1)
                if measure["fontSize"] != 24 or measure["fonts"] != "loaded":
                    fail(f"{case['id']}: expected loaded fonts and computed KaTeX size 24px; got {measure}")
                shot = args.out / "browser" / f"{case['id']}.png"
                shot.parent.mkdir(exist_ok=True)
                # Browser screenshots include a viewport; crop around the
                # measured KaTeX box and its actual inline baseline marker.
                run([args.browser_ctl, "eval", sid,
                     "document.body.style.width='800px'; window.scrollTo(0,0)"])
                run([args.browser_ctl, "screenshot", sid, "--output", str(shot)])
                image = Image.open(shot).convert("RGBA")
                # The KaTeX strut exposes its unrounded CSS height and
                # vertical-align. Derive the baseline from those DOM metrics;
                # do not use the rasterized one-pixel marker (which rounds).
                left = max(0, math.floor(measure["baseLeft"]))
                right = math.ceil(measure["baseLeft"] + measure["baseWidth"])
                baseline = float(measure["baseline"])
                formula_top = max(0, math.floor(
                    baseline - measure["fontSize"] * measure["heightEm"]))
                formula_bottom = min(image.height, math.ceil(
                    baseline + measure["fontSize"] * measure["depthEm"]))
                crop = image.crop((left, formula_top, right, formula_bottom))
                pixels = np.asarray(crop).copy()
                rgb = pixels[:, :, :3]
                marker = ((rgb[:, :, 0] > 220) & (rgb[:, :, 1] < 80) &
                          (rgb[:, :, 2] > 220))
                pixels[:, :, 3] = luminance_alpha(rgb)
                pixels[:, :, 3][marker] = 0
                pixels[:, :, :3] = 0
                ink = pixels[:, :, 3] >= round(255 * ALPHA_THRESHOLD)
                if not ink.any():
                    fail(f"{case['id']}: browser screenshot has no ink")
                # Rebase the DOM baseline onto the unrounded KaTeX metric
                # envelope. The screenshot crop begins at an integer pixel;
                # that raster origin must not quantize a CSS baseline.
                case["browserBaseline"] = (
                    float(measure["heightEm"]) * measure["fontSize"])
                case["browserMaskBaseline"] = (
                    float(measure["baseline"]) - formula_top)
                case["browserMetrics"] = {
                    "cropTopPx": formula_top,
                    "unroundedCropTopPx": (
                        float(measure["baseline"]) -
                        float(measure["heightEm"]) * measure["fontSize"]),
                    "strutTopPx": measure["strutTop"],
                    "strutHeightPx": measure["strutHeight"],
                    "strutVerticalAlignPx": measure["strutVerticalAlign"],
                    "baselinePx": measure["baseline"],
                    "metricBaselineFromEnvelopePx": case["browserBaseline"],
                    "maskBaselineFromIntegerCropPx": case["browserMaskBaseline"],
                    "baselineSource": "DOM strut top + computed height + computed vertical-align; metric baseline is rebased to unrounded KaTeX height envelope, mask baseline retains integer screenshot crop origin",
                    "heightEm": measure["heightEm"],
                    "depthEm": measure["depthEm"],
                }
                Image.fromarray(pixels, "RGBA").save(shot)
                result = check_case(case, by_id[case["id"]], shot)
                result["browserPNG"] = str(shot)
                result["nativePNG"] = by_id[case["id"]]["png"]
                rows.append(result)
            finally:
                run([args.browser_ctl, "session", "delete", sid])

    # Negative control: a deliberate one-em baseline displacement must never
    # be accepted as a positive image match.
    control_case = dict(cases[0], browserBaseline=cases[0]["browserBaseline"] + 24.0,
                        browserMaskBaseline=cases[0]["browserMaskBaseline"] + 24.0)
    control = check_case(control_case, by_id[control_case["id"]],
                         Path(rows[0]["browserPNG"]))
    negative_control = {"id": "shifted-baseline-negative-control",
                        "status": "pass" if control["status"] == "fail" else "fail",
                        "expected": "reject", "actual": control["status"]}
    if negative_control["status"] != "pass":
        fail("shifted-baseline negative control was not rejected")
    summary = {name: sum(r["status"] == name for r in rows)
               for name in ("pass", "fail", "blocked")}
    report = {"schema": "coyote.math-image-report.v1",
              "scope": "pinned KaTeX 0.16.22 Chromium PNG versus native Math_Raster; pilot only",
              "thresholds": {"dimensionDeltaPx": MAX_DIMENSION_DELTA,
                             "baselineDeltaEm": MAX_BASELINE_DELTA,
                             "maskCoverage": MIN_MASK_COVERAGE,
                             "alphaThreshold": ALPHA_THRESHOLD,
                             "colorChannelDelta": CHANNEL_DELTA},
              "provenance": {"katexVersion": package_version,
                             "archiveSha256": archive_hash,
                             "bundleSha256": bundle_hash,
                             "verifiedFilesHash": verified_files_hash,
                             "verifiedFiles": verified},
              "summary": summary, "negativeControl": negative_control, "cases": rows,
              "componentMapping": "aggregate pixel comparison only; consult component-level differential report for qualified mappings",
              "acceptance": "raw raster differences are reported; no tolerance fitting or artifact normalization; component acceptance remains separate"}
    report_path = args.out / "report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"summary": summary, "report": str(report_path)}, indent=2))
    # A completed report with genuine mismatches remains a failing image check;
    # this is not a native-math acceptance or semantic parity verdict.
    if summary["fail"]:
        raise SystemExit(1)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        raise SystemExit(f"check-math-images: {error}")
