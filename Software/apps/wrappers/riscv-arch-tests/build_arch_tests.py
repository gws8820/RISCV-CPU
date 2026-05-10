#!/usr/bin/env python3
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
APP_DIR = Path(__file__).resolve().parent
ARCH_REPO = ROOT / "apps" / "riscv-arch-tests"
CONFIG = APP_DIR / "riscv-cpu-rv32im" / "test_config.yaml"
WORKDIR = ROOT / "build" / "riscv-arch-tests-act"
OUTDIR = ROOT / "build" / "riscv-arch-tests"
CONFIG_NAME = "riscv-cpu-rv32im"
FILTER_ROOT = WORKDIR / "test-filter"


def require_tool(name: str) -> None:
    if shutil.which(name) is None:
        raise SystemExit(f"Missing required tool: {name}")


def run(cmd: list[str], cwd: Path | None = None) -> None:
    print(" ".join(str(part) for part in cmd))
    env = os.environ.copy()
    env.setdefault("BUNDLE_PATH", str(Path.home() / ".bundle"))
    env.setdefault("UV_LINK_MODE", "copy")
    bundle_ruby = Path.home() / ".bundle" / "ruby"
    bundle_roots = [path for path in sorted(bundle_ruby.glob("*")) if path.is_dir()]
    bundle_bins = [str(path / "bin") for path in bundle_roots if (path / "bin").exists()]
    if bundle_roots:
        env.setdefault("GEM_HOME", str(bundle_roots[0]))
        env["GEM_PATH"] = os.pathsep.join(str(path) for path in bundle_roots)
    if bundle_bins:
        env["PATH"] = os.pathsep.join(bundle_bins + [env.get("PATH", "")])
    subprocess.run(cmd, cwd=cwd, env=env, check=True)


def find_test_source(test: str) -> Path:
    rv32i_root = ARCH_REPO / "tests" / "rv32i"
    matches = sorted(rv32i_root.rglob(f"{test}.S"))
    if not matches:
        matches = sorted((ARCH_REPO / "tests").rglob(f"{test}.S"))
    if not matches:
        raise SystemExit(f"No official riscv-arch-test source found for {test}")
    return matches[0]


def prepare_single_test_dir(test: str) -> tuple[Path, str]:
    src = find_test_source(test)
    rel = src.relative_to(ARCH_REPO / "tests")
    dst_root = FILTER_ROOT / test
    if dst_root.exists():
        shutil.rmtree(dst_root)
    shutil.copytree(ARCH_REPO / "tests" / "env", dst_root / "env")
    dst = dst_root / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst_root, src.parent.name


def build_act(extensions: str, jobs: int, test: str | None = None) -> None:
    require_tool("uv")
    require_tool("sail_riscv_sim")
    require_tool("riscv-none-elf-gcc")
    test_dir = ARCH_REPO / "tests"
    if test is not None:
        test_dir, extensions = prepare_single_test_dir(test)
    cmd = [
        "uv",
        "run",
        "--project",
        str(ARCH_REPO),
        "act",
        str(CONFIG),
        "--test-dir",
        str(test_dir),
        "--workdir",
        str(WORKDIR),
        "--extensions",
        extensions,
        "--jobs",
        str(jobs),
        "--fast",
    ]
    run(cmd, cwd=ARCH_REPO)


def find_elf(test: str) -> Path:
    elf_root = WORKDIR / CONFIG_NAME / "elfs"
    matches = sorted(elf_root.rglob(f"{test}.elf"))
    if not matches:
        raise SystemExit(f"No self-check ELF found for {test} under {elf_root}")
    return matches[0]


def convert_elf(elf: Path) -> Path:
    require_tool("riscv-none-elf-objcopy")
    OUTDIR.mkdir(parents=True, exist_ok=True)
    hex_path = OUTDIR / f"{elf.stem}.hex"
    run([
        "riscv-none-elf-objcopy",
        "-O",
        "verilog",
        "--verilog-data-width",
        "4",
        str(elf),
        str(hex_path),
    ])
    print(f"Ready: {hex_path}")
    return hex_path


def clean() -> None:
    if WORKDIR.exists():
        shutil.rmtree(WORKDIR)
    if OUTDIR.exists():
        shutil.rmtree(OUTDIR)


def main() -> int:
    parser = argparse.ArgumentParser(description="Build official riscv-arch-test self-checking HEX images.")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--test", default="I-add-00", help="Test stem to convert, e.g. I-add-00")
    group.add_argument("--all", action="store_true", help="Convert all generated self-check ELFs")
    group.add_argument("--clean", action="store_true", help="Remove generated arch-test build outputs")
    parser.add_argument("--extensions", default="I,M,Zicsr,Zifencei")
    parser.add_argument("--jobs", type=int, default=0)
    args = parser.parse_args()

    if args.clean:
        clean()
        return 0

    build_act(args.extensions, args.jobs, None if args.all else args.test)

    if args.all:
        elf_root = WORKDIR / CONFIG_NAME / "elfs"
        elfs = sorted(elf_root.rglob("*.elf"))
        if not elfs:
            raise SystemExit(f"No self-check ELFs found under {elf_root}")
        for elf in elfs:
            convert_elf(elf)
    else:
        convert_elf(find_elf(args.test))

    return 0


if __name__ == "__main__":
    sys.exit(main())
