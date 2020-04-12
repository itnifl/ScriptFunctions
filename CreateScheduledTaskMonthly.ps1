##Atle Holm - September 2015
##Version 1.0.0
Function Add-ScheduledTaskMonthly {
 <#
    .SYNOPSIS 
		Adds a scheduled task in a Powershell 3.0 environment and runs it once a month at the first day of the month
    .EXAMPLE
		Add-ScheduledTaskMonthly -Name "RunBatFile" -Description "This task runs a batch file" -Command "C:\Temp\runMe.bat" -Arguments "turtle snake"
  #>
	param(
		[alias("Name")]
		[Parameter(Mandatory=$True,Position=0)] 
		[String] $TaskName,
		[alias("Description")]
		[Parameter(Mandatory=$True,Position=1)] 
		[string] $TaskDescription,
		[alias("Command")]
		[Parameter(Mandatory=$True,Position=2)] 
		[string] $TaskCommand,
		[alias("Arguments")]
		[Parameter(Mandatory=$False,Position=3)] 
		[string] $TaskArg,
		[alias("WorkingDirectory")]
		[Parameter(Mandatory=$False,Position=4)]
		[string] $WorkDirectory
	)
		 
	# Attach the Task Scheduler com object
	$service = new-object -ComObject("Schedule.Service")
	# Connect to the local machine. 
	# http://msdn.microsoft.com/en-us/library/windows/desktop/aa381833(v=vs.85).aspx
	$service.Connect()
	$rootFolder = $service.GetFolder("\")
	 
	$TaskDefinition = $service.NewTask(0) 
	$Principal = $TaskDefinition.Principal

	# https://msdn.microsoft.com/en-us/library/windows/desktop/aa382076(v=vs.85).aspx
	$Principal.RunLevel = 1 #TASK_RUNLEVEL_HIGHEST
	# https://msdn.microsoft.com/en-us/library/windows/desktop/aa382075(v=vs.85).aspx
	$Principal.LogonType = 1 #TASK_LOGON_PASSWORD
	#$Principal.UserId = $runAsUser

	# The time when the task starts, for demonstration purposes we run it 1 minute after we created the task
	$TaskDefinition.RegistrationInfo.Description = "$TaskDescription"
	$TaskDefinition.Settings.Enabled = $true
	$TaskDefinition.Settings.AllowDemandStart = $true
	 
	$TaskStartTime = [datetime]::Now.AddMinutes(1) 
	$triggers = $TaskDefinition.Triggers
	#http://msdn.microsoft.com/en-us/library/windows/desktop/aa383915(v=vs.85).aspx
	$trigger = $triggers.Create(4) # Creates a "Monthly" trigger
	$trigger.Enabled = $true
	$trigger.DaysOfMonth = 1
	$trigger.StartBoundary = $TaskStartTime.ToString("yyyy-MM-dd'T'HH:mm:ss")
	 
	# http://msdn.microsoft.com/en-us/library/windows/desktop/aa381841(v=vs.85).aspx
	$action = $TaskDefinition.Actions.Create(0)
	$action.Path = "$TaskCommand"
	$action.Arguments = "$TaskArg"
	$action.WorkingDirectory = "$WorkDirectory"
	 
	#http://msdn.microsoft.com/en-us/library/windows/desktop/aa381365(v=vs.85).aspx
	$rootFolder.RegisterTaskDefinition("$TaskName",$TaskDefinition,6,"System",$null,5) | out-null
}
Function Add-ScheduledTaskMonthlyRemotely {
	param(
		[alias("Hostname")] [Parameter(Mandatory=$True,Position=0)] [String] $systemAddress,
		[alias("Username")] [Parameter(Mandatory=$True,Position=1)] [String] $systemUsername,
		[alias("Password")] [Parameter(Mandatory=$True,Position=2)] [String] $systemPassword,
		[alias("Name")]
		[Parameter(Mandatory=$True,Position=3)]
		[String] $TaskName,
		[alias("Description")]
		[Parameter(Mandatory=$True,Position=4)]
		[string] $TaskDescription,
		[alias("Command")]
		[Parameter(Mandatory=$True,Position=5)]
		[string] $TaskCommand,
		[alias("Arguments")]
		[Parameter(Mandatory=$False,Position=6)]
		[string] $TaskArg,
		[alias("WorkingDirectory")]
		[Parameter(Mandatory=$False,Position=4)]
		[string] $WorkDirectory
	)
	$props = @{
		errorID = 0;
	}
		
	#If we are using an IP-Address to communicate with the host we want to communicate with
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
		$props.Add("errorMessage", @("ERROR: 1.0 Could not initiate remote PowerShell session to create scheduled task:" + $_.Exception.Message));
		return new-object PSCustomObject -property $props
	}

	try {
		Write-Host -Foregroundcolor Yellow "-Invoking command and running remote function Add-ScheduledTaskMonthly on remote session"
		$i = Invoke-Command $session -ScriptBlock ${function:Add-ScheduledTaskMonthly} -ArgumentList $TaskName, $TaskDescription, $TaskCommand, $TaskArg, $WorkDirectory
		#If we are using an IP-Address to communicate with the host we want to rcommunicate with, remove the address to list of trusted hosts now since we are done using it:
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
		$props.Add("errorMessage", @("ERROR: 1.1 Could not initiate remote PowerShell session to create scheduled task:" + $_.Exception.Message));
		return new-object PSCustomObject -property $props
	}
}