function Get-PiMsfFile {
 <#
    .SYNOPSIS 
		Creates folder structure for MSFWinGen, uploads MSFWinGen to that structure, executes MSFWinGen and downloads the resulting msf file.
		This is done to VM specified by -VMIP and -VmName. The script assumes you are already connected to the respective vSphere system.
    .EXAMPLE
		Get-PiMsfFile -VMIP $deploymentIP -Username ".\Administrator" -Password "123" -VmName "GOL-example1" -vSphereHostUser "root" -vSphereHostPassword "password123"
  #>
	param(
		[alias("VMIP")] [Parameter(Mandatory=$True,Position=0)] [String] $systemAddress,
		[alias("Username")] [Parameter(Mandatory=$True,Position=1)] [String] $systemUsername,
		[alias("Password")] [Parameter(Mandatory=$True,Position=2)] [String] $systemPassword,
		[alias("VmName")] [Parameter(Mandatory=$True,Position=3)] [String] $virtualMachineName,
		[alias("vSphereHostUser")] [Parameter(Mandatory=$True,Position=5)] [String] $vHostUser,		
		[alias("vSphereHostPassword")] [Parameter(Mandatory=$True,Position=6)] [String] $vHostPassword
	)
	
	$props = @{
		errorID = 0;
	}

	function CreateFolderStructure {
		Write-Host -Foregroundcolor Yellow "Creating folder C:\SilentInstall"
		New-Item C:\SilentInstall -type directory -force -ErrorAction SilentlyContinue -Confirm:$false
	}
	function RunMSFWinGen {
		cd C:\SilentInstall
		C:\SilentInstall\RunMSFWinGen.exe
		<#
		$wshell = New-Object -ComObject wscript.shell;
		$wshell.CurrentDirectory = "C:\SilentInstall";
		$wshell.Run('C:\SilentInstall\MSFWinGen.exe', 0, $false);
		start-sleep -s 1
		$wshell.AppActivate('OSISoft Machine Signature File Generator'); 
		$wshell.SendKeys('~');
		$wshell.SendKeys('~');	#>
	}
	
	#If we are using an IP-Address to communicate with the host we want to registry manipulate, add the address to list of trusted hosts:
	if($systemAddress -match '\b(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}\b') {
		#Write-Host -Foregroundcolor Yellow "-Adding $systemAddress to list of trusted hosts"
		set-item wsman:\localhost\Client\TrustedHosts -value $systemAddress -Force -Confirm:$false		
	}
	try {
		Write-Host -Foregroundcolor Yellow "-Creating PowerShell remote session to $systemAddress"
		$securePassword = ConvertTo-SecureString -String $systemPassword -AsPlainText -Force
		$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $systemUsername, $securePassword
		$session = New-PSSession -Credential $cred -ComputerName $systemAddress
	} catch {
		$props["errorID"] = 1.0;
		$props.Add("failedItem", $_.Exception.ItemName);
		$props.Add("errorMessage", @("ERROR: 1.0 Could not initiate remote PowerShell session to create folder structure for MSFWinGen:" + $_.Exception.Message));
		return new-object PSCustomObject –property $props
	}

	try {
		Write-Host -Foregroundcolor Yellow "-Invoking command and running remote function CreateFolderStructure on remote session"
		try {
			#Create Folder
			$i = Invoke-Command $session -ScriptBlock ${function:CreateFolderStructure}
		} catch {
			$props["errorID"] = 1.1;
			$props.Add("failedItem", $_.Exception.ItemName);
			$props.Add("errorMessage", @("ERROR: 1.1 Could not invoke command to create folder structure for MSFWinGen:" + $_.Exception.Message));
			return new-object PSCustomObject -property $props
		}
		Write-Host -Foregroundcolor Yellow "-Uploading MSFWinGen.exe to $virtualMachineName"
		try {
			#Upload file:
			$SetupDiskLetter = (Get-WMIObject Win32_Volume | ? { $_.Label -eq 'SETUP' }).DriveLetter
			Copy-VMGuestFile -Source "$SetupDiskLetter\vSphere Configuration\Programs\MSFWinGen.exe" -Destination C:\SilentInstall\ -VM $virtualMachineName -LocalToGuest -HostUser $vHostUser -HostPassword $vHostPassword -GuestUser $systemUsername -GuestPassword $systemPassword
			Write-Host -Foregroundcolor Yellow "-Uploading RunMSFWinGen.exe to $virtualMachineName"
			Copy-VMGuestFile -Source "$SetupDiskLetter\vSphere Configuration\Programs\RunMSFWinGen.exe" -Destination C:\SilentInstall\ -VM $virtualMachineName -LocalToGuest -HostUser $vHostUser -HostPassword $vHostPassword -GuestUser $systemUsername -GuestPassword $systemPassword
		} catch {
			$props["errorID"] = 1.2;
			$props.Add("failedItem", $_.Exception.ItemName);
			$props.Add("errorMessage", @("ERROR: 1.2 Could not upload RunMSFWinGen.exe:" + $_.Exception.Message));
			return new-object PSCustomObject -property $props
		}	
		Write-Host -Foregroundcolor Yellow "-Running RunMSFWinGen.exe on $virtualMachineName"
		try {
			$hostname = Invoke-VMScript -ScriptText "hostname" -VM $virtualMachineName  -GuestUser .\$systemUsername -GuestPassword $systemPassword -ToolsWaitSec 32 -ScriptType PowerShell
			$hostname = $hostname -replace "`n","" -replace "`r",""
			#Run the File
			#$i = Invoke-Command $session -ScriptBlock ${function:RunMSFWinGen}
			Write-Host -Foregroundcolor Yellow "-Invoking psexec by user '$systemUsername' and password '$systemPassword'"
			$currentPath = $(pwd).path
			cd "$SetupDiskLetter\vSphere Configuration\Programs\PSTools"
			& cmdkey.exe /add:$systemAddress /user:$hostname\$systemUsername /pass:$systemPassword 2>&1
			Invoke-Expression ".\psexec.exe -accepteula -u $systemUsername -p $systemPassword -s -i \\$systemAddress C:\SilentInstall\RunMSFWinGen.exe" 2>&1
			& cmdkey.exe /delete:$systemAddress 2>&1
			cd $currentPath
		} catch {
			$props["errorID"] = 1.3;
			$props.Add("failedItem", $_.Exception.ItemName);
			$props.Add("errorMessage", @("ERROR: 1.3 Could not run RunMSFWinGen.exe:" + $_.Exception.Message));
			return new-object PSCustomObject -property $props
		}	
		
		#Download the result
		$destination = "$SetupDiskLetter\MSFWinGenResult"
		Write-Host -Foregroundcolor Yellow "-Downloading $hostname.msf file to $destination"		
		try {
			if(-Not (Test-Path $destination)) {
				New-Item $destination -type directory -force -Confirm:$false -ErrorAction SilentlyContinue
			}		
			Copy-VMGuestFile -Source "C:\SilentInstall\$hostname.msf" -Destination $destination -VM $virtualMachineName -GuestToLocal -HostUser $vHostUser -HostPassword $vHostPassword -GuestUser $systemUsername -GuestPassword $systemPassword
		} catch {
			$props["errorID"] = 1.4;
			$props.Add("failedItem", $_.Exception.ItemName);
			$props.Add("errorMessage", @("ERROR: 1.4 Could not download msf file $hostname.msf:" + $_.Exception.Message));
			return new-object PSCustomObject -property $props
		}
		if($systemAddress -match '\b(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}\b') {
			$newvalue = ((Get-ChildItem WSMan:\localhost\Client\TrustedHosts).Value).Replace($systemAddress,"")
			Set-Item WSMan:\localhost\Client\TrustedHosts $newvalue -Force -Confirm:$false
		}
		try {
			Remove-PSSession -Session $session -Confirm:$false
		} catch {
			$props["errorID"] = 1.5;
			$props.Add("failedItem", $_.Exception.ItemName);
			$props.Add("errorMessage", @("ERROR: 1.5 Could not terminate remote PowerShell session to $systemAddress :" + $_.Exception.Message));
			return new-object PSCustomObject -property $props
		}		
		return $i;
	} catch {
		$props["errorID"] = 1.6;
		$props.Add("failedItem", $_.Exception.ItemName);
		$props.Add("errorMessage", @("ERROR: 1.6 Could not initiate remote PowerShell session to run MSFWinGen:" + $_.Exception.Message));
		return new-object PSCustomObject -property $props
	}	
}

#Get-PiMsfFile -VMIP "10.80.109.126" -Username "Administrator" -Password "dpos" -VmName "CDL.v.1.1.0" -vSphereHostUser "root" -vSphereHostPassword "dposdpos"