#!/usr/bin/env python3
# --------------------------------------------------------------------------
# SCRIPT:   test_update_dg.py
# --------------------------------------------------------------------------
# ABSTRACT: Verify complete, fail-closed parsing before destructive DG updates.
# CREATED:  260731 BY: Sol(GPT5.6)::Copilot:MAC-00
# UPDATED:  260731 BY: Sol(GPT5.6)::Copilot:MAC-00
# VERSION:  0.3.8
# --------------------------------------------------------------------------

import importlib.util
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
UPDATER_PATH = REPO_ROOT / "examples" / "data-groups" / "update-dg.py"
PATTERNS_PATH = (
    REPO_ROOT / "examples" / "data-groups" / "dg_swagwaf_jailbreak_patterns.conf"
)
TRUSTED_PATH = (
    REPO_ROOT / "examples" / "data-groups" / "dg_swagwaf_trusted_sources.conf"
)

spec = importlib.util.spec_from_file_location("update_dg", UPDATER_PATH)
update_dg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(update_dg)


class DataGroupParserTests(unittest.TestCase):
    def test_shipped_pattern_data_group_has_68_records(self):
        self.assertEqual(len(update_dg.parse_conf(PATTERNS_PATH)), 68)

    def test_escaped_role_keys_are_preserved(self):
        names = {record["name"] for record in update_dg.parse_conf(PATTERNS_PATH)}
        self.assertTrue(
            {'"role":"assistant"', '"role":"developer"', '"role":"system"'}
            <= names
        )

    def test_trusted_source_metadata_is_preserved(self):
        self.assertEqual(
            update_dg.parse_conf(TRUSTED_PATH),
            [
                {
                    "name": "192.0.2.0/24",
                    "data": (
                        "owner=EXAMPLE;service=SYNTHETIC;ticket=CHG0123456;"
                        "expires=2026-12-31"
                    ),
                }
            ],
        )

    def test_malformed_record_rejects_partial_replacement(self):
        content = """ltm data-group internal /Common/broken {
    records {
        "good" {
            data HIGH
        }
        "bad" {
            unsupported HIGH
        }
    }
    type string
}
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "broken.conf"
            path.write_text(content)
            with self.assertRaisesRegex(ValueError, "refusing destructive replacement"):
                update_dg.parse_conf(path)

    def test_inline_malformed_record_rejects_partial_replacement(self):
        content = """ltm data-group internal /Common/broken {
    records {
        "good" { data HIGH }
        "bad" { unsupported HIGH }
    }
    type string
}
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "broken-inline.conf"
            path.write_text(content)
            with self.assertRaisesRegex(ValueError, "refusing destructive replacement"):
                update_dg.parse_conf(path)


if __name__ == "__main__":
    unittest.main()
