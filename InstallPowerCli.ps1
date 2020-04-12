$our32BitSoftware = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | select DisplayName, Publisher, InstallDate
$our64BitSoftware = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | select DisplayName, Publisher, InstallDate

Write-Host -ForegroundColor Yellow "Detecting if we should install PowerCli.."

if(($our32BitSoftware.Displayname -like "Microsoft .NET Framework 4.5*").Count -gt 0 -or ($our64BitSoftware.Displayname -like "Microsoft .NET Framework 4.5*").Count -gt 0) {
	Write-Progress -Activity "Installing PowerCli, please be patient.." -PercentComplete "1" -CurrentOperation "1 % complete" -Status "Please wait."
	$Scriptblock = {
		Param (
			[string]$argument
		)	
		#Write-Host -Foregroundcolor Yellow "Starting installation of PowerCli with the following arguments:"
		#Write-Host -Foregroundcolor Yellow "Received argument: $argument"	
		$PWD = (pwd).path
		$our32BitSoftware = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | select DisplayName, Publisher, InstallDate
		$our64BitSoftware = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | select DisplayName, Publisher, InstallDate
		$SetupDiskLetter = (Get-WMIObject Win32_Volume | ? { $_.Label -eq 'SETUP' }).DriveLetter

		if($our32BitSoftware.DisplayName -notcontains "VMware vSphere PowerCLI" -and $our64BitSoftware.DisplayName -notcontains "VMware vSphere PowerCLI") {
			Write-Host -ForegroundColor Yellow "Please be patient while PowerCli gets installed.."
			#Write-Host -ForegroundColor Yellow "Installing: VMware PowerCLI, please wait.."
			$build =  "$SetupDiskLetter\vSphere Configuration\Programs\VMware-PowerCLI\VMware-PowerCLI-5.5.0-1295336.exe"
			$arguments = "/q /s /w /V`" /qn /norestart `""
			Start-Process -Wait $build $arguments
		} else {
			Write-Host -ForegroundColor Yellow "Installing: VMware vSphere PowerCLI, already installed (skipping).."
		}
	}
	Start-Job -ScriptBlock $Scriptblock -ArgumentList "Go PowerCli!"
	$percentageComplete = 1
	$elapsedTime = [System.Diagnostics.Stopwatch]::StartNew()
	While (@(Get-Job | Where { $_.State -eq "Running" }).Count -ne 0) {  
		Start-Sleep -Seconds 5
		$percentageComplete += 1
		if($percentageComplete -gt 94) {
			$percentageComplete = 60
		}
		$CurrentOperationPercentage = "{0:P0}" -f ($percentageComplete * 10)
		Write-Progress -Activity "Installing PowerCli, please be patient.." -PercentComplete $percentageComplete -CurrentOperation "$CurrentOperationPercentage complete" -Status "Please wait."
		(Get-Job | Where { $_.State -eq "Running" -and $_.HasMoreData } | Receive-Job) | ? {$_.trim() -ne "" }
		if($elapsedTime.Elapsed.Minutes -gt 9) {
			break;
		}
	}
	Write-Progress -Activity "Installing PowerCli, please be patient.." -PercentComplete "100" -CurrentOperation "100 % complete" -Status "Done!"
	Write-Progress -Activity "Installing PowerCli, please be patient.." -Completed
} else {
	Write-Host -ForegroundColor Yellow "Microsoft .NET Framework 4.5.1 is not installed, cannot install PowerCli.."
}
	