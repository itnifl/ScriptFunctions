##Atle Holm - September 2015
##Version 1.0.0
Function Add-ScheduledTask30min {
 <#
    .SYNOPSIS 
		Adds a scheduled task in a Powershell 3.0 that runs every 30 minutes for 1 day, re-triggers every day.
    .EXAMPLE
		Add-ScheduledTask30min -Username "User" -Password "password" -Name "RunBatFile" -Command "C:\Temp\runMe.bat" -WorkDirectory "C:\Temp" -Arguments "turtle snake"
  #>
	param(
		[alias("Username")]
		[Parameter(Mandatory=$True,Position=0)] 
		[string] $usrName,
		[alias("Password")]
		[Parameter(Mandatory=$True,Position=1)] 
		[string] $pswrd,
		[alias("Name")]
		[Parameter(Mandatory=$True,Position=2)] 
		[String] $TaskName,
		[alias("Command")]
		[Parameter(Mandatory=$True,Position=3)] 
		[string] $TaskCommand,
		[alias("WorkDirectory")]
		[Parameter(Mandatory=$True,Position=4)] 
		[string] $WrkDirectory,
		[alias("Arguments")]
		[Parameter(Mandatory=$False,Position=5)] 
		[string] $TaskArg,
		[alias("LogonType")]
		[Parameter(Mandatory=$False,Position=6)] 
		[int] $intLogonType
	)
	
	$ErrorID = "0"
	try {
		<#Won't create a task as planned:
		gcm -Module PSScheduledJobparam
		if ($host.Name -eq "ConsoleHost") {Write-Host -ForeGroundColor Yellow "Creating task $TaskName"}
		$Trigger = New-JobTrigger -Once -At 7am -RepetitionDuration  (New-TimeSpan -Days 3650)  -RepetitionInterval  (New-TimeSpan -Minutes 30)
		$Options =  New-ScheduledJobOption -RunElevated
		if($TaskArgs) {Register-ScheduledJob -Name $TaskName -ScriptBlock { $TaskCommand } -ArgumentList $TaskArgs -Trigger $Trigger -ScheduledJobOption $Options -Credential $creds -confirm:$false}
		else {Register-ScheduledJob -Name $TaskName -ScriptBlock { $TaskCommand } -Trigger $Trigger -ScheduledJobOption $Options -Credential $creds -confirm:$false}#>
		
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
		if(!$intLogonType) { $intLogonType = 1}
		$Principal.LogonType =  $intLogonType
			
		#$Principal.UserId = $runAsUser

		# The time when the task starts, for demonstration purposes we run it 1 minute after we created the task
		$TaskDefinition.RegistrationInfo.Description = "$TaskDescription"
		$TaskDefinition.Settings.Enabled = $true
		$TaskDefinition.Settings.AllowDemandStart = $true
		 
		$TaskStartTime = [datetime]::Now.AddMinutes(60) 
		$triggers = $TaskDefinition.Triggers
		#http://msdn.microsoft.com/en-us/library/windows/desktop/aa383915(v=vs.85).aspx

		$trigger = $triggers.Create(2) # Creates a "Daily" trigger
		$trigger.Enabled = $true
		$trigger.Repetition.Interval = "PT30M"
		$trigger.Repetition.Duration = "P1D"
		$trigger.DaysInterval = 1
		$trigger.StartBoundary = $TaskStartTime.ToString("yyyy-MM-dd'T'HH:mm:ss")
		 
		# http://msdn.microsoft.com/en-us/library/windows/desktop/aa381841(v=vs.85).aspx
		$action = $TaskDefinition.Actions.Create(0)
		$action.Path = "$TaskCommand"
		$action.Arguments = "$TaskArg"
		$action.WorkingDirectory = "$WrkDirectory"
		 
		#http://msdn.microsoft.com/en-us/library/windows/desktop/aa381365(v=vs.85).aspx
		if(!$intLogonType) {$intLogonType=1}
		$rootFolder.RegisterTaskDefinition("$TaskName",$TaskDefinition,6,$usrName,$pswrd,$intLogonType) | out-null
	} catch {
		$ErrorMessage = $_.Exception.Message
		$FailedItem = $_.Exception.ItemName
		$ErrorID = "2"
		$LineNumber = $_.InvocationInfo.ScriptLineNumber;
		$PositionMessage = $_.InvocationInfo.PositionMessage;
		throw @("ErrorID: " + $ErrorID + ", " + $FailedItem + ", " + $ErrorMessage + " " + $LineNumber + " " + $PositionMessage);
	}
}
Function Add-ScheduledTask30minRemotely {
	param(
		[alias("Hostname")] [Parameter(Mandatory=$True,Position=0)] [String] $systemAddress,
		[alias("Username")] [Parameter(Mandatory=$True,Position=1)] [String] $systemUsername,
		[alias("Password")] [Parameter(Mandatory=$True,Position=2)] [String] $systemPassword,
		[alias("Name")]
		[Parameter(Mandatory=$True,Position=3)]
		[String] $TaskName,
		[alias("Command")]
		[Parameter(Mandatory=$True,Position=4)]
		[string] $TaskCommand,
		[alias("WorkDirectory")]
		[Parameter(Mandatory=$True,Position=3)] 
		[string] $WrkDirectory,
		[alias("Arguments")]
		[Parameter(Mandatory=$False,Position=5)]
		[string] $TaskArg
	)
	$props = @{
		errorID = 0;
	}
	if($TaskArg -eq "" -or $TaskArg -eq $null) {
		$TaskArg = ""
	}	
	#If we are using an IP-Address to communicate with the host we want to communicate with
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
		$props.Add("errorMessage", @("ERROR: 1.0 Could not initiate remote PowerShell session to create scheduled task:" + $_.Exception.Message));
		return new-object PSCustomObject -property $props
	}

	try {
		Write-Host -Foregroundcolor Yellow "-Invoking command and running remote function Add-ScheduledTask30min on remote session to create task $TaskName"
		$i = Invoke-Command $session -ScriptBlock ${function:Add-ScheduledTask30min} -ArgumentList $systemUsername, $systemPassword, $TaskName, $TaskCommand, $WrkDirectory, $TaskArg, 3
		#If we are using an IP-Address to communicate with the host we want to communicate with, remove the address to list of trusted hosts now since we are done using it:
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