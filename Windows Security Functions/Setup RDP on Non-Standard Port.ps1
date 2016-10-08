Function Configure-RDPListenerPort {
    <#
    .SYNOPSIS
      The purpose of this function is to:

        1. Modify the port which the local RDP service listens on
        
        2. Create a Windows Firewall entry to allow $NewPortNumber inbound
            
            - NOTE: this requires the New-NetFilewallRule cmdlet 

      If the function is successful, once the machine is rebooted, RDP will
      be listening on the newly configured port. You'll need to make sure that other
      network firewalls are allowing traffic to this host too, of course.


    .DESCRIPTION
      Modifies the port RDP is listening to on the local machine. Used for
      Windows 8.1 / Server 2012 +

      .PARAMETER $NewRDPPort 
        A required integer value. Represents the port that RDP should begin listening on
        
    .INPUTS
      Integer value - $NewRDPPortPort number for RDP to run on.
    .OUTPUTS
      Boolean value - returns $true if successful or $false if unsuccessful.
    .NOTES
      Version:        1.0
      Author:         Marcus Bastian
      Creation Date:  10/8/2016 
      Purpose/Change: Initial creation of a script.
      
    .EXAMPLE
      Configure-RDPListenerPort -PortNumber 3391
    #>

    Param(
        [Parameter(Mandatory=$true)][int]$NewRDPPort
    )

    $PathRDPPort_Regkey = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp";
    
    # Make sure that the reg key exists before proceeding
    if(-not $(test-path $PathRDPPort_Regkey))
    {
        Write-Error "Failed to locate RDP port number registry value under key: $PathRDPPort_Regkey. Port not changed."
        return $false
    }

    # Ensure New-NetFirewallRule cmdlet is installed
    if(-not (get-command New-NetFirewallRule))
    {
        Write-Error "Failed to locate 'New-NetFirewallRule' cmdlet in PowerShell. Cannot proceed."
        return $false
    }

    # Found reg key. Update value now.
    Set-ItemProperty $PathRDPPort_Regkey -Name 'PortNumber' -Value $NewRDPPort

    if($(get-ItemProperty -Path $PathRDPPort_Regkey -Name 'PortNumber').PortNumber -eq $NewRDPPort)
    {
        Write-verbose "Successfully changed RDP port number. Adding Windows Firewall rule next."
    } else {
        Write-Error "Failed to change RDP port number registry key."
        return $false
    }

    # Build parameters object for New-NetFirewallRule function
    $parameterObject = @{
        Name = 'Rdp-Non-Standard-Port'
        DisplayName = 'RDP-Non-Standard-Port'
        Enabled = 'True'
        Profile = 'Any'
        Direction = 'Inbound'
        Action = 'Allow'
        Protocol = 'TCP'
        LocalPort = $NewRDPPort
        Program = "%SystemRoot%\system32\svchost.exe"
    }

    # Create inbound rule for newly configured port
    New-NetFirewallRule @parameterObject -ev createErrors

    if($createErrors -ne $null)
    {
        write-error "Failed to create Windows firewall rule to allow inbound port $NewRDPPort."
        return $false;
    } else {
        write-verbose "Successfully created firewall rule. Ready for reboot."
        return $true;
    }
}





