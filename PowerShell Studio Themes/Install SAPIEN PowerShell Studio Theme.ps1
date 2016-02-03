function Download-FileFromURL ($url, $saveAs)
{
	$webclient = New-Object System.net.WebClient;
	$webclient.DownloadFile($url, $saveAs);
	
	if (Test-Path $saveAs)
	{
		return $true;
	}
	else
	{
		return $false;
	}
	
	
}

$URL = "https://gitlab.com/ByteEater/powershell-fun/blob/master/PowerShell%20Studio%20Themes/Dark%20Matrix.preset";
$SapienAppDataPath = "$env:AppData\Roaming\SAPIEN\PowerShell Studio 2015\Editor Presets";

if (-not (test-path $SapienAppDataPath))
{
    New-Item -ItemType Directory -Path $SapienAppDataPath -ev newitemError;
}

if ($newitemError)
{
    Write-Error "Failed to create Editor Presets directory in: $SapienAppDataPath";
    return;
}
else
{
    $Downloadresult = Download-FileFromURL $URL "$SapienAppDataPath\DarkMatrix.preset"
}

if ($Downloadresult)
{
    Write-Host "Successfully installed PowerShell Studio Preset!" -ForegroundColor Green
}
else
{
    Write-Error "Failed to install PowerShell Studio Preset!";
}

Read-Host "Hit any key to exit.";
exit;