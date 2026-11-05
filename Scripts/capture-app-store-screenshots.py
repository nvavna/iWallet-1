#!/usr/bin/env python3
"""Capture actual iWallet UI on a fresh, explicitly named App Store simulator."""
import argparse
import json
import pathlib
import plistlib
import shutil
import struct
import subprocess
import uuid


def run(*args):
    return subprocess.check_output(args, text=True)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--language", choices=("ru", "en"), required=True)
parser.add_argument("--device", required=True)
parser.add_argument("--xctestrun", type=pathlib.Path, required=True)
parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("build/AppStore-Screenshots"))
args = parser.parse_args()

devices = json.loads(run("xcrun", "simctl", "list", "devices", "-j"))["devices"]
device = next((d for group in devices.values() for d in group if d["udid"] == args.device), None)
if not device or not device["name"].startswith("iWallet App Store "):
    parser.error("Use a fresh simulator named 'iWallet App Store RU' or 'iWallet App Store EN'.")

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
method = "testCaptureRussian" if args.language == "ru" else "testCaptureEnglish"
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
captured = []
for test in json.loads((attachments / "manifest.json").read_text()):
    for attachment in test["attachments"]:
        name = attachment["suggestedHumanReadableName"]
        if not name.startswith(prefix):
            continue
        filename = name[len(prefix):].split("_0_")[0] + ".png"
        image = attachments / attachment["exportedFileName"]
        data = image.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n" or data[25] != 2:
            raise RuntimeError("A capture is not opaque RGB PNG; no image conversion is performed.")
        if struct.unpack(">II", data[16:24]) != (1206, 2622):
            raise RuntimeError("Use iPhone 18 Pro at its native 1206 × 2622 resolution.")
        shutil.copyfile(image, destination / filename)
        captured.append(filename)
if len(captured) != 3:
    raise RuntimeError(f"Expected exactly three captures; found {captured}")
print(f"Saved unchanged RGB screenshots to {destination}: {', '.join(sorted(captured))}")
