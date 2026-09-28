#!/usr/bin/env python3
# 两阶段引用闭包：非 Synty 文件为根，解析引用；命中的 Synty 资源再继续解析其依赖，直到不动为止
import os, re

ROOT = os.path.dirname(os.path.abspath(__file__))
SKIP_DIRS = {".git", ".godot", "dist", "__pycache__"}
TEXT_EXT = {".gd", ".tscn", ".tres", ".godot", ".cfg", ".gdshader"}

ref_re = re.compile(r'res://[A-Za-z0-9_./\-() ]+?\.(?:tscn|tres|gd|glb|gltf|fbx|png|jpg|jpeg|tga|ogg|wav|mp3|otf|ttf|res|mesh|material|shader|gdshader|theme|translation|csv)', re.I)
const_re = re.compile(r'^\s*(?:const|var)\s+([A-Z][A-Z0-9_]+)\s*:?=\s*"(res://[^"]+)"', re.M)
concat_re = re.compile(r'([A-Z][A-Z0-9_]+)\s*\+\s*"([^"]+\.(?:tscn|tres|glb|fbx|png|res|mesh))"')

files = []
texts = {}   # rel -> content
consts = {}
for dp, dn, fn in os.walk(ROOT):
    dn[:] = [d for d in dn if d not in SKIP_DIRS]
    for f in fn:
        p = os.path.join(dp, f)
        rel = os.path.relpath(p, ROOT).replace("\\", "/")
        files.append(rel)
        ext = os.path.splitext(f)[1].lower()
        if ext in TEXT_EXT or f in ("project.godot", "export_presets.cfg"):
            txt = open(p, encoding="utf-8", errors="ignore").read()
            texts[rel] = txt
            for m in const_re.finditer(txt):
                consts[m.group(1)] = m.group(2)

realmap = {rel.lower(): rel for rel in files}

def resolve(u):
    r = u[6:].strip().lstrip("/")
    return realmap.get(r.lower())

def refs_of(txt):
    out = set()
    for m in ref_re.finditer(txt):
        r = resolve(m.group(0))
        if r:
            out.add(r)
    for m in concat_re.finditer(txt):
        base = consts.get(m.group(1))
        if base:
            r = resolve(base + m.group(2))
            if r:
                out.add(r)
    return out

# 阶段 1：根 = 所有非 Synty 文本文件 + project.godot
used = set()
for rel, txt in texts.items():
    if rel.startswith("assets/Synty/"):
        continue
    used |= refs_of(txt)

# 阶段 2：闭包——命中的 Synty 文本资源继续解析
frontier = [r for r in used if r.startswith("assets/Synty/") and r in texts]
seen = set(frontier)
while frontier:
    cur = frontier.pop()
    for r in refs_of(texts[cur]):
        if r not in used:
            used.add(r)
        if r.startswith("assets/Synty/") and r in texts and r not in seen:
            seen.add(r)
            frontier.append(r)

excl = []
for rel in files:
    if not rel.startswith("assets/Synty/"):
        continue
    ext = os.path.splitext(rel)[1].lower()
    if ext in (".import", ".unwrap_cache", ".md", ".txt"):
        continue
    if rel not in used:
        excl.append(rel)

excl.sort()
total = sum(os.path.getsize(os.path.join(ROOT, r)) for r in excl)
print("files:", len(files), "used:", len(used), "synty_used:", len(seen))
print("excludable:", len(excl), "size: %.1f MB" % (total / 1048576))
with open(os.path.join(ROOT, "synty_exclude.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(excl))
musts = [
    "assets/Synty/PolygonCity/Models/extracted/SM_Bld_Shop_01.res",
    "assets/Synty/Animations/A_Idle_Standing_Masc.fbx",
    "assets/Synty/PolygonApocalypse/Models/extracted/SM_Chr_Zombie_Male_01.mesh",
    "assets/Synty/PolygonApocalypse/Models/extracted/SM_Chr_Zombie_Male_01_skin.tres",
]
for m in musts:
    print("KEEP?", m, "->", m not in excl, "exists:", os.path.exists(os.path.join(ROOT, m)))
