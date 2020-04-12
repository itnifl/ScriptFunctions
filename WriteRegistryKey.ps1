##Atle Holm - September 2015
##Version 1.0.0

function WriteRegistryValue {
 <#
    .SYNOPSIS 
		Writes to or changes a key in registry on remote machine via PowerShell Remote Session
    .EXAMPLE
		WriteRegistryValue -Hostname $deploymentIP -Username ".\Administrator" -Password "123" -Hive "HKLM" -Path ".\SYSTEM\CurrentControlSet\Services\W32Time\Config\" -Key "AnnounceFlags" -Value "5" -RegType "DWORD"
		See https://msdn.microsoft.com/en-us/library/microsoft.win32.registryvaluekind(v=vs.110).aspx for more info on possible options for the -RegType switch.
  #>
	param(
		[alias("Hostname")] [Parameter(Mandatory=$True,Position=0)] [String] $systemAddress,
		[alias("Username")] [Parameter(Mandatory=$True,Position=1)] [String] $systemUsername,
		[alias("Password")] [Parameter(Mandatory=$True,Position=2)] [String] $systemPassword,
		[alias("Hive")] [Parameter(Mandatory=$True,Position=3)]  [ValidateSet("HKCR", "HKCU","HKLM", "HKU", "HKCC")] [String] $registryHive,
		[alias("Path")] [Parameter(Mandatory=$True,Position=4)]  [String] $keyPath,
		[alias("Key")] [Parameter(Mandatory=$True,Position=5)] [String] $keyName,
		[alias("Value")] [Parameter(Mandatory=$True,Position=6)]  [String] $keyValue,
		[alias("RegType")] [Parameter(Mandatory=$True,Position=7)] [ValidateSet("BINARY", "DWORD", "NONE", "QWORD", "EXPANDSTRING", "MULTISTRING", "STRING", "UNKNOWN")] [String] $propertyType
	)
	
	$props = @{
		errorID = 0;
	}
	
	function ApplyRegistryValue {
		param(
			[alias("Hive")]
			[Parameter(Mandatory=$True,Position=0)] 
			[ValidateSet("HKCR", "HKCU","HKLM", "HKU", "HKCC")] 
			[String] $registryHive,
			[alias("Path")]
			[Parameter(Mandatory=$True,Position=1)] 
			[String] $keyPath,
			[alias("Key")]
			[Parameter(Mandatory=$True,Position=2)] 
			[String] $keyName,
			[alias("Value")]
			[Parameter(Mandatory=$True,Position=3)] 
			[String] $keyValue,
			[alias("Type")]
			[Parameter(Mandatory=$True,Position=4)] 
			[ValidateSet("BINARY", "DWORD", "NONE", "QWORD", "EXPANDSTRING", "MULTISTRING", "STRING", "UNKNOWN")]  #https://msdn.microsoft.com/en-us/library/microsoft.win32.registryvaluekind(v=vs.110).aspx
			[String] $propertyType
		)

		try {
			Write-Host -Foregroundcolor Yellow "-Writing to registry at remote machine.."
			$_1 = Push-Location
			$_2 = Set-Location "$registryHive`:"
						
			<#if($keyPath[$keyPath.Length-1] -eq "\") {
				$basePath = $keyPath -replace ".$"
			} else {
				$basePath = $keyPath
			}
			$basePath = $basePath.Substring(0,$basePath.LastIndexOf("\"))
			
			$_3 = New-Item -Force -Path $basePath -Name $keyPath.Split("\")[$keyPath.Split("\").Length-1] -Confirm:$false#>
			$_4 = New-ItemProperty -Force -Path $keyPath -Name $keyName -Value $keyValue -PropertyType $propertyType -Confirm:$false
			$_5 = Pop-Location
		} catch {
			$props = @{
				errorID = 2;
			}
			$props.Add("failedItem", $_.Exception.ItemName);
			$props.Add("errorMessage", @("ERROR: 2 Could not  change requested registry key: $keyPath\$keyName" + $_.Exception.Message));
			return new-object PSCustomObject �property $props
		}
		$props = @{
			errorID = 0;
		}
		return new-object PSCustomObject �property $props
	}
	
	#If we are using an IP-Address to communicate with the host we want to registry manipulate, add the address to list of trusted hosts:
	if($systemAddress -match '\b(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}\b') {
		#Write-Host -Foregroundcolor Yellow "-Adding $systemAddress to list of trusted hosts"
		set-item wsman:\localhost\Client\TrustedHosts -value $systemAddress -Force -Confirm:$false
	}
	try {
		Write-Host -Foregroundcolor Yellow "-Creating PowerShell remote session to $systemAddress"
		$securePassword = ConvertTo-SecureString -String $systemPassword -AsPlainText -Force
		$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $SystemUsername, $securePassword
		$session = New-PSSession -Credential $cred -ComputerName $systemAddress
	} catch {
		$props["errorID"] = 1.0;
		$props.Add("failedItem", $_.Exception.ItemName);
		$props.Add("errorMessage", @("ERROR: 1.0 Could not initiate remote PowerShell session to write to registry:" + $_.Exception.Message));
		return new-object PSCustomObject �property $props
	}

	try {
		Write-Host -Foregroundcolor Yellow "-Invoking command and running remote function ApplyRegistryValue on remote session with values: $registryHive, $keyPath, $keyName, $keyValue, $propertyType"
		$i = Invoke-Command $session -ScriptBlock ${function:ApplyRegistryValue} -ArgumentList $registryHive, $keyPath, $keyName, $keyValue, $propertyType
		#If we are using an IP-Address to communicate with the host we want to registry manipulate, remove the address to list of trusted hosts now since we are done using it:
		if($systemAddress -match '\b(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}\b') {
			$newvalue = ((Get-ChildItem WSMan:\localhost\Client\TrustedHosts).Value).Replace($systemAddress,"")
			Set-Item WSMan:\localhost\Client\TrustedHosts $newvalue -Force -Confirm:$false
		}
		try {
			Remove-PSSession -Session $session -Confirm:$false
		} catch {
			$props["errorID"] = 1.2;
			$props.Add("failedItem", $_.Exception.ItemName);
			$props.Add("errorMessage", @("ERROR: 1.2 Could not terminate remote PowerShell session to systemAddress:" + $_.Exception.Message));
			return new-object PSCustomObject -property $props
		}		
		return $i;
	} catch {
		$props["errorID"] = 1.1;
		$props.Add("failedItem", $_.Exception.ItemName);
		$props.Add("errorMessage", @("ERROR: 1.1 Could not initiate remote PowerShell session to write to registry:" + $_.Exception.Message));
		return new-object PSCustomObject -property $props
	}
}