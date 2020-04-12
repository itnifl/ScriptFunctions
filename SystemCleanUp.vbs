''Version 1.0

'Utfør følgende:
'	
'	[OK] 1. Sette opp loggrotering i scriptet. Loggene lagres på samme sted som scriptet kjøres.
'	[OK] 2. Logg hvor mye plass er ledig på systemdisken både før og etter	
'		 3. Ha med WhatIf kjørsel
'	[OK] 4. Sjekker at cleanmgr.exe og tilhørende følgefil ligger der den skal eller plasserer den rett ut fra stier funnet i http://technet.microsoft.com/en-us/library/ff630161(v=ws.10).aspx
' 	[OK] 5. Kopier over og kjør registryfil som inneholder registrysetting som hva som skal ryddes med cleanmgr.exe.
'	[OK] 6. Kjør cleanmgr.exe /d %SystemDrive% /sagerun:101 - hvor 101 er settinger definert i registryfil.
'		Disse er lagret under HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches
'		-> Rydder: Temporary Setup Files, Downloaded Program Files, Temporary Internet files, Offline Webpages, Debug Dump Files, 
'	   	Old Chkdsk files, Recycle Bin(current user), Service Pack Backup Files, Setup Logs, System Error Memory Dump Files, System Error Minidump Files,
'	   	Temporary Files, Temporary Windows Installation Files, Thumbnails, Files discarded by Windows Upgrade, 
'	   	Peruser Archived/queued Windows Error Reporting Files, System archived/queued Windows Error Reporting Files, Windows upgrade log files
'	[OK] 7. Slette alle/siste shadow copies : vssadmin delete shadows /for=%SystemDrive% /all /quiet
'	[OK] 8. Kjøre CCleaner via kommandolinjen. Dette skjer bare om denne er installert. Installere med scriptet?
'	[OK] 9. Minke alle restore points til maks 0GB : vssadmin Resize ShadowStorage /For=%SystemDrive% /On=%SystemDrive% /MaxSize=0GB
'	[OK] 10. Sjekke om det fortsatt ligger Memory dumps og slett dem : %SystemRoot%\MEMORY.DMP & %SystemRoot%\Minidump\*.* + TSM
'			 + Slå av hibernation hvis dette er på.
'	[OK] 11. IIS logfiler - %SystemDrive%\inetpub\logs\LogFiles - komprimer med compact /c /s mappe /i /q /f - samme gjelder %SystemRoot%\SYSTEM32\LogFiles\

'	[OK] 12. %SystemRoot%\installer\$PatchCache$ - slettes 
'	[OK] 13. %SystemRoot%\$blabla$ - hvis eldre enn 30 dager - slettes
'	[OK] 14. %SystemDrive%\$Recycle.Bin - slettes - rd /s c:\$Recycle.Bin 
'	[OK] 15. %SystemDrive%\PerfLogs - komprimer med compact /c /s mappe /i /q /f
'	[OK] 16. %SystemDrive%\MSOCache - komprimer med compact /c /s mappe /i /q /f
'	[OK] 17. %SystemRoot%\installer - ryddes med MsiZap.exe? - ikke lenger supportert av Microsoft :/ - Avslått!
'		Her utfører vi rydding av winsxs mappe i stedet med Microsoft verktøy.
'	[OK] 18. Slette innhold i temp katalogen for alt som er eldre enn 7 dager

