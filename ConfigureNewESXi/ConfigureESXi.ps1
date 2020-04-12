## * Uplinks begge aktive på vswitch
## * Enable vmotion på mgmt-nett
## * Sett NTP
## * Enable syslog out på security settings firewall
## * Advanced Mem.AllocLargePage=0
## * Chk Advanced Syslog/global udp://syslog01:514

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
Function LogOn {
	param(
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias("Host")]
		[string]$Server,
		[Parameter(Mandatory = $True, Position = 1)]
		[Alias("Username")]
		[string]$ESXiUsername,
		[Parameter(Mandatory = $True, Position = 2)]
		[Alias("Password")]
		[string]$ESXiPassword
	)
	if ($Global:server -eq $null) {
		$Global:server = $Server
		$Global:username = $ESXiUsername
		$Global:password = $ESXiPassword
		$connection = $null
		try {                                     
			$connection = Connect-VIServer -server $Global:server -user $Global:username -password $Global:password
			if($connection -eq $null -or ($connection -ne $null -and $connection.IsConnected -eq $false)) {
						   $Global:server = $null;
			}
		} catch {                                            
			$item = $_.Exception.ItemName;
			$message = $_.Exception.Message;                                      
		} finally {
			if($connection -eq $null -or ($connection -ne $null -and $connection.IsConnected -eq $false)) {
			   $Global:server = $null;
			}
		}
    }
}

function ActivateUplinks {
	param(
		[Parameter(Mandatory = $True, Position = 0)]
		[Alias("ESXi")]
		[String]$strESXi
	)
	
}

function Start-ESXiConfig {
	##########################################################################################
	# Add PowerShell snapins for PowerCLI if they are not already loaded
	##########################################################################################
	if(-not (Get-PSSnapin VMware.VimAutomation.Core 2> $NULL)) { 
		Add-pssnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue | out-null
	}             
	if(-not (Get-PSSnapin VMware.VimAutomation.Vds 2> $NULL)) { 
		Add-PSSnapin VMware.VimAutomation.Vds -ErrorAction SilentlyContinue | out-null
	}             
	if(-not (Get-PSSnapin VMware.VimAutomation.License -ErrorAction SilentlyContinue 2> $NULL)) { 
		Add-PSSnapin VMware.VimAutomation.License -ErrorAction SilentlyContinue | out-null
	}             
	if(-not (Get-PSSnapin VMware.ImageBuilder 2> $NULL)) { 
		Add-PSSnapin VMware.ImageBuilder -ErrorAction SilentlyContinue | out-null
	}             
	if(-not (Get-PSSnapin VMware.DeployAutomation 2> $NULL)) { 
		Add-PSSnapin VMware.DeployAutomation -ErrorAction SilentlyContinue | out-null
	}

   #Set-Item wsman:localhost\Shell\MaxMemoryPerShellMB 2048 -Force
   Set-PowerCLIConfiguration -DisplayDeprecationWarnings $false -Confirm:$false | out-null


	$strAddress = Read-Host "Enter ESXi or vCenter address"
	$strUsername = Read-Host "Enter ESXi or vCenter username"
	$strPassword = Read-Host "Enter ESXi or vCenter password"
	$strESXi = Read-Host "Enter name or address of ESXi server to configure"
	LogOn -Host $strAddress -Username $strUsername -Password $strPassword
	
	#Enable All uplinks on virtual switch
	#$strESXi = "vm05"
	$StandbyNics = (Get-VirtualSwitch -VMHost $strESXi -Name vSwitch0 | Get-NICTeamingPolicy).StandbyNic	
	foreach($StandbyNic in $StandbyNics) {
		Get-VirtualSwitch -VMHost $strESXi -Name vSwitch0 | Get-NICTeamingPolicy | Set-NICTeamingPolicy -MakeNicActive $StandbyNic
	}
	
	#Enable All uplinks on port management network
	$StandbyNics = (Get-VirtualPortGroup -VMHost $strESXi -Name Management* | Get-NICTeamingPolicy).StandbyNic	
	foreach($StandbyNic in $StandbyNics) {
		Get-VirtualPortGroup -VMHost $strESXi -Name Management* | Get-NICTeamingPolicy | Set-NICTeamingPolicy -MakeNicActive $StandbyNic
	}
	
	#Enable vMotion
	Get-VMHost $strESXi | Get-VMHostNetworkAdapter -vmkernel | Set-VmHostNetworkAdapter -VmotionEnabled $true -Confirm:$false
	#Disable IPv6
	#Get-VMHost $strESXi | Get-VMHostNetworkAdapter -vmkernel | Set-VmHostNetworkAdapter -AutomaticIPv6 $false -Confirm:$false -ErrorAction 'SilentlyContinue'
	#Set the NTP server
	Get-VMHost $strESXi | Add-VmHostNTPServer -NTPServer "ntpvmware.dada.dudu.edu" -ErrorAction SilentlyContinue
	#Start the NTP server service
	Get-VmHostService -VMHost $strESXi | Where-Object {$_.key -eq "ntpd"} | Start-VMHostService
	#Set the NTP server service to autostart on boot
	Get-VmHostService -VMHost $strESXi | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "automatic"
	#Set the Syslog server
	Get-VMHost $strESXi | Set-VMHostSysLogServer -SyslogServer "syslog01:514"
	#Enable syslog out in the firewall
	Get-VMHostFirewallException -VMHost $strESXi | where {$_.Name -eq "syslog"} | Set-VMHostFirewallException -Enabled:$true
	#Set Advanced Mem.AllocGuestLargePage=0
	Set-VMHostAdvancedConfiguration -VMHost (Get-VMHost $strESXi) -Name Mem.AllocGuestLargePage -Value 0	
    Disconnect-VIserver -Confirm:$false
    $Global:server = $null
}

Start-ESXiConfig