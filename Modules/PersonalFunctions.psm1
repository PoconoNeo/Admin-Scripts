# -------------------------------------------
# Function Name: p
# Test if a computer is online (quick ping replacement)
# -------------------------------------------
function p {
    param($computername)
    return (test-connection $computername -count 1 -quiet)
}

# -------------------------------------------
# Function Name: Get-LoggedIn
# Return the current logged-in user of a remote machine.
# -------------------------------------------
function Get-LoggedIn {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$True)]
    [string[]]$computername
  )

  foreach ($pc in $computername){
    $logged_in = (gwmi win32_computersystem -COMPUTER $pc).username
    $name = $logged_in.split("\")[1]
    "{0}: {1}" -f $pc,$name
  }
}

# -------------------------------------------
# Function Name: Get-Uptime
# Calculate and display system uptime on a local machine or remote machine.
# TODO: Fix multiple computer name / convertdate errors when providing more
# than one computer name.
# -------------------------------------------
function Get-Uptime {
    [CmdletBinding()]
    param (
        [string]$ComputerName = 'localhost'
    )
    
    foreach ($Computer in $ComputerName){
        $pc = $computername
        $os = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $computername
        $diff = $os.ConvertToDateTime($os.LocalDateTime) - $os.ConvertToDateTime($os.LastBootUpTime)

        $properties=@{
            'ComputerName'=$pc;
            'UptimeDays'=$diff.Days;
            'UptimeHours'=$diff.Hours;
            'UptimeMinutes'=$diff.Minutes
            'UptimeSeconds'=$diff.Seconds
        }
        $obj = New-Object -TypeName PSObject -Property $properties

        Write-Output $obj
    }
       
 }

# -------------------------------------------
# Function Name: Get-HWVersion
# Retreives device name, driver date, and driver version
# -------------------------------------------
function Get-HWVersion($computer, $name) {

     $pingresult = Get-WmiObject win32_pingstatus -f "address='$computer'"
     if($pingresult.statuscode -ne 0) { return }

     gwmi -Query "SELECT * FROM Win32_PnPSignedDriver WHERE DeviceName LIKE '%$name%'" -ComputerName $computer | 
           Sort DeviceName | 
           Select @{Name="Server";Expression={$_.__Server}}, DeviceName, @{Name="DriverDate";Expression={[System.Management.ManagementDateTimeconverter]::ToDateTime($_.DriverDate).ToString("MM/dd/yyyy")}}, DriverVersion
}

