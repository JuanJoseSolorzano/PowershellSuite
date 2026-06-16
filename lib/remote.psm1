
$SUITE_PATH = "C:\LegacyApp\Powershell_Suite" 

function Save-Credentials{
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$PC_HOST,[Parameter(Mandatory=$true)][string]$user,[Parameter(Mandatory=$true)][string]$pass)
    try{
        cmdkey /add:$PC_HOST /user:$user /pass:$pass
        Write-Host "[+] Credentials saved successfully for $PC_HOST"    
    }catch {
        Write-Host "Error: $($_.Exception.Message)"
    }
    
}

function Remote {
    [CmdletBinding()]
    param ([Parameter(Mandatory=$true)][string]$PCName,[switch]$GetHost,[switch]$HostOnly,[switch]$AllScreens)
    if(-not $HostOnly){
        Write-Host "Connecting to $PCName..."
        if(Test-Path -Path "$SUITE_PATH\lib\utils\configurations.json"){
	        # Read the configurations.json file to get the repository link or the repository name.
	        $conf = Get-Content -Path "$SUITE_PATH\lib\utils\configurations.json" -Raw | ConvertFrom-Json	
	    	$PCHost = $conf.RemoteHosts.PSObject.Properties | Where-Object { $_.Name -eq $PCName} | Select-Object -ExpandProperty Value
	    }else {
	    	Write-Host "[!] >> The configurations.json file does not exist in the expected path."
	    	return
	    }
    }else{
        $PCHost = $PCName
    }
    if($GetHost) {
        Set-Clipboard $PCHost
        Write-Host "[+] Host name copied to clipboard."
        Write-Host "The host name is: $PCHost"
        return
    }
    
    try{
        if($AllScreens){
            mstsc /v:$PCHost /span
        }
        else {
            mstsc /v:$PCHost
        }
    }catch {
        Write-Host "Error: $($_.Exception.Message)"
    } 
}

