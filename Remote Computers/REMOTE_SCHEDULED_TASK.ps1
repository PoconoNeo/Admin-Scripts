######################## CONFIG ########################
# File containing the list of servers
$SERVERS_FILE="servers.txt"
# Script that will be copied to the remote server
$SCRIPT="C:\SCRIPTS\daily_script.bat"
########################################################

$REMOTE_FILE=$SCRIPT -replace ":","$"
$SERVERS=Get-Content $SERVERS_FILE

Foreach ($SERVER in $SERVERS)
{
	If(Test-WSMan -ComputerName $SERVER -EA 0)
	{
        "Configuring the task on server $SERVER..."
        Copy-Item -Path "$SCRIPT" -Destination "\\$SERVER\$REMOTE_FILE"
		Invoke-Command -ComputerName $SERVER -FilePath ".\SCHEDULED_TASK.ps1"
	}
	Else 
	{
		"$SERVER is not available"
	}
}