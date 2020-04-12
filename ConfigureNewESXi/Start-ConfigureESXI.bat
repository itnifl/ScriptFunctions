@echo ON
cd %~dp0
%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -NoExit -executionpolicy unrestricted -File "%~dp0\ConfigureESXi.ps1" %~dp0
