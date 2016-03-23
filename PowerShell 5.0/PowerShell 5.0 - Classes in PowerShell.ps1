#Requires -version 5.0

class Vehicle 
{
    [string]$Manufacturer
    [string]$ModelName
    [int]$Year

    Vehicle($Manufacturer, $ModelName, $year )
    {
        $this.Manufacturer = $Manufacturer
        $this.ModelName    = $ModelName
        $this.Year         = $year
    }

    hidden [int] $speed

    [void] IncreaseThrottle()
    {
        $this.Speed++;
    }

    [int] GetSpeed()
    {
        return $this.Speed;
    }
}

# Instantiate an object using the constructor defined in the PowerShell 5.0 class above
$myVehicle = new-object Vehicle("Ford","Edge",2005);

for($i =0; $i -lt 50; $i ++)
{
    $myVehicle.IncreaseThrottle();
}

# Call method that returns the current value of the hidden $speed member.
$myVehicle.GetSpeed();

