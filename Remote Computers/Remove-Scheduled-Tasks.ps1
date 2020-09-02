Clear-Host
$LogFile = "SchdTasksRemove.log"
$servers = get-content "SchdTasksRemove.txt"
foreach ($server in $servers)
{
 #Unregister-ScheduledTask -CimSession $server -TaskName "WSUS Check-in" -Confirm:$false -WhatIf
 Unregister-ScheduledTask -CimSession $server -TaskName "WSUS Check-in" -Confirm:$false
}
