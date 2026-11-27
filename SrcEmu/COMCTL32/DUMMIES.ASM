
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

InitCommonControls proc public
	mov eax,1
	@strace <"InitCommonControls()=", eax>
	ret
	align 4
InitCommonControls endp

InitCommonControlsEx proc public lpInitCtrls:ptr
	mov eax,1
	@strace <"InitCommonControlsEx(", lpInitCtrls, ")=", eax>
	ret
	align 4
InitCommonControlsEx endp

CreatePropertySheetPage proc public lppsp:ptr
CreatePropertySheetPage endp

CreatePropertySheetPageA proc public lppsp:ptr
	xor eax, eax
	@strace <"CreatePropertySheetPageA(", lppsp, ")=", eax, " *** unsupp ***">
	ret
	align 4
CreatePropertySheetPageA endp

PropertySheet proc public pSheet:ptr
PropertySheet endp

PropertySheetA proc public pSheet:ptr
	mov eax,0
	@strace <"PropertySheetA(", pSheet, ")=", eax, " *** unsupp ***">
	ret
	align 4
PropertySheetA endp

CreateStatusWindowA proc public d1:dword, d2:dword, d3:dword, d4:dword
	xor eax, eax
	@strace <"CreateStatusWindowA(", d1, ", ", d2, ", ", d3, ", ", d4, ")=", eax, " *** unsupp ***">
	ret
	align 4
CreateStatusWindowA endp

GetEffectiveClientRect proc public hwnd:dword, pRect:ptr RECT, d3:dword
	invoke GetClientRect, hwnd, pRect
	@strace <"GetEffectiveClientRect(", hwnd, ", ", pRect, ", ", d3, ")=", eax>
	ret
	align 4
GetEffectiveClientRect endp

LBItemFromPt proc public hLB:dword, pt:POINT, bAutoScroll:dword
	xor eax, eax
	@strace <"LBItemFromPt(", hLB, ", ", pt, ", ", bAutoScroll, ")=", eax, " *** unsupp ***">
	ret
	align 4
LBItemFromPt endp

DrawInsert proc public hParent:dword, hLB:dword, nItem:dword
	xor eax, eax
	@strace <"DrawInsert(", hParent, ", ", hLB, ", ", nItem, ")=", eax, " *** unsupp ***">
	ret
	align 4
DrawInsert endp


;--- image lists are not implemented (MFC based programs import them: they load, the lists are empty)

ImageList_Add proc public p1:dword, p2:dword, p3:dword
	xor eax, eax
	@strace <"ImageList_Add()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_Add endp

ImageList_BeginDrag proc public p1:dword, p2:dword, p3:dword, p4:dword
	xor eax, eax
	@strace <"ImageList_BeginDrag()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_BeginDrag endp

ImageList_Create proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
	xor eax, eax
	@strace <"ImageList_Create()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_Create endp

ImageList_Destroy proc public p1:dword
	xor eax, eax
	@strace <"ImageList_Destroy()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_Destroy endp

ImageList_DragEnter proc public p1:dword, p2:dword, p3:dword
	xor eax, eax
	@strace <"ImageList_DragEnter()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_DragEnter endp

ImageList_DragLeave proc public p1:dword
	xor eax, eax
	@strace <"ImageList_DragLeave()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_DragLeave endp

ImageList_DragMove proc public p1:dword, p2:dword
	xor eax, eax
	@strace <"ImageList_DragMove()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_DragMove endp

ImageList_DragShowNolock proc public p1:dword
	xor eax, eax
	@strace <"ImageList_DragShowNolock()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_DragShowNolock endp

ImageList_Draw proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword
	xor eax, eax
	@strace <"ImageList_Draw()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_Draw endp

ImageList_DrawEx proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword, p7:dword, p8:dword, p9:dword, p10:dword
	xor eax, eax
	@strace <"ImageList_DrawEx()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_DrawEx endp

ImageList_EndDrag proc public 
	xor eax, eax
	@strace <"ImageList_EndDrag()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_EndDrag endp

ImageList_GetBkColor proc public p1:dword
	xor eax, eax
	@strace <"ImageList_GetBkColor()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_GetBkColor endp

ImageList_GetDragImage proc public p1:dword, p2:dword
	xor eax, eax
	@strace <"ImageList_GetDragImage()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_GetDragImage endp

ImageList_GetIconSize proc public p1:dword, p2:dword, p3:dword
	xor eax, eax
	@strace <"ImageList_GetIconSize()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_GetIconSize endp

ImageList_GetImageCount proc public p1:dword
	xor eax, eax
	@strace <"ImageList_GetImageCount()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_GetImageCount endp

ImageList_Read proc public p1:dword
	xor eax, eax
	@strace <"ImageList_Read()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_Read endp

ImageList_Remove proc public p1:dword, p2:dword
	xor eax, eax
	@strace <"ImageList_Remove()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_Remove endp

ImageList_ReplaceIcon proc public p1:dword, p2:dword, p3:dword
	xor eax, eax
	@strace <"ImageList_ReplaceIcon()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_ReplaceIcon endp

ImageList_SetBkColor proc public p1:dword, p2:dword
	xor eax, eax
	@strace <"ImageList_SetBkColor()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_SetBkColor endp

ImageList_SetDragCursorImage proc public p1:dword, p2:dword, p3:dword, p4:dword
	xor eax, eax
	@strace <"ImageList_SetDragCursorImage()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_SetDragCursorImage endp

ImageList_SetIconSize proc public p1:dword, p2:dword, p3:dword
	xor eax, eax
	@strace <"ImageList_SetIconSize()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_SetIconSize endp

ImageList_Write proc public p1:dword, p2:dword
	xor eax, eax
	@strace <"ImageList_Write()=", eax, " *** unsupp ***">
	ret
	align 4
ImageList_Write endp

	end
