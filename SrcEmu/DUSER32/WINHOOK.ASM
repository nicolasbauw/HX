
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
        include duser32.inc
        include macros.inc

		.DATA

;--- hooks are kept in a small table, but only WH_CBT is called (HCBT_CREATEWND, by
;--- CreateWindowEx, before WM_CREATE: MFC subclasses its windows there, and its
;--- CWnd::CreateEx fails if the hook cannot be set). Other hooks are accepted and
;--- never called (keyboard, message filters...): programs that only need the call
;--- to succeed go on.

?MAXHOOKS equ 16
?WH_CBT equ 5
?HCBT_CREATEWND equ 3

HOOKENTRY struct
idHook	dd ?
lpfn	dd ?		;0: free entry
dwSeq	dd ?		;order of installation
HOOKENTRY ends

g_Hooks	HOOKENTRY ?MAXHOOKS dup (<0,0,0>)
g_dwHookSeq dd 0

        .CODE

;--- entry of a hook handle, or 0

_HookEntry proc hhk:dword
		mov eax, hhk
		.if ((eax >= offset g_Hooks) && (eax < offset g_Hooks + ?MAXHOOKS * sizeof HOOKENTRY))
			sub eax, offset g_Hooks
			xor edx, edx
			mov ecx, sizeof HOOKENTRY
			div ecx
			.if (edx)
				xor eax, eax
			.else
				mov eax, hhk
			.endif
		.else
			xor eax, eax
		.endif
		ret
		align 4
_HookEntry endp

;--- newest hook of type idHook installed before dwSeq (-1: any), or 0

_FindHook proc uses ebx idHook:dword, dwSeq:dword
		xor eax, eax
		xor edx, edx		;sequence of the best entry
		mov ecx, offset g_Hooks
		mov ebx, ?MAXHOOKS
		.while (ebx)
			.if ([ecx].HOOKENTRY.lpfn)
				push eax
				mov eax, idHook
				cmp eax, [ecx].HOOKENTRY.idHook
				pop eax
				.if (ZERO?)
					push eax
					mov eax, [ecx].HOOKENTRY.dwSeq
					.if ((eax < dwSeq) && (eax >= edx))
						mov edx, eax
						pop eax
						mov eax, ecx
					.else
						pop eax
					.endif
				.endif
			.endif
			add ecx, sizeof HOOKENTRY
			dec ebx
		.endw
		ret
		align 4
_FindHook endp

SetWindowsHookExA proc public idHook:DWORD, lpfn:HOOKPROC, hMod:HINSTANCE, dwThreadId:DWORD

		xor eax, eax
		.if (lpfn)
			mov ecx, offset g_Hooks
			mov edx, ?MAXHOOKS
			.while (edx)
				.if (![ecx].HOOKENTRY.lpfn)
					mov eax, idHook
					mov [ecx].HOOKENTRY.idHook, eax
					inc g_dwHookSeq
					mov eax, g_dwHookSeq
					mov [ecx].HOOKENTRY.dwSeq, eax
					mov eax, lpfn
					mov [ecx].HOOKENTRY.lpfn, eax
					mov eax, ecx
					.break
				.endif
				add ecx, sizeof HOOKENTRY
				dec edx
			.endw
		.endif
        @strace <"SetWindowsHookExA(", idHook, ", ", lpfn, ", ", hMod, ", ", dwThreadId, ")=", eax>
		ret
        align 4
SetWindowsHookExA endp

UnhookWindowsHookEx proc public hhk:dword

		invoke _HookEntry, hhk
		.if (eax)
			mov [eax].HOOKENTRY.lpfn, 0
			mov eax, 1
		.endif
        @strace <"UnhookWindowsHookEx(", hhk, ")=", eax>
		ret
        align 4
UnhookWindowsHookEx endp

;--- calls the next (older) hook of the same type

CallNextHookEx proc public hhk:dword, nCode:dword, wParam:WPARAM, lParam:LPARAM

		invoke _HookEntry, hhk
		.if (eax)
			invoke _FindHook, [eax].HOOKENTRY.idHook, [eax].HOOKENTRY.dwSeq
			.if (eax)
				push lParam
				push wParam
				push nCode
				call [eax].HOOKENTRY.lpfn
			.endif
		.endif
        @strace <"CallNextHookEx(", hhk, ", ", nCode, ", ", wParam, ", ", lParam, ")=", eax>
		ret
        align 4
CallNextHookEx endp

;--- called by CreateWindowEx: newest WH_CBT hook, HCBT_CREATEWND. eax = its result
;--- (non zero: the window must not be created)

_CallCbtCreate proc public hWnd:dword, lpcs:ptr

local	cbt[2]:dword			;CBT_CREATEWND: lpcs, hwndInsertAfter

		invoke _FindHook, ?WH_CBT, -1
		.if (eax)
			mov ecx, lpcs
			mov cbt[0], ecx
			mov cbt[4], 0
			lea ecx, cbt
			push ecx
			push hWnd
			push ?HCBT_CREATEWND
			call [eax].HOOKENTRY.lpfn
		.endif
		@strace <"_CallCbtCreate(", hWnd, ")=", eax>
		ret
		align 4
_CallCbtCreate endp

        END
