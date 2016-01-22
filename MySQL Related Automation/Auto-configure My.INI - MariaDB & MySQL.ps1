<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2015 v4.2.89
	 Created on:   	1/15/2016 
	 Revision:      1.1.0
	 Created by:   	Marcus Bastian
	 Filename:      Auto-configure My.INI - MariaDB & MySQL.ps1
	===========================================================================
	.DESCRIPTION
		This script identifies the associated defaults file of the local MySQL instance and reconfigures it 
		to our suggested state.

		The transaction log files will be removed if the local MySQL version is MySQL 5.5.

#>

#####################################################################
# Declare functions used throughout the script
#####################################################################

function Get-DefaultsFilePathMySQL
{
	
	# Build object to be returned
	$ReturnObj = New-Object -TypeName System.Management.Automation.PSObject -Property @{
		Errors = $null
		DefaultsFilePath = $null
	}
	
	$PathToService = gwmi -cl win32_service | ? { $_.PathName -like '*MySQLd*' -AND $_.PathName -notLike '*5.7*' } | select -expand PathName;
	
	$countMatchingSvcs = ($PathToService | Measure-Object).Count;
	
	if ($CountMatchingSvcs -eq 0)
	{
		# Can't find a matching service	
		$ErrorMsg = "[ERROR] :: Cannot find a non-5.7 MySQLd service";
		Write-Error $ErrorMsg;
	}
	elseif ($countMatchingSvcs -gt 1)
	{
		# multiple MySQL services deteted... Let's bail
		$ErrorMsg = "[ERROR] :: Multiple MySQL services found.";
		Write-Error $ErrorMsg;
	}
	elseif ($countMatchingSvcs -eq 1)
	{
		# We can proceed! We found a single MySQL instance		
		# Example pathName
		# "C:\Program Files\MySQL\MySQL Server 5.6\bin\mysqld.exe" --defaults-file="C:\ProgramData\MySQL\MySQL Server 5.6\my.ini" LabMySQL
		# $PathToService = "`"C:\Program Files\MySQL\MySQL Server 5.6\bin\mysqld.exe`" --defaults-file=`"C:\ProgramData\MySQL\MySQL Server 5.6\my.ini`" LabMySQL";
				
		$defaultsFileRegex = '(?:--defaults-file=")(.*)(?:")'
		
		$DefaultsFilePath = ([regex]::matches($PathToService, $defaultsFileRegex)).groups[1].value;
		
		if (-not $DefaultsFilePath)
		{
			$ErrorMsg = "[ERROR] :: Failed to identify defaults-file path.";
			Write-Error $ErrorMsg;
		}
		else
		{
			Write-Verbose "Defaults file to proceed with:    $DefaultsFilePath";
			$ReturnObj.DefaultsFilePath = $DefaultsFilePath;
		}
	}
	
	$ReturnObj.Errors = $ErrorMsg;
	
	return $ReturnObj;
}

function Remove-TransactionLogs ($TransLog_Directory)
{
	$TransLog_Directory = $TransLog_Directory.Replace("`"", "").Trim();
	
	Write-Host "$TransLog_Directory" -ForegroundColor Green;
	
	if (!(Test-Path $TransLog_Directory))
	{
		$ErrorMsg = "[ERROR] :: Failed to identify defaults-file path.";
		Write-Error $ErrorMsg;
		return $null;
	}
	else
	{		
		Get-ChildItem $TransLog_Directory ib_logfile* | Remove-Item -Force;
		return $true;
	}
		
}

function Backup-IniFile
{
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$filePath,
		[Parameter(Mandatory = $true)]
		[string]
		$backupLocation
	)
	
	#TODO: Place script here
	
	
	if (Test-Path $filePath)
	{
		# If INI exists, copy it to 
		Copy-Item $filePath $BackupLocation;
		$CopiedSuccessfully = Test-Path $BackupLocation;
		
		if ($CopiedSuccessfully -eq $true)
		{
			# INI backup was verified!
			return $true;
		}
		else
		{
			# Failled to backup the MY.INI. 
			return $false;
		}
	}
	else
	{
		# The INI doesn't exist where it should
		return $null;
	}
}

