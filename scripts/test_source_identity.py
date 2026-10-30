import tempfile
import unittest
from pathlib import Path
from source_identity import identify


class SourceIdentityTests(unittest.TestCase):
    def test_detects_modified_and_untracked_inputs_and_ignores_outputs(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'Atelier').mkdir()
            source = root / 'Atelier/Example.swift'
            source.write_text('first')
            first = identify(root)
            self.assertEqual(first, identify(root))
            (root / 'work').mkdir()
            (root / 'work/report.json').write_text('{}')
            self.assertEqual(first, identify(root))
            source.write_text('second')
            self.assertNotEqual(first['source_sha256'], identify(root)['source_sha256'])
            second = identify(root)
            (root / 'Atelier/New.swift').write_text('new')
            self.assertNotEqual(second['source_sha256'], identify(root)['source_sha256'])


if __name__ == '__main__':
    unittest.main()
