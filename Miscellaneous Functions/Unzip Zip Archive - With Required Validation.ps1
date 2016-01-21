function Unzip-Archive
{
	param
	(
		[Parameter(Mandatory = $true)]
		[string]
		$zipPath,
		[Parameter(Mandatory = $true)]
		[string]
		$ExtractToDirectory
	)
	
	$FilesBefore = (Get-ChildItem $ExtractToDirectory -ea SilentlyContinue | Measure-Object).Count;
	
	if (Test-Path $zipPath)
	{
		$shellApplication = new-object -com shell.application
		$zipPackage = $shellApplication.NameSpace($ZipPath)
		$destinationFolder = $shellApplication.NameSpace($ExtractToDirectory)
		$destinationFolder.CopyHere($zipPackage.Items(), 20)
		
		$FilesThatFailedToCopy = 0;
		
		foreach ($File in $zipPackage.items())
		{
			$FileName = ($File | select name).Name;
			if (-not (Test-Path "$($destinationfolder.self.path)\$FileName"))
			{
				Write-Error "Failed to extract $FileName!"
				$FilesThatFailedToCopy += 1;
			}
			else
			{
				Write-Verbose "Successfully extracted $FileName"	
			}
		}

		if ($FilesThatFailedToCopy -eq 0)
		{
			return $true;
		}
		else
		{
			return $false;
		}
	}
	else
	{
		Write-Error "Unable to locate archive specified for extraction."
		return $false;
	}
}


# Where is the zip file?
$ArchiveLocation = "$env:USERPROFILE\desktop\SomeZip.zip"

# What directory should we extract it to?
$ExtractToPath = "$env:windir\temp\MyArchive"

# If the directory specified for extraction doesn't exist, create it.
new-item -ItemType Directory -Path $ExtractToPath -ea SilentlyContinue | out-null

if (-not (Test-Path $ExtractToPath))
{
	Write-Output "Failed to create temporary directory used for storing extracted files!"
	return;
}

$Result = Unzip-Archive $ArchiveLocation $ExtractToPath

if ($Result -eq $true)
{
	Write-Output "Files extracted successfully!"
}
else
{
	Write-Output "Files failed to extract!"
}




