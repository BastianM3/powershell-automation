do {

	try {
		$ValidThreshold = $true;
		cls
		[int]$CPUThreshold = Read-Host "Please enter in the desired % CPU Threshold (1-100).`r`nThis parameter defines the % CPU spike we want to begin recording diagnostics"
		}
	catch 
		{ 
		$ValidThreshold = $false;
		}
	}
	until (($CPUThreshold -ge 1 -and $CPUThreshold -le 100) -and $ValidThreshold)
	
#This parameter defines at what % CPU we want to begin recording process list / LabTech script engine data for.
#[int]$CPUThreshold = 20;

# The number of times that a continual process list dump and related queries with continue, should CPU drop below the threshold. 
# "Oh, well we were pulling the MySQL processlist because of a CPU spike, but the spike has since subsided for $ThresholdForConsecutiveBelow consecutive samples
# so we will stop and wait for another CPU spike above $CPUTHreshold!"
$ThresholdForConsecutiveBelow = 5;

#

function FetchHardwareMetrics {

$Results = @("\PhysicalDisk(*)\Current Disk Queue Length", 
  "\PhysicalDisk(_Total)\% Disk Time", 
  "\PhysicalDisk(_Total)\Avg. Disk Queue Length", 
  "\PhysicalDisk(_Total)\Avg. Disk Read Queue Length", 
  "\PhysicalDisk(_Total)\Avg. Disk Write Queue Length", 
  "\PhysicalDisk(_Total)\Avg. Disk sec/Transfer" 
  "\PhysicalDisk(_Total)\Avg. Disk sec/Read", 
  "\PhysicalDisk(_Total)\Avg. Disk sec/Write") |% { 
    (Get-Counter $_).CounterSamples } | 
    Select-Object Path,CookedValue | 
    #Format-Table -AutoSize
	ConvertTo-Html | select -Skip 5;
	
	

$Results = $Results -replace "<table>","<table class=""imagetable""";
	
if($Results)
{
	Write-Output "<font style=""font-family: verdana,arial,sans-serif;font-size:11px;font-weight:bold; margin-left:5px;""><u>Disk Performance:</u></font><br>  $Results"
}
	
$MemoryResults = @("\Memory\Page Faults/sec", 
					  "\Memory\Committed Bytes", 
					  "\Memory\Commit Limit", 
					  "\Memory\Pages/sec", 
					  "\Memory\Free System Page Table Entries" 
					  "\Memory\Pool Paged Resident Bytes", 
					  "\Memory\Available MBytes") |% { 
    (Get-Counter $_).CounterSamples } | 
    Select-Object Path,CookedValue | 
    #Format-Table -AutoSize
	ConvertTo-Html | select -Skip 5;
	
#Js4Gas8!
	$MemoryResults = $MemoryResults -replace "<table>","<table class=""imagetable""";
	
	if($MemoryResults)
	{
		Write-Output "<font style=""font-family: verdana,arial,sans-serif;font-size:11px;font-weight:bold; margin-left:5px;""><u>Memory Performance:</u></font><br> $MemoryResults"
	}
	
}


$RunningScriptsQry= @"

use labtech;
select ThreadID as 'Script Thread ID',
		r.ScriptID as 'Script ID',
		ls.ScriptName as 'Script Name',
		ClientID as 'Client ID',
		computerID as 'Computer ID',
		Executed as 'Start Time',
		LastCheck as 'Last Script Engine Update',
		SEC_TO_TIME(TIMESTAMPDIFF(	second, Executed, LastCheck)) as 'Current Script Time',
		Running as 'Is Script Running?',
		r.ComputerScript as 'Is Computer Script?',
		r.UserScript as 'Is User Script?',
		r.ClientScript as 'Is Client Script?', 
		Params as 'Script Parameters' 
from runningscripts r 
left outer join lt_scripts ls 
	on ls.ScriptID=r.ScriptID
where running=1;

"@;




#Region Functions

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

$ExistCheckSQLDir = CheckRegKeyExists HKLM:\Software\Wow6432Node\Labtech\Setup MySQLDir;
$ExistCheckRootPwd = CheckRegKeyExists HKLM:\Software\Wow6432Node\Labtech\Setup RootPassword;

