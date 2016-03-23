<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2016 v5.2.117
	 Created on:   	3/23/2016 10:34 AM
	 Created by:   	Marcus Bastian
	 Filename:     	LabTech Monitor Logs - Extract Performance Info.ps1
	===========================================================================
	.DESCRIPTION

		This script identifies the local LTADMonitors.txt/txtold.txt files, fetches their contents and 
		parses them to extract the following important bits of information:
		
		1. How long the internal monitor took to execute
		2. When the monitor executed
		3. The name of the respective monitor

		The string representation of the results are out-filed to path declared by var "$outputLog".
		
		The generated object is also exported to JSON for easy consumption by a UI.

		The complete list of monitor performance details is then displayed in a grid-view 
		rendered by PowerShell.
		
#>
#region Functions
function Identify-LTADMonitorsLogs
{
	$CurrentAndOldFileArray = @();
	
	if (!(Test-Path "$env:ProgramFiles\LabTech\Logs\"))
	{
		if (!(Test-Path "$env:ProgramFiles(x86)\LabTech\Logs\"))
		{
			return $null;
		}
		else
		{
			$CurrentAndOldFileArray += "$env:ProgramFiles(x86)\LabTech\Logs\LTADMonitors.txt";
			$CurrentAndOldFileArray += "$env:ProgramFiles(x86)\LabTech\Logs\LTADMonitors.txtold.txt";
		}
	}
	else
	{
		$CurrentAndOldFileArray += "$env:ProgramFiles\LabTech\Logs\LTADMonitors.txt";
		$CurrentAndOldFileArray += "$env:ProgramFiles\LabTech\Logs\LTADMonitors.txtold.txt";
	}
	
	# return an array of the two files I want to parse.
	return $CurrentAndOldFileArray;
	
}
#endregion

$ErrorActionPreference = 'SilentlyContinue';

# Log file to restore the raw text results of the script
$outputLog 		= "$env:windir\temp\MonitorPerformance.txt";
$outputJsonFile = "$env:windir\temp\MonitorPerformance_Json.txt";

# Retrieve an array of log files to parse through. Could be 32-bit or 64-bit depending
# on if LabTech 10 or 10.5+
$LogsToParse = Identify-LTADMonitorsLogs;

if ($LogsToParse -eq $null)
{
	Write-Error "Failed to identify LabTech log files."
	return;
}

Write-Progress -Activity 'Fetching contents of LTADMonitor logs files ....' -PercentComplete 10

$rawLogText = get-content $LogsToParse;

Write-Progress -Activity 'Fetching contents of LTADMonitor logs files ....' -PercentComplete 100

if ($rawLogText.Length -lt 1)
{
	# No output to parse	
	Write-Error "The LTADMonitors.txt/txtold.txt log files contain no data. Script is exiting.";
	return;
}

$ArrayOfMonitors = @();
$SplitArray = $rawLogText -Split ":::`n" | ? { $_ -like '*Time Taken*' }

foreach ($monitorLogEntry in $SplitArray)
{
	
	# get time taken
	$monitorLogEntry -match "(?:Time Taken:)(.*)(?=:::)" | out-null;
	$TimeTaken = $matches[1];
	
	# get name of the monitor from the log entry
	$monitorLogEntry -match "(?:DbaseMonitor Finished:\s)(.*)(?=Time Taken:\d)" | out-null;
	$MonitorName = $Matches[1];
	
	$monitorLogEntry -match "(?:-\s)(.*)(?=-\sDbase)" | out-null;
	$monitorRanAt = $matches[1];
	
	
	$thisObject = New-Object System.Management.Automation.PSObject -Property @{
		MonitorName = $monitorName
		TimeTaken = [double]$timeTaken
		TimeRan = [datetime]$monitorRanAt
	}
	
	$ArrayOfMonitors += $thisObject;
	
}

$sortedArrayOutput = $ArrayOfMonitors | Sort-Object -Property TimeTaken -Descending
Set-Content $outputLog $($sortedArrayOutput | Out-String);

# Output JSON to file too
if ($PSVersionTable.PSVersion.Major -ge 3)
{
	$sortedArrayOutput | ConvertTo-Json | Out-File $outputJsonFile;
}

$sortedArrayOutput | out-gridview








