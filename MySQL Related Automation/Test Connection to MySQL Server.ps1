<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2015 v4.2.89
	 Created on:   	8/5/2015 1:00 PM
	 Created by:   	Marcus Bastian
	 Filename:     	Test Connection to MySQL Server.ps1
	===========================================================================
	.DESCRIPTION
		A PowerShell script that downloads MySql.exe and tests connectivity to the specified
        MySQL host. 

        $args[0] to PS1 = MySQL Host
        $args[1] to PS1 = MySQL User
        $args[2] to PS1 = MySQL Pass
#>
cls
$ErrorActionPreference  = 'silentlycontinue';
$FilePathMySQLErr = "$env:windir\temp\mysqlconnecterrors.txt";

Remove-Item $FilePathMySQLErr -Force

$global:mysqlConnectionErrors = $false;

Function Test-MySQLConnection
{
	<#
	.SYNOPSIS
		This function will use the provided:
		
		MySQL host
		MySQL user
		MySQL password
		
		to make a MySQL connection to the requested MySQL instance. Should everything work as expected, $true will be returned.
		
#>
	param
	(
	[Parameter(Mandatory = $false, Position = 0)]
	[string]$mysqlUser,
	[Parameter(Mandatory = $false, Position = 1)]
	[String]$mysqlPass,
	[Parameter(Mandatory = $false, Position = 2)]
	[string]$mysqlHost,
	[Parameter(Mandatory = $false, Position = 3)]
	[string]$mysqlPath
	)
	
	if (-not (Test-Path "$mysqlPath\mysql.exe"))
	{
		return "Invalid MySQL path";
	}
	$ErrorActionPreference = 'Continue';
	$MySQLResult = . $mysqlPath\mysql.exe --user="$MySQLUser" --password="$MySQLPass" --host="$mysqlHost" -N -B information_schema -e "select concat('Successfully Connected: ',count(*)) from Tables" 2>&1
	
	$ErrorActionPreference = 'silentlycontinue';
	#$err = Get-Content -ea SilentlyContinue -Path stderr.txt
	
	if ($MySQLResult -like '*Successfully Connected*')
	{
		return $true;
	}
	else
	{
		#bubble up the error to 
		$global:mysqlConnectionErrors = $MySQLResult;
		Set-Content $filePathMySQLErr $MySQLResult
		ii $env:windir\temp\mysqlconnecterrors.txt 
		return $false;
	}
	
}

Function Zip-Actions
{
       <#
       .SYNOPSIS
              A function to zip or unzip files.
       
       .DESCRIPTION
              This function has 3 possible uses.
              1) Zip a folder or files and save the zip to specified location.
              2) Unzip a zip file to a specified folder.
              3) Unzip a zip file and delete the original zip when complete.       
      
 
       .PARAMETER ZipPath
              The full path of the file to unzip or the full path of the zip file to be created.
       
       .PARAMETER FolderPath
              The path to the files to zip or the path to the directory to unzip the files to.
       
       .PARAMETER Unzip
              If $true the function will perform an unzip instead of a zip
       
       .PARAMETER DeleteZip
              If set to $True the zip file will be removed at then end of the unzip operation.
       
       .EXAMPLE
              PS C:\> Zip-Actions -ZipPath 'C:\Windows\Temp\ziptest.zip' -FolderPath 
              PS C:\> Zip-Actions -ZipPath 'C:\Windows\Temp\ziptest.zip' -FolderPath 'C:\Windows\Temp\ZipTest' -Unzip $true
              PS C:\> Zip-Actions -ZipPath 'C:\Windows\Temp\ziptest.zip' -FolderPath 'C:\Windows\Temp\ZipTest' -Unzip $true -DeleteZip $True

       
       .NOTES
              Additional information about the function.
#>
       
       [CmdletBinding(DefaultParameterSetName = 'Zip')]
       param
       (
              [Parameter(ParameterSetName = 'Unzip')]
              [Parameter(ParameterSetName = 'Zip',
                              Mandatory = $true,
                              Position = 0)]
              [ValidateNotNull()]
              [string]$ZipPath,
              [Parameter(ParameterSetName = 'Unzip')]
              [Parameter(ParameterSetName = 'Zip',
                              Mandatory = $true,
                              Position = 1)]
              [ValidateNotNull()]
              [string]$FolderPath,
              [Parameter(ParameterSetName = 'Unzip',
                              Mandatory = $false,
                              Position = 2)]
              [ValidateNotNull()]
              [bool]$Unzip,
              [Parameter(ParameterSetName = 'Unzip',
                              Mandatory = $false,
                              Position = 3)]
              [ValidateNotNull()]
              [bool]$DeleteZip
       )
       
       Write-Output "Entering Zip-Actions Function." -Severity 1
       
       switch ($PsCmdlet.ParameterSetName)
       {
              'Zip' {
                     
                     If ([int]$psversiontable.psversion.Major -lt 3)
                     {
                           
                           New-Item $ZipPath -ItemType file
                           $shellApplication = new-object -com shell.application
                           $zipPackage = $shellApplication.NameSpace($ZipPath)
                           $files = Get-ChildItem -Path $FolderPath -Recurse
                           
                           foreach ($file in $files)
                           {
                                  $zipPackage.CopyHere($file.FullName)
                                  Start-sleep -milliseconds 500
                           }
                           
                           Write-Output "Exiting Zip-Actions Function." -Severity 1
                           break           
                     }
                     
                     Else
                     {
                           
                           Add-Type -assembly "system.io.compression.filesystem"
                           $Compression = [System.IO.Compression.CompressionLevel]::Optimal
                           [io.compression.zipfile]::CreateFromDirectory($FolderPath, $ZipPath, $Compression, $True)
                           Write-Output "Exiting Zip-Actions Function." -Severity 1
                           break
                     }
              }
              
              'Unzip' {
                     <#
			Add-Type -assembly "system.io.compression.filesystem"
                     $Compression = [System.IO.Compression.CompressionLevel]::Optimal
                     [io.compression.zipfile]::ExtractToDirectory($ZipPath, $FolderPath)
                     
                     If ($DeleteZip) { Remove-item $ZipPath }
                     
                     Write-Output "Exiting Zip-Actions Function." -Severity 1
					break
			#>
			
			$shellApplication = new-object -com shell.application 
			$zipPackage = $shellApplication.NameSpace($ZipPath)
			$destinationFolder = $shellApplication.NameSpace($FolderPath) 
			$destinationFolder.CopyHere($zipPackage.Items(), 20)
	
		
			
			
			
              }
       }
       
}