if($ExistCheckSQLDir -eq $true)
{
	$SQLDir=(Get-ItemProperty HKLM:\Software\Wow6432Node\Labtech\Setup -name MySQLDir).MySQLDir;
}
elseif ($ExistsCheckSQLDir -eq $false)
{ 
	write-output "Critical Error: Unable to Locate SQL Directory Registry key ( HKLM:\Software\Wow6432Node\LabTech\Setup.MySQLDir )"
	exit;
}

if($ExistCheckRootPwd -eq $true)
{
	$RootPwd=(Get-ItemProperty HKLM:\Software\Wow6432Node\Labtech\Setup -name RootPassword).RootPassword;
} 
elseif ($LabTechDir -eq $false) 
{ 
	write-output "Critical Error: Unable to Locate Root Password Registry key ( HKLM:\Software\Wow6432Node\LabTech\Setup.RootPassword )";
	exit;
}

Function FetchSQLResults {
	$Query = $Args[0];
	$Result = .\mysql --user=root --password=$RootPwd -e "$Query" --html
	Write-Output $Result
}

function GetShowFullProcesslist {

	#Establishing file naming convention
	$SampleStartDate = $(get-date -format g).Replace("/","-").Replace(":",".").Replace("/","-");
	$SampleFolderName =$("$env:windir\temp\LabTechCPUMonitor\Sample-$SampleStartDate")
	
	#Create sample log file dumps, if it does not exist of course!
	if(!(test-path  $SampleFolderName))
	{
		New-Item -ItemType directory -Path $SampleFolderName | Out-Null;
	}
	
	$Now =  $(get-date -format g).Replace("/","-").Replace(":",".").Replace("/","-");
	
	
	if(!(Test-Path  "$env:windir\temp\LabTechCPUMonitor\Sample-$SampleStartDate\$now.html"))
	{
		Add-Content "$env:windir\temp\LabTechCPUMonitor\Sample-$SampleStartDate\$now.html" "$CSSHeader`r`n"
	}
	
	
	$HeaderWritten = $false;
	#The number of consecutive readings below the threshold (our hint to stop logging)
	$NumConsecutivelyBelowThresh = 0;
	$FilePath = "$env:windir\temp\LabTechCPUMonitor\Sample-$SampleStartDate\$now.html"
	
	for($i=1; $i -lt 100; $i++)
	{	
		
		
	$Header = @"
		
		<body style="margin: 0px; padding: 0px;">
		<div>
		<br>
		 <font color="#33CC00"> Current High CPU Utilization of $Value% - $Now </font><br>
		<br>
		</div>
"@;	


		$CurTime = Get-Date -Format F;
		
		#Check to see if we've been below the specified monitoring threshold before continuing
		if($NumConsecutivelyBelowThresh -ge $ThresholdForConsecutiveBelow)
		{
			Write-Output "===  The past $ThresholdForConsecutiveBelow samples have been below threshold. ==`r`n  Waiting for CPU spike ....`r`n";
			Add-Content $FilePath "<b><br>CPU has fallen below threshold for $ThresholdForConsecutiveBelow samples at $(Get-Date -Format F)</b><br><br>"
			break;
		}
		
		#Fetch current reading for CPU %
		$CurrentReading = (Get-counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1).Readings
		[int]$Value = [System.Math]::Round($CurrentReading.Split("`r`n")[1]);
		
		#Add another to consecutively below threshold
		if($Value -lt $CPUThreshold)
		{
			$NumConsecutivelyBelowThresh+=1;
		}
		else
		{
			$NumConsecutivelyBelowThresh=0;
		}
		
		
		
		if($HeaderWritten -eq $true)
		{
			$Header="<div style=""margin-left: 5px;""><font color=""#FFFFFF"" size=""3px""><b><u> Log Entry - $CurTime </u></b></font></div>";
		}
		
		$HeaderWritten = $true;
		Write-Output "`r`nINIT - MySQL Show Full Processlist check number: $i  - CPU = $Value%";
		Write-Output "Fetching full processlist information from local MySQL Instance ...";
		#Fetching Show Full Processlist command output here.
		$ProcList = FetchSQLResults "SELECT * FROM INFORMATION_SCHEMA.PROCESSLIST WHERE Command<>'Sleep' order by time desc;"
		$ProcList = $ProcList -replace "<TABLE BORDER=1>","<TABLE class=""imagetable"">"
		
		Write-Output "Fetching list of all runnings scripts from local MySQL Instance ...";
		$RunningScripts = FetchSQLResults $RunningScriptsQry;
		
		if($RunningScripts.length -gt 40)
		{
			$RunningScriptsHeader = "<font style=`"font-family: verdana,arial,sans-serif;font-size:11px;font-weight:bold; margin-left:5px;`"><u>Running Scripts:</u></font><br>"
			$RunningScripts = $RunningScriptsHeader+$($RunningScripts -replace "<TABLE BORDER=1>","<TABLE class=""imagetable"">";)
		}
		else
		{
			$RunningScriptsHeader = "<font style=`"font-family: verdana,arial,sans-serif;font-size:11px;font-weight:bold; margin-left:5px;`"><u>Running Scripts:</u><br><br> <font color=`"Green`">&nbsp;No scripts currently running....</font><br><br>"
			$RunningScripts = $RunningScriptsHeader
		}
		
		Write-Output "Fetching hardware metric information now ...";
		$HWDiagnostics = FetchHardwareMetrics 
				
		Add-Content $FilePath "$Header`r`n$ProcList`r`n$RunningScripts`r`n$HWDiagnostics";
		Start-Sleep -Seconds 1;
		
	}

}


