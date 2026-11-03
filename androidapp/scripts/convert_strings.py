#!/usr/bin/env python3
"""Convierte los Localizable.strings de iOS a strings.xml de Android.

Las claves con puntos (`dashboard.title`) pasan a guiones bajos (`dashboard_title`).
`StringRes.key("dashboard.title")` hace la misma conversión en tiempo de ejecución.
"""
import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
IOS = ROOT / "iosapp/TerritoryTool/TerritoryTool/Resources"
RES = ROOT / "androidapp/app/src/main/res"
LINE = re.compile(r'^\s*"((?:[^"\\]|\\.)+)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')
FMT = re.compile(r'%(\d+\$)?(\.\d+)?([@dfs])')


def parse(path):
    entries = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        m = LINE.match(line)
        if m:
            entries[m.group(1)] = m.group(2)
    return entries


def android_key(key):
    return re.sub(r"[^A-Za-z0-9_]", "_", key)


def android_value(value):
    value = value.replace('\\"', '"').replace("\\n", "\n")
    matches = list(FMT.finditer(value))
    positional = len(matches) > 1

    def repl(m):
        repl.i += 1
        pos = m.group(1) or (f"{repl.i}$" if positional else "")
        conv = "s" if m.group(3) == "@" else m.group(3)
        return f"%{pos}{m.group(2) or ''}{conv}"

    repl.i = 0
    value = FMT.sub(repl, value)
    # `%` sueltos que no son especificadores.
    value = re.sub(r"%%|%(?!(\d+\$)?(\.\d+)?[dfs])", "%%", value)
    value = escape(value).replace("'", "\\'").replace('"', '\\"').replace("\n", "\\n")
    if value.startswith("@") or value.startswith("?"):
        value = "\\" + value
    return value


def write(entries, out, extra=None):
    lines = ['<?xml version="1.0" encoding="utf-8"?>', "<resources>"]
    if extra:
        lines.extend(extra)
    seen = set()
    for key, value in entries.items():
        akey = android_key(key)
        if akey in seen:
            continue
        seen.add(akey)
        lines.append(f'    <string name="{akey}">{android_value(value)}</string>')
    lines.append("</resources>")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")


en = parse(IOS / "en.lproj/Localizable.strings")
es = parse(IOS / "es.lproj/Localizable.strings")
base = dict(en)
for k, v in es.items():
    base.setdefault(k, v)
spanish = dict(es)
for k, v in en.items():
    spanish.setdefault(k, v)

write(base, RES / "values/strings.xml", ['    <string name="app_name" translatable="false">Territory Tool</string>'])
write(spanish, RES / "values-es/strings.xml")
print(f"{len(base)} strings", file=sys.stderr)
