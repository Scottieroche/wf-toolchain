# toolchain-env.sh — ships INSIDE the bundle at .tools/toolchain-env.sh.
# Location-relative: works wherever the bundle is unpacked.
_WF_TC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export PATH="$_WF_TC/chez/bin:$_WF_TC/idris2/bin:$PATH"
export SCHEME="$_WF_TC/chez/bin/scheme"
export CHEZ="$SCHEME"                                   # idris2 uses $CHEZ to compile user programs
export SCHEMEHEAPDIRS="$(ls -d "$_WF_TC"/chez/lib/csv*/*/ 2>/dev/null | head -1)"   # chez boot files
export IDRIS2_PREFIX="$_WF_TC/idris2"
export IDRIS2="$_WF_TC/idris2/bin/idris2"
[ -d "$_WF_TC/lib" ] && export LD_LIBRARY_PATH="$_WF_TC/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
unset _WF_TC
