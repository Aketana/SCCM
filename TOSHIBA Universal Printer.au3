#NoTrayIcon
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <MsgBoxConstants.au3>

; ==============================
; CONFIG
; ==============================
Global $DriverName  = "TOSHIBA Universal Printer 2"
Global $PrinterBase = "TOSHIBA Universal Printer 2"

Global $LogDir = "C:\ProgramData\PrinterDeploy"
Global $LogFile = $LogDir & "\deploy_log.txt"

DirCreate($LogDir)
FileWrite($LogFile, "===== START =====" & @CRLF)

; ==============================
; CUSTOM TOPMOST INPUT
; ==============================

Local $hGUI = GUICreate("TOSHIBA Universal Printer 2", 360, 170, -1, -1, -1, $WS_EX_TOPMOST)

GUICtrlCreateLabel("ใส่ IP Address ของ Printer (เช่น 172.xx.xx.xx)", 20, 30, 320, 20)

Local $InputIP = GUICtrlCreateInput("", 20, 60, 320, 25)

Local $BtnInstall = GUICtrlCreateButton("Install", 80, 105, 80, 30)
Local $BtnCancel  = GUICtrlCreateButton("Cancel", 200, 105, 80, 30)

GUICtrlSetState($BtnInstall, $GUI_DEFBUTTON)

GUISetState(@SW_SHOW)
WinActivate("TOSHIBA Universal Printer 2")

Local $PrinterIP = ""

While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE, $BtnCancel
            GUIDelete($hGUI)
            FileWrite($LogFile, "User cancelled." & @CRLF)
            Exit
        Case $BtnInstall

            $PrinterIP = StringStripWS(GUICtrlRead($InputIP), 3)

            If $PrinterIP = "" Then
                MsgBox($MB_TOPMOST + $MB_ICONERROR, "Error", "กรุณากรอก Printer IP")
                ContinueLoop
            EndIf

			If Not StringRegExp($PrinterIP, "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") Then
                MsgBox($MB_TOPMOST + $MB_ICONERROR, "Error", "กรุณากรอก Printer IP ให้ถูกต้อง (เช่น 172.xx.xx.xx)")
                ContinueLoop
            EndIf

            ExitLoop

    EndSwitch

WEnd
GUIDelete($hGUI)

FileWrite($LogFile, "IP Entered: " & $PrinterIP & @CRLF)

; ==============================
; SET VARIABLES
; ==============================

Local $PortName    = "IP_" & $PrinterIP
Local $PrinterName = $PrinterBase & " IP_" & $PrinterIP
Local $DriverInf   = @ScriptDir & "\Driver\eSf6u.inf"

FileWrite($LogFile, "Driver path: " & $DriverInf & @CRLF)

If Not FileExists($DriverInf) Then
    MsgBox($MB_ICONERROR, "Error", "Driver file not found!")
    FileWrite($LogFile, "Driver not found." & @CRLF)
    Exit
EndIf

; ==============================
; INSTALL DRIVER
; ==============================

FileWrite($LogFile, "Installing driver..." & @CRLF)

Local $cmd = @SystemDir & '\pnputil.exe /add-driver "' & $DriverInf & '" /install /subdirs'
Local $rc1 = RunWait($cmd, "", @SW_HIDE)

FileWrite($LogFile, "pnputil RC = " & $rc1 & @CRLF)

; 0 = success, 1 = already exists
If $rc1 <> 0 And $rc1 <> 1 Then
    MsgBox($MB_ICONERROR, "Driver Error", "Driver installation failed. RC=" & $rc1)
    Exit
EndIf

FileWrite($LogFile, "Registering driver with spooler..." & @CRLF)

RunWait('cmd.exe /c rundll32 printui.dll,PrintUIEntry /ia /m "' & _
        $DriverName & '" /f "' & $DriverInf & '"', "", @SW_HIDE)

; ==============================
; RESTART PRINT SPOOLER
; ==============================

RunWait('cmd.exe /c net stop spooler', "", @SW_HIDE)
Sleep(2000)
RunWait('cmd.exe /c net start spooler', "", @SW_HIDE)
Sleep(3000)

; ==============================
; CREATE TCP PORT
; ==============================

FileWrite($LogFile, "Creating TCP port..." & @CRLF)

RunWait( _
    'cmd.exe /c cscript //nologo "%SystemRoot%\System32\Printing_Admin_Scripts\en-US\prnport.vbs"' & _
    ' -a -r ' & $PortName & _
    ' -h ' & $PrinterIP & _
    ' -o raw -n 9100', _
    "", @SW_HIDE)

; ==============================
; REMOVE OLD PRINTER (if exists)
; ==============================

RunWait('cmd.exe /c rundll32 printui.dll,PrintUIEntry /dl /n "' & _
        $PrinterName & '" /q', "", @SW_HIDE)

; ==============================
; ADD PRINTER
; ==============================

FileWrite($LogFile, "Adding printer..." & @CRLF)

Local $rc2 = RunWait('cmd.exe /c rundll32 printui.dll,PrintUIEntry /if /b "' & _
        $PrinterName & '" /r "' & $PortName & _
        '" /m "' & $DriverName & '" /z', "", @SW_HIDE)

FileWrite($LogFile, "Add printer RC = " & $rc2 & @CRLF)

If $rc2 <> 0 Then
    MsgBox($MB_ICONERROR, "Error", "Add printer failed")
    Exit
EndIf

Sleep(2000)

; ==============================
; WRITE DETECTION KEY FOR VERIFICATION
; ==============================

RegWrite("HKLM\SOFTWARE\PrinterDeploy", "ToshibaInstalled", "REG_SZ", "Yes")

; ==============================
; INSTRUCTION
; ==============================

;Run('rundll32 printui.dll,PrintUIEntry /p /n "' & $PrinterName & '"', "", @SW_SHOW)

MsgBox($MB_TOPMOST + $MB_ICONINFORMATION, "เสร็จสิ้น", _
    "ติดตั้งเรียบร้อย" & @CRLF & @CRLF & _
    "กรณีใช้ Department Code:" & @CRLF & _
    "1. ค้นหา 'Printer' ใน Search Bar" & @CRLF & _
    "2. เลือก Printer: " & $PrinterName & @CRLF & _
    "3. เลือก checkbox หาคำที่มีชื่อว่า SNMP Communications → และนำติ๊กถูกออก" & @CRLF & _
    "4. เข้า Printer Preference → Others แล้วกรอก Code")

FileWrite($LogFile, "===== END =====" & @CRLF)

Exit 0
