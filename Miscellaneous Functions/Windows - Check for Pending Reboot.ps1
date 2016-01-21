Function CheckRegKeyExists ($Dir,$KeyName) 
{

	try
    	{
        $CheckIfExists = Get-ItemProperty $Dir $KeyName -ErrorAction SilentlyContinue
        if ((!$CheckIfExists) -or ($CheckIfExists.Length -eq 0))
        {
            return $false
        }
        else
        {
            return $true
        }
    }
    catch
    {
    return $false
    }
	
}

$fileRenameReboot = CheckRegKeyExists "HKLM:\SYSTEM\CurrentControlSet\Control\Session Managezr", PendingFileRenameOperations
$RebootPending = CheckRegKeyExists "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing", RebootPending
$RebootRequired = CheckRegKeyExists "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update", RebootRequired

if ($fileRenameReboot -or $RebootPending -or $RebootRequired)
{
	Write-output "Pending reboot"
}
else
{
	Write-Output "No pending reboot was detected."
}

return;
