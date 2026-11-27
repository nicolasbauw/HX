
		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
		option proc:private

		include winbase.inc
		include winuser.inc
		include wingdi.inc
		include wincon.inc
		include macros.inc
		include duser32.inc

		.DATA

;--- dialogs run without a dialog manager: no control is created. The dialog is a real, hidden
;--- window (so that SendMessage(hDlg, WM_SETICON...), GetWindowRect(hDlg) and the like work) of the
;--- class "HXDlg", whose window procedure hands every message to the dialog procedure (DefWindowProc
;--- if it returns FALSE). The template is only read to find the default push button: the dialog
;--- procedure gets WM_INITDIALOG, then WM_COMMAND with the id of that button (as if the user had
;--- pressed Enter on the setup dialog of a demo: "Start", "Run"...), then IDOK, IDCANCEL and WM_CLOSE,
;--- until it calls EndDialog(). A modeless dialog (CreateDialogParam) gets WM_INITDIALOG, and the
;--- WM_COMMAND of its default button is posted to its window. The check state of buttons set by
;--- CheckDlgButton/CheckRadioButton/BM_SETCHECK is kept, so IsDlgButtonChecked reads back the
;--- defaults chosen by the program. If the window of a modal dialog cannot be created, the
;--- "window handle" is a pointer to the DLGSTATE on the stack of the caller and the dialog procedure
;--- is called directly.

?MAXCHECKS	equ 32
?BUTTON		equ 80h		;atom of the class "BUTTON" in templates
?DEFPUSH	equ 1		;BS_DEFPUSHBUTTON
?SETFONT	equ 40h		;DS_SETFONT
?BMGETCHECK	equ 0F0h
?BMSETCHECK	equ 0F1h
?NCDESTROY	equ 82h

DLGSTATE struct
pPrev		dd ?		;enclosing modal dialog / next modeless dialog
bEnded		dd ?
dwRC		dd ?
hDlg		dd ?		;window of the dialog, or 0
lpProc		dd ?		;dialog procedure
nChecks		dd ?
aChecks		dd ?MAXCHECKS dup (?)	;LOWORD id, HIWORD check state
DLGSTATE ends

g_pDlg		dd 0		;innermost modal dialog
g_pModeless	dd 0		;modeless dialogs
g_bDlgClass	dd 0		;class "HXDlg" registered

		.code

_DlgWndProc proc uses ebx hWnd:dword, msg:dword, wParam:dword, lParam:dword

		invoke GetWindowLongA, hWnd, 0
		.if (eax)
			mov ebx, eax
			push lParam
			push wParam
			push msg
			push hWnd
			call [ebx].DLGSTATE.lpProc
			.if (msg == ?NCDESTROY)
				mov [ebx].DLGSTATE.hDlg, 0
			.endif
			.if (eax)
				xor eax, eax		;processed
				jmp done
			.endif
		.endif
		invoke DefWindowProcA, hWnd, msg, wParam, lParam
done:
		ret
		align 4
_DlgWndProc endp

;--- send a message to the dialog: through its window, or directly

_DlgSend proc uses ebx pDlg:dword, msg:dword, wParam:dword, lParam:dword

		mov ebx, pDlg
		.if ([ebx].DLGSTATE.hDlg)
			invoke SendMessageA, [ebx].DLGSTATE.hDlg, msg, wParam, lParam
		.else
			push lParam
			push wParam
			push msg
			push ebx
			call [ebx].DLGSTATE.lpProc
		.endif
		ret
		align 4
_DlgSend endp

;--- create the hidden window of a dialog, ebx = DLGSTATE

_DlgCreateWindow proc hwndParent:dword

local	wc:WNDCLASS
local	hInst:dword

		invoke GetModuleHandleA, 0
		mov hInst, eax
		.if (!g_bDlgClass)
			invoke RtlZeroMemory, addr wc, sizeof WNDCLASS
			mov wc.lpfnWndProc, offset _DlgWndProc
			mov wc.cbWndExtra, 4
			mov eax, hInst
			mov wc.hInstance, eax
			mov wc.lpszClassName, CStr("HXDlg")
			invoke RegisterClassA, addr wc
			mov g_bDlgClass, 1
		.endif
		invoke CreateWindowExA, 0, CStr("HXDlg"), CStr(""), WS_POPUP, 0, 0, 0, 0, hwndParent, 0, hInst, 0
		.if (eax)
			mov [ebx].DLGSTATE.hDlg, eax
			push eax
			invoke SetWindowLongA, eax, 0, ebx
			pop eax
		.endif
		ret
		align 4
