#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""packaging/rea-ghidra-setup.spdx.json 文档自校验（stdlib，离线）。

断言：
  - SPDX 2.3 必填字段存在且形状合法；
  - 5 个 package 的 name/versionInfo/downloadLocation/licenseConcluded/checksum 齐全；
  - DESCRIBES / DEPENDS_ON 关系完整；
  - 文档内组件版本与 config/versions.env 一致；
  - 若环境变量 OFFLINE_DIR 指向真实离线清单，则 checksum 与清单逐件一致
    （未提供则 skip，不失败）。
"""
import json
import os
import re
import sys
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SBOM_PATH = os.path.join(REPO_ROOT, "packaging", "rea-ghidra-setup.spdx.json")
VERSIONS_PATH = os.path.join(REPO_ROOT, "config", "versions.env")


def load_versions(path):
    vals = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            s = line.strip()
            if s and not s.startswith("#") and "=" in s:
                k, v = s.split("=", 1)
                vals[k.strip()] = v.strip()
    return vals


class SpdxSelfCheckTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(SBOM_PATH, encoding="utf-8") as fh:
            cls.doc = json.load(fh)
        cls.versions = load_versions(VERSIONS_PATH)
        cls.pkgs = {p["name"]: p for p in cls.doc["packages"]}

    def test_document_required_fields(self):
        self.assertEqual(self.doc["spdxVersion"], "SPDX-2.3")
        self.assertEqual(self.doc["dataLicense"], "CC0-1.0")
        self.assertEqual(self.doc["SPDXID"], "SPDXRef-DOCUMENT")
        self.assertTrue(self.doc["documentNamespace"].startswith("https://"))
        self.assertRegex(self.doc["creationInfo"]["created"], r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
        self.assertGreater(len(self.doc["creationInfo"]["creators"]), 0)

    def test_packages_fields(self):
        expected = {
            "rea-ghidra-setup", "Eclipse Temurin OpenJDK", "NSA Ghidra",
            "Node.js", "rea-agents",
        }
        self.assertEqual(set(self.pkgs), expected)
        for name, p in self.pkgs.items():
            self.assertTrue(p["SPDXID"].startswith("SPDXRef-Package-"), name)
            self.assertTrue(p["versionInfo"], name)
            self.assertTrue(p["downloadLocation"], name)
            self.assertIn("licenseConcluded", p)

    def test_runtime_packages_have_sha256(self):
        for name in ("Eclipse Temurin OpenJDK", "NSA Ghidra", "Node.js", "rea-agents"):
            cs = self.pkgs[name].get("checksums", [])
            self.assertEqual(len(cs), 1, name)
            self.assertEqual(cs[0]["algorithm"], "SHA256", name)
            self.assertRegex(cs[0]["checksumValue"], r"^[0-9a-f]{64}$", name)

    def test_relationships(self):
        rels = {(r["spdxElementId"], r["relationshipType"], r["relatedSpdxElement"])
                for r in self.doc["relationships"]}
        self.assertIn(("SPDXRef-DOCUMENT", "DESCRIBES", "SPDXRef-Package-wrapper"), rels)
        for dep in ("jdk", "ghidra", "node", "rea"):
            self.assertIn(("SPDXRef-Package-wrapper", "DEPENDS_ON", "SPDXRef-Package-" + dep), rels)

    def test_versions_match_versions_env(self):
        v = self.versions
        self.assertEqual(self.pkgs["NSA Ghidra"]["versionInfo"], v["GHIDRA_VERSION"])
        self.assertEqual(self.pkgs["Node.js"]["versionInfo"], v["REA_NODE_VERSION"])
        self.assertEqual(self.pkgs["rea-agents"]["versionInfo"], v["REA_VERSION"])
        self.assertEqual(self.pkgs["Eclipse Temurin OpenJDK"]["versionInfo"], v["JDK_FEATURE"])
        with open(os.path.join(REPO_ROOT, "VERSION"), encoding="utf-8") as fh:
            wrapper_ver = fh.read().strip()
        self.assertEqual(self.pkgs["rea-ghidra-setup"]["versionInfo"], wrapper_ver)

    def test_checksums_match_offline_manifest(self):
        offline = os.environ.get("OFFLINE_DIR", "")
        manifest = os.path.join(offline, "SHA256SUMS.txt") if offline else ""
        if not manifest or not os.path.isfile(manifest):
            self.skipTest("OFFLINE_DIR 未提供或清单缺失，跳过哈希比对")
        want = {}
        with open(manifest, encoding="utf-8") as fh:
            for line in fh:
                parts = line.split()
                if len(parts) >= 2:
                    want[parts[1]] = parts[0].lower()
        v = self.versions
        basename = {
            "Eclipse Temurin OpenJDK": "jdk21-linux-x64.tar.gz",
            "NSA Ghidra": "ghidra_%s_PUBLIC_%s.zip" % (v["GHIDRA_VERSION"], v["GHIDRA_DATE"]),
            "Node.js": "node-v%s-linux-x64.tar.gz" % v["REA_NODE_VERSION"],
            "rea-agents": "rea-agents-%s.tgz" % v["REA_VERSION"],
        }
        for name, base in basename.items():
            self.assertIn(base, want, "清单缺 %s" % base)
            self.assertEqual(self.pkgs[name]["checksums"][0]["checksumValue"], want[base], name)


if __name__ == "__main__":
    unittest.main(verbosity=2)
