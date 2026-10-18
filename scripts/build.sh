#!/usr/bin/env bash
# Build the relocatable Linux x86_64 toolchain bundle.
# Runs as root inside ubuntu:22.04 (amd64): the GitHub workflow or a local Lima/Rosetta container.
#   OUT=/out bash scripts/build.sh      -> $OUT/<bundle>.tar.xz, SHA256SUMS, BUILD-INFO.txt
set -euo pipefail
CHEZ_TAG="${CHEZ_TAG:-v10.1.0}"; IDRIS_TAG="${IDRIS_TAG:-v0.7.0}"
BUNDLE="wf-toolchain-linux-x86_64-chez${CHEZ_TAG#v}-idris2-${IDRIS_TAG#v}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$HERE/out}"; WORK="${WORK:-/tmp/wfbuild}"; P="$WORK/tools"
JOBS="$(nproc)"
IDRIS_JOBS="${IDRIS_JOBS:-1}"   # the Idris2 bootstrap is memory-hungry; -j4 is OOM-killed in 4 GB
mkdir -p "$OUT" "$WORK"
# REUSE=1 keeps an already-built $P (iterate on packaging/tests without recompiling)
if [ "${REUSE:-0}" != 1 ]; then rm -rf "$P"; fi

[ "$(uname -m)" = x86_64 ] || { echo "must run on x86_64 (got $(uname -m))"; exit 1; }
export DEBIAN_FRONTEND=noninteractive
SUDO=""; [ "$(id -u)" = 0 ] || SUDO=sudo
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq build-essential libgmp-dev libncurses-dev uuid-dev xz-utils git ca-certificates curl python3 binutils lsb-release >/dev/null

if [ -x "$P/idris2/bin/idris2" ] && [ "${REUSE:-0}" = 1 ]; then echo "== REUSE: skipping compile"; export PATH="$P/chez/bin:$PATH"; else
echo "== Chez $CHEZ_TAG"
rm -rf "$WORK/ChezScheme"
git clone -q --recurse-submodules --depth 1 --branch "$CHEZ_TAG" https://github.com/cisco/ChezScheme "$WORK/ChezScheme"
( cd "$WORK/ChezScheme" && ./configure --threads --disable-x11 --installprefix="$P/chez" >/dev/null && make -j"$JOBS" >/dev/null && make install >/dev/null )
"$P/chez/bin/scheme" --version

echo "== Idris2 $IDRIS_TAG"
export PATH="$P/chez/bin:$PATH"   # the bootstrap idris2.so starts with "#!/usr/bin/env scheme"
rm -rf "$WORK/Idris2"
git clone -q --depth 1 --branch "$IDRIS_TAG" https://github.com/idris-lang/Idris2 "$WORK/Idris2"
( cd "$WORK/Idris2" && make bootstrap SCHEME="$P/chez/bin/scheme" PREFIX="$P/idris2" -j"$IDRIS_JOBS" >/dev/null && make install SCHEME="$P/chez/bin/scheme" PREFIX="$P/idris2" >/dev/null )

fi

echo "== relocatable launcher"
L="$P/idris2/bin/idris2"
echo "--- launcher before:"; cat "$L"
head -c 2 "$P/idris2/bin/idris2_app/idris2.so" 2>/dev/null | grep -q '#!' && echo "(idris2.so carries a shebang)"
python3 - "$L" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
if '--program "$DIR/idris2_app/idris2.so"' in s: print("already patched"); sys.exit(0)
s2, n = re.subn(r'(?m)^(\s*(?:exec\s+)?)"\$DIR/idris2_app/idris2\.so"', r'\1"${SCHEME:-scheme}" --program "$DIR/idris2_app/idris2.so"', s)
if n == 0: sys.exit("launcher line not found: inspect bin/idris2 above")
open(p, "w").write(s2); print(f"patched {n} line(s)")
PY
cp "$HERE/toolchain-env.sh" "$P/toolchain-env.sh"

echo "== runtime libraries"
mkdir -p "$P/lib"
ldd "$P/chez/bin/scheme" "$P"/idris2/bin/idris2_app/*.so "$P"/idris2/lib/*.so 2>/dev/null | tee "$P/LDD.txt" || true
if grep -q 'libgmp' "$P/LDD.txt"; then cp -L "$(ldconfig -p | awk '/libgmp\.so\.10 /{print $NF; exit}')" "$P/lib/"; echo "vendored libgmp"; fi
objdump -T "$P/chez/bin/scheme" | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1 > "$P/MIN_GLIBC.txt"

echo "== relocation test: other path, empty env, no system scheme"
T="$WORK/elsewhere"; rm -rf "$T"; mkdir -p "$T"; cp -a "$P" "$T/.tools"
printf 'module Main\nmain : IO ()\nmain = putStrLn "toolchain ok"\n' > "$T/Hello.idr"
env -i HOME="$WORK" PATH=/usr/bin:/bin bash -c "
  set -e
  if command -v scheme >/dev/null; then echo 'system scheme visible'; exit 1; fi
  source '$T/.tools/toolchain-env.sh'
  scheme --version
  idris2 --version
  cd '$T' && idris2 Hello.idr -o hello && ./build/exec/hello
" 2>&1 | tee "$WORK/RELOCATION-TEST.txt"
grep -q "toolchain ok" "$WORK/RELOCATION-TEST.txt"

echo "== package"
{ uname -a; lsb_release -ds 2>/dev/null; ldd --version | head -1; echo "min glibc needed: $(cat "$P/MIN_GLIBC.txt")"; echo "chez $CHEZ_TAG idris2 $IDRIS_TAG"; echo; cat "$WORK/RELOCATION-TEST.txt"; } > "$P/BUILD-INFO.txt"
tar -C "$P" -cf - . | xz -9 -T0 > "$OUT/$BUNDLE.tar.xz"
cp "$P/BUILD-INFO.txt" "$OUT/"
( cd "$OUT" && sha256sum "$BUNDLE.tar.xz" > SHA256SUMS && cat SHA256SUMS && ls -la "$BUNDLE.tar.xz" )
