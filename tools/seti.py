#!/usr/bin/env python3
"""The icons of the files of Visual Studio Code (the theme Seti, MIT,
github.com/jesseweed/seti-ui through microsoft/vscode): its font of WOFF made
a TrueType font (its tables inflated), and its table of icons (by extension,
by name of file) written as a table of Lua: `{ char, colour }`, and as a
module of Isocron for the editor compiled (examples/editor/icons.isc).
usage: seti.py seti.woff vs-seti-icon-theme.json OUT.ttf OUT.lua [OUT.isc]"""
import json, struct, sys, zlib

def woff_to_ttf(data):
    sig, flavor, length, n, _, total = struct.unpack(">4sIIHHI", data[:20])
    assert sig == b"wOFF", sig
    entries = [struct.unpack(">4sIIII", data[44 + 20 * i:64 + 20 * i]) for i in range(n)]
    tables = []
    for tag, off, clen, olen, chk in entries:
        raw = data[off:off + clen]
        tables.append((tag, zlib.decompress(raw) if clen < olen else raw, chk))
    # the offset table, the records, the tables (each on 4 bytes)
    es = 1
    while es * 2 <= n:
        es *= 2
    head = struct.pack(">IHHHH", flavor, n, es * 16, (es.bit_length() - 1), n * 16 - es * 16)
    at = 12 + 16 * n
    recs, body = b"", b""
    for tag, t, chk in tables:
        recs += struct.pack(">4sIII", tag, chk, at + len(body), len(t))
        body += t + b"\0" * ((4 - len(t) % 4) % 4)
    return head + recs + body

def lua_string(s):
    return '"' + "".join(c if 32 <= ord(c) < 127 and c not in '"\\' else "\\u{%X}" % ord(c) for c in s) + '"'

def isc_module(t, defs):
    def pair(key):
        d = defs[key]
        char = chr(int(d["fontCharacter"].lstrip("\\"), 16))
        return lua_string(char), "0x%sus" % d.get("fontColor", "#CCCCCC").lstrip("#").upper()
    def table(name, entries):
        keys = [k for k, _ in entries]
        pairs = [pair(v) for _, v in entries]
        return ["const %s_KEYS: string[] = [%s];" % (name, ", ".join(lua_string(k) for k in keys)),
                "const %s_CHARS: string[] = [%s];" % (name, ", ".join(c for c, _ in pairs)),
                "const %s_COLORS: u32[] = [%s];" % (name, ", ".join(c.replace("us", "u32") for _, c in pairs))]
    out = ["// The icons of the files of Visual Studio Code (the theme Seti, MIT:",
           "// github.com/jesseweed/seti-ui), made by tools/seti.py: by name of",
           "// file, by extension and by language, each a character of seti.ttf and",
           "// its colour; the lookup of the editor in Lua (editor.lua, kindOf).",
           "import { rgb, Color } from \"../../src/paint\";",
           ""]
    out += table("NAMES", sorted(t["fileNames"].items()))
    out += table("EXTENSIONS", sorted(t["fileExtensions"].items()))
    out += table("LANGUAGES", sorted(t.get("languageIds", {}).items()))
    fc, fcol = pair(t["file"])
    out += ["const FILE_CHAR: string = %s;" % fc, "const FILE_COLOR: u32 = %s;" % fcol.replace("us", "u32"), "",
            "// the language of an extension (those of Visual Studio Code)",
            "const LANGUAGE_EXTS: string[] = [%s];" % ", ".join(lua_string(k) for k in LANGUAGE_OF),
            "const LANGUAGE_IDS: string[] = [%s];" % ", ".join(lua_string(v) for v in LANGUAGE_OF.values()),
            "const NAME_FILES: string[] = [%s];" % ", ".join(lua_string(k) for k in NAME_LANGUAGE),
            "const NAME_IDS: string[] = [%s];" % ", ".join(lua_string(v) for v in NAME_LANGUAGE.values()),
            "",
            "// the icon of the file `name`: by its name, then by its extensions (the",
            "// longest first), then by its language; else the icon of a file",
            "function iconOf(name: string): [string, u32] {",
            "    const low = baseOf(name).toLowerCase();",
            "    const n = findIndex(NAMES_KEYS, (k) => k == low);",
            "    if (n >= 0) {",
            "        return [NAMES_CHARS[n], NAMES_COLORS[n]] as const;",
            "    }",
            "    const b = bytes(low);",
            "    const dots = filter(iota(b.length), (i) => i > 0 && b[i] == 46u8);",
            "    const hits = filter(map(dots, (d) => findIndex(EXTENSIONS_KEYS, (k) => k == low.slice(d + 1, low.length))), (x) => x >= 0);",
            "    if (hits.length > 0) {",
            "        return [EXTENSIONS_CHARS[hits[0]], EXTENSIONS_COLORS[hits[0]]] as const;",
            "    }",
            "    const ext = dots.length > 0 ? low.slice(dots[dots.length - 1] + 1, low.length) : \"\";",
            "    const byName = findIndex(NAME_FILES, (k) => k == low);",
            "    const byExt = findIndex(LANGUAGE_EXTS, (k) => k == ext);",
            "    const language = byName >= 0 ? NAME_IDS[byName] : (byExt >= 0 ? LANGUAGE_IDS[byExt] : \"\");",
            "    const l = findIndex(LANGUAGES_KEYS, (k) => k == language);",
            "    return l >= 0 ? [LANGUAGES_CHARS[l], LANGUAGES_COLORS[l]] as const : [FILE_CHAR, FILE_COLOR] as const;",
            "}",
            "",
            "function baseOf(p: string): string {",
            "    const k = max(p.lastIndexOf(\"/\"), p.lastIndexOf(\"\\\\\"));",
            "    return k < 0 ? p : p.slice(k + 1, p.length);",
            "}",
            "",
            "export function fileIcon(name: string): string {",
            "    const [c, col] = iconOf(name);",
            "    return c;",
            "}",
            "",
            "export function fileIconColor(name: string): Color {",
            "    const [c, col] = iconOf(name);",
            "    return rgb(col);",
            "}"]
    return "\n".join(out) + "\n"

