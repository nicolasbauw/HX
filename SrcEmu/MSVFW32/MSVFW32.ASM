
;--- MSVFW32.DLL: the DrawDib functions of Video for Windows (the part of it that demos and games
;--- use to put a bitmap on the screen). DrawDibDraw() draws through StretchDIBits(); the other
;--- functions only keep a program that asks for a "draw dib" handle going. The compression
;--- functions (IC...), the video capture and the AVI functions are not provided.
;--- HX has no MSVFW32.DLL: a program that loads it and calls the function pointer it gets
;--- jumped to address 0.

		.386
		.MODEL FLAT, stdcall
		option casemap:none
		option proc:private

		include winbase.inc
		include wingdi.inc

DDF_DONTDRAW	equ 0008h

StretchDIBits proto stdcall :dword, :SDWORD, :SDWORD, :SDWORD, :SDWORD, :SDWORD, :SDWORD, :SDWORD, :SDWORD, :ptr, :ptr, :dword, :dword

		.CODE

;--- HDRAWDIB DrawDibOpen(void)
;--- the handle is only a non-zero value

DrawDibOpen proc public
		mov eax, 1
		ret
DrawDibOpen endp

DrawDibClose proc public hdd:dword
		mov eax, 1
		ret
DrawDibClose endp

DrawDibBegin proc public hdd:dword, hdc:dword, dxDest:SDWORD, dyDest:SDWORD, lpbi:ptr, dxSrc:SDWORD, dySrc:SDWORD, wFlags:dword
		mov eax, 1
		ret
DrawDibBegin endp

DrawDibEnd proc public hdd:dword
		mov eax, 1
		ret
DrawDibEnd endp

;--- BOOL DrawDibDraw(hdd, hdc, xDst, yDst, dxDst, dyDst, lpbi, lpBits, xSrc, ySrc, dxSrc, dySrc, wFlags)
;--- dxDst, dyDst, dxSrc, dySrc may be -1 (the size of the bitmap), lpBits may be NULL (the bits follow
;--- the header and the color table), the origin of the source rectangle is its upper left corner.

DrawDibDraw proc public hdd:dword, hdc:dword, xDst:SDWORD, yDst:SDWORD, dxDst:SDWORD, dyDst:SDWORD,
		lpbi:ptr BITMAPINFOHEADER, lpBits:ptr, xSrc:SDWORD, ySrc:SDWORD, dxSrc:SDWORD, dySrc:SDWORD, wFlags:dword

local	dwHeight:SDWORD
local	pBits:dword
local	yConv:SDWORD

		mov ecx, lpbi
		test ecx, ecx
		jz fail
		cmp hdc, 0
		jz fail
		test wFlags, DDF_DONTDRAW
		jnz done
		mov eax, [ecx].BITMAPINFOHEADER.biHeight
		mov edx, eax
		sar edx, 31
		xor eax, edx
		sub eax, edx			;abs
		mov dwHeight, eax
		cmp dxSrc, -1
		jnz @F
		mov eax, [ecx].BITMAPINFOHEADER.biWidth
		mov dxSrc, eax
@@:
		cmp dySrc, -1
		jnz @F
		mov eax, dwHeight
		mov dySrc, eax
@@:
		cmp dxDst, -1
		jnz @F
		mov eax, dxSrc
		mov dxDst, eax
@@:
		cmp dyDst, -1
		jnz @F
		mov eax, dySrc
		mov dyDst, eax
@@:
		mov eax, lpBits
		test eax, eax
		jnz havebits
		mov eax, ecx
		add eax, [ecx].BITMAPINFOHEADER.biSize
		mov edx, [ecx].BITMAPINFOHEADER.biClrUsed
		test edx, edx
		jnz hascolors
		movzx edx, [ecx].BITMAPINFOHEADER.biBitCount
		cmp edx, 8
		ja nopalette
		push ecx
		mov ecx, edx
		mov edx, 1
		shl edx, cl			;1 shl bit count colors
		pop ecx
		jmp hascolors
nopalette:
		xor edx, edx
		cmp [ecx].BITMAPINFOHEADER.biCompression, BI_BITFIELDS
		jnz hascolors
		mov edx, 3			;three masks
hascolors:
		lea eax, [eax+edx*4]
havebits:
		mov pBits, eax
		mov eax, ySrc			;StretchDIBits counts from the lower left corner of a bottom-up bitmap
		cmp [ecx].BITMAPINFOHEADER.biHeight, 0
		jle @F
		mov eax, dwHeight
		sub eax, ySrc
		sub eax, dySrc
@@:
		mov yConv, eax
		invoke StretchDIBits, hdc, xDst, yDst, dxDst, dyDst, xSrc, yConv, dxSrc, dySrc, pBits, lpbi, DIB_RGB_COLORS, SRCCOPY
done:
		mov eax, 1
		ret
fail:
		xor eax, eax
		ret
DrawDibDraw endp

DrawDibGetPalette proc public hdd:dword
		xor eax, eax
		ret
DrawDibGetPalette endp

DrawDibSetPalette proc public hdd:dword, hpal:dword
		mov eax, 1
		ret
DrawDibSetPalette endp

DrawDibRealize proc public hdd:dword, hdc:dword, fBackground:dword
		xor eax, eax
		ret
DrawDibRealize endp

DrawDibChangePalette proc public hdd:dword, iStart:dword, iLen:dword, lppe:ptr
		mov eax, 1
		ret
DrawDibChangePalette endp

DrawDibStart proc public hdd:dword, lFrameRate:dword
		mov eax, 1
		ret
DrawDibStart endp

DrawDibStop proc public hdd:dword
		mov eax, 1
		ret
DrawDibStop endp

DrawDibTime proc public hdd:dword, lpddtime:ptr
		xor eax, eax
		ret
DrawDibTime endp

DrawDibProfileDisplay proc public lpbi:ptr
		xor eax, eax
		ret
DrawDibProfileDisplay endp

DrawDibGetBuffer proc public hdd:dword, lpbi:ptr, dwSize:dword, dwFlags:dword
		xor eax, eax
		ret
DrawDibGetBuffer endp

		end
