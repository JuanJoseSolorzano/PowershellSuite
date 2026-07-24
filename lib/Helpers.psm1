#REQUIRES -Version 1.0
<#
.SYNOPSIS
	Helpers is a module created to facilte commands in powershell.
.DESCRIPTION
	There are many commands that you can use with the powershell profile.
.NOTES
    File Name      : GitComCom.psm1
    Author         : Solorzano, Juan Jose
    Prerequisite   : PowerShell V 1.0
#>

# Define ANSI escape codes for colors
$RESET = "`e[0m"
$RED = "`e[31m"
$GREEN = "`e[32m"
$GRAY = "`e[37m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$MAGENTA = "`e[38;5;13m"
$CYAN = "`e[36m"
$WHITE = "`e[37m"
$BLACK = "`e[30m"
$BOLD = "`e[1m"
# Constants 
$HELP = "${YELLOW}[?] Usage:`n    ${GREEN}PS> {0}${MAGENTA} {1}${RESET}"
$POWERSHELL = "\PowerShell\"

function ps1_location {
	$currentLocation = Get-Location
	$isRepo = (test-path -Path ".git") -or (git rev-parse --abbrev-ref HEAD)
	if($currentLocation.Path -like $HOME) {
		return "🏠"
	}
	if($currentLocation.Path -like "C:\LegacyApp*") {
		$relativePath = $currentLocation.Path.Substring($currentLocation.Path.IndexOf("C:\LegacyApp") + "C:\LegacyApp".Length)
		return "$($BOLD)🐧$relativePath$($RESET)"
	}
	if($currentLocation.Path -like "*GitHub*") {
		$relativePath = $currentLocation.Path.Substring($currentLocation.Path.IndexOf("GitHub") + "GitHub".Length)
		return "$($BOLD) $relativePath$($RESET)"
	}
	if($currentLocation.Path -like "*OneDrive*") {
		$relativePath = $currentLocation.Path.Substring($currentLocation.Path.IndexOf("OneDrive") + "OneDrive".Length)
		return "$($BOLD)☁ $relativePath$($RESET)"
	}
	if($currentLocation.Path -like "*Documents*") {
		$relativePath = $currentLocation.Path.Substring($currentLocation.Path.IndexOf("Documents") + "Documents".Length)
		return "$($BOLD)📄 $relativePath$($RESET)"
	}
	if($currentLocation.Path.ToLower() -like "*vt.prj.*" -or $currentLocation.Path.ToLower() -like "*gmg*") {
		try{
			$config = Get-Content -Path "$SUITE_PATH\lib\utils\configurations.json" -Raw | ConvertFrom-Json
			$suiteName = $config.TA_SUITES.PSObject.Properties | Where-Object { $currentLocation.Path -like "*$($_.Value)*" } | Select-Object -ExpandProperty Value
			$relativePath = $currentLocation.Path.Substring($currentLocation.Path.IndexOf($suiteName) + $suiteName.Length)
			if(-not $suiteName) {
				$suiteName = "Unknown-Suite"
			}
			if($suiteName.ToUpper() -eq "GMG") {
				$firstFolderName = $relativePath.split("\")[0]
				$suiteName = "GMG$firstFolderName"
				$relativePath = $relativePath.Substring($firstFolderName.Length)	
			}
			return "$($BOLD)[$suiteName]$relativePath$($RESET)"
		}catch{
			return "⚠️$($BOLD)$(Get-Location)$($RESET)"
		}	
	}
	return "$($BOLD)$(Get-Location)$($RESET)"
}

function ps1_newstyle {
    $esc = [char]27
    $reset = "$esc[0m"
    $location = ps1_location
    $branchName = Write-BranchName2
    $seg1 = "$esc[48;2;116;199;236m$esc[38;2;30;30;46m  "
    $seg2 = "$esc[48;2;180;190;254m$esc[38;2;17;17;27m  $location"
    $seg3 = "$esc[38;2;180;190;254m$esc[48;2;166;227;161m$esc[38;2;30;30;46m$branchName $esc[0m$esc[38;2;166;227;161m$reset"

    Write-Host "$seg1$seg2$seg3"
}

<#
.SYNOPSIS
	This function returns the CPU current usage.
#>
function Get-CpuUsage {
	param([switch]$showProcess)
  	$usage=[math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue,2)
  	$mem = Get-CimInstance Win32_OperatingSystem
  	$memory = [math]::Round((($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / $mem.TotalVisibleMemorySize) * 100, 2)
  	Write-Host "======================================================="
  	Write-Host "          -       Cumputer Usage         -"
  	Write-Host "======================================================="
  	Write-Host "CPU: $usage%"
  	Write-Host "Memory: $memory%"
  	if($showProcess){
		Get-CimInstance Win32_Process | 
		Select-Object Name, @{Name="MemoryUsageMB"; Expression={[math]::Round($_.WorkingSetSize / 1MB, 2)}} |
		Sort-Object MemoryUsageMB -Descending | Select-Object -First 15 Name, MemoryUsageMB
  	}
}

<#
.SYNOPSIS
	This function removes a process by its name. This function avoids the to use the Kill -ProcessName cmdlet.
#>
function Del-Process {
	param([Parameter(Mandatory=$true)][string]$name,[switch]$h)

	if($h){
		Write-Host "$($HELP -f 'Del-Process','[-name <process name>] [-h <help>]')"
		return
	}
	if($name.Contains('.')){
		$name = $name.split('.')[0]
	}
	try {
		kill -processName $name
		Write-Host "[+] The process `"$name`" was removed."
	}
	catch {
		Write-Host "[!] Error: $name is still running ..."
	}
}

function mktemp {
	[CmdletBinding()]
	param([string]$name,[switch]$go,[switch]$file)
	$tmpPath = [System.IO.Path]::GetTempPath()
	if(-not $name){
		$tmpName="temp_folder"
		Remove-Item -Force -Recurse -Path "$tmpPath\$tmpName" 2>$null
	}
	else{$tmpName = $name}
	$rootTempPath = Join-Path $tmpPath $tmpName
	New-Item -Path $rootTempPath -ItemType Directory > $null
	if($file){
		$fName="$(Get-Random)"
		New-Item -ItemType file -Name $fName -Path $rootTempPath 1>$null
		return "$rootTempPath\$fName"
	}else{
		return $rootTempPath
	}
	if($go){set-location $rootTempPath}
}

function set-note {
	param([string]$head,[string]$note,[switch]$nvim)
	if(-not $head){
		$head="[General]"
	}
	if($nvim){
		$path = mktemp -file
		nvim $path
		$note = Get-Content -Delimiter "`n`t" $path
	}
	if($note){
		$outlook = New-Object -ComObject Outlook.Application
		$appointment = $outlook.CreateItem(1)
		$appointment.Subject = "[NOTES]$head".ToUpper()
		$appointment.Body = $note
		$appointment.AllDayEvent = $true
		$appointment.ReminderSet = $false
		$appointment.Save()
		$appointment = $null
		$outlook = $null
	}else{
		Write-Host "[!] The content note is necessary."
	}
}

function get-notes {
	[CmdletBinding()]
	param([string]$prj,[string]$date,[switch]$today,[switch]$month,[switch]$h)
	$outlook = New-Object -ComObject Outlook.Application
	$namespace = $outlook.GetNamespace("MAPI")
	$calendarFolder = $namespace.GetDefaultFolder(9) # 9 corresponds to olFolderCalendar
	if($h){
		Write-Host "> Get-Logwork -date '2023-10-25'"
		return
	}
	if(-not $date){
		$date=Get-Date
		$specific_date=$false
	}else{
		$specific_date=$true
	}
	$calendarItems = $calendarFolder.Items
	$calendarItems.Sort("[Start]")
	$calendarItems.IncludeRecurrences = $true
	if($month){
		$monthStart = Get-Date -Year (Get-Date).Year -Month (Get-Date).Month -Day 1
		$monthEnd = $monthStart.AddMonths(1)
		# Create a filter to get appointments for the current month
		$filter = "[Start] >= '" + $monthStart.ToString("g") + "' AND [Start] < '" + $monthEnd.ToString("g") + "'"
	}
	elseif($today){
		$dayStart = Get-Date -Year (Get-Date).Year -Month (Get-Date).Month -Day (Get-Date).Day -Hour 00 -Minute 00 -Second 5
		$dayEnd = Get-Date -Year (Get-Date).Year -Month (Get-Date).Month -Day (Get-Date).Day -Hour 23 -Minute 59 -Second 5
		write-host "TODAY: $dayStart"
		write-host "end: $dayEnd"
		# Create a filter to get appointments for the specific date
		$filter = "[Start] >= '" + $dayStart.ToString("g") + "' AND [Start] < '" + $dayEnd.ToString("g") + "'"
	}else{
		$yearStart = Get-Date -Year (Get-Date).Year -Month 1 -Day 1
		$yearEnd = Get-Date -Year (Get-Date).Year -Month 12 -Day 31 -Hour 23 -Minute 59 -Second 5
		# Create a filter to get appointments for the current year
		$filter = "[Start] >= '" + $yearStart.ToString("g") + "' AND [Start] < '" + $yearEnd.ToString("g") + "'"
	}
	$filteredItems = $calendarItems.Restrict($filter)
	# Initialize arrays to hold all-day and normal appointments
	$allDayAppointments = @()
	foreach($appointment in $filteredItems) {
    	if ($appointment.AllDayEvent -eq $true) {
        	$allDayAppointments += $appointment
    	}
	}
	# return
	$ret = ""
	if(-not $prj){
		foreach ($appointment in $allDayAppointments) {
			if($specific_date){
				$event_date = Get-Date "$($appointment.Start.ToString().Split(" ").Get(0))"
				$target_date = [datetime]::ParseExact($date, 'dd-MM-yyyy', $null)
				if($event_date -eq $target_date){
					$ret += "$($appointment.Subject) - $($appointment.Start.ToString().Split(" ").Get(0))`n"
					$ret += "$($appointment.Body)`n"
					$ret += "---------------------------------`n"
				}
			}else{
				$ret += "$($appointment.Subject) - $($appointment.Start.ToString().Split(" ").Get(0))`n"
				$ret += "$($appointment.Body)`n"
				$ret += "---------------------------------`n"
			}
		}	
	}else{
		foreach($appointment in $allDayAppointments) {
			if($appointment.Subject.Contains($prj.ToUpper())){
				if($specific_date){
					$event_date = Get-Date "$($appointment.Start.ToString().Split(" ").Get(0))"
					$target_date = [datetime]::ParseExact($date, 'dd-MM-yyyy', $null)
					if($event_date -eq $target_date){
						$ret += "$($appointment.Subject) - $($appointment.Start.ToString().Split(" ").Get(0))`n"
						$ret += "$($appointment.Body)`n"
						$ret += "---------------------------------`n"
					}
				}else{
					$ret += "$($appointment.Subject) - $($appointment.Start.ToString().Split(" ").Get(0))`n"
					$ret += "$($appointment.Body)`n"
					$ret += "---------------------------------`n"
				}
			}
		}
	}
	return $ret
}

