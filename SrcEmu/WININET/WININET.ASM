;--- WININET.DLL for HX: Internet access is not available. The functions exist (programs that load them by name or link them,
;--- e.g. to ask InternetGetConnectedState(), keep running) and report failure / "not connected".

        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include macros.inc

        .CODE

InternetGetConnectedState proc public p1:dword, p2:dword
		mov ecx, p1
		.if (ecx)
			mov dword ptr [ecx], 0
		.endif
		xor eax, eax
		@strace <"InternetGetConnectedState()=", eax, " (no Internet)">
		ret
		align 4
InternetGetConnectedState endp

InternetOpenA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
		xor eax, eax
		@strace <"InternetOpenA()=", eax, " (no Internet)">
		ret
		align 4
InternetOpenA endp

InternetOpenUrlA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword
		xor eax, eax
		@strace <"InternetOpenUrlA()=", eax, " (no Internet)">
		ret
		align 4
InternetOpenUrlA endp

InternetCloseHandle proc public p1:dword
		@mov eax, 1
		@strace <"InternetCloseHandle()=", eax, " (no Internet)">
		ret
		align 4
InternetCloseHandle endp

InternetReadFile proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"InternetReadFile()=", eax, " (no Internet)">
		ret
		align 4
InternetReadFile endp

InternetWriteFile proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"InternetWriteFile()=", eax, " (no Internet)">
		ret
		align 4
InternetWriteFile endp

InternetQueryDataAvailable proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"InternetQueryDataAvailable()=", eax, " (no Internet)">
		ret
		align 4
InternetQueryDataAvailable endp

InternetConnectA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword, p7:dword, p8:dword
		xor eax, eax
		@strace <"InternetConnectA()=", eax, " (no Internet)">
		ret
		align 4
InternetConnectA endp

HttpOpenRequestA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword, p7:dword, p8:dword
		xor eax, eax
		@strace <"HttpOpenRequestA()=", eax, " (no Internet)">
		ret
		align 4
HttpOpenRequestA endp

HttpSendRequestA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
		xor eax, eax
		@strace <"HttpSendRequestA()=", eax, " (no Internet)">
		ret
		align 4
HttpSendRequestA endp

HttpQueryInfoA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
		xor eax, eax
		@strace <"HttpQueryInfoA()=", eax, " (no Internet)">
		ret
		align 4
HttpQueryInfoA endp

InternetSetOptionA proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"InternetSetOptionA()=", eax, " (no Internet)">
		ret
		align 4
InternetSetOptionA endp

InternetQueryOptionA proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"InternetQueryOptionA()=", eax, " (no Internet)">
		ret
		align 4
InternetQueryOptionA endp

InternetCrackUrlA proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"InternetCrackUrlA()=", eax, " (no Internet)">
		ret
		align 4
InternetCrackUrlA endp

InternetCanonicalizeUrlA proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"InternetCanonicalizeUrlA()=", eax, " (no Internet)">
		ret
		align 4
InternetCanonicalizeUrlA endp

InternetCheckConnectionA proc public p1:dword, p2:dword, p3:dword
		xor eax, eax
		@strace <"InternetCheckConnectionA()=", eax, " (no Internet)">
		ret
		align 4
InternetCheckConnectionA endp

InternetAttemptConnect proc public p1:dword
		xor eax, eax
		@strace <"InternetAttemptConnect()=", eax, " (no Internet)">
		ret
		align 4
InternetAttemptConnect endp

InternetAutodial proc public p1:dword, p2:dword
		xor eax, eax
		@strace <"InternetAutodial()=", eax, " (no Internet)">
		ret
		align 4
InternetAutodial endp

InternetAutodialHangup proc public p1:dword
		xor eax, eax
		@strace <"InternetAutodialHangup()=", eax, " (no Internet)">
		ret
		align 4
InternetAutodialHangup endp

InternetGoOnlineA proc public p1:dword, p2:dword, p3:dword
		xor eax, eax
		@strace <"InternetGoOnlineA()=", eax, " (no Internet)">
		ret
		align 4
InternetGoOnlineA endp

InternetSetStatusCallback proc public p1:dword, p2:dword
		xor eax, eax
		@strace <"InternetSetStatusCallback()=", eax, " (no Internet)">
		ret
		align 4
