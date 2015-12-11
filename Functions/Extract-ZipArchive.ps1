
<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2015 v4.2.89
	 Created on:   	12/01/2015 1:00 PM
	 Created by:   	Marcus Bastian
	 Filename:     	Extract-ZipArchive.ps1
	===========================================================================

	.DESCRIPTION
		 Extracts the provided zip archive into the destination provided.. 

    .OUTPUT:

         All files extracted  = $true
         Failed to extract    = $false
         No items in archive  = $null
#>

function Extract-ZipArchive ($PathToZip,$destination) 
{ 
    # Extracts the provided zip archive into the destination provided..
    
    # Possible output:
    #
    #    All files extracted = $true
    #    Failed to extract   = $false
    #    No items in archive = $null
    
	$shellApplication = new-object -com shell.application 
	$zipPackage = $shellApplication.NameSpace($PathToZip)

	write-verbose "$PathToZip"

    $countBefore = (gci $destinationFolder -ea SilentlyContinue | measure-object).Count;
    write-verbose "$countBefore folders in destination directory before extracting zip. "
    
    $destinationFolder = $shellApplication.NameSpace($destination) 

    write-verbose "Extracting to $DestinationFolder";
    write-verbose $ZipPackage

    if($zipPackage)
    {
        # extract files
        $destinationFolder.CopyHere($zipPackage.Items(), 20)

        $countAfter = (gci $destinationFolder -ea SilentlyContinue | measure-object).Count;
        write-verbose "$countBefore folders in destination directory after extracting zip. "

        if($countAfter -eq $countBefore)
        {
            write-error "Could not find extracted files in desired destination after attempting to extract."
            return $false;
        }
        else
        {
            return $true;
        }
    }
    {
        # no items in archive
        return $null;
    }
	
}

$ZipFilePath = "C:\Users\ByteEater\Desktop\movies.zip";
$Dest = "C:\Users\ByteEater\Desktop\"

Extract-ZipArchive –PathToZip $ZipFilePath -Destination $dest