function deprecated_notes{
    [CmdletBinding()]
    param([string]$data,
          [string]$date,
		  [string]$grep,
          [switch]$open,
          [string]$go,
          [switch]$ls,
          [string]$get,
          [switch]$b,
          [string]$prj)
    $availableProjects = @("fc1","fb0","l30","l40","g70","g80","general")
    $notesPath = "C:\Users\uiv06924\OneDrive - Vitesco Technologies\mynotes\"
    function help {Write-Host "$> notes -prj [$availableProjects]"}
    $currLocation = (Get-Location).Path
    if($go){
		if($go -eq "."){set-location $notesPath}
		else{Set-Location $notesPath$go}
		return
	}
    elseif(-not $prj -and -not $get) {help; return}
    if($prj -and -not $get){
        $prj = $prj.ToLower()
        # WRITE NOTES
        if($availableProjects.Contains($prj)){
            if ($ls){Get-ChildItem "$notesPath$prj";return}
            Set-Location "$notesPath$prj"
            $currentDate = (Get-Date -Format "dd_MM_yyyy").ToString()
            $dayNote = $currentDate+".txt"
            if(Test-Path $dayNote){
                nvim $dayNote
            }else{
                New-Item -ItemType file -Name $dayNote
                nvim $dayNote
            }
        }else{Write-Host "Project `"$prj`" not found."}
    }
    # GET NOTES DATA
    elseif($get){
        Set-Location "$notesPath$get"
        if($date){
            $dayFormated = $("$date-$(get-date -Format "yyyy")").ToString().Replace("-","_")
            $dateNote=$dayFormated+".txt"
            if(Test-Path $dateNote){
                if($b){bat $dateNote}else{cat $dateNote}
            }else{Write-Host "No date note found."}
        }else{
            $currentDate = (Get-Date -Format "dd_MM_yyyy").ToString()+".txt"
            if(Test-Path $currentDate){
                if($b){bat $currentDate}else{cat $currentDate}
            }else{Write-Host "Nothing to read ..."}
        }
    }
	elseif($grep){
		
	}
	else{Write-Host "Project `"$prj`" not found."}
    Set-Location $currLocation
}

function whatis {
	[CmdletBinding()]
	param([string]$word,[switch]$pronunce)
	if(-not $word){Write-Host "Usage: `n>> whatis -word 'any' -pronunce[optional]";return}
	$response = Invoke-WebRequest -Uri "https://api.dictionaryapi.dev/api/v2/entries/en/$word"
	$meaning = ($response.Content | ConvertFrom-Json -Depth 1000).meanings
	Write-Host $meaning.definitions.definition	
	Write-Host "[?] Synonyms:"
	Write-Host $meaning.synonyms
	if($pronunce){
		$phonetics = ($response.Content | ConvertFrom-Json -Depth 1000).phonetics
		google $phonetics.audio.get(1)
	}
}

function Set-Logwork {
	[CmdletBinding()]
	param([string]$title,[string]$start,[string]$end,[string]$note)
	try {
	    $outlook = New-Object -ComObject Outlook.Application
	} catch {
	    Write-Host "Error: Unable to start Outlook. Ensure it is installed."
		return
	}
	if(-not $start.Contains(":")){
		$start = "$start"+":00"
	}
	if(-not $end.Contains(":")){
		$end = "$end"+":00"
	}
	$date = Get-Date
	$start_date = Get-Date "$($date.Year)-$($date.Month.ToString("00"))-$($date.Day.ToString("00")) $start"
	$end_date = Get-Date "$($date.Year)-$($date.Month.ToString("00"))-$($date.Day.ToString("00")) $end"
	# Create a new appointment item
	$appointment = $outlook.CreateItem(1) # 1 indicates an AppointmentItem
	# Set the appointment properties
	$appointment.Subject = "$title"
	$appointment.Body = "NOTES: `n$note"   
	$appointment.Start = $start_date
	$appointment.End = $end_date
	$appointment.ReminderSet = $false                                             
	#$appointment.ReminderMinutesBeforeStart = 15                                     
	$appointment.Save()
	$appointment = $null
	# Optionally, you can quit Outlook if you opened it
	# $outlook.Quit()  # Uncomment to close Outlook
	$outlook = $null
	Write-Host ">> Work Logged"
}

function Get-Logwork {
	[CmdletBinding()]
	param([string]$date,[switch]$h)
	if($h){
		Write-Host "> Get-Logwork -date '2023-10-25'"
		return
	}
	if(-not $date){
		$date=Get-Date
	}
	write-host "===================================================================="
	write-host "  		  TIME WORKED"
	write-host "===================================================================="
	# Create an Outlook Application COM object
	$outlook = New-Object -ComObject Outlook.Application
	$namespace = $outlook.GetNamespace("MAPI")
	$calendarFolder = $namespace.GetDefaultFolder(9) # 9 corresponds to olFolderCalendar
	$specificDate = Get-Date $date # Change this to your desired date
	$start = $specificDate.Date
	$end = $specificDate.Date.AddDays(1)
	$calendarItems = $calendarFolder.Items
	$calendarItems.Sort("[Start]")
	$calendarItems.IncludeRecurrences = $true
	$results = @()  # Initialize as an empty array
	$totalDuration = [System.TimeSpan]::Zero
	$filter = "[Start] >= '" + $start.ToString("g") + "' AND [Start] < '" + $end.ToString("g") + "'"
	$filteredItems = $calendarItems.Restrict($filter)
	$bms_time = 0
	$ecu_time = 0
	# Iterate through filtered appointments and output details
	foreach ($item in $filteredItems) {
		if($item.Subject.Contains("[BMS]") -or $item.Subject.Contains("[ECU]") -and -not $item.Subject.Contains("[NOTES]")){
	    	$duration = $item.End - $item.Start
			if($item.Subject.Contains("[BMS]")){
				$bms_time += $duration
			}elseif($item.Subject.Contains("[ECU]")){
				$ecu_time += $duration
			}
			$totalDuration += $duration
			$result = [PSCustomObject]@{
            Subject  = $item.Subject
            Duration = $duration
			Note = $item.Body}
        	$results += $result
		}
	}
	$sortedResults = $results | Sort-Object {
    	if ($_.Subject -like "*[BMS]*") { 0 }
    	elseif ($_.Subject -like "*[ECU]*") { 1 }
    	else { 2 }
	}, { $_.Subject }  # Optionally sort alphabetically within groups

	if ($sortedResults.Count -gt 0) {
	    $sortedResults | Format-Table -AutoSize
		Write-Host " BMS: $bms_time"
		Write-Host " ECU: $ecu_time"
		Write-Host " Total: $totalDuration"
	} else {
	    Write-Output "No appointments found with the specified criteria."
	}
	write-host "===================================================================="
}

function temp {
	cd "$($home)\temp"
}

function BinToDec{
	param($value,[switch]$ToHex)
	$output = [convert]::ToInt32($value, 2)
	if($ToHex){
		return "0x$([convert]::ToString($output, 16))"
	}
	else {
		return $output
	}
}

function DecToBin {
	param($value,[switch]$ToHex)
	$output = [convert]::ToString($value, 2)
	if($ToHex){
		return BinToDec $output -ToHex
	}
	else {
		return "b$output"
	}
}

function Sum-Num {
	param([string[]]$parameters)
	return ($parameters | measure -sum).sum
}

function net {
    [CmdletBinding()]
    $command = $args
    $process = Start-Process -NoNewWindow -File C:\LegacyApp\dotnet8\dotnet.exe -ArgumentList $command -PassThru -Wait
    # Wait for the process to complete
    $process.WaitForExit()
    # Check the exit code
    if ($process.ExitCode -ne 0) {
        Write-Host "Command failed with exit code: $($process.ExitCode)"
    }
}

function recycle{
    [CmdletBinding()]
    param([switch]$rmAll,[switch]$l)
    $shellComO = New-Object -ComObject Shell.Application
    $recycleF = $shellComO.Namespace(10)
    if($l){
        $recycleF.Items() | ForEach-Object{$_.Name}
    }
    elseif ($rmAll) {
        Clear-RecycleBin -Confirm:$false
    }
    else {
        Write-Host "$($HELP -f 'recycle','[-l <list items>] [-rmAll <Clear RecycleBin>]')"
    }
}

function del-pyc {
    $pycPath = Get-ChildItem -Recurse -Include "*.pyc"
    $pycachePath = Get-ChildItem -Recurse -Directory -Filter "__pycache__"
    if ($pycPath -or $pycachePath) {
        $pycPath | Remove-Item -Force
        $pycachePath | Remove-Item -Recurse -Force
        Start-Sleep -Seconds 1
    	Clear-Host
		Start-Sleep -Seconds 1
        echo "[+] Python cache files and directories removed."
    } else {
        echo "[!] No Python cache data found."
    }
}

function bat{
	param([string]$file,[string]$l)
	$script_py = $(Get-ChildItem -Path "." -Recurse -Filter "bat.py").FullName	
	if(-not $file_path){
		Write-Host "[!] bat.py not found in the current directory."
		return
	}
  	if($l){
  	    C:/LegacyApp/Python39/python.exe $file $script_py $l
  	}
  	else{
  	    C:/LegacyApp/Python39/python.exe $script_py $file
  	}
}

function rec2json {
	[CmdletBinding()]
	param (
		[string]$file,
		[switch]$plot,
		[switch]$show
	)
	if($plot -And $show){
		C:\LegacyApp\Python39\python3.exe $home\rec2json.py $file --plot --show
	}
	elseif($show){
		echo "show"
		C:\LegacyApp\Python39\python3.exe $home\rec2json.py $file --show
	}
	elseif($plot){
		C:\LegacyApp\Python39\python3.exe $home\rec2json.py $file --plot
	}
	else{
		C:\LegacyApp\Python39\python3.exe $home\rec2json.py $file
	}
}

function profile{
	[CmdletBinding()]
	param([switch]$go)
	$path = "$($home)\PowerShell"
	if($go){
		set-location $path	
	}else{
	return $path
	}
}

function del-recurse($item){
	$command = "del $item /s"
	Start-Process -NoNewWindow -FilePath "cmd.exe" -ArgumentList "/C", $command
    Clear-Host
}

function rm-readonly{
    Set-ItemProperty -Path "." -Name Attributes -Value ((Get-Item ".").Attributes -band -not [System.IO.FileAttributes]::ReadOnly)
}

function rc {
	#!/usr/bin/env pwsh
	echo "`e[6 q"
}

function bash {
    $curr_location = get-location
    $curr_location = $curr_location.path
    &"C:\Program Files\Git\bin\bash.exe"
    set-location $curr_location
}

function Edge($page) {
	try {
		$temp_dir = Get-Location
		Set-Location "C:\Program Files (x86)\Microsoft\Edge\Application\"
		Start-Process "msedge.exe" $page 
		Set-Location $temp_dir.Path
	}
	catch {
		Start-Process "msedge.exe"
		Set-Location $temp_dir.Path
	}
}

function Google($page) {
	try {
		$temp_dir = Get-Location
		Set-Location "C:\Program Files\Google\Chrome\Application\"
		Start-Process "chrome.exe" $page 
		Set-Location $temp_dir.Path
	}
	catch {
		Start-Process "chrome.exe"
		Set-Location $temp_dir.Path
	}
}

function Mlink ($target, $link){
	New-Item -Force -Path $link -ItemType SymbolicLink -Value $target
}

function b($n){

	$back_patern = '../'
	$multiplier = $n
	# Empty string to store the result.
	$total_back = ''

	if($null -eq $n){
		Set-Location $back_patern
	}
	else{
		# Repeating the string.
		for ($i = 1; $i -le $multiplier; $i++) {
		    $total_back += $back_patern
		}
		Set-Location $total_back
	}
}

function ll {
	Get-ChildItem -Force | Sort-Object Extension
}

function note ($file){
	C:\LegacyApp\Notepad++\notepad++.exe $file
}

function re {
	pwsh.exe
    echo "`e[6 q"
}

function eclipse ($file){
	if($null -eq $file){
		Start-Process "C:\LegacyApp\Eclipse_Contest\eclipse.exe"
	}
	else{
		Start-Process "C:\LegacyApp\Eclipse_Contest\eclipse.exe" $file
	}
}

function delete ($item){
    rm -Force -Recurse $item
}

function edit-globals {
	start-Process C:\WINDOWS\system32\rundll32.exe sysdm.cpl,EditEnvironmentVariables
}

function prj{
	[CmdletBinding()]
    param([string]$name,[string]$opt,[switch]$go)
	$projects = "d:/GitHub"
    function showDirOptions($directories,$opt) {
        Write-Host "${YELLOW}[!] ${CYAN}The project name given has multiple locations."
            $idx = 0
            foreach($location in $directories){
                Write-Host "  ${MAGENTA}[$idx] ${GREEN}$location"
                $idx++
            }
            $usr_selection = Read-Host "${YELLOW}[?]${CYAN} Which folder?${RESET}"
			$selection = [int]$usr_selection
		    if($directories){
                $dir = $directories.Item($selection)
				if($opt -eq "ls"){
					ls $dir
					return
				}
                if($go){
                    set-location (Get-ChildItem -Path $dir | Where-Object { $_.PSIsContainer -and $_.Name -eq "$bms_suite" }).FullName
                }
                else{
                    set-location $dir
                }
            }
    }
    if($name -eq "a"){
		set-location .
		return
	}else{
        Write-Host "$($HELP -f 'prj','[-name<default>]')"
    }
}

function edge {
	param($target)
	try 
	{
	    start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" $target    
	}
	catch {
	    start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
	}	
}

#####################################################
#get the parameters by console line
#####################################################
function whereis{
	[CmdletBinding()]
    param([string]$item,[string]$path,[switch]$nV,[switch]$setClipboard)

	#Constants
	$vvv = "
		------------- Searching for < $item > -------------
		----- you can stop the search using 'ctr+c' -----
	searching...
	"
	$help_str = "Parameters:
		-item:: the file that you want to search
		-path:: the location where you want to search
		-vvv:: it shows the information"

	#Search the file.
	if($item -And -not $path){
		$ret_path = Get-ChildItem -Force -Filter $item -Recurse 2> $null
	}
	elseif($item -and $path){
		$ret_path = Get-ChildItem -Force -Path $path -Filter $item -Recurse 2> $null
	}	
	else
	{
		help $MyInvocation.MyCommand.Name
		Write-Host $help_str
	}
	##### returns #####
	if(-not $ret_path){
		return "[!]>> '$item' NOT FOUND !!!!!"
	}
	if(-not $nV){
		Write-Host $vvv
		Write-Host "Item found at:"
		if($ret_path.GetType().FullName -eq 'System.IO.FileInfo'){
			Set-Clipboard $ret_path.FullName
		}
		if($setClipboard){
			$i = 0
			foreach($_path in $ret_path){
				$i++
				Write-Host "[$i]>>"$_path.FullName
			}
			$idx = Read-Host "Select the number of the desire path"
			if($idx){
				if($ret_path[$idx-1]){Set-Clipboard $ret_path[$idx-1].FullName.trim()}
				else{"$idx not in the array."}
			}
		}else{
			return $ret_path.FullName
		}
	}
	else{
		return $ret_path.FullName
	}
}

function Get-ComMethods {
	<#
	.SYNOPSIS
	    Lists the methods and properties of a specified COM object.
	.DESCRIPTION
	    The Get-ComMethods function retrieves and displays the names of methods and properties
	    available for a given object in PowerShell. This is particularly useful for exploring COM objects,
	    such as those used for Microsoft Excel, to understand the functionalities they offer.
	.PARAMETER obj
	    [object] The COM object whose methods and properties are to be listed. This parameter is mandatory.
	.PARAMETER name
	    [string] Optional. A string that specifies the name of the object being examined. This is used for 
	    display purposes to indicate which object's methods and properties are being listed.
	.EXAMPLE
	    Get-MethodsAndProperties -obj $excel -name "Excel.Application"
	    This example lists the methods and properties of the Excel Application object.
	.EXAMPLE
	    Get-MethodsAndProperties -obj $workbooks -name "Workbooks"
	    This example lists the methods and properties of the Workbooks collection object.
	.NOTES
	    Author: Solorzano, Juan Jose
	    Version: 1.0
	#>
    param (
        [Parameter(Mandatory=$true)]
        [object]$obj,
        [string]$name = ""
    )
    Write-Host "`n$name Methods and Properties:"
    $members = $obj | Get-Member

    foreach ($member in $members) {
        if ($member.MemberType -eq "Method" -or $member.MemberType -eq "Property") {
            Write-Host $member.Name
        }
    }
}

function Get-ComObject{
	param($name)
	return New-Object -ComObject $name
}

function Insert-line($filePath,$stringToFind,$insertedString){
	# Specify the string you want to insert with a line break
	$insertedString = "`r`n$insertedString"  # Use `r`n for a line break
	$fileContent = Get-Content -Path $filePath
	# Find the line number that contains the specified string
	$lineNumber = 1
	foreach ($line in $fileContent) {
    	if ($line.contains($stringToFind)) {
        		break
    		}
    	$lineNumber++
	}
	# Check if the string was found
	if ($lineNumber -le $fileContent.Count) {
    # Insert the string with a line break after the line that contains the specified string
		if($lineNumber -eq 1){
    		$fileContent[$lineNumber - 1] += $insertedString
		}else{
			$class_name = $fileContent[$lineNumber-2]
    		$fileContent[$lineNumber - 2] += $insertedString
		}
	} else {
    	Write-Host "String '$stringToFind' not found in file."
	}
	# Write the modified content back to the file
	$fileContent | Set-Content -Path $filePath
	try {
		return $class_name.split()[1].split(':')[0].Split('(')[0]
	}
	catch {
		return
	}
}

function set-globals {
    [CmdletBinding()]
    param (
        [string]$VarName,     # The environment variable name
        [string]$Value,      # The value to set (ignored if removing)
        [string]$rm          # To indicate if we are removing the variable
    )
    if ($rm -ne $null -and $rm -ne "") {
        [System.Environment]::SetEnvironmentVariable($rm, $null, 'User')
        Remove-Item "Env:$rm" -ErrorAction SilentlyContinue
        Write-Host "Environment variable '$rm' removed."
    }
    else {
        [System.Environment]::SetEnvironmentVariable($VarName, $Value, 'User')
		Set-Variable -Name $VarName -Value $Value -Scope Global
        Write-Host "Environment variable '$VarName' set to '$Value'."
    }
}

function psgrep{
    param($string)
    Where-Object {$_.name -like "$string"}
}

function cdll {
	param($cfile,$name)
	if($cfile){
		if($name){
			$name=$name.split(".")[0]
			$dll_name="$name.dll"
		}else{
			$_cfile=$cfile.replace(".c","")
			$dll_name="$_cfile.dll"
		}
	}else{
		echo "$($HELP -f 'cdll','[<file.c>]')"
        echo "      ${YELLOW}-or: ${GREEN}gcc ${MAGENTA}-shared -o [<dll_name.dll>] [<file.c>]${RESET}"
		return
	}
	gcc -shared -o $dll_name $cfile	
	echo "[+] $dll_name created"
}

function Del-line($filePath,$stringToFind){
	# Specify the string you want to insert with a line break
	$insertedString = ""  # Use `r`n for a line break
	$fileContent = Get-Content -Path $filePath
	# Find the line number that contains the specified string
	$lineNumber = 1
	foreach ($line in $fileContent) {
    	if ($line.contains($stringToFind)) {
        		break
    		}
    	$lineNumber++
	}
	# Check if the string was found
	if ($lineNumber -le $fileContent.Count) {
    # Insert the string with a line break after the line that contains the specified string
		if($lineNumber -eq 1){
    		$fileContent[$lineNumber-1] += $insertedString
		}else{
    		$fileContent[$lineNumber - 2] += $insertedString
		}
	} else {
    	Write-Host "String '$stringToFind' not found in file."
	}
	# Write the modified content back to the file
	$fileContent | Set-Content -Path $filePath
}

function Set-PyEnv() {
	echo "*********************************************************************"
	echo "*********************************************************************"
	echo "		Wellcome to Python environment :) "
	echo "*********************************************************************"
	echo "[!] Searching for Python interperter..."
	echo " "
	Start-Sleep -Seconds 0.6
	$pythonPaths = Get-Command python*.exe -All
	$pythonPaths = $pythonPaths | Sort-Object
	if ($pythonPaths) {
		$cnt=0
	    Write-Host "Python is installed in the following locations:"
	    foreach ($path in $pythonPaths) {
	        Write-Host "  $cnt-"$path.Source
			$cnt++
	    }
		echo " "
		$interpreter = Read-Host "Select a python interperter"
		echo ""
		$tst = $pythonPaths[$interpreter].Source
		$lib = "Lib"
		$site_module = "\site.py"
		$ta_module = "\own_env.py"
		$py_exe = $pythonPaths[$interpreter].Name
		$py_rootpath = $pythonPaths[$interpreter].Source
		$py_path = $py_rootpath.replace($py_exe,'')
		$py_lib = $py_path + $lib 
		$py_lib_dir = $py_lib + $ta_module
		$site_path = $py_lib + $site_module
		$ta_file = ($PROFILE | Split-Path) + "\lib\own_env"
		cp $ta_file $py_lib_dir 
		echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo "[+] '$py_rootpath' has been updated."
		echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo ""
	} else {
	    Write-Host "Python is not installed or not in the system's PATH."
	}
}

function Get-Size{
    param([string]$item,[switch]$m,[switch]$b,[switch]$g,[switch]$h)
    if(($null -eq $item) -or $h){
       Write-Host "$($HELP -f 'Get-Size','[-item] [-m <show size in Megasbytes] [-b <show size in Bytes]')"
       return
    }
    elseif ($m) {
       echo "${YELLOW}$((gci -path $item -recurse | measure-object -property length -sum).sum /1Mb) Mb${RESET}"
    }
    elseif ($b) {
       echo "${YELLOW}$((gci -path $item -recurse | measure-object -property length -sum).sum) B${RESET}"
    }
    elseif ($g) {
       echo "${YELLOW}$((gci -path $item -recurse | measure-object -property length -sum).sum /1Gb) Gb${RESET}"
    }
    elseif ($item) {
       echo "${GREEN}$item -> ${YELLOW}$((gci -path $item -recurse | measure-object -property length -sum).sum /1Mb) Mb${RESET}"
    }
    else {
       echo "${GREEN}$(Get-Location) -> ${YELLOW}$((gci -path $item -recurse | measure-object -property length -sum).sum /1Mb) Mb${RESET}"
    }

}