<#

###########################################################################
#################### END FUNCTIONS ########################################
###########################################################################

#>

#EndRegion Functions

$CSSHeader = @'
<html>
<head>
 <Title>
 LabTech AMP Server - Script Summary
 </title>
 <style type="text/css">
		tr:nth-child(even) {background: #CCC}
		tr:nth-child(odd) {background: #FFF}
		div {
			background-color: #202020;
			border-width: 2px;
			padding: 10PX;
			border-color: #000000;
			border-style: solid;
			float: none;
			width: 50%;
			margin-left: 5px;
			margin-bottom: 10px;
			margin-top: 5px;
			font-family: tahoma;
			font-size 13px;
			font-weight: bold;
			font-color: #33CC00;
		}
		div.date
		{
		
		}
		table.imagetable {
			font-family: verdana,arial,sans-serif;
			font-size:11px;
			font-weight:bold;
			border-width: 1px;
			padding: 10px;
			width: 50%;
			border-color: #999999;
			border-collapse: collapse;
			margin-left: 5px;
			margin-top: 8px;
			Margin-bottom: 20px;
		table.imagetable th {
		}
			
			border-width: 1px;
			font-weight:bold;
			padding: 8px;
			border-style: solid;
			border-color: #999999;
		}
		table.imagetable td {
			padding: 10px;
			border-width: 1px;
			font-weight:bold;
			padding: 6px;
			border-style: solid;
			border-color: #999999;
		}
		.customheader {
		color:black;
		font-size:1.1em;
		font-family:tahoma;
		float: none;
		margin-bottom: 10px;
		margin-top: 20px;
		margin-left: 5px;
		width: 50%;
				}
		u {
    	text-decoration: underline;
		
}
		</style>

</script>
 
</head>
<body style="margin: 0px; padding: 0px;">

'@;

#Clear the screen before beginning...
cls

#Create the LabTechCPUMonitor directory if it doesn't exist
if(!(test-path $env:windir/temp/LabTechCPUMonitor))
{
	New-Item -ItemType Directory -Path $env:windir/temp/LabTechCPUMonitor | Out-Null;
}

set-location $SQLDir\bin;

while($true)
{
	#Get-counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 5 
	$MyReading = (Get-counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1).Readings
	[int]$Value = [System.Math]::Round($MyReading.Split("`r`n")[1]);
	Write-Output "Current % Processor Time is currently = ~$Value";
	
	if([int]$Value -gt $CPUThreshold)
	{
		#Write-Output "$Value  is greater than $CpuThreshold?";
		Write-Output "Threshold of $CPUThreshold has been exceeded by $Value!"
		Write-Output "`r`n------------------------------------------"
		Write-Output "---- INITIALIZING PROCESS LIST FETCH! ----";
		Write-Output "------------------------------------------`r`n";
		GetShowFullProcesslist;
	}
	else
	{
		Write-Output "No alerts necessary ... Pulling processor time again ...`r`n"
	}
}
#EndRegion Monitor
