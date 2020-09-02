Clear-Host
Get-ADComputer -Filter "OperatingSystem -like 'Windows*'" -Properties OperatingSystem | group operatingsystem | sort name

## This could be Active Directory, a text file, a SQL database, whatever
$PendingReboots = Get-Content -Path "RebootList.csv"

foreach ($c in $PendingReboots) {
    try {
        $session = New-PSSession -ComputerName $c
        $icmParams = @{
            Session = $session
        }
        $output = @{
            ComputerName = $c
        }
        ## In case they're running Powerhell v3
        $icmParams.ScriptBlock = { $env:PSModulePath; [Environment]::GetEnvironmentVariable("PSModulePath", "Machine") }
        $output.PSModulePath = (Invoke-Command @icmParams) -split ';' | Select-Object -Unique | Sort-Object

        ## Grab the existing version
        $icmParams.ScriptBlock = { $PSVersionTable.BuildVersion.ToString() }
        $output.PSModulePath = Invoke-Command @icmParams

        ## Check .NET Framework 4.5.2
        if (Get-ChildItem -Path "\\$c\c$\windows\Microsoft.NET\Framework" -Directory | Where-Object { $_.Name -match '^v4.5.2.*' }) {
            $output.DotNetGood = $true
        }
        else {
            $output.DotNetGood = $false
        }
        [pscustomobject]$output
    }
    catch {

    }
    finally {
        Remove-PSSession -Session $session -ErrorAction Ignore
    }
}