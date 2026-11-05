#!/usr/bin/env python3
"""Capture iWallet UI on a dedicated simulator; optionally reuse existing demo data."""
import argparse
import json
import pathlib
import plistlib
import shutil
import struct
import subprocess
import uuid

EXPECTED_CAPTURES = (
    "01-overview.png",
    "02-transactions.png",
    "03-categories.png",
    "04-new-transaction.png",
    "05-new-category.png",
    "06-settings.png",
    "07-payments.png",
    "08-analytics.png",
    "09-category-chart.png",
)


def run(*args):
    return subprocess.check_output(args, text=True)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--language", choices=("ru", "en"), required=True)
parser.add_argument("--device", required=True)
parser.add_argument("--xctestrun", type=pathlib.Path, required=True)
parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("build/AppStore-Screenshots"))
parser.add_argument("--existing-demo", action="store_true",
                    help="Read-only refresh of an already populated demo wallet; do not create or edit wallet records.")
args = parser.parse_args()

devices = json.loads(run("xcrun", "simctl", "list", "devices", "-j"))["devices"]
device = next((d for group in devices.values() for d in group if d["udid"] == args.device), None)
if not device or not device["name"].startswith("iWallet App Store "):
    parser.error("Use a dedicated simulator named 'iWallet App Store RU' or 'iWallet App Store EN'. Default capture requires a fresh wallet; --existing-demo requires a populated demo wallet.")

source = args.xctestrun.resolve()
configuration = plistlib.loads(source.read_bytes())
if "TestConfigurations" in configuration:
    targets = [t for c in configuration["TestConfigurations"] for t in c["TestTargets"]]
else:
    targets = [v for k, v in configuration.items() if k != "__xctestrun_metadata__"]
for target in targets:
    target.setdefault("EnvironmentVariables", {})["IWALLET_CAPTURE_APP_STORE"] = "1"

token = uuid.uuid4().hex[:8]
temporary = source.with_name(f"AppStore-{args.language}-{token}.xctestrun")
temporary.write_bytes(plistlib.dumps(configuration))
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
result = output / f"capture-{args.language}-{token}.xcresult"
attachments = output / f"attachments-{args.language}-{token}"
language_suffix = "Russian" if args.language == "ru" else "English"
method = ("testRefresh" if args.existing_demo else "testCapture") + language_suffix
try:
    subprocess.run([
        "xcodebuild", "test-without-building", "-xctestrun", str(temporary),
        "-destination", f"id={args.device}", "-parallel-testing-enabled", "NO",
        "-only-testing:iWalletUITests/WalletAppStoreScreenshotTests/" + method,
        "-resultBundlePath", str(result),
    ], check=True)
finally:
    temporary.unlink(missing_ok=True)

subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                "--output-path", str(attachments)], check=True)
destination = output / args.language
destination.mkdir(exist_ok=True)
prefix = f"AppStore-{args.language}-"
captured = {}
for test in json.loads((attachments / "manifest.json").read_text()):
    for attachment in test["attachments"]:
        name = attachment["suggestedHumanReadableName"]
        if not name.startswith(prefix):
            continue
        filename = name[len(prefix):].split("_0_")[0] + ".png"
        if filename not in EXPECTED_CAPTURES or filename in captured:
            raise RuntimeError(f"Unexpected or duplicate screenshot: {filename}")
        image = attachments / attachment["exportedFileName"]
        data = image.read_bytes()
        if len(data) < 26 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[25] != 2:
            raise RuntimeError("A capture is not opaque RGB PNG; no image conversion is performed.")
        if struct.unpack(">II", data[16:24]) != (1206, 2622):
            raise RuntimeError("Use iPhone 18 Pro at its native 1206 × 2622 resolution.")
        captured[filename] = image
if set(captured) != set(EXPECTED_CAPTURES):
    raise RuntimeError(f"Expected all {len(EXPECTED_CAPTURES)} named captures; found {sorted(captured)}")
for filename in EXPECTED_CAPTURES:
    shutil.copyfile(captured[filename], destination / filename)
print(f"Saved unchanged RGB screenshots to {destination}: {', '.join(EXPECTED_CAPTURES)}")
