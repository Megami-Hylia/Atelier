#!/usr/bin/env python3
"""Verify a real unsigned iPad device IPA; needs only Python's standard library."""
import argparse
import hashlib
import json
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


def require(condition, message):
    if not condition:
        raise ValueError(message)


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
        require(any(name.endswith(".json") for name in names), "No bundled preset JSON found")
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
    except (ValueError, KeyError, OSError, zipfile.BadZipFile, plistlib.InvalidFileException, struct.error) as error:
        print(f"IPA VERIFICATION FAILED: {error}", file=sys.stderr)
        return 1
    output = json.dumps(report, indent=2)
    if args.report:
        args.report.write_text(output + "\n", encoding="utf-8")
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
