#!/usr/bin/env bash
# Download and unpack the Linux x86_64 toolchain into <target>/.tools (default: ./.tools).
#   curl -fsSL https://raw.githubusercontent.com/Scottieroche/wf-toolchain/main/fetch.sh | bash -s -- /path/to/writing-factory
set -euo pipefail
TARGET="${1:-.}/.tools"; TAG="${WF_TOOLCHAIN_TAG:-linux-x86_64-v1}"
BASE="https://github.com/Scottieroche/wf-toolchain/releases/download/$TAG"
B=wf-toolchain-linux-x86_64-chez10.1.0-idris2-0.7.0.tar.xz
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
curl -fsSL -o "$T/$B" "$BASE/$B"
curl -fsSL -o "$T/SHA256SUMS" "$BASE/SHA256SUMS"
(cd "$T" && sha256sum -c SHA256SUMS)
mkdir -p "$TARGET" && xz -dc "$T/$B" | tar -C "$TARGET" -xf -
echo "unpacked into $TARGET — now: source $TARGET/toolchain-env.sh   (writing-factory's .tools/env.sh does this for you)"
