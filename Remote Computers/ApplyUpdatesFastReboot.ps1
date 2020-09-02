Install-Module -Name PSWindowsUpdate
Import-Module -Name PSWindowsUpdate
Clear-Host
#set-executionpolicy unrestricted
$PendingReboots = Get-Content -Path "RebootList.csv"

ForEach ($c in $PendingReboots) {
    $Target = $C
    Write-Host $Target
    $PSWindowsUpdateLog = "\\$c\c$\PSWindowsUpdate.log"
    $PackageManagement = "\\$c\C$\Windows\System32\WindowsPowerShell\v1.0\Modules"
    if (Test-Path "$PackageManagement\NuGet") { Write-Host "NuGet Module Available" }
    else {
        Write-Host "NuGet Module not available"
        Write-Host "Copying Module NuGet"
        #New-Item -ItemType Directory -Force -Path "$PackageManagement"
        Save-Module -Name NuGet -Path "$PackageManagement"
    }

    if (Test-Path "$PackageManagement\PSWindowsUpdate") { Write-Host "PSWindowsUpdateModule Module Available" }
    else {
        Write-Host "PSWindowsUpdate Module not available"
        Write-Host "Copying Module PSWindowsUpdate"
        Save-Module -Name PSWindowsUpdate -Path $PackageManagement
        #New-Item -ItemType Directory -Force -Path "\\$c\C$\Program Files\PackageManagement"
        #cmd /c copy $SourceLocation $Destination
    }
    
    #invoke-command -ComputerName $c -ScriptBlock {install-module pswindowsupdate -force}
    invoke-command -ComputerName $c -ScriptBlock {Import-Module -Name PSWindowsUpdate -force }
    Do {
        #Reset Timeouts
        $connectiontimeout = 0
        $updatetimeout = 0
    
        #starts up a remote powershell session to the computer
        do {
            $session = New-PSSession -ComputerName $c
            "Connecting Remotely to $c"
            sleep -seconds 10
            $connectiontimeout++
        } until ($session.state -match "Opened" -or $connectiontimeout -ge 10)

        #retrieves a list of available updates

        "Checking for new updates available on $c"

        $updates = invoke-command -session $session -scriptblock { Get-wulist -verbose }

        #counts how many updates are available

        $updatenumber = ($updates.kb).count

        #if there are available updates proceed with installing the updates and then reboot the remote machine

        if ($updates -ne $null) {

            #remote command to install windows updates, creates a scheduled task on remote computer

            invoke-command -ComputerName $c -ScriptBlock { Invoke-WUjob -ComputerName localhost -Script "ipmo PSWindowsUpdate; Install-WindowsUpdate -AcceptAll | Out-File C:\PSWindowsUpdate.log" -Confirm:$false -RunNow }

            #Show update status until the amount of installed updates equals the same as the amount of updates available

            sleep -Seconds 30

            do {
                $updatestatus = Get-Content $PSWindowsUpdateLog

                "Currently processing the following update:"

                Get-Content $PSWindowsUpdateLog | select-object -last 1

                sleep -Seconds 10

                $ErrorActionPreference = "SilentlyContinue"

                $installednumber = ([regex]::Matches($updatestatus, "Installed" )).count

                $Failednumber = ([regex]::Matches($updatestatus, "Failed" )).count

                $ErrorActionPreference = "Continue"

                $updatetimeout++


            }until ( ($installednumber + $Failednumber) -eq $updatenumber -or $updatetimeout -ge 720)

            #restarts the remote computer and waits till it starts up again

            "restarting remote computer"

            #removes schedule task from computer

            invoke-command -computername $c -ScriptBlock { Unregister-ScheduledTask -TaskName PSWindowsUpdate -Confirm:$false }

            # rename update log
            $date = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
            Rename-Item $PSWindowsUpdateLog -NewName "$C-WindowsUpdate-$date.log"

            Restart-Computer -Wait -ComputerName $c -Force

        }


    }until($updates -eq $null)

    #restarts the remote computer and waits till it starts up again

    "Final restarting of remote computer"

    #removes schedule task from computer

    invoke-command -computername $c -ScriptBlock { Unregister-ScheduledTask -TaskName PSWindowsUpdate -Confirm:$false }

    # rename update log
    $date = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
    Rename-Item $PSWindowsUpdateLog -NewName "$C-WindowsUpdate-$date.log"

   # invoke-command -computername $c -ScriptBlock { shutdown /r /f /t 0 }

    "Windows is now up to date on $Target"

}

