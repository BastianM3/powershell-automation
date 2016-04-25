Function ReadCellData($Worksheet,$Cell)
{
    $Worksheet.Range($Cell).text
}


$VerbosePreference = 'Continue'
$type = "txt";
$nameofHost = "gmail.com";
$filePath = "C:\Users\Marcus Bastian\Desktop\Project Mailman - Missed Servers.xlsx"

# $webReq = invoke-restmethod "http://dns-api.org/$type/$nameofHost"

#open up a new instance of excel
$xl = new-object -comobject excel.application
$xl.Visible = $true
$xl.DisplayAlerts = $False

#open up a blank workbook that already exists on the desktop
#I refer to this as the $master workbook
$ExcelWorkBook = $xl.Workbooks.Open($filePath)
$ExcelWorkSheet = $xl.WorkSheets.item("sheet1")
$ExcelWorkSheet.activate()

$Row = 1

do
{

    $unpredictableFqdn = ReadCellData -Worksheet $ExcelWorkSheet -Cell "D$Row"

    If ($unpredictableFqdn -ne "")
    {
        #$fqdn = ReadCellData -Workbook $Workbook -Cell "D$Row"
        
        $cleanFqdn = $unpredictableFqdn.Replace("http://","").Replace("Https://","").Replace("www.","").TrimEnd("/").TrimEnd("\");
        Write-Verbose "Clean FQDN (Original):  $cleanFqdn"
        
        if($cleanFqdn -like '*/*')
        { 
            #$cleanFqdn = split-path $cleanFqdn;
            $cleanFqdn = $cleanFqdn.Split("/")[0]; 
            write-host "Mitigated extra junk! New = $cleanFqdn" -ForegroundColor Green 
        }
        elseif($cleanFqdn -like '*\*')
        { 

            $cleanFqdn = $cleanFqdn.Split("\")[0]; 
            write-host "Mitigated extra junk! New = $cleanFqdn" -ForegroundColor Green 
        }

        $lookupResults = Resolve-DnsName -name $cleanFqdn -Type TXT -Server 8.8.8.8 -ErrorAction SilentlyContinue;
        $numResults    = ($lookupResults | measure-object).Count;

        if($lookupResults -eq $null -or $numResults -lt 1 -or $lookupResults.TYPE -ne 'TXT')
        {
            $ExcelWorkSheet.Cells.Item($row,6) = "No SPF Record Detected"
        }
        else
        {
            $ExcelWorkSheet.Cells.Item($row,6) = $lookupResults.Strings
            $ExcelWorkSheet.Cells.Item($row,7) = "N/A";
            $ExcelWorkSheet.Cells.Item($row,8) = $lookupResults.ttl;
        }

        $Row++

    }
    else
    {
        write-verbose "$cleanFqdn"
        break
    }


} until (1 -eq 0)
 
$ExcelWorkBook.Save()
#$ExcelWorkBook.Close()
#$xl.Quit()

[System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl)

Get-Process | where {$_.Name -like “Excel*”} | % {
 $Id = $_.id
 if ((Get-WmiObject Win32_Process | ? { $_.ProcessID -eq $id } | select CommandLine) -like “*embed*”)
 {
 Stop-Process -Id $id 
 }
 }


 invoke-item $filePath

