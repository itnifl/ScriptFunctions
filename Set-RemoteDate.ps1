##Atle Holm - September 2015
##Version 1.0.0
Function Set-RemoteDate {
 <#
    .SYNOPSIS 
		Sets date and time on a remote Windows System via a Powershell session
    .EXAMPLE
		Set-RemoteDate -Address "address" -Username "administrator" -Password "123pass" -DateString "17/11/2011 5:35:25 PM"
  #>
	param(
		[alias("Address")] [Parameter(Mandatory=$True,Position=0)] [String] $systemAddress,
		[alias("Username")] [Parameter(Mandatory=$True,Position=1)] [String] $systemUsername,
		[alias("Password")] [Parameter(Mandatory=$True,Position=2)] [String] $systemPassword,
		[alias("DateString")]
		[Parameter(Mandatory=$True,Position=3)]
		[String] $dString,
		[alias("TimeZone")]
		[Parameter(Mandatory=$False,Position=4)]
		[String] $tZone
	)
	$props = @{
		errorID = 0;
	}
		
	#If we are using an IP-Address to communicate with the host we want to registry manipulate, add the address to list of trusted hosts:
	if($systemAddress -match '\b(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}\b') {
		#Write-Host -Foregroundcolor Yellow "-Adding $systemAddress to list of trusted hosts"
		set-item wsman:\localhost\Client\TrustedHosts -value $systemAddress -Force -Confirm:$false
	}
	function Set-TimeZoneRemote { 
		param( 
			[parameter(Mandatory=$true)] 
			[string]$TimeZone 
		) 
		 
		$osVersion = (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").GetValue("CurrentVersion") 
		$proc = New-Object System.Diagnostics.Process 
		$proc.StartInfo.WindowStyle = "Hidden" 
	 
		if ($osVersion -ge 6.0) 
		{ 
			# OS is newer than XP 
			$proc.StartInfo.FileName = "tzutil.exe" 
			$proc.StartInfo.Arguments = "/s `"$TimeZone`"" 
		} 
		else 
		{ 
			# XP or earlier 
			$proc.StartInfo.FileName = $env:comspec 
			$proc.StartInfo.Arguments = "/c start /min control.exe TIMEDATE.CPL,,/z $TimeZone" 
		} 
		$proc.Start() | Out-Null 
	}
	try {
		Write-Host -Foregroundcolor Yellow "-Creating PowerShell remote session to $systemAddress"
		$securePassword = ConvertTo-SecureString -String $systemPassword -AsPlainText -Force
		$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $SystemUsername, $securePassword
		$session = New-PSSession -Credential $cred -ComputerName $systemAddress
	} catch {
		$props["errorID"] = 1.0;
		$props.Add("failedItem", $_.Exception.ItemName);
		$props.Add("errorMessage", @("ERROR: 1.0 Could not initiate remote PowerShell session to create scheduled task:" + $_.Exception.Message));
		return new-object PSCustomObject -property $props
	}
	function Set-RemoteDate { 
		param( 
			[parameter(Mandatory=$true)] 
			[System.DateTime]$RemoteDate 
		) 
		Set-Date -Date $RemoteDate -Confirm:$false
	}
	try {
		Write-Host -Foregroundcolor Yellow "-Creating PowerShell remote session to $systemAddress"
		$securePassword = ConvertTo-SecureString -String $systemPassword -AsPlainText -Force
		$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $SystemUsername, $securePassword
		$session = New-PSSession -Credential $cred -ComputerName $systemAddress
	} catch {
		$props["errorID"] = 1.3;
		$props.Add("failedItem", $_.Exception.ItemName);
		$props.Add("errorMessage", @("ERROR: 1.0 Could not initiate remote PowerShell session to create scheduled task:" + $_.Exception.Message));
		return new-object PSCustomObject -property $props
	}

	try {
		Write-Host -Foregroundcolor Yellow "-Invoking command and running Set-Date on remote session"	
		if($tZone) {
			Write-Host -Foregroundcolor Yellow "-Invoking command and running remote function Set-TimeZoneRemote on remote session with argument $tZone"
			$i = Invoke-Command $session -ScriptBlock ${function:Set-TimeZoneRemote} -ArgumentList $tZone
		}
		if($dString -ne "NA") {
			Write-Host -Foregroundcolor Yellow "-Invoking command and running remote function Set-RemoteDate on remote session with argument $dString"
			$i = Invoke-Command $session -ScriptBlock ${function:Set-RemoteDate} -ArgumentList (Get-Date $dString)
		}
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
			$props.Add("errorMessage", @("ERROR: 1.2 Could not terminate remote PowerShell session to systemAddress: " + $_.Exception.Message));
			return new-object PSCustomObject -property $props
		}		
		return $i;
	} catch {
		$props["errorID"] = 1.1;
		$props.Add("failedItem", $_.Exception.ItemName);
		$props.Add("LineNumber",  @("At line: " + $_.InvocationInfo.ScriptLineNumber));
		$props.Add("PositionMessage",  @($_.InvocationInfo.PositionMessage));
		$props.Add("errorMessage", @("ERROR: 1.1 Could not initiate remote PowerShell session to create scheduled task: " + $_.Exception.Message));
		return new-object PSCustomObject -property $props
	}
}