_DlgCreateWindow endp

;--- template of a dialog resource (0 if not found)

_DlgTemplate proc hInst:dword, lpName:dword

		mov eax, hInst
		.if (!eax)
			invoke GetModuleHandleA, 0
			mov hInst, eax
		.endif
		invoke FindResourceA, hInst, lpName, RT_DIALOG
		.if (eax)
			invoke LoadResource, hInst, eax	;HX: the address of the resource
		.endif
		ret
		align 4
_DlgTemplate endp

;--- skip a "sz_Or_Ord" field of a template: esi in, esi out

_SkipSzOrd proc
		.if (word ptr [esi] == 0FFFFh)
			add esi, 4
		.else
			.repeat
				lodsw
			.until (ax == 0)
		.endif
		ret
		align 4
_SkipSzOrd endp

;--- id of the default push button of a template (DLGTEMPLATE or DLGTEMPLATEEX), IDOK if none

_DlgDefButton proc uses ebx esi edi pTemplate:dword

local	dwId:dword

		mov dwId, IDOK
		mov esi, pTemplate
		and esi, esi
		jz done
		xor edi, edi
		.if (dword ptr [esi] == 0FFFF0001h)	;DLGTEMPLATEEX
			inc edi
			mov edx, [esi+12]
			movzx ecx, word ptr [esi+16]
			add esi, 26
		.else
			mov edx, [esi]
			movzx ecx, word ptr [esi+8]
			add esi, 18
		.endif
		cmp ecx, 256
		jnc done
		call _SkipSzOrd		;menu
		call _SkipSzOrd		;class
		call _SkipSzOrd		;title
		.if (edx & ?SETFONT)
			.if (edi)
				add esi, 6	;point size, weight, italic, charset
			.else
				add esi, 2	;point size
			.endif
			call _SkipSzOrd	;typeface
		.endif
		.while (ecx)
			add esi, 3
			and esi, not 3
			.if (edi)
				mov edx, [esi+8]
				movzx ebx, word ptr [esi+20]
				add esi, 24
			.else
				mov edx, [esi]
				movzx ebx, word ptr [esi+16]
				add esi, 18
			.endif
			.if ((word ptr [esi] == 0FFFFh) && (word ptr [esi+2] == ?BUTTON))
				and edx, 0Fh
				.if (edx == ?DEFPUSH)
					mov dwId, ebx
					jmp done
				.endif
			.endif
			call _SkipSzOrd	;class
			call _SkipSzOrd	;title
			movzx eax, word ptr [esi]
			lea esi, [esi+eax+2]	;creation data
			dec ecx
		.endw
done:
		mov eax, dwId
		ret
		align 4
_DlgDefButton endp

_RunDialog proc uses ebx lpDialogProc:dword, dwInitParm:dword, hwndParent:dword, pTemplate:dword

local	dlg:DLGSTATE
local	dwDefId:dword

		mov eax, g_pDlg
		mov dlg.pPrev, eax
		mov dlg.bEnded, 0
		mov dlg.dwRC, 1		;IDOK if the procedure never calls EndDialog
		mov dlg.hDlg, 0
		mov dlg.nChecks, 0
		mov eax, lpDialogProc
		mov dlg.lpProc, eax
		lea ebx, dlg
		mov g_pDlg, ebx
		.if (lpDialogProc)
			invoke _DlgDefButton, pTemplate
			mov dwDefId, eax
			invoke _DlgCreateWindow, hwndParent
			invoke _DlgSend, ebx, WM_INITDIALOG, 0, dwInitParm
			.if ((!dlg.bEnded) && (dwDefId != IDOK))
				invoke _DlgSend, ebx, WM_COMMAND, dwDefId, 0
			.endif
			.if (!dlg.bEnded)
				invoke _DlgSend, ebx, WM_COMMAND, IDOK, 0
			.endif
			.if (!dlg.bEnded)
				invoke _DlgSend, ebx, WM_COMMAND, IDCANCEL, 0
			.endif
			.if (!dlg.bEnded)
				invoke _DlgSend, ebx, WM_CLOSE, 0, 0
			.endif
			.if (dlg.hDlg)
				invoke DestroyWindow, dlg.hDlg
			.endif
		.endif
		mov eax, dlg.pPrev
		mov g_pDlg, eax
		mov eax, dlg.dwRC
		ret
		align 4
