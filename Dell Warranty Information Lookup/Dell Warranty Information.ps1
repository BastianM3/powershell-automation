#Grabs the Model
$Model = (Get-ItemProperty "HKLM:\HARDWARE\DESCRIPTION\System\BIOS").systemsku
#Grabs the Serial
$Serial = (Get-WmiObject Win32_Bios).SerialNumber
#Builds the link
$link = "http://h10025.www1.hp.com/ewfrf/wc/weInput?cc=us&lc=en"
#Opens IE and grabs the results

$ie = new-object -com "InternetExplorer.Application"
$ie.navigate($link)
$ie.visible = $false
while($ie.busy) {sleep 1}
$ie.Document.getElementByID('serialnum').value = $Serial
$ie.Document.getElementByID('prodname').value = $Model
$ie.Document.getElementByID('Continue').Click()

While($ie.Document.URL –notlike ‘*http://h10025.www1.hp.com/ewfrf/wc/weResults*’) { sleep 1 }

[string]$Contents = $ie.Document.body.innerHTML;
$Precursor = $Contents.IndexOf("&nbsp;(YYYY-MM-DD)");
$EndDate = $Contents.Substring($Precursor - 10, 10);

Write-Output $EndDate;


