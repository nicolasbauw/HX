
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
	include macros.inc

	.CODE

ConvertWStr proc public
	and eax, eax
	jz exit
	push eax
	invoke lstrlenW, eax
	add eax,3+1
	and al,0FCh
	pop ecx
	pop edx
	sub esp,eax
	mov eax,esp
	push edx
	push esi
	push edi
	mov edi, eax
	mov edx, eax
	mov esi, ecx
@@:
	lodsw
	stosb
	and ax,ax
	jnz @B
	mov eax, edx
	pop edi
	pop esi
exit:
	ret
	align 4
ConvertWStr endp

;--- module of a file: the module itself if it is loaded (a DLL that reads its own version
;--- in its DllMain, like Intel's IJL), else loaded here. edx = 1 if it must be freed.

_OpenMod proc lpszFilename:ptr BYTE

	invoke GetModuleHandleA, lpszFilename
	xor edx, edx
	.if (!eax)
		invoke LoadLibrary, lpszFilename
		mov edx, 1
	.endif
	ret
	align 4

_OpenMod endp

;--- as in Windows, the buffer has room for ANSI copies of the strings after the
;--- version resource, marked by the signature "FE2X" (used by VerQueryValueA).

?SIGFE2X equ 58324546h

GetFileVersionInfoA proc public uses ebx esi edi lpszFilename:ptr BYTE, dwHandle:dword, dwLen:dword, lpData:ptr

local	bFree:dword
local	pRes:dword

	xor esi, esi
	invoke _OpenMod, lpszFilename
	.if (eax)
		mov ebx, eax
		mov bFree, edx
		invoke FindResource, ebx, 1, RT_VERSION
		.if (eax)
			mov edi, eax
			invoke LoadResource, ebx, edi
			.if (eax)
				mov pRes, eax
				invoke SizeofResource, ebx, edi
				mov edi, eax		;size of the resource
				mov ecx, dwLen
				.if (eax > ecx)
					mov eax, ecx
				.endif
				invoke CopyMemory, lpData, pRes, eax
				add edi, 3
				and edi, not 3
				lea eax, [edi*2+4]
				.if (eax <= dwLen)
					mov eax, lpData
					mov dword ptr [eax+edi], ?SIGFE2X
				.endif
				mov esi, 1
			.endif
		.endif
		.if (bFree)
			invoke FreeLibrary, ebx
		.endif
	.endif
	mov eax, esi
	@strace <"GetFileVersionInfoA(", lpszFilename, ", ", dwHandle, ", ", dwLen, ", ", lpData, ")=", eax>
	ret
	align 4

GetFileVersionInfoA endp

GetFileVersionInfoW proc public uses ebx lpszFilename:ptr BYTE, dwHandle:dword, dwLen:dword, lpData:ptr

	mov eax, lpszFilename
	call ConvertWStr
	invoke GetFileVersionInfoA, eax, dwHandle, dwLen, lpData
	@strace <"GetFileVersionInfoW(", lpszFilename, ", ", dwHandle, ", ", dwLen, ", ", lpData, ")=", eax>
	ret
	align 4

GetFileVersionInfoW endp

GetFileVersionInfoSizeA proc public uses ebx esi lpszFilename:ptr BYTE, lpdwHandle:ptr dword

local	bFree:dword

	mov ecx, lpdwHandle
	.if (ecx)
		mov dword ptr [ecx], 0
	.endif
	xor esi, esi
	invoke _OpenMod, lpszFilename
	.if (eax)
		mov ebx, eax
		mov bFree, edx
		invoke FindResource, ebx, 1, RT_VERSION
		.if (eax)
			invoke SizeofResource, ebx, eax
			.if (eax)
				add eax, 3
				and eax, not 3
				lea esi, [eax*2+4]	;room for the ANSI strings, as Windows
			.endif
		.endif
		.if (bFree)
			invoke FreeLibrary, ebx
		.endif
	.endif
	mov eax, esi
	@strace <"GetFileVersionInfoSizeA(", lpszFilename, ", ", lpdwHandle, ")=", eax>
	ret
	align 4

GetFileVersionInfoSizeA endp

GetFileVersionInfoSizeW proc public uses ebx lpszFilename:ptr WORD, lpdwHandle:ptr dword

	mov eax, lpszFilename
	call ConvertWStr
	invoke GetFileVersionInfoSizeA, eax, lpdwHandle
	@strace <"GetFileVersionInfoSizeW(", lpszFilename, ", ", lpdwHandle, ")=", eax>
	ret
	align 4

GetFileVersionInfoSizeW endp

;--- VS_VERSIONINFO: nodes of WORD wLength, WORD wValueLength, WORD wType (1: text, wValueLength
;--- in WCHARs; 0: binary, in bytes), WCHAR szKey[], padding to a DWORD, value, padding, children.

;--- value of a node: eax = address, ecx = size in bytes

_ValueOf proc pNode:ptr

	mov eax, pNode
	add eax, 6
	.while (word ptr [eax])
		add eax, 2
	.endw
	add eax, 2+3
	and eax, not 3
	mov edx, pNode
	movzx ecx, word ptr [edx+2]
	.if (word ptr [edx+4] == 1)
		shl ecx, 1
	.endif
	ret
	align 4

_ValueOf endp

;--- compare the key (WCHAR) of a node with a path component (ending with '\' or 0),
;--- ignoring case: eax = end of the component if they match, else 0

_KeyMatch proc uses ebx pKey:ptr, pComp:ptr, bWide:dword

	mov edx, pKey
	mov ecx, pComp
	.while (1)
		.if (bWide)
			movzx eax, word ptr [ecx]
		.else
			movzx eax, byte ptr [ecx]
		.endif
		movzx ebx, word ptr [edx]
		.if ((eax == 0) || (eax == '\'))
			.if (ebx)
				xor eax, eax
			.else
				mov eax, ecx
			.endif
			jmp done
		.endif
		.if ((eax >= 'A') && (eax <= 'Z'))
			or al, 20h
		.endif
		.if ((ebx >= 'A') && (ebx <= 'Z'))
			or bl, 20h
		.endif
		.if (eax != ebx)
			xor eax, eax
			jmp done
		.endif
		add edx, 2
		inc ecx
		.if (bWide)
			inc ecx
		.endif
	.endw
done:
	ret
	align 4

_KeyMatch endp

_VerQuery proc uses ebx esi edi pBlock:ptr, lpSubBlock:ptr, bWide:dword, lplpBuffer:ptr ptr, puLen:ptr dword

local	pEnd:dword

	mov ebx, pBlock
	mov esi, lpSubBlock
	xor eax, eax
	and ebx, ebx
	jz exit
	and esi, esi
	jz exit
nextcomp:
	.while (1)				;skip backslashes
		.if (bWide)
			movzx eax, word ptr [esi]
		.else
			movzx eax, byte ptr [esi]
		.endif
		.break .if (eax != '\')
		inc esi
		.if (bWide)
			inc esi
		.endif
	.endw
	and eax, eax
	jz found
	movzx ecx, word ptr [ebx]
	add ecx, ebx
	mov pEnd, ecx
	invoke _ValueOf, ebx
	lea edi, [eax+ecx+3]
	and edi, not 3			;first child
	.while (edi < pEnd)
		movzx ecx, word ptr [edi]
		.break .if (!ecx)
		lea eax, [edi+6]
		invoke _KeyMatch, eax, esi, bWide
		.if (eax)
			mov esi, eax
			mov ebx, edi
			jmp nextcomp
		.endif
		movzx ecx, word ptr [edi]
		lea edi, [edi+ecx+3]
		and edi, not 3
	.endw
	xor eax, eax
	jmp exit
found:
	invoke _ValueOf, ebx
	movzx ecx, word ptr [ebx+2]	;wValueLength
	.if ((!bWide) && (word ptr [ebx+4] == 1) && ecx)
		;--- ANSI copy of the string: after the resource if the buffer has room
		;--- (signature), else in place (narrowing never overtakes the source)
		mov esi, eax
		mov edi, eax
		mov edx, pBlock
		movzx eax, word ptr [edx]
		add eax, 3
		and eax, not 3
		.if (dword ptr [edx+eax] == ?SIGFE2X)
			lea edi, [edx+eax+4]
			mov eax, esi
			sub eax, edx
			shr eax, 1
			add edi, eax
		.endif
		push edi
		push ecx
		.repeat
			lodsw
			stosb
			.break .if (!ax)
		.untilcxz
		mov byte ptr [edi-1], al	;keeps the terminating 0 if it was cut
		.if (al)
			mov byte ptr [edi], 0
		.endif
		pop ecx
		pop eax
	.endif
	mov edx, lplpBuffer
	.if (edx)
		mov [edx], eax
	.endif
	mov edx, puLen
	.if (edx)
		mov [edx], ecx
	.endif
	mov eax, 1
exit:
	ret
	align 4

_VerQuery endp

VerQueryValueA proc public pBlock:ptr, lpSubBlock:ptr BYTE, lplpBuffer:ptr ptr, puLen:ptr dword

	invoke _VerQuery, pBlock, lpSubBlock, 0, lplpBuffer, puLen
	@strace <"VerQueryValueA(", pBlock, ", ", lpSubBlock, ", ", lplpBuffer, ", ", puLen, ")=", eax>
	ret
	align 4

VerQueryValueA endp

VerQueryValueW proc public pBlock:ptr, lpSubBlock:ptr WORD, lplpBuffer:ptr ptr, puLen:ptr dword

	invoke _VerQuery, pBlock, lpSubBlock, 1, lplpBuffer, puLen
	@strace <"VerQueryValueW(", pBlock, ", ", lpSubBlock, ", ", lplpBuffer, ", ", puLen, ")=", eax>
	ret
	align 4

VerQueryValueW endp

	end
