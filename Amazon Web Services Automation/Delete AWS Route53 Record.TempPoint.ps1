#Requires -Module AWSPowerShell
# MB 11/3/2014 - Initial Creation of script


$FQDN = Read-Host "Enter a proper AWS FQDN, i.e:   sub.domain.com";
#$FQDN=$args[0]

if(!$FQDN)
{
	Write-Output "NO FQDN PROVIDED! EXITING!"
	exit;
}

$AccessKey = 'MyAccessKey';
$SecretKey = 'MySecretKey';
$ZoneId = 'ASD123'

Set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey;

$HostedZoneID = "/hostedzone/$zoneID";

$RecordSets = Get-R53ResourceRecordSet -HostedZoneId $HostedZoneID -startRecordName $FQDN -MaxItems 1

if($RecordSets.ResourceRecordSets -and $RecordSets.ResourceRecordSets.Name -eq "$FQDN." )
{
	$CurrentIP = $RecordSets.ResourceRecordSets.ResourceRecords.Value
	$CurrentTTL = $RecordSets.ResourceRecordSets.TTL
	$RecordType = $RecordSets.ResourceRecordSets.Type.Value
	Write-Output "$Fqdn's IP address is currently $CurrentIP .... Proceeding to modification process!";
}
else
{
	Write-Output "No single FQDN detected with entered FQDN! Hit any key to exit.";
	Read-Host;
	exit;
}

# Construct objects to identify current record
$TargetRecord = $RecordSets.ResourceRecordSets;
$rr = New-Object Amazon.Route53.Model.ResourceRecord
$rr.Value = $currentIP

$rrs = New-Object Amazon.Route53.Model.ResourceRecordSet
$rrs.Name = $FQDN
$rrs.Type = $RecordType
$rrs.TTL = $CurrentTTL
$rrs.ResourceRecords = $rr

#Deletes the record set
Edit-R53ResourceRecordSet -HostedZoneId $HostedZoneID -ChangeBatch_Changes @( @{Action="DELETE";ResourceRecordSet=$rrs} )

[int]$CurIteration = 0;
[bool]$DeleteConfirmed = $false;
do
{
	$RecordSets = Get-R53ResourceRecordSet -HostedZoneId $HostedZoneID -startRecordName $FQDN -MaxItems 1
	if($RecordSets.ResourceRecordSets -and $RecordSets.ResourceRecordSets.Name -eq "$FQDN.")
	{
		$CurIteration+=1;
		Write-Output "Waiting before trying to verify that FQDN was deleted... "
		Start-Sleep -Seconds 2;
	}
	else
	{
		#Record is deleted!
		$DeleteConfirmed = $true;
		Write-Output "Record: $FQDN was successfully deleted!"
	}

}
while($CurIteration -lt 60 -and $DeleteConfirmed -eq $false)

if($CurIteration -ge 60)
{
	Write-Output "Failed to detect whether or not DNS record was deleted. Process timed-out.";
	pause;
}




















