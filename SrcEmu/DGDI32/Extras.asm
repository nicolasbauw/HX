
;--- small functions that programs call and HX's GDI32 emulation did not have

		.386
		.MODEL FLAT, stdcall
		option casemap:none
		option proc:private

		include winbase.inc
		include wingdi.inc
		include dgdi32.inc
		include macros.inc

LOGPEN_ struct
lopnStyle	DWORD ?
lopnWidthX	DWORD ?
lopnWidthY	DWORD ?
lopnColor	DWORD ?
LOGPEN_ ends

		.CODE

;--- the origin of brushes is always 0,0 (patterns are aligned to the screen)

GetBrushOrgEx proc public hdc:dword, lppt:ptr POINT
		mov ecx, lppt
		.if (ecx)
			mov dword ptr [ecx], 0
			mov dword ptr [ecx+4], 0
		.endif
		@mov eax, 1
		ret
		align 4
GetBrushOrgEx endp

SetBrushOrgEx proc public hdc:dword, nXOrg:dword, nYOrg:dword, lppt:ptr POINT
		mov ecx, lppt
		.if (ecx)
			mov dword ptr [ecx], 0
			mov dword ptr [ecx+4], 0
		.endif
		@mov eax, 1
		ret
		align 4
SetBrushOrgEx endp

CreatePenIndirect proc public lplgpn:ptr LOGPEN_
		mov ecx, lplgpn
		invoke CreatePen, [ecx].LOGPEN_.lopnStyle, [ecx].LOGPEN_.lopnWidthX, [ecx].LOGPEN_.lopnColor
		ret
		align 4
CreatePenIndirect endp

GetBkMode proc public hdc:dword
		mov ecx, hdc
		movzx eax, [ecx].DCOBJ.bBkMode
		ret
		align 4
GetBkMode endp

		end
