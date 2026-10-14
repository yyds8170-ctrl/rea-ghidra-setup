#!/usr/bin/env node
/*
 * scripts/verify-check.js — 跨平台（Linux / macOS / Windows）统一的 REA 结果断言。
 *
 * 三个 verify 脚本（verify.sh / verify-macos.sh / verify.ps1）都用 Node 调用本文件，
 * 保证「analyze / decompile / 无符号 / 函数名解析」的断言逻辑在各平台完全一致。
 *
 * 用法：
 *   node scripts/verify-check.js analyze    <analyze.json>   <format: elf|mach|pe>
 *   node scripts/verify-check.js decompile  <decompile.json> <wantName> <hexConst>
 *   node scripts/verify-check.js count      <analyze.json>   <minProcedures>
 *   node scripts/verify-check.js funcname   <search.json>    <nameSubstr>
 *
 * 成功 exit 0，失败 exit 1；funcname 永远 exit 0（只打印解析到的名字，空=未找到）。
 */
'use strict';
const fs = require('fs');

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

const [, , mode, ...args] = process.argv;
let ok = false;
let line = '';

try {
  if (mode === 'analyze') {
    const [file, formatTok] = args;
    const j = readJson(file);
    const s = j.subject || {};
    const n = j.normalized_result || {};
    const fmt = String(s.format || '').toLowerCase();
    const procs = Number(n.procedure_count || 0);
    const strs = Number(n.string_count || 0);
    ok = fmt.includes(formatTok) && procs >= 3 && strs > 0;
    line = `format=${s.format} arch=${s.architecture} procs=${procs} strings=${strs}`;
  } else if (mode === 'decompile') {
    const [file, wantName, hexConst] = args;
    const j = readJson(file);
    const code = String(j.normalized_result || '');
    const hasName = code.includes(wantName);
    const hasConst = code.includes(hexConst);
    ok = j.confidence === 'observed' && hasName && hasConst;
    line = `confidence=${j.confidence} name=${hasName} const_${hexConst}=${hasConst}`;
  } else if (mode === 'count') {
    const [file, minStr] = args;
    const j = readJson(file);
    const procs = Number((j.normalized_result || {}).procedure_count || 0);
    ok = procs >= Number(minStr);
    line = `procedures=${procs}`;
  } else if (mode === 'funcname') {
    // 解析 `rea search --kind procedures` 的结果，返回包含目标子串的真实函数名
    const [file, sub] = args;
    const j = readJson(file);
    const arr = Array.isArray(j.normalized_result) ? j.normalized_result : [];
    const hit = arr.map((x) => x && x.value).find((v) => v && String(v).includes(sub));
    process.stdout.write(hit ? String(hit) : '');
    process.exit(0);
  } else {
    process.stderr.write(`未知模式：${mode}\n`);
    process.exit(2);
  }
} catch (e) {
  line = `读取/解析 JSON 失败：${e.message}`;
  ok = false;
}

process.stdout.write(`${ok ? 'PASS' : 'FAIL'}|${line}\n`);
process.exit(ok ? 0 : 1);
