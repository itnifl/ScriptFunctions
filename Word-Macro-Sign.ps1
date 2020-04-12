Add-Type -AssemblyName "System.Windows.Forms"
Add-Type -AssemblyName "Microsoft.VisualBasic"

$Word = New-Object -ComObject Word.Application
$Word.Visible = $true
Start-Sleep -MilliSeconds 1000
$WordProcess = Get-Process -Name 'winword'
[Microsoft.VisualBasic.Interaction]::AppActivate($WordProcess.Id)
Start-Sleep -MilliSeconds 500
[System.Windows.Forms.SendKeys]::SendWait('%{F11}')
Start-Sleep -MilliSeconds 500
[System.Windows.Forms.SendKeys]::SendWait('%{T}{D}')