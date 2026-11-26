
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include wingdi.inc
        include dgdi32.inc
        include macros.inc


        .CODE

SetStretchBltMode proc public hdc:dword, bMode:dword
		mov ecx, hdc
        mov eax, bMode
      	xchg al, [ecx].DCOBJ.bStretch
        movzx eax, al
        @strace <"SetStretchBltMode(", hdc, ", ", bMode, ")=", eax>
		ret
        align 4
SetStretchBltMode endp

;--- StretchBlt: nearest neighbour scaling, SRCCOPY only, sources of 8, 16, 24 or 32 bits.
;--- the source rectangle is scaled into a temporary bitmap of the size of the destination
;--- (limited to the size of the destination DC), which has the orientation of the source
;--- and is then copied by BitBlt(), so that BitBlt() keeps doing the color conversion.
;--- same size, other raster operation, 1 and 4 bit sources, sizes <= 0: plain BitBlt().

StretchBlt proc public uses ebx esi edi hdcDst:dword, nXOriginDst:dword, nYOriginDst:dword, 
				nWidthDst:dword, nHeightDst:dword,
                hdcSrc:dword, nXOriginSrc:dword, nYOriginSrc:dword, 
				nWidthSrc:dword, nHeightSrc:dword,
                dwRop:dword

local	dcTmp:DCOBJ
local	pBuf:DWORD
local	dwPitch:DWORD
local	dwBytes:DWORD
local	dwW:DWORD
local	dwH:DWORD
local	dwDY:DWORD
local	pSrcRow:DWORD
local	pDstRow:DWORD
local	dwResult:DWORD

		mov esi, hdcSrc
		mov edi, hdcDst
		test esi, esi
		jz plain
		test edi, edi
		jz plain
		cmp dwRop, SRCCOPY
		jnz plain
		mov eax, nWidthDst
		cmp eax, nWidthSrc
		jnz @F
		mov eax, nHeightDst
		cmp eax, nHeightSrc
		jz plain
@@:
		cmp nWidthDst, 0
		jle plain
		cmp nHeightDst, 0
		jle plain
		cmp nWidthSrc, 0
		jle plain
		cmp nHeightSrc, 0
		jle plain
		mov eax, [esi].DCOBJ.dwBpp
		cmp eax, 15
		jnz @F
		mov eax, 16
@@:
		cmp eax, 8
		jz bppok
		cmp eax, 16
		jz bppok
		cmp eax, 24
		jz bppok
		cmp eax, 32
		jnz plain
bppok:
		shr eax, 3
		mov dwBytes, eax
		cmp [esi].DCOBJ.dwWidth, 0
		jz plain
		cmp [esi].DCOBJ.dwHeight, 0
		jz plain
		mov eax, nWidthDst
		cmp eax, [edi].DCOBJ.dwWidth
		jbe @F
		mov eax, [edi].DCOBJ.dwWidth
@@:
		mov dwW, eax
		mov eax, nHeightDst
		cmp eax, [edi].DCOBJ.dwHeight
		jbe @F
		mov eax, [edi].DCOBJ.dwHeight
@@:
		mov dwH, eax
		cmp dwW, 0
		jz plain
		cmp dwH, 0
		jz plain
		mov eax, dwW
		mul dwBytes
		add eax, 3
		and al, 0FCh
		mov dwPitch, eax
		mul dwH
		invoke _GDImalloc, eax
		and eax, eax
		jz plain
		mov pBuf, eax

		mov dwDY, 0
nextrow:
		mov eax, dwDY
		cmp eax, dwH
		jae rowsdone
		mul nHeightSrc			;line of the source (counted from the top)
		div nHeightDst
		add eax, nYOriginSrc
		add eax, [esi].DCOBJ.ptViewportOrg.y
		test eax, eax
		jns @F
		xor eax, eax
@@:
		mov ecx, [esi].DCOBJ.dwHeight
		cmp eax, ecx
		jb @F
		lea eax, [ecx-1]
@@:
		test [esi].DCOBJ.dwFlags, DCF_BOTTOM_UP
		jz @F
		mov ecx, [esi].DCOBJ.dwHeight
		dec ecx
		sub ecx, eax
		mov eax, ecx
@@:
		mul [esi].DCOBJ.lPitch
		add eax, [esi].DCOBJ.pBMBits
		mov pSrcRow, eax
		mov eax, dwDY			;same line in the temporary bitmap
		test [esi].DCOBJ.dwFlags, DCF_BOTTOM_UP
		jz @F
		mov eax, dwH
		dec eax
		sub eax, dwDY
@@:
		mul dwPitch
		add eax, pBuf
		mov edi, eax
		xor ebx, ebx
nextcol:
		cmp ebx, dwW
		jae coldone
		mov eax, ebx
		mul nWidthSrc
		div nWidthDst
		add eax, nXOriginSrc
		add eax, [esi].DCOBJ.ptViewportOrg.x
		test eax, eax
		jns @F
		xor eax, eax
@@:
		mov ecx, [esi].DCOBJ.dwWidth
		cmp eax, ecx
		jb @F
		lea eax, [ecx-1]
