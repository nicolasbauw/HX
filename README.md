# HX DOS Extender — fork with a few loader and GDI fixes

This is a fork of [HX DOS Extender](https://github.com/Baron-von-Riedesel/HX) by
Japheth (Baron-von-Riedesel). All the credit for HX goes to him; this fork only
carries a few fixes needed by [Bare86](https://github.com/nicolasbauw/bare86), a
program that runs DOS programs, and Windows programs through HX, on Linux.

Upstream is based on v2.24 (`198ec32`). Nothing else than what is listed under
[What this fork changes](#what-this-fork-changes) differs from it. Two binaries
differ from the official HX package: `DPMILD32.EXE` and `DGDI32.DLL`.

## What HX is

HX is a DOS extender: it lets 32-bit programs run under DOS, without a Windows
installation. It contains:

| Part | What it does |
|------|--------------|
| **HDPMI** (`HDPMI16`, `HDPMI32`) | A DPMI host: it puts the processor in protected mode and gives programs extended memory, descriptors, interrupts. |
| **DPMILD32** | The PE loader: it reads a Win32 executable (`.exe` or `.dll`), maps its sections in extended memory, applies the relocations, resolves the imports, and starts it. |
| **DKRNL32, DUSER32, DGDI32, DDDRAW, …** | A partial emulation of the Win32 API (KERNEL32, USER32, GDI32, DirectDraw, OpenGL front end…), so that Win32 **console** programs and, with limits, Win32 **graphics** programs (GDI, DirectDraw, OpenGL) run in DOS. |
| **HXLdr32, PEStub** | Ways to start a Win32 program from the DOS prompt without typing `DPMILD32` first. |

It is not Windows and not a virtual machine: the Win32 functions are
re-implemented by small DOS-hosted DLLs, and many are missing or reduced to stubs.
Programs that stay within what is implemented work very well; the others stop
with a message such as `Unable to load function: USER32.dll:GetClipCursor`.

The upstream project documents itself in a text file (`Readme.txt`, and the `Doc`
directory of the binary package, `HXRT.TXT` in particular). The source repository
has no top-level description, which is the reason for this page.

## What this fork changes

### 1. DPMILD32 keeps the executable's own header (fixes Petite 2.3 programs)

**Symptom.** Programs compressed with **Petite 2.3** (a Win32 executable packer
of the late 1990s, common among demoscene productions) stop at start-up with the
message box *“This file has been tampered with and MAY BE INFECTED BY A VIRUS!”*.
Programs packed with Petite 2.2 are not affected.

**Cause.** Petite's decompressor checks the header of its own image in memory
before running. The header of such a file is not an ordinary linker header: it
holds the DOS stub, a Rich header, the string `Compressed by Petite, (c) 1998-99
Ian Luck.` and the PE header at its original offset (`e_lfanew`, here `0x11C`).
DPMILD32 did not map that header: it copied the first `0x40` bytes, cleared the
rest of the page, and put its own copy of the PE structures at offset `0x40`
(with, in front of them, its bookkeeping fields at `0x20`–`0x3B`). The checked
bytes were therefore different from the file's.

**Change.** The first `0x600` bytes of the file are now mapped as they are at the
image base. DPMILD32 keeps its own copy of the PE structures (headers, section
table, module name, small heap) at `base + NTOFS` (`NTOFS = 0x600`), instead of
`base + 0x40`; the 45 places that assumed the old offset use the constant. Only
`0x20`–`0x3B` of the header still belong to the loader (this passes the check on
the programs tried). When `e_lfanew` is outside `0x40`–`0x300`, the loader behaves as
before (non-faithful header, `e_lfanew` pointing to its own copy).

The change is in `Src/DPMILDR/PELOAD.ASM`; the diff against upstream v2.24 is
about 140 lines.

**Measured** (under Bare86, see below):

- 50 demos of a collection of 264 Win32 demos showed the message; after the change
  none does (45 of them were run for 14 seconds and photographed; the other 5 did
  not return within the test's time limit). They then reach their own next obstacle, usually a missing API
  function — which is progress, not yet a working demo;
- 45 demos that already worked produce the same images as before;
- HX's own `GDITEST.EXE` draws its window as before.

**Not tested** on real DOS, FreeDOS, or a PC-compatible. The change only uses
standard DOS file calls (`INT 21h`, functions 42h and 3Fh), but it has been run only
under Bare86's emulated PC. Reports from real machines are welcome.

### 2. `SetDIBits` copies the lines it is given (DGDI32)

**Symptom.** Some programs stop with `exception C0000005` in `gdi32.dll`, reading
past the end of a buffer (found with the 64k intro `3s-money`, among a collection of
Win32 demos; two others fault in `gdi32.dll` for other reasons, not fixed here).

**Cause.** `SetDIBits(hdc, hbm, uStartScan, cScanLines, lpvBits, lpbmi, usage)`
receives `cScanLines` lines in `lpvBits`, the first one being scan line
`uStartScan`. DGDI32 ignored `cScanLines` and copied the whole height of the
bitmap, starting at `uStartScan`: a program that sends one line at a time made it
read the memory behind that line.

**Change.** `SrcEmu/DGDI32/DIBITMAP.ASM`: only `cScanLines` lines are copied (clamped
to what is left in the bitmap), to the rows that correspond to `uStartScan`
(counted from the bottom for a bottom-up bitmap). For `uStartScan = 0` and a full
bitmap, the usual call, the copy is the same as before.

`3s-money` goes past this fault with the change. (It then stops later, at a missing
DirectX object: a different problem, not fixed here.)

### 3. `GetDeviceCaps(RASTERCAPS)` declares `StretchBlt` and `StretchDIBits` (DGDI32)

`StretchBlt` and `StretchDIBits` exist (`STRETCH.ASM`; they copy, they do **not** scale
yet) but were not declared by `GetDeviceCaps(RASTERCAPS)` (`RC_STRETCHBLT`,
`RC_STRETCHDIB`). The launcher of
Half-Life checks them and stops with “Your graphics card does not support a
necessary raster operation”. `SrcEmu/DGDI32/DEVCAPS.ASM` now declares them.

### 4. `StretchDIBits` gives its temporary DC the size and orientation of the bitmap (DGDI32)

`StretchDIBits` built a compatible DC and overrode its bit count, pitch and bits,
but not its width and height, which stayed those of the screen: `BitBlt` then
believed the source to be 800×600 and read past the end of a smaller bitmap
(the 2001 fast intro `WURST!!` crashed in `gdi32.dll`). `SrcEmu/DGDI32/STRETCH.ASM`
now sets width and height from the bitmap header, rounds the pitch to a dword
(DIB lines are dword aligned) and marks a positive-height bitmap as bottom-up (it
was drawn upside down). `WURST!!` runs and shows its picture, unscaled.

## Building

HX's own build needs Open Watcom's `wmake` or `nmake`, JWasm, JWlink and a DOS or
Windows environment. For the loader, a script builds everything on Linux with
nothing but `gcc`, `make` and `git`:

```sh
build-linux/build-dpmild32.sh [WORK_DIR]     # default WORK_DIR: /tmp/hx-build
# result: WORK_DIR/b/ldr/out/DPMILD32.EXE
build-linux/build-dgdi32.sh   [WORK_DIR]
# result: WORK_DIR/dgdi32/out/DGDI32.DLL
```

The script fetches and builds JWasm and JWlink from their own repositories, copies
the sources with lower-case names (JWasm is case-sensitive on Linux), then runs the
same three assemblies and the same link as `Src/DPMILDR/DPMILD32.MAK`. Built from
the unmodified upstream sources, its result is byte-identical to the `DPMILD32.EXE`
of the official HX 2.23 package (the loader did not change between 2.23 and 2.24).

`build-dgdi32.sh` also downloads the import libraries of the official HXDEV package
(SHA-256 checked) and links with JWlink. Its DLL has the same size as the official
one but is not byte-identical (other linker, other order; two builds of the same
sources differ by one byte, a time stamp). It was checked by running programs, not
by comparison: HX's own `GDITEST.EXE` and 45 demos that already worked give the same
images with it as with the official DLL.

The other parts of HX (HDPMI, the other DLLs) are **not** rebuilt by this fork: use
the binaries of the [official packages](https://github.com/Baron-von-Riedesel/HX/releases)
and replace `BIN/DPMILD32.EXE` and `BIN/DGDI32.DLL` with the ones of this fork's releases.

## Use with Bare86

[Bare86](https://github.com/nicolasbauw/bare86) downloads the official HX package on
first use and checks its SHA-256. The fork's `DPMILD32.EXE` and `DGDI32.DLL` replace the official
ones in the same directory; both can be told apart by their SHA-256, given in each
release's notes.

## Relation to upstream

- This fork follows upstream: its changes are small and kept separate so that they
  can be proposed to Japheth. If upstream adopts the change, this fork becomes
  unnecessary and says so here.
- Please report bugs of HX itself upstream. Report here only what concerns the
  changes listed above.

## Licence

HX is distributed by its author as freeware: the runtime “is freeware and may be
used for any purpose… [and] can be freely distributed with any application”
(`HXRT.TXT`, *Copyright Japheth 1996–2024*). The source files carry their own
notices, kept as they are. This fork adds none of its own restriction: the
changes in this repository are given under the same terms as HX.

## Credits

HX DOS Extender, HDPMI, DPMILD32, DKRNL32 and the rest: **Japheth**
([Baron-von-Riedesel/HX](https://github.com/Baron-von-Riedesel/HX)).
JWasm and JWlink, used to build: Japheth and the Open Watcom contributors.
The change of this fork was written with Claude Code (Anthropic) for Bare86.
