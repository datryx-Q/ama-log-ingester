<#
.SYNOPSIS
    AMA Log Ingester - Core Utility with Maintenance & Zip Support
    
.DESCRIPTION
    1. Rotates the script log if it exceeds 10MB.
    2. Clears previous ingest files.
    3. Extracts zip archives in the staging area.
    4. Streams logs into the AMA-monitored directory.

.PARAMETER FileTag
    Optional string to append to the processed filename (e.g., "SiteA").
	
	EXAMPLE USE:
    .\Invoke-AMALogIngest.ps1 -FileTag "Incident01"
#>

param (
    [string]$FileTag = ""
)

# --- Configuration ---
$AppName     = "ama-log-ingestor"
$BaseDir     = Join-Path ([Environment]::GetFolderPath("CommonApplicationData")) $AppName
$IncomingDir = Join-Path $BaseDir "Log Staging"
$UploadDir   = Join-Path $BaseDir "Ingest"
$LogDir      = Join-Path $BaseDir "Script Logs"
$LogFile     = Join-Path $LogDir "ama-log-ingestor-log-file.txt"
$MaxLogSize  = 10MB 

# --- Initialization ---
foreach ($dir in @($IncomingDir, $UploadDir, $LogDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# --- Log Maintenance ---
if (Test-Path $LogFile) {
    if ((Get-Item $LogFile).Length -ge $MaxLogSize) {
        Clear-Content -Path $LogFile
    }
}

# --- Pre-Run Cleanup ---
if (Test-Path "$UploadDir\*") {
    Remove-Item -Path "$UploadDir\*" -Force -Recurse
}

# --- Zip Handling ---
Get-ChildItem -Path $IncomingDir -Filter "*.zip" | ForEach-Object {
    try {
        Expand-Archive -Path $_.FullName -DestinationPath $IncomingDir -Force
        Remove-Item -Path $_.FullName -Force
    }
    catch {
        Add-Content -Path $LogFile -Value "[$((Get-Date).ToString('u'))] UNZIP ERROR: $($_.Name)"
    }
}

# --- Main Processing ---
Get-ChildItem -Path $IncomingDir -File | ForEach-Object {
    $src       = $_.FullName
    $origName  = $_.Name
    $start     = Get-Date
    $ts        = $start.ToString("yyyyMMddHHmmssfff")
    
    $reader = $null; $writer = $null
    
    try {
        $baseName = [IO.Path]::GetFileNameWithoutExtension($origName)
        $origExt  = [IO.Path]::GetExtension($origName)
        $ext      = if ([string]::IsNullOrEmpty($origExt)) { ".txt" } else { $origExt }
        
        # --- Tag Logic ---
        # If $FileTag is provided, add it with an underscore, otherwise keep it empty
        $formattedTag = if (-not [string]::IsNullOrWhiteSpace($FileTag)) { "_$FileTag" } else { "" }
        
        # Filename Pattern: OriginalName_Timestamp_Tag.ext
        $newName   = "{0}_{1}{2}{3}" -f $baseName, $ts, $formattedTag, $ext
        $destPath  = Join-Path $UploadDir $newName
        
        $reader = [System.IO.StreamReader]::new($src)
        $writer = [System.IO.StreamWriter]::new($destPath, $false, [System.Text.Encoding]::UTF8)
        
        while (-not $reader.EndOfStream) {
            $writer.WriteLine($reader.ReadLine())
        }
        
        $reader.Close(); $writer.Close()
        
        Add-Content -Path $LogFile -Value "[$($start.ToString('u'))] PROCESSED: $origName -> $newName"
        Remove-Item -Path $src -Force
    }
    catch {
        Add-Content -Path $LogFile -Value "[$((Get-Date).ToString('u'))] ERROR: ${origName} | $($_.Exception.Message)"
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        if ($null -ne $writer) { $writer.Dispose() }
    }
    
    Start-Sleep -Milliseconds 500
}