_RunDialog endp

DialogBoxParamA proc public hInstance:dword, lpTemplateName:dword, 
		hwndParent:HWND, lpDialogProc:dword, dwInitParm:dword

		invoke _DlgTemplate, hInstance, lpTemplateName
		invoke _RunDialog, lpDialogProc, dwInitParm, hwndParent, eax
		@strace	<"DialogBoxParamA(", hInstance, ", ", lpTemplateName, ", ", hwndParent, ", ", lpDialogProc, ", ", dwInitParm, ")=", eax, " (no controls: default button sent)">
		ret
		align 4
DialogBoxParamA endp

DialogBoxParamW proc public hInstance:dword, lpTemplateName:dword, 
		hwndParent:HWND, lpDialogProc:dword, dwInitParm:dword

		mov eax, lpTemplateName
		.if ( eax > 0ffffh)
			call ConvertWStr
		.endif
		invoke DialogBoxParamA, hInstance, eax, hwndParent, lpDialogProc, dwInitParm
		ret
		align 4
DialogBoxParamW endp

DialogBoxIndirectParamA proc public hInstance:dword, lpTemplate:ptr, 
		hwndParent:HWND, lpDialogProc:dword, dwInitParm:dword

		invoke _RunDialog, lpDialogProc, dwInitParm, hwndParent, lpTemplate
		@strace	<"DialogBoxIndirectParamA(", hInstance, ", ", lpTemplate, ", ", hwndParent, ", ", lpDialogProc, ", ", dwInitParm, ")=", eax, " (no controls: default button sent)">
		ret
		align 4
DialogBoxIndirectParamA endp

EndDialog proc public hDlg:dword, dwRC:dword

		mov ecx, g_pDlg
		.while (ecx)
			mov eax, hDlg
			.if ((ecx == eax) || (eax && (eax == [ecx].DLGSTATE.hDlg)))
				mov [ecx].DLGSTATE.bEnded, 1
				mov eax, dwRC
				mov [ecx].DLGSTATE.dwRC, eax
				@mov eax, 1
				jmp done
			.endif
			mov ecx, [ecx].DLGSTATE.pPrev
		.endw
		xor eax, eax
done:
		@strace	<"EndDialog(", hDlg, ", ", dwRC, ")=", eax>
		ret
		align 4
EndDialog endp

;--- modeless dialog: the state lives on the heap, in the list g_pModeless

_CreateModeless proc uses ebx pTemplate:dword, hwndParent:dword, lpDialogProc:dword, dwInitParm:dword

		xor eax, eax
		cmp lpDialogProc, eax
		jz done
		invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof DLGSTATE
		and eax, eax
		jz done
		mov ebx, eax
		mov eax, lpDialogProc
		mov [ebx].DLGSTATE.lpProc, eax
		invoke _DlgCreateWindow, hwndParent
		.if (!eax)
			invoke LocalFree, ebx
			xor eax, eax
			jmp done
		.endif
		mov eax, g_pModeless
		mov [ebx].DLGSTATE.pPrev, eax
		mov g_pModeless, ebx
		invoke SendMessageA, [ebx].DLGSTATE.hDlg, WM_INITDIALOG, 0, dwInitParm
		mov eax, [ebx].DLGSTATE.hDlg
		.if (eax)
			invoke _DlgDefButton, pTemplate
			invoke PostMessageA, [ebx].DLGSTATE.hDlg, WM_COMMAND, eax, 0
			mov eax, [ebx].DLGSTATE.hDlg
		.endif
done:
		ret
		align 4
_CreateModeless endp

CreateDialogParamA proc public hInstance:dword, lpTemplateName:dword, 
		hwndParent:HWND, lpDialogProc:dword, dwInitParm:dword

		invoke _DlgTemplate, hInstance, lpTemplateName
		invoke _CreateModeless, eax, hwndParent, lpDialogProc, dwInitParm
		@strace	<"CreateDialogParamA(", hInstance, ", ", lpTemplateName, ", ", hwndParent, ", ", lpDialogProc, ", ", dwInitParm, ")=", eax, " (no controls: default button posted)">
		ret
		align 4
