#!/usr/bin/env python3
"""Verify source catalogs, the packaged app and optionally Xcode's extracted UI keys."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = {"en", "ru", "zh-Hans", "hi", "es", "ar", "fr", "bn", "pt", "id", "ur"}
SOURCE_KEY = re.compile(r'^\s*"((?:\\.|[^"\\])*)"\s*=', re.MULTILINE)
ARGUMENT = re.compile(r"%(?:(\d+)\$)?(lld|d|@|%)|%")


def catalog(path):
    return json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(path)]))


def arguments(value):
    result = []
    indexed = set()
    for match in ARGUMENT.finditer(value):
        position, kind = match.groups()
        if not kind:
            raise ValueError(f"unrecognized format in {value!r}")
        if kind != "%":
            indexed.add(position is not None)
            result.append((int(position) if position else len(result) + 1, kind))
    if len(indexed) > 1:
        raise ValueError(f"mixed positional and sequential arguments in {value!r}")
    return Counter(result)


def verify(app=None, extraction=None):
    directory = ROOT / "iWallet" / "Localizable"
    keys = catalog(directory / "en.lproj" / "Localizable.strings")
    errors = []
    available = {p.parent.stem for p in directory.glob("*.lproj/Localizable.strings")}
    if available != LANGUAGES:
        raise ValueError(f"Unexpected source language set: {sorted(available ^ LANGUAGES)}")
    source = {}
    for lang in sorted(LANGUAGES):
        path = directory / f"{lang}.lproj" / "Localizable.strings"
        values = catalog(path)
        source[lang] = values
        entries = SOURCE_KEY.findall(path.read_text(encoding="utf-8"))
        if len(entries) != len(set(entries)) or len(entries) != len(values):
            errors.append(f"{lang}: duplicate or unrecognized source entries")
        if set(keys) != set(values):
            errors.append(f"{lang}: differing keys {sorted(set(keys) ^ set(values))}")
        for key in keys.keys() & values.keys():
            if not values[key].strip() or arguments(key) != arguments(values[key]):
                errors.append(f"{lang}: empty value or placeholder mismatch for {key!r}")
        if values.get("iWallet") != "iWallet":
            errors.append(f"{lang}: changed product name")
    if app:
        packaged = {p.parent.stem for p in app.glob("*.lproj/Localizable.strings")}
        if packaged != LANGUAGES:
            errors.append(f"{app}: differing languages {sorted(packaged ^ LANGUAGES)}")
        for lang in packaged & LANGUAGES:
            if catalog(app / f"{lang}.lproj" / "Localizable.strings") != source[lang]:
                errors.append(f"{app}: packaged {lang} differs from the source catalog")
    if extraction:
        files = list(extraction.glob("*.stringsdata"))
        if not files:
            errors.append(f"No Xcode stringsdata files under {extraction}")
        for file in files:
            records = json.loads(file.read_text()).get("tables", {}).get("Localizable", [])
            for row in records:
                key = row["key"]
                if key and key not in keys:
                    errors.append(f"{file.stem}: missing extracted key {key!r}")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"Verified {len(keys)} keys in {len(source)} languages.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, help="check the .app from a build or archive")
    parser.add_argument("--stringsdata", type=Path, help="Xcode Objects-normal/<architecture> directory for iWallet")
    options = parser.parse_args()
    verify(options.app, options.stringsdata)
