#!/usr/bin/env python3
# 精简导出：按 synty_exclude.txt 临时移走未引用的 Synty 资源，导出后原样恢复
import os, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
STASH = os.path.join(ROOT, ".synty_stash")
GODOT = os.path.expandvars(
    r"%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
)

def main() -> int:
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.expanduser("~"), "Desktop", "试玩版.exe")
    with open(os.path.join(ROOT, "synty_exclude.txt"), encoding="utf-8") as f:
        excl = [ln.strip() for ln in f if ln.strip()]
    moved = []
    try:
        for rel in excl:
            src = os.path.join(ROOT, rel)
            if not os.path.exists(src):
                continue
            dst = os.path.join(STASH, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.move(src, dst)
            moved.append(rel)
            # .import 附属文件一并移走（存在的话）
            imp = src + ".import"
            if os.path.exists(imp):
                shutil.move(imp, dst + ".import")
        print("moved:", len(moved), flush=True)
        r = subprocess.run(
            [GODOT, "--headless", "--path", ROOT, "--export-release", "Windows Desktop", out],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=2400,
        )
        print(r.stdout[-2000:])
        print(r.stderr[-2000:], file=sys.stderr)
        if r.returncode != 0:
            print("EXPORT FAILED rc=%d" % r.returncode)
            return 1
        if not os.path.exists(out):
            print("EXPORT FAILED: no output file")
            return 1
        print("EXPORT OK -> %s (%.1f MB)" % (out, os.path.getsize(out) / 1048576))
        return 0
    finally:
        # 无论成败都把素材放回原位
        for rel in reversed(moved):
            src = os.path.join(STASH, rel)
            dst = os.path.join(ROOT, rel)
            if os.path.exists(src):
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.move(src, dst)
            if os.path.exists(src + ".import"):
                shutil.move(src + ".import", dst + ".import")
        shutil.rmtree(STASH, ignore_errors=True)
        print("restored", flush=True)

if __name__ == "__main__":
    sys.exit(main())
