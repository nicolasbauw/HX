#!/bin/bash
# Builds VESA32.DLL (HX's VESA library) on Linux, from this source tree. Tools: JWasm and JWlink (as for
# build-dpmild32.sh); no import libraries are needed. The result is WORK_DIR/vesa32/out/VESA32.DLL.
# Usage: build-linux/build-vesa32.sh [WORK_DIR]   (default: /tmp/hx-build)
# Built from the unmodified upstream sources it has the size of the official DLL (9216 bytes).
# JWlink does not resolve the short names of VESA32.RSP on these objects ("FUZZYEXPORT"): the exports are
# written with their decorated names (_Name@N) found in the object files.
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
B=$W/vesa32; rm -rf "$B"; mkdir -p "$B/src" "$B/out" "$B/inc"
for f in "$HX"/Src/VESA32/*; do [ -f "$f" ] && cp "$f" "$B/src/$(basename "$f" | tr A-Z a-z)"; done
for f in "$HX"/Include/*; do [ -f "$f" ] && cp "$f" "$B/inc/$(basename "$f" | tr A-Z a-z)"; done
cd "$B/src"
MODS=$(tr -d '\r' < modules.inc | sed 's/\\//g; s#\./##g; s#^\.##; s/\.asm//I' | tr A-Z a-z | tr -s ' \n' ' ')
for m in $MODS vesa32; do
    $JW -c -coff -nologo -Sg -D?FLAT=1 -D_VESA32_=1 -I../inc -I. -Fl=../out/$m -Fo=../out/$m.obj $m.asm >../out/$m.log 2>&1 || { echo "FAILED: $m" >&2; tail -3 ../out/$m.log >&2; exit 1; }
done
cd ../out
OBJS=$(for m in $MODS vesa32; do echo -n "$m.obj,"; done); OBJS=${OBJS%,}
python3 - <<'PY'
import re,subprocess,glob
syms={}
for f in glob.glob('*.obj'):
    t=subprocess.run(['objdump','-t',f],capture_output=True,text=True).stdout
    for m in re.finditer(r'\s(_(\w+)@(\d+))$',t,re.M): syms[m.group(2)]=m.group(1)
names=[l.strip() for l in open('../src/vesa32.rsp') if re.fullmatch(r'\s*\w+\s*',l) and l.strip() not in ('EXPORT','OPTION')]
open('vesa32.exp','w').write('EXPORT {\n'+''.join(f" {n}='{syms[n]}'\n" if n in syms else f" {n}\n" for n in names)+'}\n')
PY
$LK format win pe dll file $OBJS name VESA32.DLL op q, map=VESA32, implib=VESA32 @vesa32.exp
ls -l VESA32.DLL
