
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include macros.inc

	.CODE

MulDiv proc public uses ebx esi dw1:DWORD, dw2:dword, dw3:dword

;--- as Windows: signed, (dw1 * dw2) / dw3 rounded to the nearest (halves away
;--- from zero), -1 if dw3 is 0 or if the result does not fit (no exception)
	mov ecx, dw3
	and ecx, ecx
	jz error
	mov eax, dw1
	imul dw2		;edx:eax = product
	mov esi, edx
	xor esi, ecx		;bit 31: sign of the result
	.if (SDWORD ptr edx < 0)
		neg edx
		neg eax
		sbb edx, 0
	.endif
	.if (SDWORD ptr ecx < 0)
		neg ecx
	.endif
	mov ebx, ecx
	shr ebx, 1
	add eax, ebx		;rounding
	adc edx, 0
	cmp edx, ecx
	jae error		;quotient would not fit in 32 bits
	div ecx
	.if (SDWORD ptr esi < 0)
		cmp eax, 80000000h
		ja error
		neg eax
	.else
		and eax, eax
		js error
	.endif
	jmp done
error:
	or eax, -1
done:
	@strace <"MulDiv(",dw1, ", ", dw2, ", ", dw3, ")=", eax>
	ret
MulDiv endp

	end

