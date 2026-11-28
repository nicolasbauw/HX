
;--- implements icon functions:
;--- CopyIcon
;--- CreateIcon
;--- CreateIconFromResource
;--- CreateIconFromResourceEx
;--- CreateIconIndirect
;--- DestroyIcon
;--- DrawIconEx
;--- GetIconInfo
;--- LoadIcon

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
        include duser32.inc
        include macros.inc

?FORMVER	equ 030000h

		.CODE

CreateIconIndirect proc public pIconInfo:ptr ICONINFO
		xor eax,eax
		@strace	<"CreateIconIndirect(", pIconInfo, ")=", eax, " *** unsupp ***">
		ret
        align 4
CreateIconIndirect endp

CreateIcon proc public hInstance:DWORD, nWidth:DWORD, nHeight:DWORD,
			cPlanes:DWORD, cBitsPixel:DWORD, lpbANDbits:ptr, lpbXORbits:ptr
		xor eax,eax
		@strace	<"CreateIcon(", hInstance, ", ", nWidth, ", ", nHeight, ", ", cPlanes, ", ", cBitsPixel, ", ...)=", eax, " *** unsupp ***">
		ret
        align 4
CreateIcon endp

DestroyIcon proc public hIcon:DWORD
		mov eax, 1
		@strace	<"DestroyIcon(", hIcon, ")=", eax>
		ret
        align 4
DestroyIcon endp

;--- icons are never drawn (DrawIcon/DrawIconEx do nothing): the "handle" of an icon is
;--- the address of its resource data, so that LoadIcon, and SetClassLong(GCL_HICON) after it,
;--- succeed as on Windows (MFC treats a NULL previous icon as an error).

CreateIconFromResource proc public pResBits:ptr, dwSize:DWORD, bIcon:DWORD, dwVer:DWORD
		xor eax, eax
		.if (dwSize)
			mov eax, pResBits
		.endif
		@strace	<"CreateIconFromResource(", pResBits, ", ", dwSize, ", ", bIcon, ", ", dwVer, ")=", eax>
		ret
        align 4
CreateIconFromResource endp

CreateIconFromResourceEx proc public pbIconBits:ptr, cbIconBits:DWORD, fIcon:DWORD,
			dwVersion:DWORD, cxDesired:DWORD, cyDesired:DWORD, uFlags:DWORD
		xor eax,eax
		.if (cbIconBits)
			mov eax, pbIconBits
		.endif
		@strace	<"CreateIconFromResourceEx(", pbIconBits, ", ", cbIconBits, ", ", fIcon, ", ", dwVersion, ", ", cxDesired, ", ", cyDesired, ", ", uFlags, ")=", eax>
		ret
        align 4
CreateIconFromResourceEx endp

LoadIconA proc public uses ebx hInstance:HINSTANCE, lpIconName:ptr BYTE

local	dwSysIcon:dword

		mov dwSysIcon, 0
        .if (!hInstance)
        	mov eax, lpIconName
        	.if (eax < 10000h)
        		mov dwSysIcon, eax	;IDI_xxx
        	.endif
        	mov ecx, g_hInstance
            mov hInstance, ecx
            mov edx, lpIconName
            test edx, 0FFFF0000h
            .if (ZERO?)
            	sub lpIconName, 32512 - 52
            .endif
        .endif
if 1        
        invoke FindResource, hInstance, lpIconName, RT_GROUP_ICON
        .if (eax)
        	invoke LoadResource, hInstance, eax
            .if (eax)
				mov ebx, eax
                add ebx, sizeof NEWHEADER
                movzx eax, [ebx].RESDIR.IconCursorId
	            invoke FindResource, hInstance, eax, RT_ICON
        	.endif
        .endif
else
        invoke FindResource, hInstance, lpIconName, RT_ICON
endif       
        .if (eax)
        	mov ebx, eax		;HRSRC of the RT_ICON resource
        	invoke LoadResource, hInstance, eax
            .if (eax)
            	push eax
                invoke SizeofResource, hInstance, ebx
                mov ecx, eax
                pop eax
            	invoke CreateIconFromResource, eax, ecx, TRUE, ?FORMVER
            .endif
        .endif
;--- system icons (IDI_APPLICATION...) are not in DUSER32: their id is their "handle"
        .if ((!eax) && (dwSysIcon))
        	mov eax, dwSysIcon
        .endif
		@strace	<"LoadIconA(", hInstance, ", ", lpIconName, ")=", eax>
		ret
        align 4
LoadIconA endp

CopyIcon proc public hIcon:DWORD
		mov eax, hIcon
		@strace	<"CopyIcon(", hIcon, ")=", eax>
		ret
        align 4
CopyIcon endp

GetIconInfo proc public hIcon:HICON, pIconInfo:ptr ICONINFO
		xor eax, eax
		@strace	<"GetIconInfo(", hIcon, ", ", pIconInfo, ")=", eax, " *** unsupp ***">
		ret
        align 4
GetIconInfo endp

		end

