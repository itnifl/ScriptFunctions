<#
	1. Get original ISO localtion input. [OK]
	2. Get csv file location for script input settings (ip, hostname). [OK]
	3. Extract original ISO. [OK]
	4. Generate script and place it in ISO extracted directory. [OK]
	5. Create custom bootable ISO with hostname in ISO name by using mkisofs.exe. [OK]
	6. Notify script result. [OK]
#>
Set-Variable -name GlobalLogFileLocation -value "$(pwd)\IsoCreation.log"  -scope global
Function LogAction {
	param(
		[Parameter(Mandatory = $False, Position = 0)]
		[Alias("Message")]
		[String]$strMessage,
		[Parameter(Mandatory = $False, Position = 1)]
		[Alias("Error")]
		[bool]$boolError,
		[Parameter(Mandatory = $False, Position = 2)]
		[Alias("SetWhite")]
		[bool]$boolSetWhite
	)
	
	if(-Not $strMessage) {
		return "";
	}
	Trap {
		Write-Warning ('Failed to LogAction "{0}" : {1} in "{2}"' -f $strMessage, $_.Exception.Message, $_.InvocationInfo.ScriptName)
		Continue;
	}
	$date = get-date
	if($psversiontable.Psversion.Major -lt 3) {
		if($boolError) { Write-Host -Foregroundcolor Red "$date - $strMessage"}
		elseif($boolSetWhite) { 
			Write-Host "##########################################################"
			Write-Host -Foregroundcolor White "$date - $strMessage"
			Write-Host "##########################################################"
		}
		else { Write-Host -Foregroundcolor Yellow "$date - $strMessage" }
	} else {
		if($boolError) { echo "$date - $strMessage" | Tee-Object -FilePath $GlobalLogFileLocation -Append | Write-Host -Foregroundcolor Red }
		elseif($boolSetWhite) { 
			Write-Host "##########################################################"
			echo "$date - $strMessage" | Tee-Object -FilePath $GlobalLogFileLocation -Append | Write-Host -Foregroundcolor White
			Write-Host "##########################################################"
		}
		else { echo "$date - $strMessage" | Tee-Object -FilePath $GlobalLogFileLocation -Append | Write-Host -Foregroundcolor Yellow }
	}	
}

function Generate-ISO {
	param(
		[alias("ESXi_Path")] [Parameter(Mandatory=$True,Position=0)] [String] $inputESXi
	)
	Set-Variable -name GlobalCSVFilePath -value ".\ConfigurationFiles\ESXiConfigs.csv" -scope global
	Set-Variable -name GlobalBOOTFile -value ".\ConfigurationFiles\BOOT.CFG" -scope global
	Set-Variable -name GlobalKSFile -value ".\ConfigurationFiles\KS.CFG" -scope global
	Set-Variable -name GlobalIsoLinuxFile -value ".\ConfigurationFiles\isolinux.cfg" -scope global
	LogAction -Message "Log file is: $GlobalLogFileLocation"
	
	if(-Not (Test-Path $GlobalCSVFilePath)) {
		LogAction -Message "ERROR: $GlobalCSVFilePath was not found, aborting.." -Error $true
		exit 1;
	}
	if(-Not (Test-Path $GlobalKSFile)) {
		LogAction -Message "ERROR: $GlobalKSFile was not found, aborting.." -Error $true
		exit 1;
	}
	if(-Not (Test-Path $GlobalBOOTFile)) {
		LogAction -Message "ERROR: $GlobalBOOTFile was not found, aborting.." -Error $true
		exit 1;
	}
	if(Test-Path $inputESXi) {	
		$isoNames = @()
		#CSV in the format: HostIP, NetMask, GateWay, ReplaceHostName, VLANID, NameServer, license:
		foreach($confLine in Get-Content $GlobalCSVFilePath) {
			$confArray = $confLine.Split(",");
			$NewHostName = $confArray[3]
			$folderOutPath = [System.IO.Path]::GetFileNameWithoutExtension($inputESXi)
			$folderOutPath = "$folderOutPath_$NewHostName"
			
			#$driveLabel = Read-Host "Enter the path where you have the source of the ESXi ISO, for instance D:\"
			Copy-CD -MountLabel $inputESXi	-Destination $folderOutPath -FolderOverwrite $true
			
			if(-Not (Test-Path "$folderOutPath\KS.CFG")) { 
				if(-Not (Test-Path "$folderOutPath")) { New-Item "$folderOutPath" -type directory }
				New-Item "$folderOutPath\KS.CFG" -type file 
			}
			(Get-Content $GlobalKSFile).replace('172.123.123.123', $confArray[0]).replace('255.255.0.0', $confArray[1]).replace('172.123.123.2', $confArray[2]).replace('ReplaceHostName', $NewHostName).replace('888', $confArray[4]).replace('8.8.8.8', $confArray[5]).replace('ReplaceLicense', $confArray[6])  | Set-Content "$folderOutPath\KS.CFG"
			
			if(-Not (Test-Path "$folderOutPath\BOOT.CFG")) { 				
				if(-Not (Test-Path "$folderOutPath")) { New-Item "$folderOutPath" -type directory }
				New-Item "$folderOutPath\BOOT.CFG" -type file 
			}
			(Get-Content $GlobalBOOTFile).replace('172.123.123.123', $confArray[0]).replace('255.255.0.0', $confArray[1]).replace('172.123.123.2', $confArray[2]).replace('ReplaceHostName', $NewHostName).replace('888', $confArray[4]).replace('8.8.8.8', $confArray[5]) | Set-Content "$folderOutPath\BOOT.CFG"
			
			if(-Not (Test-Path "$folderOutPath\isolinux.cfg")) { 				
				if(-Not (Test-Path "$folderOutPath")) { New-Item "$folderOutPath" -type directory }
				New-Item "$folderOutPath\isolinux.cfg" -type file 
			}
			(Get-Content $GlobalIsoLinuxFile).replace('ReplaceHostName', $NewHostName) | Set-Content "$folderOutPath\isolinux.cfg"
			
			$splitPath = Split-Path -Path "$inputESXi" -Leaf			
			LogAction -Message "Generating a new name from $splitPath"
			
			$NewIsoName = "$splitPath_$NewHostName.iso"
			LogAction -Message "Creating $NewIsoName, please be patient.."
			<#$build = ".\mkisofs.exe"
			$arguments = "-relaxed-filenames -J -R -o $NewIsoName -b $folderOutPath\isolinux.bin -c $folderOutPath\boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table $folderOutPath"
			Start-Process -Wait $build $arguments#>
			cp .\mkisofs.exe "$folderOutPath"
			cd $folderOutPath
			.\mkisofs.exe -relaxed-filenames -J -R -o ..\$NewIsoName -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table . 2> $NULL
			if($?) {
				$isoNames += $NewIsoName				
			}			
			cd ..
			if($?) {
				LogAction -Message "Cleaning up $folderOutPath"
				#Remove-Item $folderOutPath -Force -confirm:$false 
			}
		}
		LogAction -Message "Congratulations, all your ISO files have been created:"
		$isoNames | % { LogAction -Message $_ }
	} else {
		LogAction -Message "Paths do not exist, aborting..." -Error $true
	}
}