'	[OK] 19. Slette alt som er mulig å slette under c:\windows\temp\
'	[OK] 20. Rydd rota for småfiler - bare systemfiler skal være her(.rnd, bootmgr, BOOTSECT.BAK, END. HIBERFIL.SYS, PAGEFILE.SYS, 
'			autoexec.bat, config.sys, io.sys, Bootlog.prv, Bootlog.txt, Command.com, Command.dos, Config.dos, Cvt.log, Detlog.old, Detlog.txt,
'			Io.dos, Logo.sys, Msdos.dos, Msdos.sys, Suhdlog.dat, System.1st, Videorom.bin, W95undo.dat, W95undo.ini)
'	[OK] 21. Brukerprofilrydding
'   [OK] 22. Rydde i Fontcache filer
'	[OK] 23. Skriv inn i registry hvor scriptet ligger og hvilken versjon det er

''Kode begynner her:
Option Explicit
On Error Resume Next

Dim oShell, oFSO, oProcEnv, oDate, sSystemDrive, sSystemRoot, sProcess_architecture, objRE, oReg, sRegContent, sLogLocation, sLogFileName, oLogLocation, oFile, oFiles, oLocation
Dim file, folder, disk, count, strDate, strDay, strMonth, strYear, sSystem_architecture, oFolderRoot, progressCount, progressMax, strDiskBefore
Dim versionInfo
versionInfo = "1.0"

oDate = date()
strDate = CDate(oDate)
strDay = DatePart("d", strDate)
strMonth = DatePart("m", strDate)
strYear = DatePart("yyyy", strDate)

'We have 23 main steps in this script, we set progressMax to 32:
progressMax = 23
progressCount = 0

set oShell = wScript.createObject("wScript.shell")
set oFSO = CreateObject("Scripting.FileSystemObject")
Set oProcEnv = oShell.Environment("Process")
sSystemDrive = oShell.ExpandEnvironmentStrings("%SYSTEMDRIVE%")
sSystemRoot = oShell.ExpandEnvironmentStrings("%SYSTEMROOT%")
'sLogLocation = sSystemDrive & "\ryddeScriptLogs"
sLogLocation = oFSO.GetParentFolderName(Wscript.ScriptFullName)
sLogFileName = "ryddeLog-" & strDay & "." & strMonth & "." & strYear & ".log"
'sProcess_architecture = oProcEnv("PROCESSOR_ARCHITECTURE")
'sProcess_architecture = ReadReg("HKLM\SYSTEM\ControlSet001\Control\Session Manager\Environment\PROCESSOR_ARCHITECTURE")
sProcess_architecture = oProcEnv("PROCESSOR_ARCHITECTURE") 
If sProcess_architecture = "x86" Then    
    sSystem_architecture = oProcEnv("PROCESSOR_ARCHITEW6432")

    If Not sSystem_architecture = ""  Then    
        sProcess_architecture = sSystem_architecture
    End if    
End If

If UserPerms("Admin") Then
	'Goood to go
Else
	Call forceAsAdmin
End If
Call forceUseCScript

'	1. Sette opp loggrotering i scriptet.
If Not oFSO.FolderExists(sLogLocation) Then
	oFSO.CreateFolder sLogLocation
End If

Set oFile = oFSO.CreateTextFile(sLogLocation & "\" & sLogFileName, True)
Set oLogLocation = oFSO.GetFolder(sLogLocation)
For each file In oLogLocation.Files	 
	If (DateDiff("d",file.DateCreated,oDate) >= 14) AND (StrComp(oFSO.GetExtensionName(file.Name),"log",1) = 0) Then 
		file.Delete True
	End If
Next

'	2. Logg hvor mye plass er ledig på systemdisken både før og etter
Set disk = Nothing
Set disk = oFSO.GetDrive(sSystemDrive)
oFile.WriteLine "Free diskspace before running the script " & FormatNumber(((disk.FreeSpace / 1024) / 1024),2) & " MB"
strDiskBefore = "Free diskspace before running the script " & FormatNumber(((disk.FreeSpace / 1024) / 1024),2) & " MB"
wScript.Echo strDiskBefore
Err.Clear

'	Show Progress as dots:
DisplayProgress(3)

'	4. Sjekker at cleanmgr.exe og tilhørende følgefil ligger der den skal eller plasserer den rett ut fra stier funnet i http://technet.microsoft.com/en-us/library/ff630161(v=ws.10).aspx
If NOT oFSO.fileExists(sSystemRoot & "\SYSTEM32\cleanmgr.exe") OR NOT oFSo.fileExists(sSystemRoot + "\System32\en-US\Cleanmgr.exe.mui") Then
	oFile.WriteLine "Attempting to place cleanmgr files correctly." 
	Set objRE = New RegExp
	With objRE
		.Pattern    = "64"
		.IgnoreCase = True
		.Global     = False
	End With
	If objRE.Test(sProcess_architecture) Then		
		Dim strComputer, objWMIService, oss, os, osVersion
		strComputer = "."
		Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
		Set oss = objWMIService.ExecQuery ("Select * from Win32_OperatingSystem")

		For Each os in oss
			oFile.WriteLine "- Evaluating a 64 bit architecture with OS version:" & vbCrlf & "       " & os.Version & " equaling " & os.Caption
			osVersion = Left(os.Version, 3)
			If Not StrComp(osVersion,"6.1") Then
				If oFSO.fileExists(sSystemRoot & "\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.1.7600.16385_none_c9392808773cd7da\cleanmgr.exe") Then
					oFile.WriteLine "      * Copying " & sSystemRoot & "\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.1.7600.16385_none_c9392808773cd7da\cleanmgr.exe"
					oFile.WriteLine "         ->to " & sSystemRoot & "\SYSTEM32\"
					oFSO.CopyFile sSystemRoot & "\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.1.7600.16385_none_c9392808773cd7da\cleanmgr.exe", sSystemRoot & "\SYSTEM32\", True
				End If
				If oFSO.fileExists(sSystemRoot & "\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.1.7600.16385_en-us_b9cb6194b257cc63\cleanmgr.exe.mui") Then
					oFile.WriteLine "      * Copying " & sSystemRoot & "\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.1.7600.16385_en-us_b9cb6194b257cc63\cleanmgr.exe.mui"
					oFile.WriteLine "         ->to " & sSystemRoot & "\SYSTEM32\en-US\"
					oFSO.CopyFile sSystemRoot & "\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.1.7600.16385_en-us_b9cb6194b257cc63\cleanmgr.exe.mui", sSystemRoot & "\SYSTEM32\en-US\", True
				End If
			End If
			If Not StrComp(osVersion,"6.0") Then
				If oFSO.fileExists(sSystemRoot & "\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.0.6001.18000_en-us_b9f50b71510436f2\cleanmgr.exe.mui") Then
					oFile.WriteLine "      * Copying " & sSystemRoot & "\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.0.6001.18000_en-us_b9f50b71510436f2\cleanmgr.exe.mui"
					oFile.WriteLine "         ->to " & sSystemRoot & "\SYSTEM32\en-US\"
					oFSO.CopyFile sSystemRoot & "\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.0.6001.18000_en-us_b9f50b71510436f2\cleanmgr.exe.mui", sSystemRoot & "\SYSTEM32\en-US\", True
				End If
				If oFSO.fileExists(sSystemRoot & "\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.0.6001.18000_none_c962d1e515e94269\cleanmgr.exe.mui") Then
					oFile.WriteLine "      * Copying " & sSystemRoot & "\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.0.6001.18000_none_c962d1e515e94269\cleanmgr.exe.mui"
					oFile.WriteLine "         ->to " & sSystemRoot & "\SYSTEM32\en-US\"
					oFSO.CopyFile sSystemRoot & "\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.0.6001.18000_none_c962d1e515e94269\cleanmgr.exe.mui", sSystemRoot & "\SYSTEM32\en-US\", True
				End If
			End If
		Next
	Else
		oFile.WriteLine "- Evaluating a non 64 bit architecture."
		If oFSO.fileExists(sSystemRoot & "\winsxs\x86_microsoft-windows-cleanmgr_31bf3856ad364e35_6.0.6001.18000_none_6d4436615d8bd133\cleanmgr.exe") Then
			oFile.WriteLine "      * " & sSystemRoot & "\winsxs\x86_microsoft-windows-cleanmgr_31bf3856ad364e35_6.0.6001.18000_none_6d4436615d8bd133\cleanmgr.exe"
			oFile.WriteLine "         ->to " & sSystemRoot & "\SYSTEM32"
			oFSO.CopyFile sSystemRoot & "\winsxs\x86_microsoft-windows-cleanmgr_31bf3856ad364e35_6.0.6001.18000_none_6d4436615d8bd133\cleanmgr.exe", sSystemRoot & "\SYSTEM32", True
		End If
		If oFSO.fileExists(sSystemRoot & "\winsxs\x86_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.0.6001.18000_en-us_5dd66fed98a6c5bc\cleanmgr.exe.mui") Then
			oFile.WriteLine "      * Copying " & sSystemRoot & "\winsxs\x86_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.0.6001.18000_en-us_5dd66fed98a6c5bc\cleanmgr.exe.mui"
			oFile.WriteLine "         ->to " & sSystemRoot & "\SYSTEM32\en-US"
			oFSO.CopyFile sSystemRoot & "\winsxs\x86_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.0.6001.18000_en-us_5dd66fed98a6c5bc\cleanmgr.exe.mui", sSystemRoot & "\SYSTEM32\en-US", True
		End If
	End If
End If 
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear

' 	5. Sett registrysettinger med hva som skal ryddes med cleanmgr.exe.
'   Dvs. her settes registry innslagene opp direkte.
oFile.WriteLine "Adding registry settings for cleanmgr.exe.."
const HKEY_LOCAL_MACHINE = &H80000002
strComputer = "."

Set oReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strComputer & "\root\default:StdRegProv")
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Active Setup Temp Folders","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Active Setup Temp Folders","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Downloaded Program Files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Internet Cache Files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Memory Dump Files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Offline Pages Files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Old ChkDsk Files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Recycle Bin","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Service Pack Cleanup","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Setup Log Files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\System error memory dump files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\System error minidump files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Setup Files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Thumbnail Cache","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Upgrade Discarded Files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting Archive Files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting Queue Files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting System Archive Files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting System Queue Files","StateFlags0101",00000002
oReg.SetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Upgrade Log Files","StateFlags0101",00000002
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear

'	6. Kjør cleanmgr.exe /d %SystemDrive% /sagerun:101 
'		-> Rydder: Temporary Setup Files, Downloaded Program Files, Temporary Internet files, Offline Webpages, Debug Dump Files, 
'	   	Old Chkdsk files, Recycle Bin(current user), Service Pack Backup Files, Setup Logs, System Error Memory Dump Files, System Error Minidump Files,
'	   	Temporary Files, Temporary Windows Installation Files, Thumbnails, Filesdiscarded by Windows Upgrade, 
'	   	Peruser Archived/queued Windows Error Reporting Files, System archived/queued Windows Error Reporting Files, Windows upgrade log files
If oFSO.fileExists(sSystemRoot & "\SYSTEM32\cleanmgr.exe")  Then
	oFile.WriteLine "Starting cleanmgr.exe.."
	oShell.run "cleanmgr.exe /d %SystemDrive% /sagerun:101", 1, true
	If Err.Number <> 0 Then
		oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 6."
		Err.Clear
	End If
Else
	oFile.WriteLine "Did not find " & sSystemRoot & "\SYSTEM32\cleanmgr.exe"
	oFile.WriteLine "      Skipping..."
End If
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear

'	7. Slette alle/siste shadow copies: vssadmin delete shadows /for=%SystemDrive% /all /quiet
If oFSO.fileExists(sSystemRoot & "\SYSTEM32\vssadmin.exe")  Then
	oFile.WriteLine "Starting vssadmin.exe and cleaning out all shadow copies.."
	oShell.run "vssadmin delete shadows /for=" & sSystemDrive & " /all /quiet", 1, true
	If Err.Number <> 0 Then
		oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 7."
		Err.Clear
	End If
Else
	oFile.WriteLine "Did not find " & sSystemRoot & "\SYSTEM32\vssadmin.exe"
	oFile.WriteLine "      Skipping..."
End If
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear

'	8. Silent install av CCleaner og kjøre denne via kommandolinjen? - Silent install via Nimbus
If oFSO.fileExists(sSystemDrive & "\Program Files\CCleaner\CCleaner.exe")  Then
	oFile.WriteLine "Starting CCleaner.exe and cleaning out what we can.."
	oShell.run """" & sSystemDrive & "\Program Files\CCleaner\CCleaner.exe"" /AUTO", 1, true
	If Err.Number <> 0 Then
		oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 8."
		Err.Clear
	End If
Else
	oFile.WriteLine "Did not find " & sSystemDrive & "\Program Files\CCleaner\CCleaner.exe"
	oFile.WriteLine "      Skipping..."
End If
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear

'	9. Minke alle restore points til maks 0GB: vssadmin Resize ShadowStorage /For=%SystemDrive% /On=%SystemDrive% /MaxSize=0GB
If oFSO.fileExists(sSystemRoot & "\SYSTEM32\vssadmin.exe")  Then
	oFile.WriteLine "Starting vssadmin.exe and resizing shadow storage to max 0 GB.."
	oShell.run "vssadmin Resize ShadowStorage /For=" & sSystemDrive & " /On=" & sSystemDrive & "/MaxSize=0GB", 1, true
	If Err.Number <> 0 Then
		oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 9."
		Err.Clear
	End If
Else
	oFile.WriteLine "Did not find " & sSystemRoot & "\SYSTEM32\vssadmin.exe"
	oFile.WriteLine "      Skipping..."
End If
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear

'	10. Sjekke om det fortsatt ligger Memory dumps og slett dem: %SystemRoot%\MEMORY.DMP & %SystemRoot%\Minidump\*.*, samt hos TSM
If oFSO.fileExists(sSystemRoot & "\MEMORY.DMP")  Then
	oFile.WriteLine "Deleting MEMORY.DMP.."
	oFSO.DeleteFile(sSystemRoot & "\MEMORY.DMP")
	If Err.Number <> 0 Then
		oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 10."
		Err.Clear
	End If
Else
	oFile.WriteLine "Did not find " & sSystemRoot & "\MEMORY.DMP"
	oFile.WriteLine "      Skipping..."
End If
Err.Clear
If oFSO.FolderExists(sSystemRoot & "\Minidump")  Then
	oFile.WriteLine "Deleting " & sSystemRoot & "\Minidump\*.*"
	oFSO.DeleteFile(sSystemRoot & "\Minidump\*.*")
	If Err.Number <> 0 Then
		oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 10."
		Err.Clear
	End If
Else
	oFile.WriteLine "Did not find " & sSystemRoot & "\Minidump"
	oFile.WriteLine "      Skipping..."
End If
Err.Clear
If oFSO.fileExists(sSystemDrive & "\hiberfil.sys")  Then
	oFile.WriteLine "Turning off Hibernation.."
	oShell.run "powercfg.exe /hibernate off", 1, true
	If Err.Number <> 0 Then
		oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 10."
		Err.Clear
	End If
	If oFSO.fileExists(sSystemDrive & "\hiberfil.sys")  Then
		oFile.WriteLine "Deleting " & sSystemDrive & "\hiberfil.sys"
		oFSO.DeleteFile sSystemDrive & "\hiberfil.sys", True
		If Err.Number <> 0 Then
			oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 10."
			Err.Clear
		End If
	Else
		oFile.WriteLine sSystemDrive & "\hiberfil.sys is already removed.."
		oFile.WriteLine "      Skipping..."
	End If
Else
	oFile.WriteLine "Did not find " & sSystemDrive & "\hiberfil.sys"
	oFile.WriteLine "      Skipping..."
End If
Err.Clear
If regValueExists("HKLM\SOFTWARE\IBM\ADSM\CurrentVersion\TSMClientPath") Then
	Dim oDeepFolderRoot
	Set sRegContent = Nothing
	sRegContent = ReadReg("HKLM\SOFTWARE\IBM\ADSM\CurrentVersion\TSMClientPath")
	If oFSO.FolderExists(sRegContent) Then
		Set oFolderRoot = oFSO.GetFolder(sRegContent)
		For each folder In oFolderRoot.SubFolders
			If StrComp("config",folder.Name,1) <> 0 AND StrComp("doc",folder.Name,1) <> 0 Then
				Set oDeepFolderRoot = oFSO.GetFolder(folder.Path)
				If Err.Number <> 0 Then
					oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 10 - mapping oDeepFolderRoot"
					Err.Clear
				End If
				For each file In oDeepFolderRoot.Files
					If StrComp(file.Name,"sqlfull.log",1) = 0 Then
						oFile.WriteLine "Deleting " & file.Path
						oFSO.DeleteFile file.Path, True
						If Err.Number <> 0 Then
							oFile.WriteLine "    An error was encountered deleting sqlfull.log (" & Err.Number & " - " & Err.Description & ") at point 10 - path " & file.Path
							Err.Clear
						End If
					End If
					If StrComp(file.Name,"sqlfull.log.old",1) = 0 Then
						oFile.WriteLine "Deleting " & file.Path
						oFSO.DeleteFile file.Path, True
						If Err.Number <> 0 Then
							oFile.WriteLine "    An error was encountered deleting sqlfull.log.old (" & Err.Number & " - " & Err.Description & ") at point 10 - path " & file.Path
							Err.Clear
						End If
					End If
					If StrComp(file.Name,"sqlfull.log.old2",1) = 0 Then
						oFile.WriteLine "Deleting " & file.Path
						oFSO.DeleteFile file.Path, True
						If Err.Number <> 0 Then
							oFile.WriteLine "    An error was encountered deleting sqlfull.log.old2 (" & Err.Number & " - " & Err.Description & ") at point 10 - path " & file.Path
							Err.Clear
						End If
					End If
					If StrComp(file.Name,"excfull.log",1) = 0 Then
						oFile.WriteLine "Deleting " & file.Path
						oFSO.DeleteFile file.Path, True
						If Err.Number <> 0 Then
							oFile.WriteLine "    An error was encountered deleting excfull.log (" & Err.Number & " - " & Err.Description & ") at point 10 - path " & file.Path
							Err.Clear
						End If
					End If
					If StrComp(file.Name,"excfull.log.old",1) = 0 Then
						oFile.WriteLine "Deleting " & file.Path
						oFSO.DeleteFile file.Path, True
						If Err.Number <> 0 Then
							oFile.WriteLine "    An error was encountered deleting excfull.log.old (" & Err.Number & " - " & Err.Description & ") at point 10 - path " & file.Path
							Err.Clear
						End If
					End If
					If StrComp(file.Name,"excfull.log.old2",1) = 0 Then
						oFile.WriteLine "Deleting " & file.Path
						oFSO.DeleteFile file.Path, True
						If Err.Number <> 0 Then
							oFile.WriteLine "    An error was encountered deleting excfull.log.old2 (" & Err.Number & " - " & Err.Description & ") at point 10 - path " & file.Path
							Err.Clear
						End If
					End If
					If StrComp(oFSO.GetExtensionName(file.Name),"dmp",1) = 0 Then
						oFile.WriteLine "Deleting TSM Dump " & file.Path
						oFSO.DeleteFile file.Path, True
						If Err.Number <> 0 Then
							oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 10 - when deleting " & file.Path
							Err.Clear
						End If
					End If
					If (DateDiff("d",file.DateCreated,oDate) >= 31) AND FormatNumber(((file.Size / 1024) / 1024),0) > 100 Then
						oFile.WriteLine "Deleting " & file.Path & " with size " & FormatNumber(((file.Size / 1024) / 1024),2) & " MB - it is more then 31 days since it was last modified and it is more then 100 MB large"
						subFile.Delete True
						If Err.Number <> 0 Then
							oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 11 when deleting subfiles in subfolders in log folder.."
							Err.Clear
						End If
					End If
				Next
			End If
		Next
	Else 
		oFile.WriteLine "Found registry keys for TSM, but the detected installation folder """ & sRegContent & """ was not found."
		oFile.WriteLine "      Skipping..."
	End If 
Else
	oFile.WriteLine "Did not detect TSM on this server"
	oFile.WriteLine "      Skipping..."
End If
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear


'	11. IIS logfiler - %SystemDrive%\inetpub\logs\LogFiles - komprimer med compact /s mappe /i /q - samme gjelder %SystemRoot%\SYSTEM32\LogFiles\
If oFSO.FolderExists(sSystemDrive & "\inetpub\logs\LogFiles\")  Then
	Set objRE = Nothing
	Set objRE = New RegExp
	With objRE
		'Tester om filnavn ender på zip eller iso:
		.Pattern    = "^.*\.(log)$"
		.IgnoreCase = True
		.Global     = True
	End With	
	set folder = Nothing
	set folder = oFSO.GetFolder(sSystemDrive & "\inetpub\logs\LogFiles\")
	For each file in folder.Files
		If Err.Number <> 0 Then
			oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 11 when looping files in log folder."
			Err.Clear
		End If
		If objRE.Test(file.Name) Then
			If DateDiff("d",file.DateCreated,oDate) >= 14 Then
				oFile.WriteLine "Deleting " & file.Path & " with size " & FormatNumber(((file.Size / 1024) / 1024),2) & " MB - it is more then 14 days since it was last modified"
				file.Delete True
				If Err.Number <> 0 Then
					oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 11 when deleting files in log folder."
					Err.Clear
				End If
			End If
		End If
	Next
	Dim subFolder
	For each subFolder in folder.SubFolders
		If Err.Number <> 0 Then
			oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 11 when looping folders in log folder."
			Err.Clear
		End If
		Dim subFile
		For each subFile in subFolder.files
			If Err.Number <> 0 Then
				oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 11 when looping subfiles in subfolders in log folder."
				Err.Clear
			End If
			If objRE.Test(subFile.Name) Then
				If DateDiff("d",subFile.DateCreated,oDate) >= 14 Then
					oFile.WriteLine "Deleting " & subFile.Path & " with size " & FormatNumber(((subFile.Size / 1024) / 1024),2) & " MB - it is more then 14 days since it was last modified"
					subFile.Delete True
					If Err.Number <> 0 Then
						oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 11 when deleting subfiles in subfolders in log folder.."
						Err.Clear
					End If
				End If
			End If
		Next
	Next
	oFile.WriteLine "Archiving " & sSystemDrive & "\inetpub\logs\LogFiles" & " - original size is " & FormatNumber(((folder.Size / 1024) / 1024),2) & " MB"
	oShell.run "compact /c /s " & sSystemDrive & "\inetpub\logs\LogFiles\* /i /q /f", 1, true
	If Err.Number <> 0 Then
		oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 11."
		Err.Clear
	End If
	Set objRE = Nothing
Else
	oFile.WriteLine "Did not find " & sSystemDrive & "\inetpub\logs\LogFiles\"
	oFile.WriteLine "      Skipping..."
End If
If oFSO.FolderExists(sSystemRoot & "\SYSTEM32\LogFiles\")  Then
	oFile.WriteLine "Removing all log files older then 14 days under all subfolders of " & sSystemRoot & "\SYSTEM32\LogFiles\"
	Dim system32SystemFolder, system32SubFolder, subFolderFile
	Set system32SystemFolder = oFSO.GetFolder(sSystemRoot & "\SYSTEM32\LogFiles\")
	For Each system32SubFolder in system32SystemFolder.SubFolders
		For Each subFolderFile in system32SubFolder.Files 
			If DateDiff("d",subFolderFile.DateCreated,oDate) >= 14 Then
					oFile.WriteLine "Deleting " & subFolderFile.Path & " with size " & FormatNumber(((subFolderFile.Size / 1024) / 1024),2) & " MB - it is more then 14 days since it was last modified"
					subFolderFile.Delete True
					If Err.Number <> 0 Then
						oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 11 when deleting subfiles in subfolders in system32 log folder.."
						Err.Clear
					End If
			End If
		Next
	Next	
	oFile.WriteLine "Archiving " & sSystemRoot & "\SYSTEM32\LogFiles\"
	If Err.Number <> 0 Then
		oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 11."
		Err.Clear
	End If
	oShell.run "compact /c /s " & sSystemRoot & "\SYSTEM32\LogFiles\* /i /q /f", 1, true
Else
	oFile.WriteLine "Did not find " & sSystemRoot & "\SYSTEM32\LogFiles\"
	oFile.WriteLine "      Skipping..."
End If
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear

'	12. %SystemRoot%\installer\$PatchCache$ - slettes
If oFSO.FolderExists(sSystemRoot & "\installer\$PatchCache$") Then 
	deletePatchCache(oFile)
Else 
	oFile.WriteLine "Did not find " & sSystemRoot & "\installer\$PatchCache$"
	oFile.WriteLine "      Skipping..."
End If
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear

'	13. %SystemRoot%\$blabla$ - eldre enn 30 dager - slettes
Set objRE = New RegExp
With objRE
	'Tester om mappenavn starter på dollartegn og ender på dollartegn:
	.Pattern    = "^(\$)(.*\$)$"
	.IgnoreCase = True
	.Global     = True
End With
Set oFolderRoot = Nothing
Set oFolderRoot = oFSO.GetFolder(sSystemRoot)
For each folder In oFolderRoot.SubFolders	
	If objRE.Test(folder.Name) Then
		If oFSO.FolderExists(folder.Path) AND DateDiff("d",folder.DateCreated,oDate) >= 30 Then 
			oFile.WriteLine "Deleting " & folder.Path
			oFSO.DeleteFolder folder.Path, True
			If Err.Number <> 0 Then
				oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 14."
				Err.Clear
			End If
		End If
	End If
Next
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear

'	14. %SystemDrive%\$Recycle.Bin - slettes
If oFSO.FolderExists(sSystemDrive & "\$Recycle.Bin") Then
	deleteRecycleBin(oFile)
Else 
	oFile.WriteLine "Did not find " & sSystemDrive & "\$Recycle.Bin"
	oFile.WriteLine "      Skipping..."
End If
'	Show Progress as dots:
DisplayProgress(1)

'	15. %SystemDrive%\PerfLogs - komprimer med compact /s mappe /i /q
If oFSO.FolderExists(sSystemDrive & "\PerfLogs")  Then
	oFile.WriteLine "Archiving " & sSystemDrive & "\PerfLogs"
	oShell.run "compact /c /s " & sSystemDrive & "\PerfLogs\* /i /q /f", 1, true
	If Err.Number <> 0 Then
		oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 17."
		Err.Clear
	End If
Else
	oFile.WriteLine "Did not find " & sSystemDrive & "\PerfLogs"
	oFile.WriteLine "      Skipping..."
End If
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear

'	16 %SystemDrive%\MSOCache - komprimer med compact /s mappe /i /q
If oFSO.FolderExists(sSystemDrive & "\MSOCache")  Then
	oFile.WriteLine "Archiving " & sSystemDrive & "\MSOCache"
	oShell.run "compact /c /s " & sSystemDrive & "\MSOCache\* /i /q /f", 1, true
	If Err.Number <> 0 Then
		oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 18."
		Err.Clear
	End If
Else
	oFile.WriteLine "Did not find " & sSystemDrive & "\MSOCache"
	oFile.WriteLine "      Skipping..."
End If
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear

'	17. %SystemRoot%\installer - ryddes med MsiZap.exe? - ikke lenger supportert av Microsoft :/ - Avslått!
'		Her utfører vi rydding av winsxs mappe i stedet:
Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
Set oss = objWMIService.ExecQuery ("Select * from Win32_OperatingSystem")

For Each os in oss
	osVersion = Left(os.Version, 3)
	oFile.WriteLine "Cleaning up " & sSystemRoot & "\winsxs"
	
	If Not StrComp(osVersion,"6.3") Then '2012R2
		oShell.run "dism.exe /online /cleanup-image /spsuperseded", 1, true
		oShell.run "dism.exe /online /cleanup-image /StartComponentCleanup ", 1, true
		If Err.Number <> 0 Then
			oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 20."
			Err.Clear
		End If
	End If
	If Not StrComp(osVersion,"6.2") Then '2012
		oShell.run "dism.exe /online /cleanup-image /spsuperseded", 1, true
		oShell.run "dism.exe /online /cleanup-image /StartComponentCleanup ", 1, true
		If Err.Number <> 0 Then
			oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 20."
			Err.Clear
		End If
	End If
	If Not StrComp(osVersion,"6.1") Then '2008R2
		oShell.run "dism.exe /online /cleanup-image /spsuperseded", 1, true
		If Err.Number <> 0 Then
			oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 20."
			Err.Clear
		End If
	End If
	If Not StrComp(osVersion,"6.0") Then '2008
		If oFSO.fileExists(sSystemRoot & "\system32\compcln.exe") Then
			oShell.run sSystemRoot & "\system32\compcln.exe /quiet", 1, true
			If Err.Number <> 0 Then
				oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 20."
				Err.Clear
			End If
		End If
		If oFSO.fileExists(sSystemRoot & "\system32\vsp1cln.exe") Then
			oShell.run sSystemRoot & "\system32\vsp1cln.exe /quiet", 1, true
			If Err.Number <> 0 Then
				oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 20."
				Err.Clear
			End If
		End If
	End If
Next
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear

'	18. Slette innhold i temp katalogen for alt som er eldre enn 7 dager
If oFSO.FolderExists(sSystemDrive & "\Temp") Then
	oFile.WriteLine "Checking " & sSystemDrive & "\Temp"
	set oLocation = Nothing
	set folder = Nothing

	Set oLocation = oFSO.GetFolder(sSystemDrive & "\Temp")
	For each folder In oLocation.Subfolders
		Set folderSize = Nothing
		folderSize = FormatNumber(((folder.Size / 1024) / 1024),2)
		If Err.Number <> 0 Then
			oFile.WriteLine "An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 22."
			Err.Clear
		End If
		'On Error Goto 0
		If DateDiff("d",folder.DateLastModified,oDate) >= 7 Then 
			oFile.WriteLine "Deleting " & folder.Path & " with size " & folderSize & " MB - it is more then 7 days since it was last modified"
			oFSO.DeleteFolder folder.Path, True
		End If
	Next
	Set oFiles = oLocation.Files
	set file = Nothing	
	For Each file in oFiles
		If Err.Number <> 0 Then
			oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ") at point 22."
			Err.Clear
		End If
		'On Error Goto 0
		If DateDiff("d",file.DateLastModified,oDate) >= 7 Then 
			oFile.WriteLine "Deleting " & file.Path & " with size " & FormatNumber(((file.Size / 1024) / 1024),2) & " MB - it is more then 7 days since it was last modified"
			file.Delete True
		End If
	Next
Else
	oFile.WriteLine "Did not find " & sSystemDrive & "\Temp"
	oFile.WriteLine "      Skipping..."
End If
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear

'19. Slette alt som er mulig å slette under sSystemDrive\windows\temp\*
oFile.WriteLine "Deleting files and folders under " & sSystemRoot & "\Temp\"
Dim f
Set folder = Nothing
Set folder = oFSO.GetFolder(sSystemRoot & "\Temp\")
If folder.Files.Count > 0 Then
	for each f In folder.Files
		On Error Resume Next
		oFile.WriteLine "	Deleting: " & f.Path
		f.Delete True   
		If Err.Number <> 0 Then
			oFile.WriteLine "	Error deleting: " & f.name & " - (" & Err.Number & " - " & Err.Description & ") at point 24 - " & sSystemRoot & "\temp\* file deletion."
		End If
		On Error GoTo 0
		Err.Clear
	Next
End If
If folder.SubFolders.Count > 0 Then
	Dim folderHolder
	For Each folderHolder In folder.SubFolders
		If folderHolder.Files.Count > 0 Then
			for each f In folderHolder.Files
				On Error Resume Next
				oFile.WriteLine "	Deleting: " & f.Path
				f.Delete True   
				If Err.Number <> 0 Then
					oFile.WriteLine "	Error deleting: " & f.name & " - (" & Err.Number & " - " & Err.Description & ") at point 24 - " & sSystemRoot & "\temp\" & folderHolder.name & "\* file deletion."
				End If
				On Error GoTo 0
				Err.Clear
			Next
		End If
		On Error Resume Next
		Err.Clear
				oFile.WriteLine "	Deleting: " & folderHolder.Path
		folderHolder.Delete True	
		If Err.Number <> 0 Then
			oFile.WriteLine "	Error deleting: " & folderHolder.name & " - (" & Err.Number & " - " & Err.Description & ") at point 24 - " & sSystemRoot & "\temp\* folder deletion."
		End If
		On Error GoTo 0
		Err.Clear
	Next
End If
'	Show Progress as dots:
DisplayProgress(1)

' 20. Rydd rota for småfiler - bare systemfiler skal være her(.rnd, bootmgr, BOOTSECT.BAK, END. HIBERFIL.SYS, PAGEFILE.SYS, 
'			autoexec.bat, config.sys, io.sys, Bootlog.prv, Bootlog.txt, Command.com, Command.dos, Config.dos, Cvt.log, Detlog.old, Detlog.txt,
'			Io.dos, Logo.sys, Msdos.dos, Msdos.sys, Suhdlog.dat, System.1st, Videorom.bin, W95undo.dat, W95undo.ini)
' Sjekk også om filene har system attribute satt, disse skal ikke ryddes.
oFile.WriteLine "Deleting files under " & sSystemDrive & "\ that are not system files.."
Dim allowedRootFiles(34)
allowedRootFiles(0) = ".rnd"
allowedRootFiles(1) = "bootmgr"
allowedRootFiles(2) = "BOOTSECT.BAK"
allowedRootFiles(3) = "END"
allowedRootFiles(4) = "HIBERFIL.SYS"
allowedRootFiles(5) = "PAGEFILE.SYS"
allowedRootFiles(6) = "autoexec.bat"
allowedRootFiles(7) = "config.sys"
allowedRootFiles(8) = "io.sys"
allowedRootFiles(9) = "Bootlog.prv"
allowedRootFiles(10) = "Bootlog.txt"
allowedRootFiles(11) = "Command.com"
allowedRootFiles(12) = "Command.dos"
allowedRootFiles(13) = "Config.dos"
allowedRootFiles(14) = "Cvt.log"
allowedRootFiles(15) = "Detlog.old"
allowedRootFiles(16) = "Detlog.txt"
allowedRootFiles(17) = "Io.dos"
allowedRootFiles(18) = "Logo.sys"
allowedRootFiles(19) = "Msdos.dos"
allowedRootFiles(20) = "Msdos.sys"
allowedRootFiles(21) = "Suhdlog.dat"
allowedRootFiles(22) = "System.1st"
allowedRootFiles(23) = "Videorom.bin"
allowedRootFiles(24) = "W95undo.dat"
allowedRootFiles(25) = "W95undo.ini"
allowedRootFiles(26) = "boot.ini"
allowedRootFiles(27) = "ntdetect.com"
allowedRootFiles(28) = "ntldr"
allowedRootFiles(29) = "boot"
allowedRootFiles(30) = "bootmgr.exe"
allowedRootFiles(31) = "autoexec.nt"
allowedRootFiles(32) = "config.nt"
allowedRootFiles(33) = "bootnxt"
allowedRootFiles(34) = "NO_SMS_ON_DRIVE.SMS"

Set folder = Nothing
Set folder = oFSO.GetFolder(sSystemDrive & "\")
Dim arf, fileOK, oCurrentFile

For Each f in folder.Files
	If Err.Number <> 0 Then
		oFile.WriteLine "	Error deleting: " & f.name & " - (" & Err.Number & " - " & Err.Description & ") at point 25 - " & sSystemDrive & "\* file deletion."
		Err.Clear
	End If
	fileOK = true
	Set oCurrentFile = oFSO.GetFile(sSystemDrive & "\" & f.Name)
	For Each arf In allowedRootFiles
		If StrComp(LCase(arf), LCase(f.Name)) = 0 Then
			fileOK = false
		End If
	Next
	If fileOK Then
		If oCurrentFile.Attributes AND 4 Then			
			oFile.WriteLine "	" & f.Path & " was not in the exclude list but has the system file attribute set, skipping it."
		Else
			oFile.WriteLine "	Deleting: " & f.Path
			f.Delete True
			If Err.Number <> 0 Then
				oFile.WriteLine "	Error deleting: " & f.name & " - (" & Err.Number & " - " & Err.Description & ") at point 25 - " & sSystemDrive & "\* file deletion."
			End If
		End If 		
	End If
	On Error GoTo 0
	Err.Clear
	Set oCurrentFile = Nothing
Next
'	Show Progress as dots:
DisplayProgress(1)

'	21. Brukerprofilrydding:
'		1. Delete C:\Users\%user%\AppData\Local\Temp\*.*  (%temp%)
If oFSO.FolderExists(sSystemDrive & "\Users") OR oFSO.FolderExists(sSystemDrive & "\Documents And Settings") Then
	set oLocation = Nothing
	set folder = Nothing
	If oFSO.FolderExists(sSystemDrive & "\Documents And Settings") Then
		Set oLocation = oFSO.GetFolder(sSystemDrive & "\Documents And Settings")
	End If
		If oFSO.FolderExists(sSystemDrive & "\Users") Then
		Set oLocation = oFSO.GetFolder(sSystemDrive & "\Users")
	End If
	oFile.WriteLine "Checking user profiles temp folder: " & oLocation
	For each folder In oLocation.Subfolders
		If Not folder is Nothing And Not IsNull(folder) And Not IsEmpty(folder) Then
			If StrComp(folder.Name,"All Users", 1) AND StrComp(folder.Name,"Alle Brukere", 1) AND StrComp(folder.Name,"Default", 1) AND StrComp(folder.Name,"Default User", 1) Then
				If Err.Number <> 0 Then
					oFile.WriteLine "    An error was encountered (" & Err.Number & " - " & Err.Description & ")  at point 4."
					Err.Clear
				End If
				If oFSO.FolderExists(folder.Path & "\AppData\Local\Temp") Then
					Dim oTempFolder
					Set oTempFolder = oFSO.GetFolder(folder.Path & "\AppData\Local\Temp")
					Set f = Nothing
					If oTempFolder.Files.Count > 0 Then
						for each f In oTempFolder.Files
							On Error Resume Next
							oFile.WriteLine "	Deleting: " & f.Path
							f.Delete True   
							If Err.Number <> 0 Then
								oFile.WriteLine "	Error deleting: " & f.name & " - (" & Err.Number & " - " & Err.Description & ") at point 5 - " & oTempFolder.Path & "\* file deletion."
							End If
							On Error GoTo 0
							Err.Clear
						Next
					End If
					If oTempFolder.SubFolders.Count > 0 Then
						Set folderHolder = nothing
						For Each folderHolder In oTempFolder.SubFolders
							If folderHolder.Files.Count > 0 Then
								for each f In folderHolder.Files
									On Error Resume Next
									oFile.WriteLine "	Deleting: " & f.Path
									f.Delete True   
									If Err.Number <> 0 Then
										oFile.WriteLine "	Error deleting: " & f.name & " - (" & Err.Number & " - " & Err.Description & ") at point 5 - " & sSystemRoot & "\temp\" & folderHolder.name & "\* file deletion."
									End If
									On Error GoTo 0
									Err.Clear
								Next
							End If
							On Error Resume Next
							Err.Clear
							
							' Ignore bginfo.bmp in temp folder to prevent scclient.exe bug.
							IF folderHolder.Path <> (folder.Path & "\AppData\Local\Temp\1") AND folderHolder.Path <> (folder.Path & "\AppData\Local\Temp\2") THEN
								oFile.WriteLine "	Deleting: " & folderHolder.Path
								folderHolder.Delete True
							ELSE
								oFile.WriteLine "	Ignoring : " & folderHolder.Path & " due to SCClient.exe bug."
							End If
							If Err.Number <> 0 Then
								oFile.WriteLine "	Error deleting: " & folderHolder.name & " - (" & Err.Number & " - " & Err.Description & ") at point 5 - " & sSystemRoot & "\temp\* folder deletion."
							End If
							On Error GoTo 0
							Err.Clear
						Next
					End If
				End If	
			Else
				oFile.WriteLine "Checked """ & folder.Path & """ but the script was programmed to avoid it.."
			End If
		End If
	Next
Else
	oFile.WriteLine "Did not find " & sSystemDrive & "\Users or " & sSystemDrive & "\Documents And Settings"
	oFile.WriteLine "      Skipping..."
End If
'	Show Progress as dots:
DisplayProgress(1)
Err.Clear

'	22. Fontcache rydding - cmd streng fra Jarle Hansen:
'		forfiles /P C:\Windows\
If oFSO.FolderExists(sSystemDrive & "\ServiceProfiles\LocalService\AppData\Local") Then
	oFile.WriteLine "Cleaning op FontCache Files in " & sSystemDrive & "\ServiceProfiles\LocalService\AppData\Local"
	oShell.run sSystemDrive & "\ServiceProfiles\LocalService\AppData\Local /M FontCache* /D -30 /C ""cmd /c del @path""", 1, true
	If Err.Number <> 0 Then
		oFile.WriteLine "	Error cleaning up FontCache files: - (" & Err.Number & " - " & Err.Description & ") at point 31."
	End If
	Err.Clear
End If 
DisplayProgress(1)
Err.Clear

'	23. Skriv inn i registry hvor scriptet ligger og hvilken versjon det er
Dim versionKey 
versionKey = "HKLM\SOFTWARE\ryddeScript\CurrentVersion"
Dim lastRunKey
lastRunKey = "HKLM\SOFTWARE\ryddeScript\LastRunFrom"
On Error Resume Next
oShell.RegWrite versionKey,versionInfo,"REG_SZ"
Err.Clear
oShell.RegWrite lastRunKey,sLogLocation,"REG_SZ"
Err.Clear
DisplayProgress(1)

'And at last we then check how much disk space is free now:
Set disk = Nothing
Set disk = oFSO.GetDrive(sSystemDrive)
oFile.WriteLine "Free diskspace after running the script " & FormatNumber(((disk.FreeSpace / 1024) / 1024),2) & " MB"
wScript.Echo " "
wScript.Echo " "
wScript.Echo strDiskBefore
wScript.Echo "Free diskspace after running the script " & FormatNumber(((disk.FreeSpace / 1024) / 1024),2) & " MB"
wScript.Echo " "
oFile.Close

Dim Input
Wscript.StdOut.Write "Script Execution is done. Press the ENTER key to continue. "
Do While Not WScript.StdIn.AtEndOfLine
   Input = WScript.StdIn.Read(1)
Loop

Sub forceUseCScript  
	If Not WScript.FullName = WScript.Path & "\cscript.exe" Then      
		oShell.Popup "Scriptet ble startet ved bruk av WScript. Starter igjen med cscript...",3,"WSCRIPT"
		oShell.Run "cmd.exe /k " & WScript.Path & "\cscript.exe //NOLOGO " & Chr(34) & WScript.scriptFullName,1,False
		WScript.Quit 0
	End If
End Sub
Sub forceAsAdmin
	If WScript.Arguments.Named.Exists("elevated") = False Then 
		'oShell.Popup "Scriptet ble ikke startet som admin. Starter igjen med cscript og som admin...",3,"Manglende admin"
		CreateObject("Shell.Application").ShellExecute WScript.Path & "\cscript.exe", """" & WScript.ScriptFullName & """ /elevated", "", "runas", 1 
		WScript.Quit 0
	End If
End Sub
Function DisplayProgress(progressNumber)
	On Error Resume Next
	Dim percentDone, percentLeft, intCount
	
	progressCount = progressCount + progressNumber
	wScript.StdOut.Write(chr(13) & "|")
	percentDone = round(((progressCount / progressMax) * 70 ))
	For intCount = 0 To percentDone
		wScript.StdOut.Write("*")
	Next
	percentLeft = round((70-((progressCount / progressMax) * 70)))
	For intCount = 0 To percentLeft
		wScript.StdOut.Write("_")
	Next
	wScript.StdOut.Write("|")
	If percentLeft <= 0 Then
		wScript.StdOut.Write(" Done!")
	End If
End Function
Function UserPerms (PermissionQuery)          
	UserPerms = False  ' False unless proven otherwise           
	Dim CheckFor, CmdToRun         

	Select Case Ucase(PermissionQuery)           
	'Setup aliases here           
	Case "ELEVATED"  
		CheckFor =  "S-1-16-12288"           
	Case "ADMIN" 
		CheckFor =  "S-1-5-32-544"           
	Case "ADMINISTRATOR"      
		CheckFor =  "S-1-5-32-544"           
	Case Else                  
		CheckFor = PermissionQuery                  
	End Select           

	CmdToRun = "%comspec% /c whoami /all | findstr /I /" & sSystemDrive & """" & CheckFor & """"  

	Dim returnValue        
	returnValue = oShell.Run(CmdToRun, 0, true)     
	If returnValue = 0 Then 
		UserPerms = True
	End If
End Function
Function ReadReg(RegPath)
	On Error Resume Next
    ReadReg = oShell.RegRead(RegPath)
End Function
Function regValueExists(key)
	On Error Resume Next
	Dim strLen
	regValueExists = False
	strLen = Len(ReadReg(key))
    If IsNumeric(strLen) And strLen > 0 Then
		regValueExists = True
	End If
End Function
Function deleteRecycleBin(oFile)
	On Error Resume Next
	oFile.WriteLine "Deleting " & sSystemDrive & "\$Recycle.Bin"
	oFSO.DeleteFolder sSystemDrive & "\$Recycle.Bin", True
	oShell.run "rmdir /Q /S " & sSystemDrive & "\$Recycle.Bin", 1, true
End Function
Function deletePatchCache(oFile)
	On Error Resume Next
	oFile.WriteLine "Deleting " & sSystemRoot & "\installer\$PatchCache$"
	oShell.run "rmdir /Q /S " & sSystemRoot & "\installer\$PatchCache$", 1, true
	oFSO.DeleteFolder sSystemRoot & "\installer\$PatchCache$", True
End Function