InternetSetStatusCallback endp

InternetGetLastResponseInfoA proc public p1:dword, p2:dword, p3:dword
		xor eax, eax
		@strace <"InternetGetLastResponseInfoA()=", eax, " (no Internet)">
		ret
		align 4
InternetGetLastResponseInfoA endp

InternetErrorDlg proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
		xor eax, eax
		@strace <"InternetErrorDlg()=", eax, " (no Internet)">
		ret
		align 4
InternetErrorDlg endp

InternetFindNextFileA proc public p1:dword, p2:dword
		xor eax, eax
		@strace <"InternetFindNextFileA()=", eax, " (no Internet)">
		ret
		align 4
InternetFindNextFileA endp

InternetGetCookieA proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"InternetGetCookieA()=", eax, " (no Internet)">
		ret
		align 4
InternetGetCookieA endp

InternetSetCookieA proc public p1:dword, p2:dword, p3:dword
		xor eax, eax
		@strace <"InternetSetCookieA()=", eax, " (no Internet)">
		ret
		align 4
InternetSetCookieA endp

FtpOpenFileA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
		xor eax, eax
		@strace <"FtpOpenFileA()=", eax, " (no Internet)">
		ret
		align 4
FtpOpenFileA endp

FtpGetFileA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword, p7:dword
		xor eax, eax
		@strace <"FtpGetFileA()=", eax, " (no Internet)">
		ret
		align 4
FtpGetFileA endp

FtpPutFileA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
		xor eax, eax
		@strace <"FtpPutFileA()=", eax, " (no Internet)">
		ret
		align 4
FtpPutFileA endp

FtpFindFirstFileA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
		xor eax, eax
		@strace <"FtpFindFirstFileA()=", eax, " (no Internet)">
		ret
		align 4
FtpFindFirstFileA endp

FtpDeleteFileA proc public p1:dword, p2:dword
		xor eax, eax
		@strace <"FtpDeleteFileA()=", eax, " (no Internet)">
		ret
		align 4
FtpDeleteFileA endp

FtpSetCurrentDirectoryA proc public p1:dword, p2:dword
		xor eax, eax
		@strace <"FtpSetCurrentDirectoryA()=", eax, " (no Internet)">
		ret
		align 4
FtpSetCurrentDirectoryA endp

FtpGetCurrentDirectoryA proc public p1:dword, p2:dword, p3:dword
		xor eax, eax
		@strace <"FtpGetCurrentDirectoryA()=", eax, " (no Internet)">
		ret
		align 4
FtpGetCurrentDirectoryA endp

FtpCreateDirectoryA proc public p1:dword, p2:dword
		xor eax, eax
		@strace <"FtpCreateDirectoryA()=", eax, " (no Internet)">
		ret
		align 4
FtpCreateDirectoryA endp

FtpRemoveDirectoryA proc public p1:dword, p2:dword
		xor eax, eax
		@strace <"FtpRemoveDirectoryA()=", eax, " (no Internet)">
		ret
		align 4
FtpRemoveDirectoryA endp

FtpRenameFileA proc public p1:dword, p2:dword, p3:dword
		xor eax, eax
		@strace <"FtpRenameFileA()=", eax, " (no Internet)">
		ret
		align 4
FtpRenameFileA endp

FtpCommandA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword
		xor eax, eax
		@strace <"FtpCommandA()=", eax, " (no Internet)">
		ret
		align 4
FtpCommandA endp

InternetSetFilePointer proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"InternetSetFilePointer()=", eax, " (no Internet)">
		ret
		align 4
InternetSetFilePointer endp

InternetLockRequestFile proc public p1:dword, p2:dword
		xor eax, eax
		@strace <"InternetLockRequestFile()=", eax, " (no Internet)">
		ret
		align 4
InternetLockRequestFile endp

InternetUnlockRequestFile proc public p1:dword
		xor eax, eax
		@strace <"InternetUnlockRequestFile()=", eax, " (no Internet)">
		ret
		align 4
InternetUnlockRequestFile endp

InternetTimeFromSystemTime proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"InternetTimeFromSystemTime()=", eax, " (no Internet)">
		ret
		align 4
