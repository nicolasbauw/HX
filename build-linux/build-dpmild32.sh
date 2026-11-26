#!/bin/sh
# Builds DPMILD32.EXE (HX's PE loader) on Linux, from this source tree.
# Tools: JWasm and JWlink (Japheth), built here from their sources (gcc and make only).
# Usage: build-linux/build-dpmild32.sh [WORK_DIR]   (default: /tmp/hx-build)
# The result is WORK_DIR/b/ldr/out/DPMILD32.EXE.
# The three assemblies and the link are exactly the commands of Src/DPMILDR/DPMILD32.MAK.
set -e
HX=$(cd "$(dirname "$0")/.." && pwd)
W=${1:-/tmp/hx-build}
mkdir -p "$W" && cd "$W"
[ -d jwasm ] || git clone -q --depth 1 https://github.com/Baron-von-Riedesel/JWasm.git jwasm
[ -d jwlink ] || git clone -q --depth 1 https://github.com/Baron-von-Riedesel/jwlink.git jwlink
[ -x jwasm/build/GccUnixR/jwasm ] || (cd jwasm && make -f GccUnix.mak -j8 >/dev/null)
[ -x jwlink/build/jwlinkLR/jwlink ] || (cd jwlink && make -f GccUnix.mak -j8 >/dev/null)
JW=$W/jwasm/build/GccUnixR/jwasm
LK=$W/jwlink/build/jwlinkLR/jwlink
# JWasm looks up included files with the case of the source: lower-case copy of the sources.
rm -rf b && mkdir -p b/ldr/out b/inc
for f in "$HX"/Src/DPMILDR/*; do [ -f "$f" ] && cp "$f" "b/ldr/$(basename "$f" | tr A-Z a-z)"; done
for f in "$HX"/Include/*; do [ -f "$f" ] && cp "$f" "b/inc/$(basename "$f" | tr A-Z a-z)"; done
cd b/ldr
for m in dpmildr kernel16 peload; do
    $JW -c -nologo -Sg -Fl=out/$m -Fo=out/$m.obj -D?32BIT=1 -D?DEBUG=0 -I../inc $m.asm
done
$LK format dos file "out/dpmildr.obj,out/kernel16.obj,out/peload.obj" name out/DPMILD32.EXE op q, map=out/DPMILD32.MAP
ls -l out/DPMILD32.EXE
