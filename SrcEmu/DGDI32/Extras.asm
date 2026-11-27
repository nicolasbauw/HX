
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

CreateRectRgn proto stdcall :SDWORD, :SDWORD, :SDWORD, :SDWORD

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

;--- GetStretchBltMode(): the mode set by SetStretchBltMode (the scaling itself does not depend on it)

GetStretchBltMode proc public hdc:dword
		mov ecx, hdc
		movzx eax, [ecx].DCOBJ.bStretch
		.if (!eax)
			mov eax, 1			;BLACKONWHITE, the default
		.endif
		ret
		align 4
GetStretchBltMode endp

;--- brushes with a pattern are not implemented: a hatch brush is a solid brush of its color,
;--- a DIB pattern brush a solid grey one (so that programs that use them keep running)

CreateHatchBrush proc public iHatch:dword, crColor:COLORREF
		invoke CreateSolidBrush, crColor
		ret
		align 4
CreateHatchBrush endp

CreateDIBPatternBrushPt proc public lpPackedDIB:ptr, iUsage:dword
		invoke CreateSolidBrush, 808080h
		ret
		align 4
CreateDIBPatternBrushPt endp

;--- a rectangular region (the rounded corners are ignored)

CreateRoundRectRgn proc public nLeft:SDWORD, nTop:SDWORD, nRight:SDWORD, nBottom:SDWORD, nWidthEllipse:SDWORD, nHeightEllipse:SDWORD
		invoke CreateRectRgn, nLeft, nTop, nRight, nBottom
		ret
		align 4
CreateRoundRectRgn endp


		end
