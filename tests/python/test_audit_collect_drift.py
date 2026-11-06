#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""scripts/audit_collect_drift.py 关键纯函数单元测试（stdlib unittest，零依赖）。

网络相关的 probe_* 通过 monkeypatch 模块级 http_get_json 注入 canned 响应，
保证离线、确定性。不触网。
"""
import os
import sys
import tempfile
import unittest
from unittest import mock

SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "..", "scripts")
sys.path.insert(0, os.path.abspath(SCRIPTS_DIR))

import audit_collect_drift as m  # noqa: E402


class ParseVerTupleTest(unittest.TestCase):
    def test_simple(self):
        self.assertEqual(m.parse_ver_tuple("6.8.0"), (6, 8, 0))

    def test_v_prefix(self):
        self.assertEqual(m.parse_ver_tuple("v24.22.2"), (24, 22, 2))

    def test_build_metadata_stripped(self):
        self.assertEqual(m.parse_ver_tuple("21.0.13+9"), (21, 0, 13))

    def test_two_segment_pads_zero(self):
        self.assertEqual(m.parse_ver_tuple("12.2"), (12, 2, 0))

    def test_empty_and_garbage(self):
        self.assertEqual(m.parse_ver_tuple(""), (0, 0, 0))
        self.assertEqual(m.parse_ver_tuple(None), (0, 0, 0))
        self.assertEqual(m.parse_ver_tuple("abc"), (0, 0, 0))


class SemverLevelTest(unittest.TestCase):
    def test_equal_is_none(self):
        self.assertEqual(m.semver_level("6.8.0", "6.8.0"), "none")

    def test_patch_only(self):
        self.assertEqual(m.semver_level("6.8.0", "6.8.1"), "patch")

    def test_minor_only(self):
        self.assertEqual(m.semver_level("12.1.4", "12.2.0"), "minor")

    def test_major(self):
        self.assertEqual(m.semver_level("6.8.0", "7.0.0"), "major")

    def test_older_upstream_is_none(self):
        # 修复回归：minor 降、patch 反高（6.8.0 -> 6.7.9）必须判 none，而非旧的误报 patch
        self.assertEqual(m.semver_level("6.8.0", "6.7.9"), "none")

    def test_two_segment_upstream_is_minor(self):
        self.assertEqual(m.semver_level("12.1.4", "12.2"), "minor")

    def test_two_digit_minor_tuple_order(self):
        # 10 > 9：字典序按数字而非字符串；6.10.0 应判 minor
        self.assertEqual(m.semver_level("6.9.0", "6.10.0"), "minor")

    def test_same_minor_higher_patch(self):
        self.assertEqual(m.semver_level("6.9.0", "6.9.1"), "patch")


class ExtractCommandsTest(unittest.TestCase):
    SAMPLE = """Usage: rea [command]

Commands:
  run        run an analysis
  report     export a report
  web-demo   start web demo
  help       show help
Options:
  --version  print version