@@:
		imul eax, dwBytes
		add eax, pSrcRow
		mov edx, eax
		mov ecx, dwBytes
@@:
		mov al, [edx]
		mov [edi], al
		inc edx
		inc edi
		dec ecx
		jnz @B
		inc ebx
		jmp nextcol
coldone:
		inc dwDY
		jmp nextrow
rowsdone:
		invoke RtlZeroMemory, addr dcTmp, sizeof DCOBJ
		mov eax, [esi].DCOBJ.dwFlags
		and eax, DCF_BOTTOM_UP
		mov dcTmp.dwFlags, eax
		mov eax, pBuf
		mov dcTmp.pBMBits, eax
		mov dcTmp.pOrigin, eax
		mov eax, [esi].DCOBJ.pColorTab
		mov dcTmp.pColorTab, eax
		mov eax, dwPitch
		mov dcTmp.lPitch, eax
		mov eax, [esi].DCOBJ.dwBpp
		mov dcTmp.dwBpp, eax
		mov eax, dwH
		mov dcTmp.dwHeight, eax
		mov eax, dwW
		mov dcTmp.dwWidth, eax
		invoke BitBlt, hdcDst, nXOriginDst, nYOriginDst, dwW, dwH, addr dcTmp, 0, 0, SRCCOPY
		mov dwResult, eax
		invoke _GDIfree, pBuf
		mov eax, dwResult
		jmp done
plain:
		invoke BitBlt, hdcDst, nXOriginDst, nYOriginDst, nWidthDst, nHeightDst,\
        	hdcSrc, nXOriginSrc, nYOriginSrc, dwRop
done:
        @strace <"StretchBlt(", hdcDst, ", ", nXOriginDst, ", ", nYOriginDst, ", ", nWidthDst, ", ", nHeightDst, ", ", hdcSrc, ", ", nXOriginSrc, ", ", nYOriginSrc, ", ", nWidthSrc, ", ", nHeightSrc, ", ", dwRop, ")=", eax>
		ret
        align 4
StretchBlt endp

StretchDIBits proc public uses esi hdcDst:dword, nXDst:dword, nYDst:dword, 
				nWidthDst:dword, nHeightDst:dword,
                nXSrc:dword, nYSrc:dword, nWidthSrc:dword, nHeightSrc:dword,
				lpBits:ptr, lpBitsInfo:ptr BITMAPINFO, iUsage:dword, dwRop:dword

		invoke CreateCompatibleDC, hdcDst
        .if (eax)
        	mov esi, eax

;--- adjust the DC so it matches the bitmap structure
;--- this is kind of a hack, but works fast. BitBlt()
;--- will provide any color transformation needed
            
        	mov ecx, lpBitsInfo
            movzx eax, [ecx].BITMAPINFOHEADER.biBitCount
            mov [esi].DCOBJ.dwBpp, eax
            mov eax, [ecx].BITMAPINFOHEADER.biWidth
            mov [esi].DCOBJ.dwWidth, eax
            mul [ecx].BITMAPINFOHEADER.biBitCount
            add eax, 31				;DIB lines are dword aligned
            shr eax, 5
            shl eax, 2
            mov [esi].DCOBJ.lPitch, eax
;--- the size of the DC must be the size of the bitmap, not the one of the screen
;--- the compatible DC was made from: BitBlt() limits the lines and the columns
;--- it reads to it (a positive height is a bottom-up bitmap)
            mov eax, [ecx].BITMAPINFOHEADER.biHeight
            or [esi].DCOBJ.dwFlags, DCF_BOTTOM_UP
            test eax, eax
            jns @F
            neg eax
            and [esi].DCOBJ.dwFlags, not DCF_BOTTOM_UP
@@:
            mov [esi].DCOBJ.dwHeight, eax
            mov eax, lpBits
            mov [esi].DCOBJ.pBMBits, eax
            mov [esi].DCOBJ.pOrigin, eax

			lea eax, [ecx+sizeof BITMAPINFOHEADER]            
            mov [esi].DCOBJ.pColorTab, eax
            
            mov eax, nYSrc
            test [esi].DCOBJ.dwFlags, DCF_BOTTOM_UP
            jz @F
            mov eax, [esi].DCOBJ.dwHeight		;the origin of the source of a bottom-up DIB is its lower left corner
            sub eax, nYSrc
            sub eax, nHeightSrc
@@:
            invoke StretchBlt, hdcDst, nXDst, nYDst, nWidthDst, nHeightDst, esi, nXSrc, eax, nWidthSrc, nHeightSrc, dwRop
            
            invoke DeleteDC, esi
        .endif
        @strace <"StretchDIBits(", hdcDst, ", ", nXDst, ", ", nYDst, ", ", nWidthDst, ", ", nHeightDst, ", ", nXSrc, ", ", nYSrc, ", ", nWidthSrc, ", ", nHeightSrc, ", ", lpBits, ", ", lpBitsInfo, ", ", iUsage, ", ", dwRop, ")=", eax>
		ret
        align 4
StretchDIBits endp

		end
