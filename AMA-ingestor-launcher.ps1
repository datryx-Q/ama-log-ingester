# This script pops up a window to ask for the tag, then runs your main utility
Add-Type -AssemblyName Microsoft.VisualBasic
$Title = "AMA Log Ingestor"
$Msg   = "Enter a FileTag (e.g., Site-A, Incident-01) or leave blank:"
$Tag   = [Microsoft.VisualBasic.Interaction]::InputBox($Msg, $Title, "")

# Get the directory where this launcher is sitting
$PSScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$UtilityPath = Join-Path $PSScriptDir "Invoke-AMALogIngest.ps1"

# Execute the main script with the tag provided
Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$UtilityPath`" -FileTag `"$Tag`"" -Wait