InternetTimeFromSystemTime endp

InternetTimeToSystemTime proc public p1:dword, p2:dword, p3:dword
		xor eax, eax
		@strace <"InternetTimeToSystemTime()=", eax, " (no Internet)">
		ret
		align 4
InternetTimeToSystemTime endp

InternetConfirmZoneCrossing proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"InternetConfirmZoneCrossing()=", eax, " (no Internet)">
		ret
		align 4
InternetConfirmZoneCrossing endp

HttpAddRequestHeadersA proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"HttpAddRequestHeadersA()=", eax, " (no Internet)">
		ret
		align 4
HttpAddRequestHeadersA endp

HttpSendRequestExA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
		xor eax, eax
		@strace <"HttpSendRequestExA()=", eax, " (no Internet)">
		ret
		align 4
HttpSendRequestExA endp

HttpEndRequestA proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"HttpEndRequestA()=", eax, " (no Internet)">
		ret
		align 4
HttpEndRequestA endp

InternetCreateUrlA proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"InternetCreateUrlA()=", eax, " (no Internet)">
		ret
		align 4
InternetCreateUrlA endp

InternetGetCookieExA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword
		xor eax, eax
		@strace <"InternetGetCookieExA()=", eax, " (no Internet)">
		ret
		align 4
InternetGetCookieExA endp

InternetSetOptionExA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
		xor eax, eax
		@strace <"InternetSetOptionExA()=", eax, " (no Internet)">
		ret
		align 4
InternetSetOptionExA endp

DeleteUrlCacheEntry proc public p1:dword
		xor eax, eax
		@strace <"DeleteUrlCacheEntry()=", eax, " (no Internet)">
		ret
		align 4
DeleteUrlCacheEntry endp

FindFirstUrlCacheEntryA proc public p1:dword, p2:dword, p3:dword
		xor eax, eax
		@strace <"FindFirstUrlCacheEntryA()=", eax, " (no Internet)">
		ret
		align 4
FindFirstUrlCacheEntryA endp

FindNextUrlCacheEntryA proc public p1:dword, p2:dword, p3:dword
		xor eax, eax
		@strace <"FindNextUrlCacheEntryA()=", eax, " (no Internet)">
		ret
		align 4
FindNextUrlCacheEntryA endp

FindCloseUrlCache proc public p1:dword
		xor eax, eax
		@strace <"FindCloseUrlCache()=", eax, " (no Internet)">
		ret
		align 4
FindCloseUrlCache endp

GetUrlCacheEntryInfoA proc public p1:dword, p2:dword, p3:dword
		xor eax, eax
		@strace <"GetUrlCacheEntryInfoA()=", eax, " (no Internet)">
		ret
		align 4
GetUrlCacheEntryInfoA endp

CreateUrlCacheEntryA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword
		xor eax, eax
		@strace <"CreateUrlCacheEntryA()=", eax, " (no Internet)">
		ret
		align 4
CreateUrlCacheEntryA endp

CommitUrlCacheEntryA proc public p1:dword, p2:dword, p3:dword, p4:dword, p5:dword, p6:dword, p7:dword, p8:dword
		xor eax, eax
		@strace <"CommitUrlCacheEntryA()=", eax, " (no Internet)">
		ret
		align 4
CommitUrlCacheEntryA endp

RetrieveUrlCacheEntryFileA proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"RetrieveUrlCacheEntryFileA()=", eax, " (no Internet)">
		ret
		align 4
RetrieveUrlCacheEntryFileA endp

UnlockUrlCacheEntryFile proc public p1:dword, p2:dword
		xor eax, eax
		@strace <"UnlockUrlCacheEntryFile()=", eax, " (no Internet)">
		ret
		align 4
UnlockUrlCacheEntryFile endp

InternetHangUp proc public p1:dword, p2:dword
		xor eax, eax
		@strace <"InternetHangUp()=", eax, " (no Internet)">
		ret
		align 4
InternetHangUp endp

InternetDial proc public p1:dword, p2:dword, p3:dword, p4:dword
		xor eax, eax
		@strace <"InternetDial()=", eax, " (no Internet)">
		ret
		align 4
InternetDial endp

		end
