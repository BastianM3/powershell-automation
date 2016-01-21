# Calculate the recommended @@innodb_buffer_pool_size based upon a sliding memory scale
$Memory = [math]::ceiling((gwmi -class win32_ComputerSystem).TotalPhysicalMemory / 1024 / 1024);
switch ($Memory)
    {
		{ ($_ -lt 4000) } { $Allocation = $_*.25; write-output "$($Allocation)M"; }
        { ($_ -GE 4000 -AND  $_ -LE 7999) } { $Allocation = $_*.37; write-output "$($Allocation)M"; }
        {($_ -GE 8000 -AND  $_ -LE 31999) } { $Allocation = $_*.5; write-output "$($Allocation)M"; }
        {($_ -GE 32000 -AND  $_ -LE 47999) } { $Allocation = $_*.75; write-output "$($Allocation)M" }
        { $_ -GE 48000 } { $Allocation = ($_*.8); write-output "$($Allocation)M" }
        default { $Allocation = "1024"; write-output '1G' }
    }
	
	