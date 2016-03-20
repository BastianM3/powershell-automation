
#Requires -Modules AwsPowerShell
Import-Module awspowershell;

$AccessKey = $args[0];
$SecretKey = $args[1];
$Region = $args[2];

Set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey;

# Establish start and end time range that we want data for
$time       = Get-Date;
$starttime  = $time.AddHours(-48).ToUniversalTime();
$endtime    = $time.ToUniversalTime();

$CWMetricName     =   'CPUUtilization';
$MetricNameSpace   =   'AWS/EC2';

$ListInstanceIDs = Get-CWMetrics -Namespace $MetricNameSpace -CWMetricName StatusCheckFailed | select -expandproperty dimensions | select -ExpandProperty value

$Dimension1 = New-Object Amazon.CloudWatch.Model.Dimension;
$Dimension1.Name = 'InstanceId';

# Array to store PSObjects created below. This will store the final results
$DataArr=@();

$ListInstanceIDs | % {
	
	$Dimension1.Value = $_

	$stats =  Get-CWMetricStatistics -Namespace $MetricNameSpace `
			-CWMetricName $CWMetricName `
			-Dimensions @($Dimension1) `
			-EndTime $endtime `
			-Period 600 `
			-StartTime $starttime `
			-Statistics 'Average' `
			-Unit 'Percent';
            
    if(!$stats -or !$stats.Datapoints)
    {
        Write-output "No data returned.";
    }
	else
	{
	    Write-Output "Collecting data for $_";
	}
	
    
	Foreach($dataEntry in $stats.Datapoints)
	{
				
	    $dataEntry | % {
            # Create PSObject to store the desired data fields
			$CurrentRecord = New-Object PSObject @{
                InstanceID      = $Dimension1.Value
                AverageValue    = $_.Average
                TimeStamp       = $_.Timestamp;
                }
                           
            # Append the new PSObject with current data to the complete data array 
            $DataArr    +=  $CurrentRecord;
		}
	}		
}
	
$ExpandedResults = $stats | where-object { $_.average -GT 50 } | select value, average, timestamp | sort-object -property timestamp;

$ExpandedResults -replace '^',','; 
 