Function Write-Log
{

	
	Param
		(
		[Parameter(Mandatory = $True, Position = 0)]
		[String]$Message,
		[Parameter(Mandatory = $False, Position = 1)]
		[INT]$Severity
	)
	
	$Note = "[NOTE]"
	$Warning = "[WARNING]"
	$Problem = "[ERROR]"
	[string]$Date = get-date
	
	switch ($Severity)
	{
		1 { add-content -path $LogFilePath -value ($Date + "`t:`t" + $Note + $Message) }
		2 { add-content -path $LogFilePath -value ($Date + "`t:`t" + $Warning + $Message) }
		3 { add-content -path $LogFilePath -value ($Date + "`t:`t" + $Problem + $Message) }
		default { add-content -path $LogFilePath -value ($Date + "`t:`t" + $Message) }
	}
	
	Write-Output "$Date `t$Message";
	
	
}

# Setting log file directory variables for general output and PS errors
$LogfilePath = "$env:windir\temp\MY_INI_OptimizationLog.txt"
$PSErrorsPath = "$env:windir\temp\MY_INI_OptimizationErrors.txt"

# Identify the path to the My.ini file
# Returns an object w/ errors and DefaultsFilePath property
$DefaultsFilePath = Get-DefaultsFilePathMySQL;

#If the error property of the object returned by Get-DefaultsFilePathMySQL <> null then there were problems
if ($DefaultsFilePath.Errors)
{
	Write-Log -Message $DefaultsFilePath.Errors  -Severity 3
	return;
}

# Fetch the contents of the identified my.ini file
$IniFilePath = $DefaultsFilePath.DefaultsFilePath;

Write-Log -Message "Identified MySQL my.ini which needs to be optimized: $IniFilePath" -Severity 1;

$FileContent = get-content $IniFilePath;

# Backup the INI file
Write-Log -Message "Proceeding to backup the current my.ini file." -Severity 1

$BackupLocation = "$env:windir\temp\backup_ini.ini";
$BackupResult = Backup-IniFile $IniFilePath $BackupLocation;

# Verify it was copied successfully
if ($BackupResult -eq $false -or $BackupResult -eq $null)
{
	# Report that we couldn't backup the current my.ini
	write-log -Message "Failed to create a copy (in temp) of the current my.ini. No changes have been made." -Severity 3
	return;
}
else
{
	Write-Log -Message "Successfully backed up the current MY.INI file to temp." -Severity 1;
}

# Get the index of each [xxxx] label. Let's make sure that a [mysqld] section exists
$Sections = $FileContent | ? { $_.StartsWith("[") }
$MySQLD_Section = $Sections | ? { $_ -eq '[mysqld]' };

if (!$Sections -or !$MySQLD_Section)
{
	# This should never be the case with a healthy INI file
	Write-log -Message "Could not identify the [mysqld] section within INI. Script cannot proceed!" -Severity 3;
	return;
}


# This will be the top-half of the FINAL my.ini which needs to be concatenated 
# with MySQLD_Portion and very bottom
$MySQLd_LineNumber = $FileContent.IndexOf('[mysqld]');
$TopHalf = $FileContent[0..($MySQLd_LineNumber - 1)];

$MaxLines = $FileContent.GetUpperBound(0);
$BottomHalfOfINI = $FileContent[($MySQLd_LineNumber + 1)..$MaxLines];

# Make sure the service stops ...
gwmi -cl win32_service | ? { $_.PathName -like '*MySQLd*' -AND $_.PathName -notLike '*5.7*' } | stop-Service -FORCE;
gwmi -cl win32_service | ? { $_.PathName -like '*MySQLd*' -AND $_.PathName -notLike '*5.7*' } | stop-Service -FORCE;

Write-Log -Message "Beginning optimization of current my.ini file, now ...." -Severity 1;

# New items to insert/update respectively
$InnoDBFlushLogAtTrxCommitFound=0;
$queryTypeFound=0;
$query_Cache_SizeFound=0;
$TranIsolationFound=0;
$FPTFound = 0;
$MaxPacketFound = 0;

