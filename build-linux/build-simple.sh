#!/bin/bash
# Builds a DLL of HX's emulation set (without resources) on Linux from this source tree: OLE32, COMCTL32...
# Tools: JWasm and JWlink (as for build-dpmild32.sh) and the import libraries of the official HXDEV package.
# Usage: build-linux/build-simple.sh NAME "LIB1.lib,LIB2.lib" [WORK_DIR]   (e.g. ole32 "DKRNL32.lib")
# The result is WORK_DIR/NAME/out/NAME.DLL. Modules: SrcEmu/NAME/MODULES.INC (plus NAME.ASM); exports: the names of SrcEmu/NAME/NAME.RSP,
# with the ordinals of NAME.DEF ("Name @17") or of the .RSP ("Name .17").
set -e
HX=$(cd "$(dirname "$0")/.." && pwd)
N=$(echo "$1" | tr A-Z a-z); U=$(echo "$1" | tr a-z A-Z)
LIBS=${2:-DKRNL32.lib}
W=${3:-/tmp/hx-build}
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
B=$W/$N; rm -rf "$B"; mkdir -p "$B/src" "$B/out" "$B/inc"
for f in "$HX"/SrcEmu/$U/*; do [ -f "$f" ] && cp "$f" "$B/src/$(basename "$f" | tr A-Z a-z)"; done
for d in "$HX/Include" "$W/hxdev/INCLUDE"; do for f in "$d"/*; do [ -f "$f" ] && cp -n "$f" "$B/inc/$(basename "$f" | tr A-Z a-z)"; done; done
cd "$B/src"
MODS=$(tr -d '\r' < modules.inc | sed 's/\\//g; s#\./##g; s#^\.##; s/\.asm//I' | tr A-Z a-z | tr -s ' \n' ' ')
for m in $MODS $N; do
    [ -f $m.asm ] || continue
    $JW -c -coff -nologo -Cp -Sg -D?FLAT=1 -I../inc -I. -Fl=../out/$m -Fo=../out/$m.obj $m.asm >../out/$m.log 2>&1 || { echo "FAILED: $m" >&2; tail -3 ../out/$m.log >&2; exit 1; }
done
cd ../out
# JWlink does not resolve the short names of the .RSP: exports with their decorated names (stdcall: _Name@N) and, if the .DEF gives
# one (" Name  @17"), the ordinal.
OBJS=$(for m in $MODS $N; do [ -f $m.obj ] && echo -n "$m.obj,"; done)
python3 - "$N" "$U" <<'PY'
import re,subprocess,sys,glob
n,u=sys.argv[1:3]
syms={}
for o in glob.glob('*.obj'):
    t=subprocess.run(['objdump','-t',o],capture_output=True,text=True).stdout
    for m in re.finditer(r'\s(_?(\w+?)(?:@(\d+))?)$',t,re.M):
        if m.group(3) is not None: syms.setdefault(m.group(2),m.group(1))
ords={}
for l in open('../src/%s.def'%n,errors='replace'):
    m=re.match(r'\s*(\w+)\s*@(\d+)',l)
    if m: ords[m.group(1)]=int(m.group(2))
names=[]
for l in open('../src/%s.rsp'%n,errors='replace'):
    m=re.fullmatch(r'\s*(\w+)(?:\s+\.(\d+))?\s*',l)
    if m and m.group(1) not in ('EXPORT','OPTION','OP'):
        names.append(m.group(1))
        if m.group(2): ords[m.group(1)]=int(m.group(2))
out=['OPTION MODNAME=%s'%u,'EXPORT {']
missing=[]
for nm in names:
    if nm not in syms and ('_'+nm) not in syms.values(): missing.append(nm); continue
    sym=syms.get(nm,'_'+nm)
    out.append(" %s%s='%s'"%(nm,('.%d'%ords[nm]) if nm in ords else '',sym))
out.append('}')
open('%s.exp'%n,'w').write('\n'.join(out)+'\n')
if missing: print('exports without a symbol:',' '.join(missing),file=sys.stderr)
PY
$LK format win pe dll file ${OBJS%,} name $U.DLL libpath "$W/hxdev/LIB" lib $LIBS op q, map=$U, implib=$U @$N.exp
ls -l $U.DLL
