;--- small functions that programs call and HX's OLE32 emulation did not have

        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include windef.inc
        include winbase.inc
        include objbase.inc
        include macros.inc

        .CODE

;--- IsEqualGUID(): TRUE if the two 16 byte GUIDs are the same

IsEqualGUID proc public uses esi edi pGuidA:REFGUID, pGuidB:REFGUID
		mov esi, pGuidA
		mov edi, pGuidB
		mov ecx, 4
		repe cmpsd
		setz al
		movzx eax, al
		@strace <"IsEqualGUID(", pGuidA, ", ", pGuidB, ")=", eax>
		ret
		align 4
IsEqualGUID endp

;--- CoBuildVersion(): version of the COM library, MAKELONG(rup, rmm) with rmm = 23 and rup = 700 (OLE 2.3)

CoBuildVersion proc public
		mov eax, 0017h * 10000h + 700
		@strace <"CoBuildVersion()=", eax>
		ret
		align 4
CoBuildVersion endp


;--- not implemented (imported by MFC based programs, which only need them to load)

IsAccelerator proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"IsAccelerator()=", eax, " *** unsupp ***">
		ret
		align 4
IsAccelerator endp

OleDraw proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
		xor eax, eax
		@strace <"OleDraw()=", eax, " *** unsupp ***">
		ret
		align 4
OleDraw endp

OleSetMenuDescriptor proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
		xor eax, eax
		@strace <"OleSetMenuDescriptor()=", eax, " *** unsupp ***">
		ret
		align 4
OleSetMenuDescriptor endp

StringFromCLSID proc public p1:dword, p2:dword
		xor eax, eax
		@strace <"StringFromCLSID()=", eax, " *** unsupp ***">
		ret
		align 4
StringFromCLSID endp

		end