function Global:Ping-IPRange {
  <#
  .SYNOPSIS
      Sends ICMP echo request packets to a range of IPv4 addresses between two given addresses.

  .DESCRIPTION
      This function lets you sends ICMP echo request packets ("pings") to 
      a range of IPv4 addresses using an asynchronous method.

      Therefore this technique is very fast but comes with a warning.
      Ping sweeping a large subnet or network with many swithes may result in 
      a peak of broadcast traffic.
      Use the -Interval parameter to adjust the time between each ping request.
      For example, an interval of 60 milliseconds is suitable for wireless networks.
      The RawOutput parameter switches the output to an unformated
      [System.Net.NetworkInformation.PingReply[]].

  .INPUTS
      None
      You cannot pipe input to this funcion.

  .OUTPUTS
      The function only returns output from successful pings.

      Type: System.Net.NetworkInformation.PingReply

      The RawOutput parameter switches the output to an unformated
      [System.Net.NetworkInformation.PingReply[]].

  .NOTES
      Author  : G.A.F.F. Jakobs
      Created : August 30, 2014
      Version : 6

  .EXAMPLE
      Ping-IPRange -StartAddress 172.30.165.1 -EndAddress 172.30.165.254 -Interval 20

      IPAddress                                 Bytes                     Ttl           ResponseTime
      ---------                                 -----                     ---           ------------
      172.30.165.41                                 32                      64                    371
      172.30.165.57                                 32                     128                      0
      172.30.165.64                                 32                     128                      1
      172.30.165.63                                 32                      64                     88
      172.30.165.254                                32                      64                      0

      In this example all the ip addresses between 172.30.165.1 and 172.30.165.254 are pinged using 
      a 20 millisecond interval between each request.
      All the addresses that reply the ping request are listed.

  .LINK
      http://gallery.technet.microsoft.com/Fast-asynchronous-ping-IP-d0a5cf0e

  #>
  [CmdletBinding(ConfirmImpact='Low')]
  Param(
      [parameter(Mandatory = $true, Position = 0)]
      [System.Net.IPAddress]$StartAddress,
      [parameter(Mandatory = $true, Position = 1)]
      [System.Net.IPAddress]$EndAddress,
      [int]$Interval = 30,
      [Switch]$RawOutput = $false
  )

  $timeout = 2000

  function New-Range ($start, $end) {

      [byte[]]$BySt = $start.GetAddressBytes()
      [Array]::Reverse($BySt)
      [byte[]]$ByEn = $end.GetAddressBytes()
      [Array]::Reverse($ByEn)
      $i1 = [System.BitConverter]::ToUInt32($BySt,0)
      $i2 = [System.BitConverter]::ToUInt32($ByEn,0)
      for($x = $i1;$x -le $i2;$x++){
          $ip = ([System.Net.IPAddress]$x).GetAddressBytes()
          [Array]::Reverse($ip)
          [System.Net.IPAddress]::Parse($($ip -join '.'))
      }
  }
  
  $IPrange = New-Range $StartAddress $EndAddress

  $IpTotal = $IPrange.Count

  Get-Event -SourceIdentifier "ID-Ping*" | Remove-Event
  Get-EventSubscriber -SourceIdentifier "ID-Ping*" | Unregister-Event

  $IPrange | foreach{

      [string]$VarName = "Ping_" + $_.Address

      New-Variable -Name $VarName -Value (New-Object System.Net.NetworkInformation.Ping)

      Register-ObjectEvent -InputObject (Get-Variable $VarName -ValueOnly) -EventName PingCompleted -SourceIdentifier "ID-$VarName"

      (Get-Variable $VarName -ValueOnly).SendAsync($_,$timeout,$VarName)

      Remove-Variable $VarName

      try{

          $pending = (Get-Event -SourceIdentifier "ID-Ping*").Count

      }catch [System.InvalidOperationException]{}

      $index = [array]::indexof($IPrange,$_)
  
      Write-Progress -Activity "Sending ping to" -Id 1 -status $_.IPAddressToString -PercentComplete (($index / $IpTotal)  * 100)

      Write-Progress -Activity "ICMP requests pending" -Id 2 -ParentId 1 -Status ($index - $pending) -PercentComplete (($index - $pending)/$IpTotal * 100)

      Start-Sleep -Milliseconds $Interval
  }

  Write-Progress -Activity "Done sending ping requests" -Id 1 -Status 'Waiting' -PercentComplete 100 

  While($pending -lt $IpTotal){

      Wait-Event -SourceIdentifier "ID-Ping*" | Out-Null

      Start-Sleep -Milliseconds 10

      $pending = (Get-Event -SourceIdentifier "ID-Ping*").Count

      Write-Progress -Activity "ICMP requests pending" -Id 2 -ParentId 1 -Status ($IpTotal - $pending) -PercentComplete (($IpTotal - $pending)/$IpTotal * 100)
  }

  if($RawOutput){
      
      $Reply = Get-Event -SourceIdentifier "ID-Ping*" | ForEach { 
          If($_.SourceEventArgs.Reply.Status -eq "Success"){
              $_.SourceEventArgs.Reply
          }
          Unregister-Event $_.SourceIdentifier
          Remove-Event $_.SourceIdentifier
      }
  
  }else{

      $Reply = Get-Event -SourceIdentifier "ID-Ping*" | ForEach { 
          If($_.SourceEventArgs.Reply.Status -eq "Success"){
              $_.SourceEventArgs.Reply | select @{
                    Name="IPAddress"   ; Expression={$_.Address}},
                  @{Name="Bytes"       ; Expression={$_.Buffer.Length}},
                  @{Name="Ttl"         ; Expression={$_.Options.Ttl}},
                  @{Name="ResponseTime"; Expression={$_.RoundtripTime}}
          }
          Unregister-Event $_.SourceIdentifier
          Remove-Event $_.SourceIdentifier
      }
  }
  if($Reply -eq $Null){
      Write-Verbose "Ping-IPrange : No ip address responded" -Verbose
  }
$Results = $Reply

  return $Reply | export-csv -path "C:\Users\borddaus\OneDrive - B. Braun\Powershell_Scripts\Ping\PingOutput.csv" -NoTypeInformation
}
write-host $Results | FT