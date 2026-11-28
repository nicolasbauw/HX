# HX DOS Extender — fork with a few loader and GDI fixes

This is a fork of [HX DOS Extender](https://github.com/Baron-von-Riedesel/HX) by
Japheth (Baron-von-Riedesel). All the credit for HX goes to him; this fork only
carries a few fixes needed by [Bare86](https://github.com/nicolasbauw/bare86), a
program that runs DOS programs, and Windows programs through HX, on Linux.

Upstream is based on v2.24 (`198ec32`). Nothing else than what is listed under
[What this fork changes](#what-this-fork-changes) differs from it. Seven binaries
differ from the official HX package (`DPMILD32.EXE`, `DGDI32.DLL`, `DUSER32.DLL`, `VESA32.DLL`, `WINMM.DLL`, `OLE32.DLL`, `COMCTL32.DLL`, `VERSION.DLL`, `DDDRAW.DLL`)
and one is added (`MSVFW32.DLL`).

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

`StretchBlt` and `StretchDIBits` exist (`STRETCH.ASM`; they scale since item 5 below)
but were not declared by `GetDeviceCaps(RASTERCAPS)` (`RC_STRETCHBLT`, `RC_STRETCHDIB`). The launcher of
Half-Life checks them and stops with “Your graphics card does not support a
necessary raster operation”. `SrcEmu/DGDI32/DEVCAPS.ASM` now declares them.

### 4. `StretchDIBits` gives its temporary DC the size and orientation of the bitmap (DGDI32)

`StretchDIBits` built a compatible DC and overrode its bit count, pitch and bits,
but not its width and height, which stayed those of the screen: `BitBlt` then
believed the source to be 800×600 and read past the end of a smaller bitmap
(the 2001 fast intro `WURST!!` crashed in `gdi32.dll`). `SrcEmu/DGDI32/STRETCH.ASM`
now sets width and height from the bitmap header, rounds the pitch to a dword
(DIB lines are dword aligned) and marks a positive-height bitmap as bottom-up (it
was drawn upside down). `WURST!!` runs and shows its picture.

### 5. `StretchBlt` and `StretchDIBits` scale the picture (DGDI32)

Both only copied: a destination rectangle of another size than the source rectangle
showed the source unscaled (the code said “there is no stretch in size implemented
as of yet”). `SrcEmu/DGDI32/STRETCH.ASM` now scales with the nearest neighbour for
`SRCCOPY` and sources of 8, 16, 24 and 32 bits: the source rectangle is resampled
into a temporary bitmap of the size of the destination (cut to the size of the
destination DC), with the orientation of the source, which `BitBlt()` then copies,
so the color conversion stays where it was. Same sizes, other raster operations and
1 and 4 bit sources go to `BitBlt()` as before. `StretchDIBits` now takes the origin of
the source rectangle of a bottom-up DIB at its lower left corner, as Windows does.
No interpolation (`HALFTONE` and `STRETCH_*` modes are ignored). Tested with a 4×4
picture stretched to 160×160 and a 2×2 sub-rectangle (`c/tests/win32/stretch.c` of
[Bare86](https://github.com/nicolasbauw/bare86), test `hx_stretch`).

### 6. The palette read through the DAC ports has the right red (VESA32)

**Symptom.** In an 8 bit mode, `GetSystemPaletteEntries` returned entries whose
red component was the index of the entry (`10  10 252  84`, instead of `84 252 84`),
so that the system palette, which DGDI32 also writes back to the DAC at start-up,
was wrong from index 10 on.

**Cause.** `Src/VESA32/SETPAL.ASM`, `_GetSetVesaPaletteEntries`, the branches that read the
DAC through the ports (taken when the DAC is handled directly, option `bHandleDAC`, or when
the VESA call `4F09h` fails):
the red value read from the port is kept in `bh`, but the entry was completed with
`mov al,bl`, the loop counter (the index). **Change:** `mov al,bh` in both branches
(6 and 8 bit DAC).

### 7. `BitBlt` to an 8 bit screen matches colors in the system palette (DGDI32)

**Symptom.** A 24 or 32 bit bitmap drawn on the 8 bit screen (`BitBlt`,
`StretchBlt`, `StretchDIBits`, `SetDIBitsToDevice`) came out in wrong colors:
pure red black, white dark grey, grey light red, and so on.

**Cause (two things).** (a) The color table `BitBlt` used for the screen was the one of the
DC, which is the stock palette by default: 20 entries, the rest zero. The search for
the nearest color (`_col24to8`, 256 entries) therefore found black or one of
the 20 static colors. (b) That table is a `PALETTEENTRY` table (red, green, blue),
the pixels of a DIB are blue, green, red: red and blue were compared crosswise.

**Change.** `SrcEmu/DGDI32/BITBLT.ASM`: for a screen of 8 bits, the system palette
(`g_syspal`, 256 entries) is used; `BitBlt` tells `_col24to8` (`COLTRANS.ASM`,
variable `g_bPalPE`) that the table is a `PALETTEENTRY` table; DIB color tables of
memory DCs (`RGBQUAD`) are handled as before. Together with item 6, a 4×4 picture with
a red, a green, a blue and a white corner shows pure red, green, blue and white.

### 8. Modal dialog boxes run (DUSER32)

**Symptom.** A program that opens a dialog box (`DialogBoxParam`, `DialogBoxIndirectParam`:
the “run in full screen?” or options box of a demo, a launcher) stopped on a grey box saying
`DialogBoxParam(41) called`, the function being a stub.

**Change.** `SrcEmu/DUSER32/Dlgbox.asm`: there is still no dialog manager (no control is created), but the
dialog is a real, hidden window of the class `HXDlg` (so that `SendMessage(hDlg, WM_SETICON, ...)`,
`GetWindowRect(hDlg)` and the like work: an opaque handle made programs jump to address 0x13), and the dialog
procedure gets what a user who presses Enter would produce: `WM_INITDIALOG` (with the initialization parameter),
then `WM_COMMAND` with the id of the **default push button** of the template (`BS_DEFPUSHBUTTON`: the “Start”
or “Run” button of a demo's setup box, whose id is rarely `IDOK`; `DLGTEMPLATE` and `DLGTEMPLATEEX` are read,
from the resource or the indirect template), then `IDOK`, `IDCANCEL` and `WM_CLOSE`, until it calls `EndDialog`;
the dialog function returns the value passed to `EndDialog` (1, `IDOK`, if the procedure never ends the dialog,
so that nothing stays blocked). `EndDialog` works, with nested dialogs. The check state set by `CheckDlgButton`,
`CheckRadioButton` or `BM_SETCHECK` is kept per dialog, so `IsDlgButtonChecked` and `BM_GETCHECK` read back the
defaults the procedure chose. **Modeless** dialogs (`CreateDialogParamA`, `CreateDialogIndirectParamA`, which
returned NULL) get the same hidden window and `WM_INITDIALOG`, and the `WM_COMMAND` of the default button is
posted to the window, so the program's message loop delivers it. `GetDlgItem` still returns 0, and procedures
that need real controls (list or combo box contents) will not do much. Found with the setup boxes of the demos
`houston` (FMOD, “Start”) and `mindstam` (BASS, modeless, “Run”). Tested with `c/tests/win32/dialog.c` of
[Bare86](https://github.com/nicolasbauw/bare86) (test `hx_dialog`): OK, cancel only, close only, never ends,
nested, message to the own window, default button, check states, modeless dialog.

### 9. `MSVFW32.DLL`, the DrawDib functions of Video for Windows (new DLL)

**Symptom.** Some demos load `MSVFW32.DLL` and call `DrawDibOpen`/`DrawDibDraw` through `GetProcAddress`.
HX has no such DLL: `LoadLibrary` fails, the function pointer stays NULL, and the call jumps to
address 0, where the interrupt vector table is executed as code until the first invalid
instruction (the exception is reported at address `0x13`).

**Change.** New `SrcEmu/MSVFW32/MSVFW32.ASM`: `DrawDibOpen`, `DrawDibClose`, `DrawDibBegin`, `DrawDibEnd`,
`DrawDibDraw`, `DrawDibGetPalette`, `DrawDibSetPalette`, `DrawDibRealize`, `DrawDibChangePalette`, `DrawDibStart`,
`DrawDibStop`, `DrawDibTime`, `DrawDibProfileDisplay`, `DrawDibGetBuffer`. `DrawDibDraw` draws through
`StretchDIBits` (which scales, item 5): sizes of -1 mean the size of the bitmap, `lpBits` may be NULL (the
bits follow the header and the color table), and the origin of the source rectangle is its upper left corner,
as documented (`StretchDIBits` counts from the lower left corner of a bottom-up bitmap: converted). The
other functions only keep a program that asks for a handle going. The compression functions (`IC...`), video
capture and AVI are **not** provided. Tested with `c/tests/win32/drawdib.c` of
[Bare86](https://github.com/nicolasbauw/bare86) (test `hx_drawdib`); the 64k intro `cashcow` runs with it.

### 10. `DefWindowProc` recovers a device context cut to 16 bits (DUSER32)

**Symptom.** Some demos crashed in `gdi32.dll` (`exception C0000005`, access to `F0000140`) as soon as their window
had to be erased (`haetten`, `yxskaft`, `obs_dp`).

**Cause.** The window procedure of these programs cuts `wParam` to 16 bits (`and eax,0FFFFh`) before passing it
to `DefWindowProc`: a habit of Win16 and Windows 9x code, where GDI handles fit in 16 bits. For `WM_ERASEBKGND`
`wParam` is the device context, and in HX a handle is the 32 bit address of an object: `DefWindowProc` got
`0x30` instead of `0x00AB0030` and `PatBlt` read the object at address `0x30`.

**Change.** `SrcEmu/DUSER32/DCStuff.ASM`: `GetDC` keeps the last eight device contexts it gave out;
`_RecoverDC` returns the whole handle for a value below `0x10000` that is the low word of one of them. Used by
`DefWindowProc` for `WM_ERASEBKGND`. Any other handle cut to 16 bits is still not recovered. Tested with
`c/tests/win32/erase16.c` of [Bare86](https://github.com/nicolasbauw/bare86) (test `hx_erase16`).

### 11. Small missing functions (DUSER32, DGDI32, WINMM)

Programs that import these functions by name did not start (“Unable to load function”, “import not
found”) or stopped when they called a function pointer that was NULL. Found by comparing the imports of 264 Win32 demos with the
exports of the HX DLLs. Most of them have nothing to do in HX (there are no scroll bars, no caret, no MDI windows, no joystick):
they return what a program that does not care expects.

- **DUSER32** (`GetClipCursor` in `CURSOR.ASM`, the others in the new `Extras.asm`): `GetClipCursor` returns the rectangle
  set by `ClipCursor`, or the screen; `FrameRect` draws a one pixel frame in the color of a brush; `GetDCEx` is `GetDC`;
  `HideCaret`, `ShowCaret`, `ExcludeUpdateRgn`, `SetScrollInfo`, `GetScrollInfo`, `GetScrollPos`, `GetScrollRange`,
  `ShowScrollBar`, `EnableScrollBar`, `DrawEdge`, `DrawFrameControl` (nothing is drawn),
  `SetMessageQueue`, `InsertMenuItemA`, `TranslateMDISysAccel`, `ActivateKeyboardLayout` (US English),
  `BeginDeferWindowPos`/`DeferWindowPos`/`EndDeferWindowPos` (the windows are moved at once);
  `DefDlgProcA`, `DefMDIChildProcA`, `DefFrameProcA` call `DefWindowProcA` (`CheckRadioButton` and
  `CreateDialogIndirectParamA`: see item 8).
- **DGDI32** (new `Extras.asm`): `GetBrushOrgEx`/`SetBrushOrgEx` (the origin is always 0,0), `CreatePenIndirect`
  (through `CreatePen`), `GetBkMode`.
- **WINMM**: `joySetThreshold`, `joyGetThreshold` (no joystick: `MMSYSERR_NODRIVER`, like the other `joy` functions),
  `joyConfigChanged`, `waveOutSetPlaybackRate`, `waveOutGetPlaybackRate` (`MMSYSERR_NOTSUPPORTED`), `timeGetSystemTime`.

- **DGDI32**, imported by demos that failed to load without them: `GetStretchBltMode` (the mode set by `SetStretchBltMode`),
  `CreateHatchBrush` (a solid brush of the hatch color), `CreateDIBPatternBrushPt` (a solid grey brush) and `CreateRoundRectRgn`
  (a rectangular region): patterns and rounded corners are not implemented, the programs just keep running.
- **WINMM**: `PlaySoundA` (file names and memory images like `sndPlaySoundA`; system sound aliases and resources report success without
  playing anything).
- **OLE32** (rebuilt by `build-linux/build-simple.sh`): `IsEqualGUID`, `CoBuildVersion` (23.700).
- **COMCTL32** (rebuilt by `build-linux/build-simple.sh`): `InitCommonControlsEx` (ordinal 81, returns TRUE).

Tested with `c/tests/win32/smallfuncs.c` of [Bare86](https://github.com/nicolasbauw/bare86) (test `hx_smallfuncs`), which imports
them by name (OLE32 and COMCTL32 by `GetProcAddress`). Not done: the image lists of COMCTL32 (`ImageList_*`, needed by the programs
that use MFC), `EnumFontsA`.

### 12. Padding after the last relocation block no longer hangs the loader (DPMILD32)

**Symptom.** Programs whose DLL is packed by UPX (`fmod.dll` of the demos `houston`, `backthen`, `avd`; some packed
executables loaded at another base) hung at start, in a loop of the loader.

**Cause.** The base relocation directory of these files is 2 bytes longer than its blocks (padding after the last
block). `DoFixups` read the padding and what follows as a block of size 0: the remaining size never decreased.

**Change.** `Src/DPMILDR/PELOAD.ASM`, `DoFixups`: a block smaller than its header, or a remainder too small for a
header, ends the table, as in Windows.

### 13. `VERSION.DLL` reads version resources

**Symptom.** Programs that ship Intel's JPEG library (`ijl11.dll`, `ijl10.dll`: about ten demos) stopped at once with
`ijl11.dll: dll init failed`.

**Cause.** The `DllMain` of the library reads its own version resource (`GetModuleFileName`, `GetFileVersionInfoSizeA`,
`GetFileVersionInfoA`, `VerQueryValueA("\")`, `VerQueryValueA("\StringFileInfo\040904B0\ProductVersion")`) and fails the
load if one of them fails: `VerQueryValueA` and `VerQueryValueW` were stubs returning 0, and the other two loaded the file
again with `LoadLibrary` while the DLL was being initialized.

**Change.** `SrcEmu/VERSION/STUBS.ASM`: `GetFileVersionInfoSizeA` and `GetFileVersionInfoA` use the module itself when it is
loaded (`GetModuleHandle`), else load it as before; as in Windows, the size returned leaves room for ANSI copies of the
strings, marked by the signature `FE2X` after the resource. `VerQueryValueA/W` walk the `VS_VERSIONINFO` tree (keys
compared without case): `\` gives the `VS_FIXEDFILEINFO`, `\VarFileInfo\Translation` the binary value, and string
values are returned as such by the W function and converted to ANSI by the A function (in the room after the resource,
or in place if the caller's buffer has none). Tested with `c/tests/win32/version.c` of
[Bare86](https://github.com/nicolasbauw/bare86) (test `hx_version`).

### 14. Window hooks and dialog controls (DUSER32)

**Symptom.** Programs built with MFC stopped at once: “abnormal program termination” (a `CMemoryException` thrown by
`AfxHookWindowCreate`) or, once past that, “An unsupported operation was attempted” (`DDX_` functions of a dialog that
finds no control). Other programs said “could not set window hook”.

**Change.** `SrcEmu/DUSER32/WINHOOK.ASM`: `SetWindowsHookExA` keeps the hooks in a table (16 entries) and returns a handle,
`UnhookWindowsHookEx` removes one, `CallNextHookEx` calls the next older hook of the same type. Only `WH_CBT` hooks are
called: `CreateWindowExA` (`WINDOWS.ASM`) calls the newest one with `HCBT_CREATEWND` (window, `CBT_CREATEWND` with the
`CREATESTRUCT`) before `WM_CREATE`, which is where MFC attaches its `CWnd` and subclasses the window; a non-zero result
destroys the window. The other hooks (keyboard, message filters...) are accepted and never called.
`SrcEmu/DUSER32/Dlgbox.asm`: each item of a dialog template becomes a hidden child window of the class `HXCtl` (style,
id, text), so `GetDlgItem` and `GetDlgCtrlID` work; the window keeps its text (`WM_SETTEXT`, `WM_GETTEXT`), its check state
(`BM_SETCHECK`, `BM_GETCHECK`, also used by `CheckDlgButton`...), the strings, item data and selection of a combo or list
box (`CB_`/`LB_` `ADDSTRING`, `INSERTSTRING` (appended), `GETCOUNT`, `SETCURSEL`, `GETCURSEL`, `GETLBTEXT`, `GETTEXT`,
`SETITEMDATA`, `GETITEMDATA`, `FINDSTRING(EXACT)` (whole strings), `SELECTSTRING`, `RESETCONTENT`) and the position of a
trackbar (`TBM_SETPOS`, `TBM_GETPOS`). Nothing is drawn. Tested with `c/tests/win32/dialog.c` of
[Bare86](https://github.com/nicolasbauw/bare86) (test `hx_dialog`); the MFC demos `moments` and `mosaik` start.

### 15. `TextOutA` stays inside the bitmap and draws bottom-up bitmaps the right way up (DGDI32)

**Symptom.** The demo `flush` crashed in `gdi32.dll` (`exception C0000005`, `TextOutA`), and text drawn into a bottom-up
bitmap (a DIB section of positive height, the usual case) came out upside down, at the bottom.

**Cause.** `TextOutA` computed the address of the text from the coordinates (with unsigned multiplications) and wrote every
pixel without any bound; rows were taken from the start of the bits downwards even for a bottom-up bitmap.

**Change.** `SrcEmu/DGDI32/TEXTOUT.ASM`: signed coordinates; for a bottom-up memory bitmap, row `y` is `height - 1 - y` rows
above the bits and the text goes up in memory; a pixel outside the surface (from its origin to `pitch × height`) is not
written. Pixels beyond the right edge of a row still wrap into the next row (no horizontal clipping yet). Tested with
`c/tests/win32/textout.c` of [Bare86](https://github.com/nicolasbauw/bare86) (test `hx_textout`).

### 16. DirectDraw describes display modes as Windows does (DDDRAW)

**Symptom.** Programs built with OpenPTC (about ten demos) stopped with “unsupported bits per pixel” as soon as they set up
the display.

**Cause.** `EnumDisplayModes` and `GetDisplayMode` (`FillDDSD`) described the 8 bit modes as `DDPF_RGB` without
`DDPF_PALETTEINDEXED8`, and the 5-5-5 modes of the VESA card with `dwRGBBitCount = 15`, a value DirectDraw never reports
(Windows reports them as 16 bits with 5-5-5 masks). Surfaces also kept 15 bits, and the sizes computed from it were short.

**Change.** `SrcEmu/DDDRAW/DDOBJECT.ASM` (`FillDDSD`): 8 bit modes get `DDPF_PALETTEINDEXED8`, 15 bit modes are reported as
16 bits with their masks; `SrcEmu/DDDRAW/SURFACE.ASM` (`SetPixelFormat`): the same for surfaces. Tested with
`c/tests/win32/ddmodes.c` of [Bare86](https://github.com/nicolasbauw/bare86) (test `hx_ddmodes`).

## Building

HX's own build needs Open Watcom's `wmake` or `nmake`, JWasm, JWlink and a DOS or
Windows environment. For the loader, a script builds everything on Linux with
nothing but `gcc`, `make` and `git`:

```sh
build-linux/build-dpmild32.sh [WORK_DIR]     # default WORK_DIR: /tmp/hx-build
# result: WORK_DIR/b/ldr/out/DPMILD32.EXE
build-linux/build-dgdi32.sh   [WORK_DIR]
# result: WORK_DIR/dgdi32/out/DGDI32.DLL
build-linux/build-duser32.sh  [WORK_DIR]     # needs wrc of Open Watcom (resources of DUSER32)
# result: WORK_DIR/duser32/out/DUSER32.DLL
build-linux/build-winmm.sh    [WORK_DIR]
# result: WORK_DIR/winmm/out/WINMM.DLL (imports from SB16.DLL declared to the linker)
build-linux/build-msvfw32.sh  [WORK_DIR]
# result: WORK_DIR/msvfw32/out/MSVFW32.DLL
build-linux/build-simple.sh ole32 "DKRNL32.lib,DADVAPI.lib,DUSER32.lib" [WORK_DIR]
# result: WORK_DIR/ole32/out/OLE32.DLL
build-linux/build-simple.sh comctl32 "DKRNL32.lib,DUSER32.lib" [WORK_DIR]
# result: WORK_DIR/comctl32/out/COMCTL32.DLL
build-linux/build-simple.sh version "DKRNL32.lib" [WORK_DIR]
# result: WORK_DIR/version/out/VERSION.DLL
build-linux/build-simple.sh dddraw "DKRNL32.lib,DGDI32.lib,VESA32.lib" [WORK_DIR]
# result: WORK_DIR/dddraw/out/DDDRAW.DLL (same size as the official one when built from the unmodified sources)
build-linux/build-vesa32.sh   [WORK_DIR]
# result: WORK_DIR/vesa32/out/VESA32.DLL (same size as the official one when built from the unmodified sources)
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
and replace `BIN/DPMILD32.EXE`, `BIN/DGDI32.DLL`, `BIN/DUSER32.DLL`, `BIN/VESA32.DLL`, `BIN/WINMM.DLL`, `BIN/OLE32.DLL`, `BIN/COMCTL32.DLL`, `BIN/VERSION.DLL` and `BIN/DDDRAW.DLL` with the ones of this fork's releases, and add `BIN/MSVFW32.DLL` (HX has none).

## Use with Bare86

[Bare86](https://github.com/nicolasbauw/bare86) downloads the official HX package on
first use and checks its SHA-256. The fork's `DPMILD32.EXE`, `DGDI32.DLL`, `DUSER32.DLL`, `VESA32.DLL`, `WINMM.DLL`, `OLE32.DLL`, `COMCTL32.DLL`, `VERSION.DLL` and `DDDRAW.DLL` replace the official
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
