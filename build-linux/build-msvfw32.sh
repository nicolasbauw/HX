#!/bin/bash
# Builds MSVFW32.DLL (the DrawDib part of Video for Windows; a DLL HX does not have) on Linux, from this source tree.
# Tools: JWasm and JWlink (as for build-dpmild32.sh) and the import libraries of the official HXDEV package.
# Usage: build-linux/build-msvfw32.sh [WORK_DIR]   (default: /tmp/hx-build)
# The result is WORK_DIR/msvfw32/out/MSVFW32.DLL.
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
B=$W/msvfw32; rm -rf "$B"; mkdir -p "$B/src" "$B/out" "$B/inc"
for f in "$HX"/SrcEmu/MSVFW32/*; do [ -f "$f" ] && cp "$f" "$B/src/$(basename "$f" | tr A-Z a-z)"; done
for d in "$HX/Include" "$W/hxdev/INCLUDE"; do for f in "$d"/*; do [ -f "$f" ] && cp -n "$f" "$B/inc/$(basename "$f" | tr A-Z a-z)"; done; done
cd "$B/src"
$JW -c -coff -nologo -Cp -Sg -D?FLAT=1 -I../inc -I. -Fl=../out/msvfw32 -Fo=../out/msvfw32.obj msvfw32.asm
cd ../out
# JWlink does not resolve the short names of the .RSP on these objects: exports with their decorated names
python3 - <<'PY'
import re,subprocess
syms={}
t=subprocess.run(['objdump','-t','msvfw32.obj'],capture_output=True,text=True).stdout
for m in re.finditer(r'\s(_(\w+)@(\d+))$',t,re.M): syms[m.group(2)]=m.group(1)
names=[l.strip() for l in open('../src/msvfw32.rsp') if re.fullmatch(r'\s*\w+\s*',l) and l.strip() not in ('EXPORT','OPTION')]
open('msvfw32.exp','w').write('OPTION MODNAME=MSVFW32\nEXPORT {\n'+''.join(f" {n}='{syms[n]}'\n" for n in names)+'}\n')
PY
$LK format win pe dll file msvfw32.obj name MSVFW32.DLL libpath "$W/hxdev/LIB" lib DKRNL32.lib,DGDI32.lib op q, map=MSVFW32, implib=MSVFW32 @msvfw32.exp
ls -l MSVFW32.DLL
