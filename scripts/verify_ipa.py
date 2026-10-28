#!/usr/bin/env python3
"""Verify a real unsigned iPad device IPA; needs only Python's standard library."""
import argparse
import hashlib
import json
import math
import plistlib
import stat
import struct
import sys
import zipfile
from pathlib import Path, PurePosixPath

ARM64 = 0x0100000C
IOS = 2
LC_BUILD_VERSION = 0x32
LC_CODE_SIGNATURE = 0x1D
MACH_MAGICS = {b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca", b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca"}
BRUSH_SETS = {"pencils": "Pencils", "pens": "Pens", "inks": "Inks", "markers": "Markers",
              "pastels": "Pastels", "oils": "Oils", "paints": "Paints", "gouache": "Gouache",
              "watercolors": "Watercolors", "charcoals": "Charcoals", "basics": "Basics",
              "lettering": "Lettering", "comics": "Comics", "design": "Design", "grunge": "Grunge",
              "street-art": "Street Art", "digital": "Digital", "creative": "Creative"}
SHAPES = {"round", "soft", "flat", "chisel", "bristle", "fleck"}
GRAINS = {"none", "paper", "canvas", "noise", "charcoal", "wash"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify_catalog(archive, app):
    catalog = json.loads(archive.read(app + "BrushCatalog.json"))
    require(isinstance(catalog, dict) and catalog.get("schemaVersion") == 1, "Invalid bundled BrushCatalog schema")
    libraries, sets, brushes = (catalog.get(key) for key in ("libraries", "sets", "brushes"))
    require(all(isinstance(value, list) for value in (libraries, sets, brushes)), "Invalid bundled catalog collections")
    require(len(libraries) == 2 and {v["id"] for v in libraries} == {"atelier", "classic"}, "Bundled libraries differ from v1 inventory")
    expected_sets = set(BRUSH_SETS) | {"classic-foundations"}
    require(len(sets) == 19 and {v["id"] for v in sets} == expected_sets, "Bundled sets differ from 18 sets + Classic Foundations")
    require(all(v["libraryID"] == ("classic" if v["id"] == "classic-foundations" else "atelier") for v in sets), "Invalid set/library relationship")
    require(all(v["name"] == BRUSH_SETS[v["id"]] for v in sets if v["id"] in BRUSH_SETS), "Required category title differs")
    require(len(brushes) == 192, f"Expected 192 bundled presets, got {len(brushes)}")
    ids = [v["id"] for v in brushes]
    require(len(set(ids)) == 192, "Duplicate bundled brush IDs")
    for set_id in BRUSH_SETS:
        require(sum(v.get("setID") == set_id for v in brushes) == 10, f"Expected ten brushes in {set_id}")
    classic = [v for v in brushes if v.get("setID") == "classic-foundations"]
    require(len(classic) == 12 and {v["id"] for v in classic} == {f"classic-foundation-{i:02d}" for i in range(1, 13)}, "Classic inventory must be twelve separate Foundations")
    for brush in brushes:
        require(brush.get("setID") in expected_sets, "Orphaned bundled brush")
        require(isinstance(brush.get("name"), str) and brush["name"].strip(), "Missing bundled brush name")
        require(brush.get("shape") in SHAPES and brush.get("grain") in GRAINS, "Unknown bundled shape or grain")
        require(type(brush.get("seed")) is int and 0 < brush["seed"] <= 0xFFFFFFFFFFFFFFFF, "Invalid persistent brush seed")
        params = brush.get("parameters")
        require(isinstance(params, dict) and params, "Missing persistent brush parameters")
        require(all(type(v) in (int, float) and math.isfinite(v) for v in params.values()), "Invalid numeric brush parameters")
    require(catalog.get("selectedID") in ids and all(v in ids for v in catalog.get("recentIDs", [])), "Invalid catalog selection or recents")
    assets = []
    for prefix, values in (("BrushShape", SHAPES), ("BrushGrain", GRAINS)):
        for value in sorted(values):
            name = f"{app}{prefix}-{value}.png"
            data = archive.read(name)
            require(len(data) >= 33 and data[:8] == b"\x89PNG\r\n\x1a\n", f"Invalid PNG signature: {name}")
            # iOS copypng may prepend a CgBI chunk before IHDR.
            offset, dimensions = 8, None
            while offset + 12 <= len(data):
                length = struct.unpack_from(">I", data, offset)[0]
                require(offset + length + 12 <= len(data), f"Truncated PNG chunk: {name}")
                if data[offset + 4:offset + 8] == b"IHDR":
                    require(length == 13, f"Invalid PNG IHDR: {name}")
                    dimensions = struct.unpack_from(">II", data, offset + 8)
                    break
                offset += length + 12
            require(dimensions and all(0 < size <= 2048 for size in dimensions), f"Invalid brush asset dimensions: {name}")
            assets.append({"path": name, "width": dimensions[0], "height": dimensions[1]})
    return {"schema_version": 1, "libraries": 2, "new_sets": 18, "presets_per_new_set": 10,
            "new_presets": 180, "classic_foundations": 12, "total_presets": 192, "assets": assets,
            "scope": "Offline resource inclusion and configuration validation; qualitative behavior requires renderer/device tests."}


def macho_slices(data):
    require(len(data) >= 8, "Truncated Mach-O")
    magic = data[:4]
    if magic in (b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca", b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca"):
        endian = ">" if magic[:1] == b"\xca" else "<"
        is64 = magic in (b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca")
        count = struct.unpack_from(endian + "I", data, 4)[0]
        size = 32 if is64 else 20
        require(0 < count <= 32 and 8 + count * size <= len(data), "Invalid FAT Mach-O table")
        result = []
        for i in range(count):
            base = 8 + i * size
            offset, length = struct.unpack_from(endian + ("QQ" if is64 else "II"), data, base + 8)
            require(offset >= 8 + count * size and length > 0 and offset + length <= len(data), "Invalid Mach-O slice")
            result.extend(macho_slices(data[offset:offset + length]))
        return result
    require(magic in (b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf"), "Not a 64-bit Mach-O")
    endian = "<" if magic == b"\xcf\xfa\xed\xfe" else ">"
    require(len(data) >= 32, "Truncated Mach-O header")
    cpu, _, filetype, count, commands_size = struct.unpack_from(endian + "IIIII", data, 4)
    require(cpu == ARM64, f"Expected arm64, got CPU {cpu:#x}")
    require(32 + commands_size <= len(data) and count <= commands_size // 8, "Invalid load-command table")
    offset = 32
    platforms = []
    for _ in range(count):
        require(offset + 8 <= 32 + commands_size, "Truncated load command")
        command, length = struct.unpack_from(endian + "II", data, offset)
        require(length >= 8 and length % 4 == 0 and offset + length <= 32 + commands_size, "Invalid load command")
        require(command != LC_CODE_SIGNATURE, "Mach-O has LC_CODE_SIGNATURE; artifact must be unsigned")
        if command == LC_BUILD_VERSION:
            require(length >= 24, "Invalid LC_BUILD_VERSION")
            platforms.append(struct.unpack_from(endian + "I", data, offset + 8)[0])
        offset += length
    require(offset == 32 + commands_size, "Mach-O command sizes do not match")
    require(platforms == [IOS], f"Expected LC_BUILD_VERSION platform iOS device (2), got {platforms}")
    return [{"architecture": "arm64", "platform": "iOS device", "platform_id": IOS, "filetype": filetype, "code_signature": False}]


def verify(path):
    path = Path(path)
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        names = [item.filename for item in entries]
        require(len(names) == len(set(names)), "Duplicate ZIP entries")
        for name in names:
            parts = PurePosixPath(name).parts
            require(not name.startswith("/") and ".." not in parts and "\\" not in name, "Unsafe ZIP path")
            require(parts and parts[0] == "Payload", "IPA must contain Payload/ directly at ZIP root")
            require("embedded.mobileprovision" not in parts and "_CodeSignature" not in parts, "Provisioning or signature directory found")
            if len(parts) > 1:
                require(parts[1] == "Atelier.app", "IPA must contain exactly Payload/Atelier.app")
        app = "Payload/Atelier.app/"
        info = plistlib.loads(archive.read(app + "Info.plist"))
        require(info.get("UIDeviceFamily") == [2], f"UIDeviceFamily must be exactly [2], got {info.get('UIDeviceFamily')}")
        require(info.get("CFBundleSupportedPlatforms") == ["iPhoneOS"], "Bundle is not iPhoneOS device")
        require(info.get("DTPlatformName") == "iphoneos", "DTPlatformName is not iphoneos")
        require(info.get("CFBundlePackageType") == "APPL", "Bundle is not an application")
        executable = info.get("CFBundleExecutable")
        require(executable == "Atelier", f"Unexpected executable {executable!r}")
        require(info.get("CFBundleIdentifier") == "org.atelier.ipad", "Unexpected bundle identifier")
        executable_entry = archive.getinfo(app + executable)
        mode = executable_entry.external_attr >> 16
        require(mode & stat.S_IXUSR, "Main executable lacks owner execute permission")
        main_slices = macho_slices(archive.read(executable_entry))
        require(all(item["filetype"] == 2 for item in main_slices), "Main binary is not MH_EXECUTE")
        binaries = {}
        for item in entries:
            if item.is_dir():
                continue
            with archive.open(item) as stream:
                magic = stream.read(4)
            if magic in MACH_MAGICS:
                binaries[item.filename] = macho_slices(archive.read(item))
        shader_name = app + "default.metallib"
        require(shader_name in names, "Compiled default.metallib is absent")
        shader = archive.read(shader_name)
        require(len(shader) > 32 and shader[:4] == b"MTLB", "Invalid compiled Metal library")
        catalog_report = verify_catalog(archive, app)
    with path.open("rb") as stream:
        checksum = hashlib.file_digest(stream, "sha256").hexdigest()
    return {
        "result": "passed", "ipa": path.name,
        "sha256": checksum,
        "bytes": path.stat().st_size,
        "bundle_identifier": info["CFBundleIdentifier"],
        "executable": executable, "device_family": info["UIDeviceFamily"],
        "platform": info["DTPlatformName"], "minimum_os": info.get("MinimumOSVersion"),
        "metal_library": shader_name, "mach_o_binaries": binaries,
        "bundled_brushes": catalog_report,
        "provisioning_profiles": [], "signatures": [],
        "scope": "Structural validation only; no installation, hardware or parity claim."
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    try:
        report = verify(args.ipa)
    except (ValueError, TypeError, KeyError, OSError, zipfile.BadZipFile, plistlib.InvalidFileException, struct.error) as error:
        print(f"IPA VERIFICATION FAILED: {error}", file=sys.stderr)
        return 1
    output = json.dumps(report, indent=2)
    if args.report:
        args.report.write_text(output + "\n", encoding="utf-8")
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