function Download-MySQLExe
{
	
	try
	{
		$DownloadObj = new-object System.Net.WebClient;
		$DownloadObj.DownloadFile($DownloadURL, $MySQLZipPath);
	}
	catch
	{
		$Caughtexception = $_.Exception.Message;
	}
	finally
	{
		
		if (!(Test-Path $MySQLZipPath))
		{
			Write-Output "[DOWNLOAD FAILED] :: Failed to download MySQL ZIP archive! If any exceptions, here they are: $Caughtexception";
			exit;
		}
	}
	
	# ok, the file exists. Let's ensure that it matches up with our hash.
	# mysql.zip hash
	$ExpectedHash = "40-FD-7B-E8-19-22-99-31-C6-64-D3-0C-46-C1-BF-F2";
	$fileMd5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
	$zipHash = [System.BitConverter]::ToString($fileMd5.ComputeHash([System.IO.File]::ReadAllBytes($MySQLZipPath)))
	
	if ($zipHash -ne $ExpectedHash)
	{
		# Integrity issue. Could be content filtering...
		Write-Output "[HASH MISMATCH] :: The mysql.zip file's md5 hash does not match the original."
		exit;
	}
	else
	{
		return $true;
	}
		

}

#######################################################################################>
#   Download mysql.exe
###############################################################

Write-Output "`n[INIT] :: Initializing test connection to MySQL Server ...";

$DownloadURL 	= "https://ltpremium.s3.amazonaws.com/third_party_apps/mysql_x64/mysql.zip"
$MySQLExePath 	= "$env:windir\temp\mysql.exe"
$MySQLZipPath = "$env:windir\temp\mysql.zip"

# download mysql.zip and verify md5
$DownloadResult = Download-MySQLExe;

Write-Output $DownloadResult;

if ($DownloadResult -ne $true)
{
	exit;
}

# Unzip mysql.exe to temp
Zip-Actions -ZipPath $MySQLZipPath -FolderPath "$env:windir\temp\" -Unzip $true -DeleteZip $true | Out-Null;

if (-not (Test-Path $MySQLExePath))
{
	Write-Output "[EXTRACTION FAILED] :: Failed to extract MySQL.exe from the zip archive. Script is exiting! Here are the Powershell errors: $($Error)";
	exit;
}
else
{
	Write-Output "[SUCCESS] :: MySQL.exe was successfully extracted from the downloaded zip archive. Proceeding to test connection";
}

# Access properties that should have returned from JSON object.
$MySQLHost = $args[0];
$MySQLUser = $args[1];
$MySQLPass = $args[2];

Write-Output "PWD: $MySQLPass"
#$DevTesting = $true;

if ($DevTesting -eq $true)
{
	$MySQLHost = 'localhost';
	$MySQLUser = 'root';
	$MySQLPass = 'rooiffaduvomobid';
}

if (!$MySQLHost)
{
	Write-Output "[INVALID ARG] :: No MySQL host value was passed into this script.";
	exit;
}

if (!$MySQLUser)
{
	Write-Output "[INVALID ARG] :: No MySQL USER value was passed into this script.";
	exit;
}

if (!$MySQLPass)
{
	Write-Output "[INVALID ARG] :: No MySQL PASS value was passed into this script.";
	exit;
}

# Port 3306 check

$PortIsOpen = new-object Net.Sockets.TcpClient
$PortIsOpen.Connect($MySQLHost, 3306);

if (-not ($PortIsOpen.Connected))
{
	Write-Output "[SQL CONNECTION ERROR] :: Cannot establish connection to port 3306 to host: $MySQLHost." | Tee-Object SQLConErr;
	Add-Content $FilePathMySQLErr $SQLConErr;
	exit;
}
else
{
	Write-Output "[SUCCESS] :: Identified that MySQLd is listening on port 3306. Testing credentials now ..."	
}

$ConnectionResult = Test-MySQLConnection -mysqlUser $MySQLUser -mysqlPass $MySQLPass -mysqlHost $MySQLHost -mysqlPath "${env:windir}\temp";

$SuccessMsg = "[SUCCESS] :: Connection to the specified MySQL host was made successfully!"
$FailureMsg = "[SQL CONNECTION ERROR] :: Failed to make a connection to the specified host. Exception caught: `n`n$($global:mysqlConnectionErrors)"

if ($ConnectionResult -eq $true)
{
	Write-Output $SuccessMsg;
}
else
{
	Write-Output $FailureMsg;
}




