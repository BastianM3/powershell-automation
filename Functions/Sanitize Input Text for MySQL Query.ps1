function Sanitize-VariableForMySQL {
param 
(
	[parameter(Mandatory=$true)][string]$TextToEscape
) 
    #variable to return
    $ReturnResult = "";
    	
    if($TexttoEscape)
    {
	    #First remove single backslash with double backslash
	    $PhaseOne = $TextToEscape.Replace("\","\\");

	    #Next replace single-quote with backslash single-quote
	    $ReturnResult 	= $PhaseOne.Replace("'","\'");
	}

	Return $ReturnResult;

}