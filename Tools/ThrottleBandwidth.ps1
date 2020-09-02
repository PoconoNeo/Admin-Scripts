powershell.exe -executionpolicy bypass "New-netqospolicy -Name "HTTP" -IPPort 80 -IPProtocol TCP -ThrottleRateActionBitsPerSecond 1000000KB"
powershell.exe -executionpolicy bypass "New-netqospolicy -Name "HTTPS" -IPPort 443 -IPProtocol TCP -ThrottleRateActionBitsPerSecond 1000000KB"

pause

Remove-NetQosPolicy "HTTPS" -a
Remove-NetQosPolicy "HTTP" -a