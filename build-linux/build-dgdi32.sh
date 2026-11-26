#!/bin/bash
# Builds DGDI32.DLL (HX's GDI32 emulation) on Linux, from this source tree.
# Tools: JWasm and JWlink (as for build-dpmild32.sh) and the import libraries of the official HXDEV package
# (downloaded and checked, they are not part of the sources). No Open Watcom, no DOS.
# Usage: build-linux/build-dgdi32.sh [WORK_DIR]   (default: /tmp/hx-build)
# The result is WORK_DIR/dgdi32/out/DGDI32.DLL.
# Not byte-identical to the DLL of the official package (other tools, other order), but the same sources;
# tested by running programs under Bare86, see the README.
set -e
HX=$(cd "$(dirname "$0")/.." && pwd)
W=${1:-/tmp/hx-build}
HXDEV_URL=https://github.com/Baron-von-Riedesel/HX/releases/download/v2.24/HXDEV224.zip
HXDEV_SHA256=40f7aebe01afd2ab252a43fb3130326b4a7be8d081873bb099be7767852678f1
mkdir -p "$W" && cd "$W"
[ -d jwasm ] || git clone -q --depth 1 https://github.com/Baron-von-Riedesel/JWasm.git jwasm
[ -d jwlink ] || git clone -q --depth 1 https://github.com/Baron-von-Riedesel/jwlink.git jwlink
[ -x jwasm/build/GccUnixR/jwasm ] || (cd jwasm && make -f GccUnix.mak -j8 >/dev/null)
[ -x jwlink/build/jwlinkLR/jwlink ] || (cd jwlink && make -f GccUnix.mak -j8 >/dev/null)
JW=$W/jwasm/build/GccUnixR/jwasm
LK=$W/jwlink/build/jwlinkLR/jwlink
if [ ! -d hxdev ]; then
    mkdir hxdev && curl -fsSL -o hxdev/hxdev.zip "$HXDEV_URL"
    echo "$HXDEV_SHA256  hxdev/hxdev.zip" | sha256sum -c - >/dev/null || { echo "HXDEV224.zip: unexpected SHA-256" >&2; rm -rf hxdev; exit 1; }
    (cd hxdev && unzip -q hxdev.zip)
fi
B=$W/dgdi32; rm -rf "$B"; mkdir -p "$B/src" "$B/out" "$B/inc"
# JWasm looks up included files with the case of the source: lower-case copies.
for f in "$HX"/SrcEmu/DGDI32/*; do [ -f "$f" ] && cp "$f" "$B/src/$(basename "$f" | tr A-Z a-z)"; done
for d in "$HX/Include" "$W/hxdev/INCLUDE"; do for f in "$d"/*; do [ -f "$f" ] && cp -n "$f" "$B/inc/$(basename "$f" | tr A-Z a-z)"; done; done
cd "$B/src"
MODS=$(tr -d '\r' < modules.inc | sed 's/\\//g; s#\./##g; s#^\.##; s/\.asm//I' | tr A-Z a-z | tr -s ' \n' ' ')
for m in $MODS dgdi32; do
    $JW -c -coff -nologo -Cp -Sg -D_GDI32_=1 -I../inc -I. -D?FLAT=1 -Fl=../out/$m -Fo=../out/$m.obj $m.asm >../out/$m.log 2>&1 || { echo "FAILED: $m" >&2; tail -3 ../out/$m.log >&2; exit 1; }
done
cd ../out
OBJS=$(for m in $MODS; do echo -n "$m.obj,"; done)
cp ../src/dgdi32.rsp .
$LK format win pe dll file ${OBJS}dgdi32.obj name DGDI32.DLL libpath "$W/hxdev/LIB" lib DKRNL32.lib op q, map=DGDI32, implib=DGDI32 @dgdi32.rsp
ls -l DGDI32.DLL