CreateDialogParamA endp

CreateDialogIndirectParamA proc public hInstance:dword, lpTemplate:ptr, hWndParent:dword, lpDialogFunc:dword, dwInitParam:dword

		invoke _CreateModeless, lpTemplate, hWndParent, lpDialogFunc, dwInitParam
		@strace	<"CreateDialogIndirectParamA(", hInstance, ", ", lpTemplate, ", ", hWndParent, ", ", lpDialogFunc, ", ", dwInitParam, ")=", eax, " (no controls: default button posted)">
		ret
		align 4
CreateDialogIndirectParamA endp

IsDialogMessageA proc public hDlg:dword, lpMsg:ptr MSG
		xor eax, eax
		@strace	<"IsDialogMessageA(", hDlg, ", ", lpMsg, ")=", eax, " *** unsupp ***">
		ret
		align 4
IsDialogMessageA endp

;--- check state of buttons

_DlgState proc hDlg:dword

		mov eax, hDlg
		mov ecx, g_pDlg
		.while (ecx)
			.if ((ecx == eax) || (eax && (eax == [ecx].DLGSTATE.hDlg)))
				jmp found
			.endif
			mov ecx, [ecx].DLGSTATE.pPrev
		.endw
		mov ecx, g_pModeless
		.while (ecx)
			.if (eax && (eax == [ecx].DLGSTATE.hDlg))
				jmp found
			.endif
			mov ecx, [ecx].DLGSTATE.pPrev
		.endw
found:
		mov eax, ecx
		ret
		align 4
_DlgState endp

;--- address of the entry of button dwId (created if bCreate), or 0

_DlgCheckEntry proc hDlg:dword, dwId:dword, bCreate:dword

		invoke _DlgState, hDlg
		.if (eax)
			mov edx, eax
			mov ecx, [edx].DLGSTATE.nChecks
			lea eax, [edx].DLGSTATE.aChecks
			.while (ecx)
				push edx
				mov edx, dwId
				cmp dx, word ptr [eax]
				pop edx
				jz done
				add eax, 4
				dec ecx
			.endw
			xor eax, eax
			.if (bCreate && ([edx].DLGSTATE.nChecks < ?MAXCHECKS))
				mov ecx, [edx].DLGSTATE.nChecks
				inc [edx].DLGSTATE.nChecks
				lea eax, [edx+ecx*4].DLGSTATE.aChecks
				movzx ecx, word ptr dwId
				mov [eax], ecx
			.endif
		.endif
done:
		ret
		align 4
_DlgCheckEntry endp

;--- dlg items

GetDlgItem proc public hDlg:dword, dwId:dword
		xor eax, eax
		@strace	<"GetDlgItem(", hDlg, ", ", dwId, ")=", eax, " *** unsupp ***">
		ret
		align 4
GetDlgItem endp

GetDlgCtrlID proc public hwndCtrl:dword
		xor eax, eax
		@strace	<"GetDlgCtrlID(", hwndCtrl, ")=", eax, " *** unsupp ***">
		ret
		align 4
GetDlgCtrlID endp

CheckDlgButton proc public hDlg:dword, dwId:dword, uCheck:dword
		invoke _DlgCheckEntry, hDlg, dwId, 1
		.if (eax)
			mov ecx, uCheck
			mov word ptr [eax+2], cx
			@mov eax, 1
		.endif
		@strace	<"CheckDlgButton(", hDlg, ", ", dwId, ",", uCheck, ")=", eax>
		ret
		align 4
CheckDlgButton endp

CheckRadioButton proc public uses ebx hDlg:dword, nIDFirstButton:dword, nIDLastButton:dword, nIDCheckButton:dword
		mov ebx, nIDFirstButton
		.while (ebx <= nIDLastButton)
			invoke _DlgCheckEntry, hDlg, ebx, 0
			.if (eax)
				mov word ptr [eax+2], 0
			.endif
			inc ebx
			.break .if (ebx > 0FFFFh)
		.endw
		invoke CheckDlgButton, hDlg, nIDCheckButton, 1
		@strace	<"CheckRadioButton(", hDlg, ", ", nIDFirstButton, ", ", nIDLastButton, ", ", nIDCheckButton, ")=", eax>
		ret
		align 4
CheckRadioButton endp

