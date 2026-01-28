import re
import subprocess
import sys
from pathlib import Path


TOTAL_RE = re.compile(r"^Total:\s+(?P<hit>\d+)/(?P<tot>\d+)\s*$")


def pct(hit: int, tot: int) -> float:
    return 100.0 if tot == 0 else 100.0 * hit / tot


def is_excluded(pkg: str) -> bool:
    return pkg.startswith("cmd/") or pkg.startswith("io/") or pkg == "."


def discover_packages(repo_root: Path) -> list[str]:
    pkgs: set[str] = set()
    for name in ("moon.pkg", "moon.pkg.json"):
        for pkg_file in repo_root.rglob(name):
            rel_parent = pkg_file.parent.relative_to(repo_root).as_posix()
            if rel_parent.startswith(("_build/", "target/", ".git/", ".mooncakes/")):
                continue
            pkgs.add(rel_parent if rel_parent else ".")
    return sorted(pkgs)


def run_pkg_summary(pkg: str) -> tuple[int, int]:
    try:
        proc = subprocess.run(
            ["moon_cove_report", "-p", pkg, "-f", "summary"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except subprocess.CalledProcessError as e:
        msg = (e.stdout or "") + (e.stderr or "")
        if "No coverage source data found" in msg:
            raise RuntimeError(f"no coverage data for package {pkg}") from None
        raise
    hit = tot = None
    for line in proc.stdout.splitlines():
        m = TOTAL_RE.match(line.strip())
        if m:
            hit = int(m.group("hit"))
            tot = int(m.group("tot"))
    if hit is None or tot is None:
        raise RuntimeError(f"missing Total line for package {pkg}")
    return hit, tot


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: scripts/coverage_gate.py <threshold_percent>", file=sys.stderr)
        return 2

    try:
        threshold = float(sys.argv[1])
    except ValueError:
        print(f"invalid threshold: {sys.argv[1]}", file=sys.stderr)
        return 2

    repo_root = Path.cwd()
    pkgs = [p for p in discover_packages(repo_root) if not is_excluded(p)]

    rows: list[tuple[float, str, int, int]] = []
    failing: list[tuple[float, str, int, int]] = []

    for pkg in pkgs:
        try:
            hit, tot = run_pkg_summary(pkg)
        except RuntimeError as e:
            # Test-only packages (e.g. e2e) may not have coverage sources.
            if str(e).startswith("no coverage data for package "):
                continue
            raise
        p = pct(hit, tot)
        rows.append((p, pkg, hit, tot))
        if p + 1e-9 < threshold:
            failing.append((p, pkg, hit, tot))

    rows.sort(key=lambda r: (r[0], r[1]))
    failing.sort(key=lambda r: (r[0], r[1]))

    print(f"coverage threshold: {threshold:.2f}% (excluding cmd/* and io/*)")
    for p, pkg, hit, tot in rows:
        print(f"{pkg:20s} {hit:5d}/{tot:<5d} {p:6.2f}%")

    if failing:
        print("\nFAILED packages:")
        for p, pkg, hit, tot in failing:
            print(f"  {pkg} {hit}/{tot} {p:.2f}%")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
