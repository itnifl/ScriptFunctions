##Atle Holm - September 2015
##Version 1.0.0
param(
	[Parameter(Mandatory = $True)]
	[Alias("IP")]
	[Net.IPAddress]$IPAddress,
	[Parameter(Mandatory = $True)]
	[Alias("Mask")]
	[Net.IPAddress]$SubnetMask,
	[Parameter(Mandatory = $True)]
	[Alias("Gateway")]
	[Net.IPAddress]$GW,
	[Parameter(Mandatory = $True)]
	[Alias("MACTarget")]
	[ValidatePattern("^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$")]
	[String]$MACAddress		
)
$executionProperties = @{
	errorID = 0;
}	
try {
	$store="persistent"
	$ethernetName=(get-wmiobject win32_networkadapter | where-object {$_.MACAddress -like $MACAddress}).NetConnectionID
	if($GW.IpAddressToString -eq "254.254.254.254") { #Interpreted as no gateway
		netsh interface ip set address "$ethernetName" source=static address=$IPAddress mask=$SubnetMask store=$store
	} else {
		netsh interface ip set address "$ethernetName" source=static address=$IPAddress mask=$SubnetMask gateway=$GW store=$store
	}
} 	catch {
	$props["errorID"] = 1;
	$props.Add("failedItem", $_.Exception.ItemName);
	$props.Add("errorMessage", @("ERROR: 1 Could not set IP on specified system,: " + $_.Exception.Message));
	return $props	
}