# Version 2 items
$Wait_Timeout_Found = 0;
$max_connections_found = 0;
$tmp_table_size_found = 0;
$table_open_cache_found = 0;
$Innodb_log_file_size_found = 0;
$thread_cache_size_found = 0;
$innodb_thread_concurrency_found = 0;
$sql_mode_found = 0;
$max_heap_table_size_found = 0;
$innodb_support_xa_found = 0;
$innodb_strict_mode_found = 0;
$innodb_buffer_pool_size_found = 0;

$ChangesNeeded = 0;

#####################################################################
# Calculate buffer pool size based upon total system memory 
#####################################################################

$Memory = [math]::ceiling((gwmi -class win32_ComputerSystem).TotalPhysicalMemory / 1024 / 1024);
switch ($Memory)
{
    { ($_ -LE 7999) } { $Allocation = [int]($_*.37); <#write-output "$($Allocation)M";#> }
    {($_ -GE 8000 -AND  $_ -LE 31999) } { $Allocation = [int]($_*.5); <#write-output "$($Allocation)M";#> }
    {($_ -GE 32000 -AND  $_ -LE 47999) } { $Allocation = [int]($_*.75); <#write-output "$($Allocation)M"#> }
    { $_ -GE 48000 } { $Allocation = [int]($_*.8); <#write-output "$($Allocation)M"#> }
	default { $Allocation = "1024"; <#write-output '1G'#> }
}

#####################################################################
# Since the partner's MySQL engine could be version 5.5, we need to check.
# In MySQL 5.5 and below, the transaction logs are not automatically resized ...
# - To that end, you must remove the tlogs and start the MySQL service.
#####################################################################

if ($IniFilePath -like '*5.5*')
{
	# it's 5.5, so we must delete old t-logs
	$DataDirRegex = "(?:datadir[\s]*=[\s]*`"?)(.*?)(?:`"?[\n])";
	$DataDirPath = ([regex]::matches($($FileContent | Out-String),
	$DataDirRegex,
	@('MultiLine',
	'Ignorecase'))).groups[1].value;
	
	Write-Log "This server is MySQL 5.5, therefore the old transaction logs 
				in $DataDirPath must be removed. Proceeding to do so now ..." -Severity 2;
	
	
	$RemovalResults = Remove-TransactionLogs $DataDirPath;
	
	if ($RemovalResults -ne $true)
	{
		Write-Log "The script was unable to locate a directory which matches the extracted 'DataDir' 
					my.cnf value. Skipping innodb_log_file_size optimizations in lieu of this." -Severity 3;
		$SkipLogFileSize = $true;
	}
	else
	{
		Write-Log -Message "Successfully removed the transaction logs from the data directory..." -Severity 1;
	}
}
else
{
	Write-Log -Message "Server is not MySQL 5.5, therefore we do not need to remove the transaction log files. Proceeding ..." -Severity 1;
}


####################################################################################################
# Identify any my.ini options which already exist within the INI file
# If the option specified by the IF statement is found, the script will replace its current value with the 
# value required for LT installs
####################################################################################################

Write-Log -Message "Beginning optimization of the MY.INI file now. Iterating line by line ....." -Severity 1;

$BottomHalfOfINI | % {
	if ($_ -like 'innodb_flush_log_at_trx_commit*')
	{
		$InnoDBFlushLogAtTrxCommitFound = 1;
		$BottomHalfOfIni = $BottomHalfOfIni -replace $_, "innodb_flush_log_at_trx_commit=0"
		$ChangesNeeded = 1;
	}
	elseif ($_ -like 'query_cache_type*')
	{
		$queryTypeFound = 1;
		$BottomHalfOfINI = $BottomHalfOfINI -replace $_, "query_cache_type=0"
		$ChangesNeeded = 1;
	}
	elseif ($_ -like 'query_cache_size*')
	{
		$query_Cache_SizeFound = 1;
		$BottomHalfOfINI = $BottomHalfOfINI -replace $_, "query_cache_size=0"
		$ChangesNeeded = 1;
	}
	elseif ($_ -like 'transaction-isolation*')
	{
		$TranIsolationFound = 1;
		$BottomHalfOfINI = $BottomHalfOfINI -replace $_, "transaction-isolation=READ-COMMITTED"
		$ChangesNeeded = 1;
	}
	elseif ($_ -like 'max_allowed_packet*')
	{
		$MaxPacketFound = 1;
		$BottomHalfOfINI = $BottomHalfOfINI -replace $_, "max_allowed_packet=128M"
		$ChangesNeeded = 1;
	}
	elseif ($_ -like 'innodb_file_per_table')
	{
		$FPTFound = 1;
		$ChangesNeeded = 1;
	}
	elseif ($_ -like 'wait_timeout*')
	{
		$Wait_Timeout_Found = 1;
		$BottomHalfOfIni = $BottomHalfOfIni -replace $_, "wait_timeout=900"
		$ChangesNeeded = 1;
	}
	elseif ($_ -like 'max_connections*')
	{
		$max_connections_found = 1;
		$BottomHalfOfIni = $BottomHalfOfIni -replace $_, "max_connections=3000"
		$ChangesNeeded = 1;
	}
	elseif ($_ -like 'tmp_table_size*')
	{
		$tmp_table_size_found = 1;
		$BottomHalfOfIni = $BottomHalfOfIni -replace $_, "tmp_table_size=96M";
		$ChangesNeeded = 1;
	}
	elseif ($_ -like 'table_open_cache*')
	{
		$table_open_cache_found = 1;
		$BottomHalfOfIni = $BottomHalfOfIni -replace $_, "table_open_cache=4500";
		$ChangesNeeded = 1;
	}
	elseif ($_ -like 'innodb_log_file_size*')
	{
		
		$Innodb_log_file_size_found = 1;
		
		if ($SkipLogFileSize -eq $true)
		{
			continue;
		}
		else
		{
			$BottomHalfOfIni = $BottomHalfOfIni -replace $_, "innodb_log_file_size=512M";
			$ChangesNeeded = 1;
		}
	}
	elseif ($_ -like 'thread_cache_size*')
	{
		$thread_cache_size_found = 1;
		
		$cur_thread_cache_value = $_ -split "=";
		[int]$cur_value = $cur_thread_cache_value[1];
		
		# Is current value < 38?
		if ([int]$cur_value -lt 38)
		{
			#Change to 128M only if lower than 128M
			$BottomHalfOfIni = $BottomHalfOfIni -replace $_, "thread_cache_size=38";
			$ChangesNeeded = 1;
		}
		
	}
	elseif ($_ -like 'innodb_thread_concurrency*')
	{
		$innodb_thread_concurrency_found = 1;
		$BottomHalfOfIni = $BottomHalfOfIni -replace $_, "innodb_thread_concurrency=0";
		$ChangesNeeded = 1;
	}
	elseif ($_ -like 'sql-mode*')
	{
		$sql_mode_found = 1;
		$BottomHalfOfIni = $BottomHalfOfIni -replace $_, "sql-mode=`"NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION`"";
		$ChangesNeeded = 1;
		
	}
	elseif ($_ -like 'max_heap_table_size*')
	{
		$max_heap_table_size_found = 1;
		$BottomHalfOfIni = $BottomHalfOfIni -replace $_, "max_heap_table_size=96M";
		$ChangesNeeded = 1;
	}
	elseif ($_ -like 'innodb_support_xa*')
	{
		$innodb_support_xa_found = 1;
		$BottomHalfOfIni = $BottomHalfOfIni -replace $_, "innodb_support_xa=0";
		$ChangesNeeded = 1;
	}
	elseif ($_ -like 'innodb_strict_mode*')
	{
		$innodb_strict_mode_found = 1;
		$BottomHalfOfIni = $BottomHalfOfIni -replace $_, "innodb_strict_mode=0";
		$ChangesNeeded = 1;
	}
	elseif ($_ -like 'innodb_buffer_pool_size*')
	{
		$innodb_buffer_pool_size_found = 1;
		# Calculate buffer_pool_size
		$BottomHalfOfIni = $BottomHalfOfIni -replace $_, "innodb_buffer_pool_size=$($Allocation)M";
		$ChangesNeeded = 1;
	}
}


####################################################################################################
# Identify any my.ini options which were not already detected and replaced. 
# The following items need to be added as new entries.
####################################################################################################

if ($Wait_Timeout_Found -eq 0) 				{ $Additions = $Additions += "wait_timeout=900`r`n"; }
if ($max_connections_found -eq 0) 			{ $Additions = $Additions += "max_connections=3000`r`n"; }
if ($tmp_table_size_found -eq 0) 			{ $Additions = $Additions += "tmp_table_size=96M`r`n"; }
if ($table_open_cache_found -eq 0) 			{ $Additions = $Additions += "table_open_cache=4500`r`n"; }
if ($Innodb_log_file_size_found -eq 0 -and $SkipLogFileSize -ne $true) { $Additions = $Additions += "innodb_log_file_size=512M`r`n"; }
if ($thread_cache_size_found -eq 0) 		{ $Additions = $Additions += "thread_cache_size=38`r`n"; }
if ($innodb_thread_concurrency_found -eq 0) { $Additions = $Additions += "innodb_thread_concurrency=0`r`n"; }
if ($sql_mode_found -eq 0) 					{ $Additions = $Additions += "sql-mode=`"NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION`"`r`n"; }
if ($max_heap_table_size_found -eq 0)		{ $Additions = $Additions += "max_heap_table_size=96M`r`n"; }
if ($innodb_support_xa_found -eq 0) 		{ $Additions = $Additions += "innodb_support_xa=0`r`n"; }
if ($innodb_strict_mode_found -eq 0) 		{ $Additions = $Additions += "innodb_strict_mode=0`r`n"; }
if ($innodb_buffer_pool_size_found -eq 0)	{ $Additions = $Additions += "innodb_buffer_pool_size=$($Allocation)M`r`n"; }
if ($InnoDBFlushLogAtTrxCommitFOUND -eq 0 )	{ $Additions = $Additions += "innodb_flush_log_at_trx_commit=0`r`n"; }
if ($queryTypeFound -eq 0) 					{ $Additions = $Additions += "query_cache_type=0`r`n"; }
if ($query_Cache_SizeFound -eq 0) 			{ $Additions = $Additions += "query_cache_size=0`r`n";	}
if ($TranIsolationFound -eq 0)				{ $Additions = $Additions += "transaction-isolation=READ-COMMITTED`r`n";	}
if ($MaxPacketFound -eq 0 )  				{ $Additions = $Additions += "max_allowed_packet=128M`r`n"; }
if ($FPTFound -eq 0) 						{ $Additions = $Additions += "innodb_file_per_table`r`n"; }

$NewINI = $TopHalf + "[mysqld]`n" + $Additions + $BottomHalfOfINI;

# Apply the updates to the current INI file.
set-content $IniFilePath $NewINI;

# Identify service to restart
$ServiceObjects = gwmi -cl win32_service | ? { $_.PathName -like '*MySQLd*' -AND $_.PathName -notLike '*5.7*' }
$ServiceObjects | Stop-Service -Force;
$ServiceObjects | Restart-Service -Force -ev restartErrors;

# One last time ... make sure the service is started
gwmi -cl win32_service | ? { $_.PathName -like '*MySQLd*' -AND $_.PathName -notLike '*5.7*' } | Start-Service;

# When we tried to restart the service, were there any errors?
# If so, maybe it doesn't like a my.ini value/option. Rollback, if so ...
if ($restartErrors)
{
	# Service failed to start
	Write-Log "Failed to start the MySQL service after making our changes. Proceeding to revert our changes and write out the my.ini ..." -Severity 3;
	Write-Log "$(Get-Content $IniFilePath)" -Severity 1;
	
	# Copying the backup BACK to the original location
	Remove-Item $IniFilePath -Force;
	Copy-Item $BackupLocation $IniFilePath;
	
	gwmi -cl win32_service | ? { $_.PathName -like '*MySQLd*' -AND $_.PathName -notLike '*5.7*' } | Start-Service;
	return;
}
else
{
	# The service is started with the new options!
	Write-Log -Message "The MySQL INI file optimizations have been completed. The MySQL/LabMySQL services are running as required." -Severity 1;
}
