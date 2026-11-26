
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

;--- modal dialogs run without a dialog manager: no template is read, no control is created.
;--- the dialog is a real, hidden window (so that SendMessage(hDlg, WM_SETICON...), GetWindowRect(hDlg)
;--- and the like work) of the class "HXDlg", whose window procedure hands every message to the
;--- dialog procedure (DefWindowProc if it returns FALSE). The dialog procedure gets WM_INITDIALOG,
;--- then WM_COMMAND with IDOK (as if the user accepted the defaults), then IDCANCEL, then WM_CLOSE,
;--- until it calls EndDialog(). If the window cannot be created, the "window handle" is a pointer to
;--- the DLGSTATE on the stack of the caller and the dialog procedure is called directly.

DLGSTATE struct
pPrev		dd ?		;enclosing modal dialog
bEnded		dd ?
dwRC		dd ?
hDlg		dd ?		;window of the dialog, or 0
lpProc		dd ?		;dialog procedure
DLGSTATE ends

g_pDlg		dd 0		;innermost modal dialog
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

_RunDialog proc uses ebx lpDialogProc:dword, dwInitParm:dword, hwndParent:dword

local	dlg:DLGSTATE
local	wc:WNDCLASS
local	hInst:dword

		mov eax, g_pDlg
		mov dlg.pPrev, eax
		mov dlg.bEnded, 0
		mov dlg.dwRC, 1		;IDOK if the procedure never calls EndDialog
		mov dlg.hDlg, 0
		mov eax, lpDialogProc
		mov dlg.lpProc, eax
		lea ebx, dlg
		mov g_pDlg, ebx
		.if (lpDialogProc)
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
				mov dlg.hDlg, eax
				invoke SetWindowLongA, eax, 0, ebx
			.endif
			invoke _DlgSend, ebx, WM_INITDIALOG, 0, dwInitParm
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

		invoke _RunDialog, lpDialogProc, dwInitParm, hwndParent
		@strace	<"DialogBoxParamA(", hInstance, ", ", lpTemplateName, ", ", hwndParent, ", ", lpDialogProc, ", ", dwInitParm, ")=", eax, " (no controls: IDOK sent)">
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

		invoke _RunDialog, lpDialogProc, dwInitParm, hwndParent
		@strace	<"DialogBoxIndirectParamA(", hInstance, ", ", lpTemplate, ", ", hwndParent, ", ", lpDialogProc, ", ", dwInitParm, ")=", eax, " (no controls: IDOK sent)">
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

CreateDialogParamA proc public hInstance:dword, lpTemplateName:dword, 
		hwndParent:HWND, lpDialogProc:dword, dwInitParm:dword

		xor eax, eax
		@strace	<"CreateDialogParamA(", hInstance, ", ", lpTemplateName, ", ", hwndParent, ", ", lpDialogProc, ", ", dwInitParm, ")=", eax, " *** unsupp ***">
		ret
		align 4
CreateDialogParamA endp

IsDialogMessageA proc public hDlg:dword, lpMsg:ptr MSG
		xor eax, eax
		@strace	<"IsDialogMessageA(", hDlg, ", ", lpMsg, ")=", eax, " *** unsupp ***">
		ret
		align 4
IsDialogMessageA endp

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
		xor eax, eax
		@strace	<"CheckDlgButton(", hDlg, ", ", dwId, ",", uCheck, ")=", eax, " *** unsupp">
		ret
		align 4
CheckDlgButton endp

IsDlgButtonChecked proc public hDlg:dword, dwId:dword
		xor eax, eax
		@strace	<"IsDlgButtonChecked(", hDlg, ", ", dwId, ")=", eax, " *** unsupp">
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

		invoke GetDlgItem, hDlg, dwID
		.if (eax)
			invoke SendMessage, eax, msg, wParam, lParam
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
