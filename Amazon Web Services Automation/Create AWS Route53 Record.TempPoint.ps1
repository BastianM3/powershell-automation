#Requires -Module AWSPowerShell

$AccessKey = 'MyAccessKey';
$SecretKey = 'MySecretKey';

Set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey;

$TTL 			=  $Args[0] #"300"
$FQDN 			=  $Args[1] #"bastian.mydomain.com"
$RecordType 	= $Args[2] #"A"
$IPAddress = $Args[3] #"172.19.0.49"
$HostedZoneID 	= "/hostedzone/$($args[4])"


# Create resource record with IP.
$ResourceRec 		= New-Object Amazon.Route53.Model.ResourceRecord
$ResourceRec.Value 	= $IPAddress

# Instantiate resource record set ( 1st layer of details of RR )
$rrs		= New-Object Amazon.Route53.Model.ResourceRecordSet
$rrs.Name 	= $FQDN
$rrs.Type 	= $RecordType
$rrs.TTL 	= $TTL

# Associate resource record w/ IP to the instantiated resource record set
$rrs.ResourceRecords = $ResourceRec

try
{
	Edit-R53ResourceRecordSet -HostedZoneId $HostedZoneID -ChangeBatch_Changes @( @{Action="CREATE";ResourceRecordSet=$rrs} ) -ErrorVariable AWSError -ErrorAction Stop
}
catch
{
	Write-Output "Failure: resource record may already exist! `r`n`r`nDetailed errors: `r`n`r`n $AwsError"
	pause;
	exit;
}

# Verify that record was created successfully!
[int]$CurIteration 	= 0;
[bool]$Confirmed 	= $false
do
{
	$RecordSets = Get-R53ResourceRecordSet -HostedZoneId $HostedZoneID -startRecordName $FQDN -MaxItems 1
	if($RecordSets.ResourceRecordSets.Name -ne "$FQDN." -and $RecordSets.ResourceRecordSets.ResourceRecords.Value -ne $FQDN)
	{
		$CurIteration+=1;
		Write-Output "Waiting before trying to verify that DNS record was created... "
		Start-Sleep -Seconds 2;
	}
	else
	{
		#Record was created successfully
		$Confirmed = $true;
		Write-Output "Record: $FQDN was successfully created w/ $IPAddress!"
	}

}
while($CurIteration -lt 60 -and $Confirmed -eq $false)

if($CurIteration -ge 60)
{
	Write-Output "Failed to detect whether or not DNS record was created. Process has timed-out.";
	pause;
}