"""

    def test_extracts_two_space_indented_commands(self):
        cmds = m.extract_commands_from_help(self.SAMPLE)
        self.assertEqual(cmds, {"run", "report", "web-demo", "help"})

    def test_empty(self):
        self.assertEqual(m.extract_commands_from_help(""), set())

    def test_command_without_trailing_description(self):
        # 命令行尾无描述列（行尾直接结束）也应被抽出
        text = "Commands:\n  run\n  report   export\n"
        self.assertEqual(m.extract_commands_from_help(text), {"run", "report"})


class LoadVersionsTest(unittest.TestCase):
    def test_parses(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "versions.env")
            with open(p, "w", encoding="utf-8") as fh:
                fh.write("# comment\nGHIDRA_VERSION=12.1.4\nJDK_FEATURE=21\n")
                fh.write("# engines = ^22.23.4 || ^24.22.1 || >=26.12.1（note）\n")
                fh.write("REA_NODE_VERSION=24.22.2\n")
            vals, engines = m.load_versions(p)
            self.assertEqual(vals["GHIDRA_VERSION"], "12.1.4")
            self.assertEqual(vals["JDK_FEATURE"], "21")
            self.assertEqual(vals["REA_NODE_VERSION"], "24.22.2")
            self.assertIn("22.23.4", engines)


class FindBaselineTest(unittest.TestCase):
    def _setup(self, d):
        os.makedirs(os.path.join(d, "base"))
        for ver, cmds in [("6.8.0", "run\nreport\n"), ("6.9.0", "run\nreport\nweb\n")]:
            with open(os.path.join(d, "base", "rea-%s.txt" % ver), "w", encoding="utf-8") as fh:
                fh.write(cmds)

    def test_prefers_locked_version(self):
        with tempfile.TemporaryDirectory() as d:
            self._setup(d)
            ver, path, cmds = m.find_baseline(os.path.join(d, "base"), "6.8.0")
            self.assertEqual(ver, "6.8.0")
            self.assertTrue(path.endswith("rea-6.8.0.txt"))
            self.assertEqual(cmds, {"run", "report"})

    def test_falls_back_to_highest(self):
        with tempfile.TemporaryDirectory() as d:
            self._setup(d)
            ver, _, _ = m.find_baseline(os.path.join(d, "base"), "6.7.0")
            self.assertEqual(ver, "6.9.0")

    def test_missing_dir(self):
        ver, path, cmds = m.find_baseline("/nonexistent-dir-xyz", "6.8.0")
        self.assertIsNone(ver)
        self.assertIsNone(path)
        self.assertEqual(cmds, set())


class ProbeGhidraTest(unittest.TestCase):
    def test_three_segment_tag(self):
        data = {
            "tag_name": "Ghidra_12.1.4_build",
            "assets": [{"name": "ghidra_12.1.4_PUBLIC_20260921.zip"}],
        }
        with mock.patch.object(m, "http_get_json", return_value=(data, None)):
            r = m.probe_ghidra("tok")
        self.assertEqual(r["upstream"], "12.1.4")
        self.assertEqual(r["date"], "20260921")
        self.assertEqual(r["build"], "Ghidra_12.1.4_build")

    def test_two_segment_tag(self):
        data = {"tag_name": "Ghidra_12.2_build", "assets": []}
        with mock.patch.object(m, "http_get_json", return_value=(data, None)):
            r = m.probe_ghidra(None)
        self.assertEqual(r["upstream"], "12.2")

    def test_probe_failure_graceful(self):
        with mock.patch.object(m, "http_get_json", return_value=(None, "HTTP 403")):
            r = m.probe_ghidra(None)
        self.assertIsNone(r["upstream"])
        self.assertIn("失败", r["note"])


class ProbeNodeTest(unittest.TestCase):
    def test_picks_same_major_lts(self):
        data = [
            {"version": "v24.22.2", "lts": "Jod"},
            {"version": "v24.0.0", "lts": False},
            {"version": "v22.23.4", "lts": "Jod"},
        ]
        with mock.patch.object(m, "http_get_json", return_value=(data, None)):
            r = m.probe_node("24.22.2")
        self.assertEqual(r["upstream"], "24.22.2")

    def test_failure_graceful(self):
        with mock.patch.object(m, "http_get_json", return_value=(None, "boom")):
            r = m.probe_node("24.22.2")
        self.assertIsNone(r["upstream"])


class ProbeReaTest(unittest.TestCase):
    def test_extracts_version_and_engines(self):
        data = {"version": "6.8.0", "engines": {"node": "^22.23.4 || ^24.22.1 || >=26.12.1"}}
        with mock.patch.object(m, "http_get_json", return_value=(data, None)):
            r = m.probe_rea(None)
        self.assertEqual(r["upstream"], "6.8.0")
        self.assertIn("22.23.4", r["engines_node"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
