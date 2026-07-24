<#
.SYNOPSIS
    PowerShell profile script for setting up the environment and importing necessary modules.

.DESCRIPTION
    This script sets up the PowerShell environment by defining color variables, clearing the console,
    importing necessary modules, and configuring the prompt and tab completion behavior.
    You can customize the behavior of the terminal by adding new modules and functions to the /Modules/Internal/ folder.

.NOTES
    Author: Solorzano, Juan Jose.
    Date: [2021-09-01]
    Version: 3.1
#>
$RESET = "`e[0m"
$RED = "`e[31m"
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$MAGENTA = "`e[1;38;5;13m"
$CYAN = "`e[36m"
$WHITE = "`e[37m"
$SUITE_PATH = "C:\LegacyApp\Powershell_Suite" # Path to the PowerShell Suite directory.
$POWERSHELL_PATH = "C:\LegacyApp\Powershell_Suite"
$INTERNAL_MODULES = @("GitComCom.psm1","Helpers.psm1","vs-suite.psm1")
$LEGACYAPP = "C:\LegacyApp" # Path to the LegacyApp directory.
$TDR = "EnDS-Test-Automation"
# Initialize the PowerShell profile.
$exe_path = Get-Location # get the current directory.
Clear-Host # clear the console.
# Import the necessary modules.
foreach($module in $INTERNAL_MODULES){
    $module_path = "$SUITE_PATH\lib\$module"
    if (Test-Path -Path $module_path) {
        Import-Module -Name $module_path -DisableNameChecking
    } else {
        Write-Host "Module $module not found in $SUITE_PATH\lib" -ForegroundColor Red
    }
}
# Global module in powershell/Modules path.
Import-Module -Name "$SUITE_PATH\Modules\git-completion\1.1.0\posh-git.psd1" -DisableNameChecking
Import-Module -Name "$SUITE_PATH\Modules\git-completion\1.1.0\posh-git.psm1" -DisableNameChecking
Import-Module Terminal-Icons
# Check if the internal modules directory exists and import them.
$hasContent = $(Get-ChildItem -Path "C:\LegacyApp\Powershell_Suite\Modules\Internal" -File)
if($hasContent){
    $internal_modules = Get-ChildItem -Path 'C:\LegacyApp\Powershell_Suite\Modules\Internal' -Filter "*.psm1" -Recurse | Where-Object { $_.PSIsContainer -eq $false }
    foreach ($module in $internal_modules) {
        Import-Module -Name $module.FullName -DisableNameChecking
    }
}
Set-Location $exe_path # return to the current directory.
# Shows the directories options.
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key Shift+Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord Ctrl+a -Function BeginningOfLine
Set-PSReadLineKeyHandler -Chord Ctrl+e -Function EndOfLine
Set-PSReadLineKeyHandler -Chord Ctrl+Shift+a -Function SelectAll

# Sets the main prompt in the terminal
function prompt{
    Write-Host "`e[5 q" -NoNewline
    $Host.UI.RawUI.WindowTitle = (Get-Location).Path
    Set-PSReadLineOption -Colors @{ Command = 'green' }
    Invoke-Starship
    ps1_newstyle
    Write-Host ("➤") -NoNewLine ` -ForegroundColor 10
    return " "
}
# This function writes the special characters of the current terminal used. 
function Invoke-Starship{
  $loc = $executionContext.SessionState.Path.CurrentLocation;
  $prompt = "$([char]27)]9;12$([char]7)"
  if ($loc.Provider.Name -eq "FileSystem")
  {
    $prompt += "$([char]27)]9;9;`"$($loc.ProviderPath)`"$([char]27)\"
  }
  $host.ui.Write($prompt)
}
# This function overwrite the behavior of the 'tab' when you will select a new derectory.
function Tab-Completion {
    param([string]$Path = '.')
    # Get the list of directories and files
    $items = Get-ChildItem -Path $Path -Force | Select-Object -ExpandProperty Name
    # Show all items in a list
    if ($items.Count -gt 0) {
        $items | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "No items found"
    }
}
