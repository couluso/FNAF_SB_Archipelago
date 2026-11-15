"""Makes the two release files: release/fnaf_sb.apworld and release/FNaF_SB_Ap.zip."""
import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent
OUT = ROOT / "release"
SKIP_DIRS = {"__pycache__", "test"}


def files(folder):
    for path in sorted(folder.rglob("*")):
        rel = path.relative_to(folder)
        if path.is_file() and not SKIP_DIRS.intersection(rel.parts):
            yield path, rel


def build_apworld():
    pkg = ROOT / "worlds" / "fnaf_sb"
    target = OUT / "fnaf_sb.apworld"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as z:
        for path, rel in files(pkg):
            z.write(path, pathlib.Path("fnaf_sb") / rel)
    return target


def build_mod():
    mod = ROOT / "mod" / "FNaF_SB_Ap"
    target = OUT / "FNaF_SB_Ap.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as z:
        for path, rel in files(mod):
            if rel.name in ("log.txt", "log_previous.txt", "trace.txt", "trace_previous.txt") or (rel.parts[0] == "bridge" and rel.name != ".keep"):
                continue
            z.write(path, pathlib.Path("FNaF_SB_Ap") / rel)
        for name in ("LICENSE", "LICENSING.md"):
            z.write(ROOT / name, pathlib.Path("FNaF_SB_Ap") / name)
        for path in sorted((ROOT / "licenses").iterdir()):
            z.write(path, pathlib.Path("FNaF_SB_Ap") / "licenses" / path.name)
    return target


def main():
    OUT.mkdir(exist_ok=True)
    for target in (build_apworld(), build_mod()):
        print(f"{target.relative_to(ROOT)}  {target.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