# the languages of extensions and names of files (those of the editor in
# Lua, editor.lua: LANGUAGE_OF, NAME_LANGUAGE)
LANGUAGE_OF = {
    "py": "python", "pyw": "python", "sh": "shellscript", "bash": "shellscript", "zsh": "shellscript",
    "yaml": "yaml", "yml": "yaml", "md": "markdown", "markdown": "markdown", "lua": "lua", "json": "json",
    "jsonc": "jsonc", "jsonl": "jsonl", "js": "javascript", "mjs": "javascript", "cjs": "javascript",
    "jsx": "javascriptreact", "ts": "typescript", "mts": "typescript", "tsx": "typescriptreact",
    "rs": "rust", "go": "go", "c": "c", "h": "c", "cpp": "cpp", "cc": "cpp", "hpp": "cpp", "cs": "csharp",
    "java": "java", "kt": "kotlin", "swift": "swift", "rb": "ruby", "php": "php", "pl": "perl",
    "css": "css", "scss": "scss", "sass": "sass", "less": "less", "html": "html", "htm": "html",
    "xml": "xml", "svg": "xml", "sql": "sql", "bat": "bat", "cmd": "bat", "ps1": "powershell",
    "r": "r", "dart": "dart", "vue": "vue", "tex": "latex", "ini": "properties", "properties": "properties",
    "gradle": "gradle", "groovy": "groovy", "ml": "ocaml", "hs": "haskell", "ex": "elixir", "jl": "julia",
}
NAME_LANGUAGE = {"dockerfile": "dockerfile", "makefile": "makefile", ".gitignore": "ignore", ".dockerignore": "ignore", ".env": "dotenv"}

def main(woff, theme, ttf, out, isc=None):
    open(ttf, "wb").write(woff_to_ttf(open(woff, "rb").read()))
    t = json.load(open(theme))
    defs = t["iconDefinitions"]
    def icon(key):
        d = defs[key]
        # (a character written as CSS does: a backslash, its hexadecimal code)
        char = chr(int(d["fontCharacter"].lstrip("\\"), 16))
        return "{ %s, %s }" % (lua_string(char), lua_string(d.get("fontColor", "#CCCCCC")))
    lines = ["-- The icons of the files of Visual Studio Code (the theme Seti, MIT:",
             "-- github.com/jesseweed/seti-ui), made by tools/seti.py: by extension",
             "-- and by name of file, each { character of seti.ttf, colour }.",
             "SETI = {",
             "  file = %s," % icon(t["file"]),
             "  extensions = {"]
    for ext, key in sorted(t["fileExtensions"].items()):
        lines.append("    [%s] = %s," % (lua_string(ext), icon(key)))
    lines.append("  },")
    lines.append("  names = {")
    for name, key in sorted(t["fileNames"].items()):
        lines.append("    [%s] = %s," % (lua_string(name), icon(key)))
    lines.append("  },")
    lines.append("  languages = {")
    for lang, key in sorted(t.get("languageIds", {}).items()):
        lines.append("    [%s] = %s," % (lua_string(lang), icon(key)))
    lines.append("  },")
    lines.append("}")
    open(out, "w").write("\n".join(lines) + "\n")
    if isc:
        open(isc, "w").write(isc_module(t, defs))

if __name__ == "__main__":
    main(*sys.argv[1:6])