IsDlgButtonChecked proc public hDlg:dword, dwId:dword
		invoke _DlgCheckEntry, hDlg, dwId, 0
		.if (eax)
			movzx eax, word ptr [eax+2]
		.endif
		@strace	<"IsDlgButtonChecked(", hDlg, ", ", dwId, ")=", eax>
		ret
		align 4
IsDlgButtonChecked endp

GetDlgItemTextA proc public hDlg:dword, dwID:dword, pszText:ptr byte, nSize:DWORD
		invoke GetDlgItem, hDlg, dwID
		.if (eax)
			invoke GetWindowTextA, eax, pszText, nSize
		.endif
		@strace	<"GetDlgItemTextA(", hDlg, ", ", dwID, ", ", pszText, ", ", nSize, ")=", eax>
		ret
		align 4
GetDlgItemTextA endp

SetDlgItemTextA proc public hDlg:dword, dwID:dword, pszText:ptr byte
		invoke GetDlgItem, hDlg, dwID
		.if (eax)
			invoke SetWindowTextA, eax, pszText
		.endif
		@strace	<"SetDlgItemTextA(", hDlg, ", ", dwID, ", ", pszText, ")=", eax>
		ret
		align 4
SetDlgItemTextA endp

SetDlgItemTextW proc public hDlg:dword, dwID:dword, pszText:ptr byte
		mov eax, pszText
		invoke ConvertWStr
		invoke SetDlgItemTextA, hDlg, dwID, eax
		@strace	<"SetDlgItemTextW(", hDlg, ", ", dwID, ", ", pszText, ")=", eax>
		ret
		align 4
SetDlgItemTextW endp

GetDlgItemInt proc public hDlg:dword, dwID:dword, lpTranslated:ptr DWORD, bSigned:DWORD

local	szText[64]:byte

		invoke GetDlgItem, hDlg, dwID
		.if (eax)
			lea ecx, szText
			invoke GetWindowTextA, eax, ecx, sizeof szText
			mov ecx, lpTranslated
			jecxz @F
			mov dword ptr [ecx],0
@@: 		   
			xor eax, eax
		.endif
		@strace	<"GetDlgItemInt(", hDlg, ", ", dwID, ", ", lpTranslated, ", ", bSigned, ")=", eax>
		ret
		align 4
GetDlgItemInt endp

SetDlgItemInt proc public uses ebx hDlg:dword, dwID:dword, uValue:DWORD, bSigned:DWORD

local	szText[64]:byte

		invoke GetDlgItem, hDlg, dwID
		.if (eax)
			mov ebx, eax
			.if (bSigned)
				invoke wvsprintf, addr szText, CStr("%d"), uValue
			.else
				invoke wvsprintf, addr szText, CStr("%u"), uValue
			.endif
			invoke SetWindowTextA, ebx, addr szText
		.endif
		@strace	<"SetDlgItemInt(", hDlg, ", ", dwID, ", ", uValue, ", ", bSigned, ")=", eax>
		ret
		align 4
SetDlgItemInt endp

SendDlgItemMessageA proc public uses ebx hDlg:dword, dwID:dword, msg:DWORD, wParam:dword, lParam:dword

		.if (msg == ?BMSETCHECK)
			invoke CheckDlgButton, hDlg, dwID, wParam
			xor eax, eax
		.elseif (msg == ?BMGETCHECK)
			invoke IsDlgButtonChecked, hDlg, dwID
		.else
			invoke GetDlgItem, hDlg, dwID
			.if (eax)
				invoke SendMessage, eax, msg, wParam, lParam
			.endif
		.endif
		@strace	<"SendDlgItemMessage(", hDlg, ", ", dwID, ", ", msg, ", ", wParam, ", ", lParam, ")=", eax>
		ret
		align 4
SendDlgItemMessageA endp

GetNextDlgTabItem proc public hDlg:dword, hCtl:dword, bPrevious:DWORD

		xor eax, eax
		@strace	<"GetNextDlgTabItem(", hDlg, ", ", hCtl, ", ", bPrevious, ")=", eax, " *** unsupp ***">
		ret
		align 4
GetNextDlgTabItem endp

GetDialogBaseUnits proc public

		mov eax, 00040004h
		@strace	<"GetDialogBaseUnits()=", eax>
		ret
		align 4
GetDialogBaseUnits endp

		end
