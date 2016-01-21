#Requires -Module AWSPowerShell
$AwsRegion = 'us-east-1';

$AccessKey = "YourAccessKey";
$SecretKey = "YoursecretKey";
$OriginS3_Bucket = "mybucket";
$S3_Obj_Key = "a_folder_under_bucket/filename.extension"

# Choose the number of days your would like this URL to be valid for
$DaysUntilExpiration = 5;
$ExpirationDate = [string]"{0:yyyy-MM-dd}T23:59:59" -f (get-date).AddDays($DaysUntilExpiration);

import-module AWSPowerShell;

set-defaultAWSRegion $AwsRegion;
set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey;

try
{
	$URL = get-s3presignedURL -bucket $OriginS3_Bucket -key $S3_Obj_Key -expires $expirationdate;
}
catch
{
	$FailureException = $_.Exception.Message;
	Write-Output "Failed to generate the pre-signed url for item: $OriginS3_Bucket/$S3_Obj_Key due to the following exception $FailureException";
	return;
}

write-output $URL;