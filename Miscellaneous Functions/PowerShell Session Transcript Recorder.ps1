
function Initialize-Transcript
{
	<#
	.SYNOPSIS
		Manages the starting, stopping and results retrieval of your PowerShell transcript.
	
	.DESCRIPTION
		Starts and stops a transcript within the current PowerShell session. 
	
		If a transcript is already started, any subsequent calls will stop the transcript 
		and return the contents of the temporarily created file. 
	
		The temp file will be removed after its' contents have been yielded.
	
	.NOTES
		This function prevents you from having to create a temporary file when you start your transcript.
		
#>
	if (!$script:transcriptPath)
	{
		# Wish start-transcript returned an object instead of a string... but that's what Regex is for!
		$startedTranscript = Start-Transcript;
		
		# Regex out path. I want to let PowerShell create a temporary file for me
		$startedTranscript -match "(?=[\w]:\\)(.*)(?:.txt)" | out-null
		$filePath = $Matches[0];
		
		if (!$filePath)
		{
			return $null;
		}
		else
		{
			# store file path to transcript file into variable for
			# access in second execution
			$script:transcriptPath = $filePath;
		}
	}
	else
	{
		# transcript already started. Stop it now
		Stop-Transcript -ea SilentlyContinue | Out-Null;
		#$return = Get-Content $script:transcriptPath | out-string;
		$return = [System.IO.File]::ReadAllText($script:transcriptPath).Replace("\", "\\").Replace("`r`n", "\n").Replace("`n", "\n").Replace("`r", "\n").Replace("`t", "\t").Trim();
		
		Remove-Item $script:transcriptPath;
		return $return;
		
	}
}