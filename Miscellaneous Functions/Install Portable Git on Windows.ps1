<#
        Created by:     Marcus Bastian (ByteEater)
        Script Name:    Install Portable Git on Windows.ps1
`       .SYNOPSIS

        Downloads and installs a portable version of Git on the local machine. 

        If the installation is successful, one can find git.exe in the following location:

        $env:systemdrive\git\cmd\git.exe
        
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

    if(-not(test-path $destination))
    {
        new-item -itemType Directory $destination;
    }

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

function Install-GitForWindows
{
    $git_installer_url = "https://github.com/git-for-windows/git/releases/download/v2.10.0.windows.1/MinGit-2.10.0-32-bit.zip"
    $git_zip_save_as = "$env:windir\temp\GitInstaller_archive.zip"
    $git_installation_directory = "$env:systemdrive\git"

    invoke-webrequest -uri $git_installer_url -outfile $git_zip_save_as

    if(-not (test-path $git_zip_save_as))
    {
        write-error "Failed to download Git installer zip. Cannot proceed.";
        return $false;
    } else {
        write-verbose "Successfully downloaded portable Git archive. Proceeding to extract archive."
    }


    # Extract archive to desired Git directory

    Extract-ZipArchive -pathtoZip $git_zip_save_as -destination $git_installation_directory;

    if(!(test-path $git_installation_directory))
    {
        write-error "Failed to extract Git installer archive." 
        return $false
    } else {
        write-verbose "Successfully extracted Git installer archive."
    }

    $expected_git_exe_path = "$git_installation_directory\cmd\git.exe"
    if(test-path $expected_git_exe_path)
    {
        # a success!
        return $true
    } else {
        write-error "Git installation has failed. Unable to locate git.exe here: `t $expected_git_exe_path."
        return $false;
    }

}