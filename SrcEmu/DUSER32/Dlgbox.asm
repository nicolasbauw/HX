
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

;--- dialogs run without a real dialog manager. The dialog is a real, hidden
;--- window (so that SendMessage(hDlg, WM_SETICON...), GetWindowRect(hDlg) and the like work) of the
;--- class "HXDlg", whose window procedure hands every message to the dialog procedure (DefWindowProc
;--- if it returns FALSE). The template is only read to find the default push button: the dialog
;--- procedure gets WM_INITDIALOG, then WM_COMMAND with the id of that button (as if the user had
;--- pressed Enter on the setup dialog of a demo: "Start", "Run"...), then IDOK, IDCANCEL and WM_CLOSE,
;--- until it calls EndDialog(). A modeless dialog (CreateDialogParam) gets WM_INITDIALOG, and the
;--- WM_COMMAND of its default button is posted to its window. The check state of buttons set by
;--- CheckDlgButton/CheckRadioButton/BM_SETCHECK is kept, so IsDlgButtonChecked reads back the
;--- defaults chosen by the program. Each item of the template becomes a hidden child window of
;--- the class "HXCtl" (with its id, style and text), so that GetDlgItem finds it: it keeps its
;--- text, its check state, the strings, item data and selection of a combo or list box and the
;--- position of a trackbar, which is what the dialog procedures of demos (and MFC's DDX_ functions)
;--- read back. Nothing is drawn. If the window of a modal dialog cannot be created, the
;--- "window handle" is a pointer to the DLGSTATE on the stack of the caller and the dialog procedure
;--- is called directly.

?MAXCHECKS	equ 32
?BUTTON		equ 80h		;atom of the class "BUTTON" in templates
?DEFPUSH	equ 1		;BS_DEFPUSHBUTTON
?SETFONT	equ 40h		;DS_SETFONT
?BMGETCHECK	equ 0F0h
?BMSETCHECK	equ 0F1h
?NCDESTROY	equ 82h
?MAXITEMS	equ 64

;--- window extra bytes of a dialog: as Windows (DLGWINDOWEXTRA, 30 bytes: DWL_MSGRESULT at 0,
;--- DWL_DLGPROC at 4, DWL_USER at 8, used by many dialog procedures), then the DLGSTATE
?DLGEXTRA	equ 36
?DLGSTATEOFS	equ 32

;--- window extra bytes of a control
CTL_CHECK	equ 0
CTL_CURSEL	equ 4
CTL_COUNT	equ 8
CTL_ITEMS	equ 12		;?MAXITEMS * (pszText, dwData)
CTL_POS		equ 16
CTL_EXTRA	equ 20

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
g_bDlgClass	dd 0		;classes "HXDlg" and "HXCtl" registered

IsWindow proto :dword

		.code

_DlgWndProc proc uses ebx hWnd:dword, msg:dword, wParam:dword, lParam:dword

		invoke GetWindowLongA, hWnd, ?DLGSTATEOFS
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
			mov wc.cbWndExtra, ?DLGEXTRA
			mov eax, hInst
			mov wc.hInstance, eax
			mov wc.lpszClassName, CStr("HXDlg")
			invoke RegisterClassA, addr wc
			mov wc.lpfnWndProc, offset _CtlWndProc
			mov wc.cbWndExtra, CTL_EXTRA
			mov wc.lpszClassName, CStr("HXCtl")
			invoke RegisterClassA, addr wc
			mov g_bDlgClass, 1
		.endif
		invoke CreateWindowExA, 0, CStr("HXDlg"), CStr(""), WS_POPUP, 0, 0, 0, 0, hwndParent, 0, hInst, 0
		.if (eax)
			mov [ebx].DLGSTATE.hDlg, eax
			push eax
			invoke SetWindowLongA, eax, ?DLGSTATEOFS, ebx
			mov eax, [esp]
			invoke SetWindowLongA, eax, 4, [ebx].DLGSTATE.lpProc	;DWL_DLGPROC
			pop eax
		.endif
		ret
		align 4
_DlgCreateWindow endp

;--- the controls: hidden child windows of the class "HXCtl"

;--- address of the item array of a control (allocated on first use), or 0

_CtlItems proc hWnd:dword
		invoke GetWindowLongA, hWnd, CTL_ITEMS
		.if (!eax)
			invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, ?MAXITEMS * 8
			.if (eax)
				push eax
				invoke SetWindowLongA, hWnd, CTL_ITEMS, eax
				pop eax
			.endif
		.endif
		ret
		align 4
_CtlItems endp

;--- index of the item whose text is pszText (no case), searched from index dwStart+1, or -1

_CtlFind proc uses ebx esi edi hWnd:dword, dwStart:dword, pszText:ptr byte
		invoke GetWindowLongA, hWnd, CTL_COUNT
		mov edi, eax
		invoke GetWindowLongA, hWnd, CTL_ITEMS
		mov esi, eax
		mov ebx, dwStart
		inc ebx
		.if (ebx >= edi)
			xor ebx, ebx
		.endif
		.if (esi && pszText)
			.while (ebx < edi)
				mov eax, [esi+ebx*8]
				.if (eax)
					invoke lstrcmpi, eax, pszText
					.if (!eax)
						mov eax, ebx
						jmp done
					.endif
				.endif
				inc ebx
			.endw
		.endif
		mov eax, -1
done:
		ret
		align 4
_CtlFind endp

_CtlWndProc proc uses ebx esi hWnd:dword, msg:dword, wParam:dword, lParam:dword

		mov eax, msg
		.if (eax == WM_SETTEXT)
			invoke SetWindowTextA, hWnd, lParam
			mov eax, 1
		.elseif (eax == WM_GETTEXT)
			invoke GetWindowTextA, hWnd, lParam, wParam
		.elseif (eax == WM_GETTEXTLENGTH)
			invoke GetWindowTextLengthA, hWnd
		.elseif (eax == ?BMGETCHECK)
			invoke GetWindowLongA, hWnd, CTL_CHECK
		.elseif (eax == ?BMSETCHECK)
			invoke SetWindowLongA, hWnd, CTL_CHECK, wParam
			xor eax, eax
		.elseif ((eax == 143h) || (eax == 14Ah) || (eax == 180h) || (eax == 181h))
			;CB_ADDSTRING, CB_INSERTSTRING, LB_ADDSTRING, LB_INSERTSTRING (appended)
			invoke GetWindowLongA, hWnd, CTL_COUNT
			mov ebx, eax
			.if (ebx >= ?MAXITEMS)
				mov eax, -1
				jmp done
			.endif
			invoke _CtlItems, hWnd
			.if (!eax)
				mov eax, -1
				jmp done
			.endif
			mov esi, eax
			mov dword ptr [esi+ebx*8], 0
			mov dword ptr [esi+ebx*8+4], 0
			.if (lParam >= 10000h)
				invoke lstrlen, lParam
				inc eax
				invoke LocalAlloc, LMEM_FIXED, eax
				.if (eax)
					mov [esi+ebx*8], eax
					invoke lstrcpy, eax, lParam
				.endif
			.endif
			lea eax, [ebx+1]
			invoke SetWindowLongA, hWnd, CTL_COUNT, eax
			mov eax, ebx
		.elseif ((eax == 146h) || (eax == 18Bh))	;CB_GETCOUNT, LB_GETCOUNT
			invoke GetWindowLongA, hWnd, CTL_COUNT
		.elseif ((eax == 147h) || (eax == 188h))	;CB_GETCURSEL, LB_GETCURSEL
			invoke GetWindowLongA, hWnd, CTL_CURSEL
		.elseif ((eax == 14Eh) || (eax == 186h))	;CB_SETCURSEL, LB_SETCURSEL
			invoke GetWindowLongA, hWnd, CTL_COUNT
			mov ebx, wParam
			.if (ebx >= eax)
				mov ebx, -1
			.endif
			invoke SetWindowLongA, hWnd, CTL_CURSEL, ebx
			mov eax, ebx
		.elseif ((eax == 14Bh) || (eax == 184h))	;CB_RESETCONTENT, LB_RESETCONTENT
			invoke SetWindowLongA, hWnd, CTL_COUNT, 0
			invoke SetWindowLongA, hWnd, CTL_CURSEL, -1
			xor eax, eax
		.elseif ((eax == 144h) || (eax == 182h))	;CB_DELETESTRING, LB_DELETESTRING: the last one only
			invoke GetWindowLongA, hWnd, CTL_COUNT
			.if (eax)
				dec eax
				push eax
				invoke SetWindowLongA, hWnd, CTL_COUNT, eax
				pop eax
			.else
				mov eax, -1
			.endif
		.elseif ((eax == 148h) || (eax == 189h) || (eax == 149h) || (eax == 18Ah))
			;CB_GETLBTEXT, LB_GETTEXT, CB_GETLBTEXTLEN, LB_GETTEXTLEN
			invoke GetWindowLongA, hWnd, CTL_COUNT
			mov ebx, wParam
			.if (ebx >= eax)
				mov eax, -1
				jmp done
			.endif
			invoke GetWindowLongA, hWnd, CTL_ITEMS
			mov esi, [eax+ebx*8]
			xor eax, eax
			.if (esi)
				.if ((msg == 148h) || (msg == 189h))
					invoke lstrcpy, lParam, esi
				.endif
				invoke lstrlen, esi
			.elseif ((msg == 148h) || (msg == 189h))
				mov ecx, lParam
				mov byte ptr [ecx], 0
			.endif
		.elseif ((eax == 150h) || (eax == 199h) || (eax == 151h) || (eax == 19Ah))
			;CB_GETITEMDATA, LB_GETITEMDATA, CB_SETITEMDATA, LB_SETITEMDATA
			invoke GetWindowLongA, hWnd, CTL_COUNT
			mov ebx, wParam
			.if (ebx >= eax)
				mov eax, -1
				jmp done
			.endif
			invoke GetWindowLongA, hWnd, CTL_ITEMS
			lea esi, [eax+ebx*8+4]
			.if ((msg == 150h) || (msg == 199h))
				mov eax, [esi]
			.else
				mov eax, lParam
				mov [esi], eax
				mov eax, 1
			.endif
		.elseif ((eax == 158h) || (eax == 14Ch) || (eax == 1A2h) || (eax == 18Fh))
			;CB_FINDSTRINGEXACT, CB_FINDSTRING, LB_FINDSTRINGEXACT, LB_FINDSTRING (whole strings)
			invoke _CtlFind, hWnd, wParam, lParam
		.elseif ((eax == 14Dh) || (eax == 18Ch))	;CB_SELECTSTRING, LB_SELECTSTRING
			invoke _CtlFind, hWnd, wParam, lParam
			.if (eax != -1)
				push eax
				invoke SetWindowLongA, hWnd, CTL_CURSEL, eax
				pop eax
			.endif
		.elseif (eax == 400h)				;TBM_GETPOS
			invoke GetWindowLongA, hWnd, CTL_POS
		.elseif (eax == 405h)				;TBM_SETPOS
			invoke SetWindowLongA, hWnd, CTL_POS, lParam
			xor eax, eax
		.else
			invoke DefWindowProcA, hWnd, msg, wParam, lParam
		.endif
done:
		ret
		align 4
_CtlWndProc endp

;--- standard control classes (BUTTON, STATIC, EDIT, COMBOBOX, LISTBOX...): HX has none, so a
;--- program that builds its setup window itself got no control. They are registered on first
;--- use (CreateWindowExA calls _StdClass) with the window procedure of the dialog controls. A
;--- push button created with BS_DEFPUSHBUTTON in a window "clicks" itself: its WM_COMMAND
;--- (BN_CLICKED) is posted to its parent, as the default button of a dialog is sent (the setup
;--- window of a demo then starts with its defaults).

		.const
g_StdClasses label byte
		db "BUTTON",0, "STATIC",0, "EDIT",0, "COMBOBOX",0, "LISTBOX",0, "SCROLLBAR",0
		db "msctls_trackbar32",0, "msctls_updown32",0, "msctls_progress32",0, "SysListView32",0
		db "ComboBoxEx32",0, "RichEdit",0, "RICHEDIT20A",0, 0
		.code

_StdCtlWndProc proc hWnd:dword, msg:dword, wParam:dword, lParam:dword

		.if (msg == WM_CREATE)
			mov ecx, lParam
			mov eax, [ecx+32]		;CREATESTRUCT.style
			and eax, 0Fh
			mov edx, [ecx+40]		;CREATESTRUCT.lpszClass
			.if ((eax == ?DEFPUSH) && (dword ptr [ecx+12]) && (edx >= 10000h))
				invoke lstrcmpi, edx, CStr("BUTTON")
				.if (!eax)
					mov ecx, lParam
					movzx eax, word ptr [ecx+8]	;id (hMenu), BN_CLICKED = 0
					invoke PostMessageA, dword ptr [ecx+12], WM_COMMAND, eax, hWnd
				.endif
			.endif
			invoke SetWindowLongA, hWnd, CTL_CURSEL, -1
			xor eax, eax
		.else
			invoke _CtlWndProc, hWnd, msg, wParam, lParam
		.endif
		ret
		align 4
_StdCtlWndProc endp

;--- register a standard control class if lpszClass names one that is not registered yet

_StdClass proc public uses esi lpszClass:dword

local	wc:WNDCLASS

		mov eax, lpszClass
		cmp eax, 10000h
		jb done
		invoke FindAtomA, eax
		.if (eax)
			invoke _FindClass, eax
			and eax, eax
			jnz done
		.endif
		mov esi, offset g_StdClasses
		.while (byte ptr [esi])
			invoke lstrcmpi, esi, lpszClass
			.if (!eax)
				invoke RtlZeroMemory, addr wc, sizeof WNDCLASS
				mov wc.lpfnWndProc, offset _StdCtlWndProc
				mov wc.cbWndExtra, CTL_EXTRA
				invoke GetModuleHandleA, 0
				mov wc.hInstance, eax
				mov eax, lpszClass
				mov wc.lpszClassName, eax
				invoke RegisterClassA, addr wc
				@strace <"_StdClass: registered ", &lpszClass, "=", eax>
				jmp done
			.endif
			invoke lstrlen, esi
			lea esi, [esi+eax+1]
		.endw
done:
		ret
		align 4
_StdClass endp

;--- create the controls of a template as children of the dialog, ebx = DLGSTATE

_DlgCreateControls proc uses esi edi pTemplate:dword

local	dwCount:dword
local	dwStyle:dword
local	dwId:dword
local	bEx:dword
local	hInst:dword
local	szText[128]:byte

		mov esi, pTemplate
		and esi, esi
		jz done
		cmp [ebx].DLGSTATE.hDlg, 0
		jz done
		invoke GetModuleHandleA, 0
		mov hInst, eax
		mov bEx, 0
		.if (dword ptr [esi] == 0FFFF0001h)	;DLGTEMPLATEEX
			mov bEx, 1
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
		mov dwCount, ecx
		call _SkipSzOrd		;menu
		call _SkipSzOrd		;class
		call _SkipSzOrd		;title
		.if (edx & ?SETFONT)
			.if (bEx)
				add esi, 6
			.else
				add esi, 2
			.endif
			call _SkipSzOrd
		.endif
		.while (dwCount)
			add esi, 3
			and esi, not 3
			.if (bEx)
				mov eax, [esi+8]
				movzx ecx, word ptr [esi+20]
				add esi, 24
			.else
				mov eax, [esi]
				movzx ecx, word ptr [esi+16]
				add esi, 18
			.endif
			and eax, not WS_VISIBLE
			or eax, WS_CHILD
			mov dwStyle, eax
			mov dwId, ecx
			call _SkipSzOrd		;class
			;--- text: string (WCHAR, narrowed) or ordinal (no text)
			mov szText, 0
			.if (word ptr [esi] == 0FFFFh)
				add esi, 4
			.else
				lea edi, szText
				xor ecx, ecx
				.repeat
					lodsw
					.if (ecx < sizeof szText - 1)
						stosb
						inc ecx
					.endif
				.until (ax == 0)
				mov byte ptr [edi], 0
			.endif
			movzx eax, word ptr [esi]
			lea esi, [esi+eax+2]	;creation data
			invoke CreateWindowExA, 0, CStr("HXCtl"), addr szText, dwStyle, 0, 0, 0, 0, [ebx].DLGSTATE.hDlg, dwId, hInst, 0
			.if (eax)
				invoke SetWindowLongA, eax, CTL_CURSEL, -1
			.endif
			dec dwCount
		.endw
done:
		ret
		align 4
_DlgCreateControls endp

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
			invoke _DlgCreateControls, pTemplate
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
;--- the hidden window is not destroyed: programs keep hDlg and use it after
;--- DialogBox returns (GetWindowRect, SendMessage...), which Windows rejects
;--- harmlessly, but which would read freed memory here. It is only detached
;--- from the DLGSTATE (on this stack) and left to DefWindowProc.
			.if (dlg.hDlg)
				invoke SetWindowLongA, dlg.hDlg, ?DLGSTATEOFS, 0
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
		invoke _DlgCreateControls, pTemplate
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
		invoke _DlgState, hDlg
		.if (eax)
			mov eax, [eax].DLGSTATE.hDlg
		.else
			invoke IsWindow, hDlg	;a window of another class (dialog of its own)
			.if (eax)
				mov eax, hDlg
			.endif
		.endif
		.if (eax)
			mov eax, [eax].WNDOBJ.hwndChilds
			.while (eax)
				mov ecx, [eax].WNDOBJ.hMenu
				.break .if (cx == word ptr dwId)
				mov eax, [eax].WNDOBJ.hwndSibling
			.endw
		.endif
		@strace	<"GetDlgItem(", hDlg, ", ", dwId, ")=", eax>
		ret
		align 4
GetDlgItem endp

GetDlgCtrlID proc public hwndCtrl:dword
		xor eax, eax
		invoke IsWindow, hwndCtrl
		.if (eax)
			mov eax, hwndCtrl
			mov eax, [eax].WNDOBJ.hMenu
		.endif
		@strace	<"GetDlgCtrlID(", hwndCtrl, ")=", eax>
		ret
		align 4
GetDlgCtrlID endp

CheckDlgButton proc public hDlg:dword, dwId:dword, uCheck:dword
		invoke GetDlgItem, hDlg, dwId
		.if (eax)
			invoke SendMessageA, eax, ?BMSETCHECK, uCheck, 0
		.endif
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
			invoke GetDlgItem, hDlg, ebx
			.if (eax)
				invoke SendMessageA, eax, ?BMSETCHECK, 0, 0
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
		invoke GetDlgItem, hDlg, dwId
		.if (eax)
			invoke SendMessageA, eax, ?BMGETCHECK, 0, 0
		.else
			invoke _DlgCheckEntry, hDlg, dwId, 0
			.if (eax)
				movzx eax, word ptr [eax+2]
			.endif
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
				invoke SendMessageA, eax, msg, wParam, lParam
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
