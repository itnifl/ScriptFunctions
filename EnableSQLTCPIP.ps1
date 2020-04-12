function EnableSqlTCPIP {
 <#
    .SYNOPSIS 
		Enables TCP IP on a SQL server instance on a remote machine via PowerShell Remote Session
    .EXAMPLE
		EnableSqlTCPIP -Hostname $deploymentIP -Username ".\Administrator" -Password "123" -InstanceName "SQLEXPRESS"
  #>
	param(
		[alias("Hostname")] [Parameter(Mandatory=$True,Position=0)] [String] $systemAddress,
		[alias("Username")] [Parameter(Mandatory=$True,Position=1)] [String] $systemUsername,
		[alias("Password")] [Parameter(Mandatory=$True,Position=2)] [String] $systemPassword,
		[alias("InstanceName")] [Parameter(Mandatory=$True,Position=3)] [String] $enableInstanceName
	)
	
	$props = @{
		errorID = 0;
	}

	function EnableTCPIP {
		param(
			[Parameter(Mandatory = $True, Position = 0)]
			[Alias("InstanceName")]
			[String]$strInstanceName
		)
		# Load the assemblies
		[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
		[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")

		$smo = 'Microsoft.SqlServer.Management.Smo.'
		$wmi = new-object ($smo + 'Wmi.ManagedComputer').

		# List the object properties, including the instance names.
		$Wmi

		# Enable the TCP protocol on the default instance.
		$uri = "ManagedComputer[@Name='" + (get-item env:\computername).Value + "']/ServerInstance[@Name='$strInstanceName']/ServerProtocol[@Name='Tcp']"
		$Tcp = $wmi.GetSmoObject($uri)
		Write-Host -Foregroundcolor Yellow @("Enabling TCP/IP on " + (get-item env:\computername).Value + "/$strInstanceName.")
		$Tcp.IsEnabled = $true
		$Tcp.Alter()
		$Tcp
		Write-Host -Foregroundcolor Yellow "Restarting service MSSQL`$$strInstanceName for changes to take effect."
		(Restart-Service "MSSQL`$$strInstanceName" -Force | out-null) 2> $null > $null
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
		$props.Add("errorMessage", @("ERROR: 1.0 Could not initiate remote PowerShell session to enable tcp/ip on SQL instance:" + $_.Exception.Message));
		return new-object PSCustomObject –property $props
	}

	try {
		Write-Host -Foregroundcolor Yellow "-Invoking command and running remote function EnableTCPIP on remote session with values: $enableInstanceName"		
		$i = Invoke-Command $session -ScriptBlock ${function:EnableTCPIP} -ArgumentList $enableInstanceName
				
		#We are dobe, remove from trusted hosts:
		if($systemAddress -match '\b(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}\b') {
			$newvalue = ((Get-ChildItem WSMan:\localhost\Client\TrustedHosts).Value).Replace($systemAddress,"")
			Set-Item WSMan:\localhost\Client\TrustedHosts $newvalue -Force -Confirm:$false
		}
		try {
			Remove-PSSession -Session $session -Confirm:$false
		} catch {
			$props["errorID"] = 1.2;
			$props.Add("failedItem", $_.Exception.ItemName);
			$props.Add("errorMessage", @("ERROR: 1.2 Could not terminate remote PowerShell session to $systemAddress :" + $_.Exception.Message));
			return new-object PSCustomObject -property $props
		}		
		return $i;
	} catch {
		$props["errorID"] = 1.1;
		$props.Add("failedItem", $_.Exception.ItemName);
		$props.Add("errorMessage", @("ERROR: 1.1 Could not initiate remote PowerShell session to enable tcp/ip on SQL instance:" + $_.Exception.Message));
		return new-object PSCustomObject -property $props
	}
}