function Extract-ISO {
	param(
		[alias("ISO")] [Parameter(Mandatory=$True,Position=0)] [string]$sourcefile, 
		[alias("Destination")] [Parameter(Mandatory=$True,Position=1)] [string]$destinationFolder, 
		[alias("FolderOverwrite")] [Parameter(Mandatory=$False,Position=2)] [bool]$overwrite = $false
	)
	$folder = $destinationFolder
	if((Test-Path $folder) -and $overwrite -eq $false) {
		LogAction -Message "Error: '$folder' already exists" -Error $true
		exit 1
	} else {
		if(Test-Path $folder) {
		  rm $folder -Recurse
		}
		$mount_params = @{ImagePath = $sourcefile; PassThru = $true; ErrorAction = "Ignore"}
		$mount = Mount-DiskImage @mount_params

		if($mount) {
			$volume = Get-DiskImage -ImagePath $mount.ImagePath | Get-Volume
			$source = $volume.DriveLetter + ":\*"
			$folder = mkdir $folder

			LogAction -Message "Extracting '$sourcefile' to '$folder'..."
			$params = @{Path = $source; Destination = $folder; Recurse = $true;}
			cp @params
			$hide = Dismount-DiskImage @mount_params
			LogAction -Message "Copy complete"
		}
		else {
			LogAction -Message "ERROR: Could not mount $sourcefile check if file is already in use" -Error $true
		}
	}
}
function Copy-CD {
	param(
		[alias("MountLabel")] [Parameter(Mandatory=$True,Position=0)] [string]$inputMountLabel, 
		[alias("Destination")] [Parameter(Mandatory=$True,Position=1)] [string]$destinationFolder, 
		[alias("FolderOverwrite")] [Parameter(Mandatory=$False,Position=2)] [bool]$overwrite = $false
	)
	$folder = $destinationFolder
	if((Test-Path $folder) -and $overwrite -eq $false) {
		LogAction -Message "Error: '$folder' already exists" -Error $true
		exit 1
	} else {
		if(Test-Path $folder) {
		  rm $folder -Recurse
		}		

		if(Test-Path $inputMountLabel) {
			$source = $inputMountLabel
			$folder = mkdir $folder

			LogAction -Message "Copying '$inputMountLabel' to '$folder'..."
			xcopy "$source" "$folder" /H /S /E
			LogAction -Message "Copy complete.."
		}
		else {
			LogAction -Message "ERROR: Could find path $inputMountLabel, check that it exists" -Error $true
		}
	}
}
function StartMe {	
	Generate-ISO -ESXi_Path "C:\temp\AutoGenerateScriptedESXiIso\vm05"
}
StartMe