
;--- small functions that programs call and HX's USER32 emulation did not have. Most of them do nothing
;--- useful (there are no scroll bars, no caret, no MDI, no menus to insert into...): a program that
;--- imports them by name no longer stops with "Unable to load function" or "import not found".

		.386
		.MODEL FLAT, stdcall
		option casemap:none
		option proc:private

		include winbase.inc
		include winuser.inc
		include wingdi.inc
		include macros.inc
		include duser32.inc

		.CODE

;--- caret: HX has none

HideCaret proc public hWnd:dword
		@mov eax, 1
		ret
		align 4
HideCaret endp

ShowCaret proc public hWnd:dword
		@mov eax, 1
		ret
		align 4
ShowCaret endp

;--- a frame of one pixel, in the color of a brush

FrameRect proc public uses ebx esi edi hdc:dword, lprc:ptr RECT, hbr:dword

local	hOld:dword
local	dwY:dword

		invoke SelectObject, hdc, hbr
		mov hOld, eax
		mov esi, lprc
		mov ebx, [esi].RECT.right
		sub ebx, [esi].RECT.left		;width
		mov edi, [esi].RECT.bottom
		sub edi, [esi].RECT.top			;height
		invoke PatBlt, hdc, [esi].RECT.left, [esi].RECT.top, ebx, 1, PATCOPY
		mov eax, [esi].RECT.bottom
		dec eax
		mov dwY, eax
		invoke PatBlt, hdc, [esi].RECT.left, dwY, ebx, 1, PATCOPY
		sub edi, 2				;height of the sides
		jle @F
		mov eax, [esi].RECT.top
		inc eax
		mov dwY, eax
		invoke PatBlt, hdc, [esi].RECT.left, dwY, 1, edi, PATCOPY
		mov eax, [esi].RECT.right
		dec eax
		invoke PatBlt, hdc, eax, dwY, 1, edi, PATCOPY
@@:
		invoke SelectObject, hdc, hOld
		@mov eax, 1
		ret
		align 4
FrameRect endp

GetDCEx proc public hWnd:dword, hrgnClip:dword, flags:dword
		invoke GetDC, hWnd
		ret
		align 4
GetDCEx endp

;--- returns NULLREGION

ExcludeUpdateRgn proc public hdc:dword, hWnd:dword
		@mov eax, 1
		ret
		align 4
ExcludeUpdateRgn endp

;--- scroll bars: there are none

SetScrollInfo proc public hWnd:dword, nBar:dword, lpsi:ptr, bRedraw:dword
		xor eax, eax
		ret
		align 4
SetScrollInfo endp

GetScrollInfo proc public hWnd:dword, nBar:dword, lpsi:ptr
		xor eax, eax
		ret
		align 4
GetScrollInfo endp

GetScrollPos proc public hWnd:dword, nBar:dword
		xor eax, eax
		ret
		align 4
GetScrollPos endp

GetScrollRange proc public hWnd:dword, nBar:dword, lpMinPos:ptr DWORD, lpMaxPos:ptr DWORD
		mov ecx, lpMinPos
		jecxz @F
		mov dword ptr [ecx], 0
@@:
		mov ecx, lpMaxPos
		jecxz @F
		mov dword ptr [ecx], 0
@@:
		@mov eax, 1
		ret
		align 4
GetScrollRange endp

ShowScrollBar proc public hWnd:dword, wBar:dword, bShow:dword
		@mov eax, 1
		ret
		align 4
ShowScrollBar endp

EnableScrollBar proc public hWnd:dword, wSBflags:dword, wArrows:dword
		@mov eax, 1
		ret
		align 4
EnableScrollBar endp

;--- drawing of edges and of control frames: nothing is drawn

DrawEdge proc public hdc:dword, qrc:ptr RECT, edge:dword, grfFlags:dword
		@mov eax, 1
		ret
		align 4
DrawEdge endp

DrawFrameControl proc public hdc:dword, lprc:ptr RECT, uType:dword, uState:dword
		@mov eax, 1
		ret
		align 4
DrawFrameControl endp

;--- dialogs have no controls

CheckRadioButton proc public hDlg:dword, nIDFirstButton:dword, nIDLastButton:dword, nIDCheckButton:dword
		@mov eax, 1
		ret
		align 4
CheckRadioButton endp

DefDlgProcA proc public hDlg:dword, msg:dword, wParam:dword, lParam:dword
		invoke DefWindowProcA, hDlg, msg, wParam, lParam
		ret
		align 4
DefDlgProcA endp

CreateDialogIndirectParamA proc public hInstance:dword, lpTemplate:ptr, hWndParent:dword, lpDialogFunc:dword, dwInitParam:dword
		xor eax, eax
		ret
		align 4
CreateDialogIndirectParamA endp

SetMessageQueue proc public cMessagesMax:dword
		@mov eax, 1
		ret
		align 4
SetMessageQueue endp

InsertMenuItemA proc public hMenu:dword, uItem:dword, fByPosition:dword, lpmii:ptr
		@mov eax, 1
		ret
		align 4
InsertMenuItemA endp

;--- MDI: there are no MDI windows, the default procedures are those of any window

DefMDIChildProcA proc public hWnd:dword, uMsg:dword, wParam:dword, lParam:dword
		invoke DefWindowProcA, hWnd, uMsg, wParam, lParam
		ret
		align 4
DefMDIChildProcA endp

DefFrameProcA proc public hWnd:dword, hWndMDIClient:dword, uMsg:dword, wParam:dword, lParam:dword
		invoke DefWindowProcA, hWnd, uMsg, wParam, lParam
		ret
		align 4
DefFrameProcA endp

TranslateMDISysAccel proc public hWndClient:dword, lpMsg:ptr
		xor eax, eax
		ret
		align 4
TranslateMDISysAccel endp

;--- the keyboard layout: US English, always

ActivateKeyboardLayout proc public hkl:dword, Flags:dword
		mov eax, 04090409h
		ret
		align 4
ActivateKeyboardLayout endp

;--- windows are moved at once

BeginDeferWindowPos proc public nNumWindows:dword
		@mov eax, 1
		ret
		align 4
BeginDeferWindowPos endp

DeferWindowPos proc public hWinPosInfo:dword, hWnd:dword, hWndInsertAfter:dword, x:dword, y:dword, cx_:dword, cy:dword, uFlags:dword
		invoke SetWindowPos, hWnd, hWndInsertAfter, x, y, cx_, cy, uFlags
		mov eax, hWinPosInfo
		ret
		align 4
DeferWindowPos endp

EndDeferWindowPos proc public hWinPosInfo:dword
		@mov eax, 1
		ret
		align 4
EndDeferWindowPos endp

		end
