#!/bin/bash
# Builds WINMM.DLL (HX's multimedia emulation) on Linux, from this source tree.
# Tools: JWasm and JWlink (as for build-dpmild32.sh) and the import libraries of the official HXDEV package.
# WINMM imports a few functions from SB16.DLL (the sound driver): the import library of SB16 is not part of the
# HXDEV package, so the imports are declared to the linker ("import" directives) from the names the SB16 sources define.
# Usage: build-linux/build-winmm.sh [WORK_DIR]   (default: /tmp/hx-build)
# The result is WORK_DIR/winmm/out/WINMM.DLL.
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
B=$W/winmm; rm -rf "$B"; mkdir -p "$B/src" "$B/sb16" "$B/out" "$B/inc"
for f in "$HX"/SrcEmu/WINMM/*; do [ -f "$f" ] && cp "$f" "$B/src/$(basename "$f" | tr A-Z a-z)"; done
for f in "$HX"/Src/SB16/*; do [ -f "$f" ] && cp "$f" "$B/sb16/$(basename "$f" | tr A-Z a-z)"; done
for d in "$HX/Include" "$W/hxdev/INCLUDE"; do for f in "$d"/*; do [ -f "$f" ] && cp -n "$f" "$B/inc/$(basename "$f" | tr A-Z a-z)"; done; done
# names (decorated) defined by the SB16 sources
cd "$B/sb16"
for m in sb16 sndblast; do $JW -c -coff -nologo -Sg -D_SB16_ -D?FLAT=1 -I../inc -I. -Fo=../out/sb16_$m.obj $m.asm >/dev/null; done
cd "$B/src"
MODS=$(tr -d '\r' < modules.inc | sed 's/\\//g; s#\./##g; s#^\.##; s/\.asm//I' | tr A-Z a-z | tr -s ' \n' ' ')
for m in $MODS winmm; do
    $JW -c -coff -nologo -Sg -D_WINMM_=1 -D?FLAT=1 -I../inc -I. -Fl=../out/$m -Fo=../out/$m.obj $m.asm >../out/$m.log 2>&1 || { echo "FAILED: $m" >&2; tail -3 ../out/$m.log >&2; exit 1; }
done
cd ../out
OBJS=$(for m in $MODS winmm; do echo -n "$m.obj,"; done); OBJS=${OBJS%,}
python3 - <<'PY'
import re,subprocess,glob
syms={}
for f in glob.glob('sb16_*.obj'):
    t=subprocess.run(['objdump','-t',f],capture_output=True,text=True).stdout
    for m in re.finditer(r'\s(_(\w+)@(\d+))$',t,re.M): syms[m.group(2)]=m.group(1)
names=[l.strip() for l in open('../sb16/sb16.rsp') if re.fullmatch(r'\s*\w+\s*',l) and l.strip() not in('EXPORT','OPTION')]
open('sb16-imports.txt','w').write(''.join(f"import '{syms[n]}' 'SB16.DLL'.{n}\n" for n in names))
# the short names of the .RSP are not resolved by JWlink on these objects: exports with their decorated names
exp={}
for f in glob.glob('[!s]*.obj')+['sndblast.obj'] if False else glob.glob('*.obj'):
    if f.startswith('sb16_'): continue
    t=subprocess.run(['objdump','-t',f],capture_output=True,text=True).stdout
    for m in re.finditer(r'\s(_(\w+)@(\d+))$',t,re.M): exp[m.group(2)]=m.group(1)
want=[l.strip() for l in open('../src/winmm.rsp') if re.fullmatch(r'\s*\w+\s*',l) and l.strip() not in('EXPORT','OPTION','OP')]
open('winmm.exp','w').write('OPTION MODNAME=WINMM\nEXPORT {\n'+''.join(f" {n}='{exp[n]}'\n" if n in exp else f" {n}\n" for n in want)+'}\n')
PY
$LK format win pe dll file $OBJS name WINMM.DLL libpath "$W/hxdev/LIB" lib DKRNL32.lib,DUSER32.lib @sb16-imports.txt op q, map=WINMM, implib=WINMM @winmm.exp
ls -l WINMM.DLL
