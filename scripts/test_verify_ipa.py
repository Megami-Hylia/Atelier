#!/usr/bin/env python3
"""Synthetic in-memory fixtures test rejection rules; these are NOT app builds."""
import plistlib
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

from verify_ipa import macho_slices, verify


def binary(platform=2, signature=False, cpu=0x0100000C):
    command = struct.pack("<IIIIII", 0x32, 24, platform, 0x120000, 0x1A0000, 0)
    if signature:
        command += struct.pack("<IIII", 0x1D, 16, 0, 0)
    return struct.pack("<IIIIIIII", 0xFEEDFACF, cpu, 0, 2, 2 if signature else 1, len(command), 0, 0) + command


class VerificationTests(unittest.TestCase):
    def test_device_arm64_is_accepted(self):
        self.assertEqual(macho_slices(binary())[0]["platform_id"], 2)

    def test_arm64_simulator_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "device"):
            macho_slices(binary(platform=7))

    def test_signature_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "SIGNATURE"):
            macho_slices(binary(signature=True))

    def test_wrong_cpu_and_truncated_commands_are_rejected(self):
        for value in (binary(cpu=0x01000007), binary()[:-1]):
            with self.assertRaises(ValueError):
                macho_slices(value)

    def fixture(self, path, families=None, extra=None):
        info = {"UIDeviceFamily": [2] if families is None else families,
                "CFBundleSupportedPlatforms": ["iPhoneOS"], "DTPlatformName": "iphoneos",
                "CFBundlePackageType": "APPL", "CFBundleExecutable": "Atelier",
                "CFBundleIdentifier": "org.atelier.ipad"}
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("Payload/Atelier.app/Info.plist", plistlib.dumps(info))
            executable = zipfile.ZipInfo("Payload/Atelier.app/Atelier")
            executable.create_system = 3
            executable.external_attr = 0o100755 << 16
            archive.writestr(executable, binary())
            archive.writestr("Payload/Atelier.app/default.metallib", b"MTLB" + bytes(40))
            archive.writestr("Payload/Atelier.app/presets.json", "[]")
            if extra:
                archive.writestr(extra, b"fixture")

    def test_container_rules(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "synthetic-test-fixture.zip"
            self.fixture(fixture)
            self.assertEqual(verify(fixture)["result"], "passed")
            for families, extra in (([1, 2], None), ([2], "Payload/Atelier.app/embedded.mobileprovision"),
                                    ([2], "../escape"), ([2], "Parent/Payload/Atelier.app/unused")):
                self.fixture(fixture, families=families, extra=extra)
                with self.assertRaises(ValueError):
                    verify(fixture)


if __name__ == "__main__":
    unittest.main()
