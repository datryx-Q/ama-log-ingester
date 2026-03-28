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
   powershell.exe -ExecutionPolicy Bypass -File ".\Invoke-AMALogIngest.ps1" -FileTag "Tag-01"
#>

param (
    [string]$FileTag = ""
)

# --- Configuration ---
$AppName     = "ama-log-ingestor"
$BaseDir     = Join-Path ([Environment]::GetFolderPath("CommonApplicationData")) $AppName
$IncomingDir = Join-Path $BaseDir "Log Staging" # Logs go here
$UploadDir   = Join-Path $BaseDir "Ingest" # AMA ingest directory
$LogDir      = Join-Path $BaseDir "Script Logs"
$LogFile     = Join-Path $LogDir "ama-log-ingestor.log"
$MaxLogSize  = 10MB 

# --- Metrics ---
$processedCount = 0
$totalBytes     = 0
$errorCount     = 0

# --- Initialization ---
foreach ($dir in @($IncomingDir, $UploadDir, $LogDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "[INIT] Created directory: $dir"
    }
}

# --- Log Maintenance ---
if (Test-Path $LogFile) {
    if ((Get-Item $LogFile).Length -ge $MaxLogSize) {
        $archive = "$LogFile.$((Get-Date).ToString('yyyyMMddHHmmss'))"
        Move-Item $LogFile $archive -Force
        Write-Host "[LOG] Rotated log file -> $archive"
    }
}

# --- Pre-Run Cleanup ---
# SAFER: only remove older files (avoid deleting files AMA hasn’t ingested yet)
Get-ChildItem $UploadDir -File -ErrorAction SilentlyContinue | Where-Object {
    $_.LastWriteTime -lt (Get-Date).AddMinutes(-10)
} | ForEach-Object {
    Write-Host "[CLEANUP] Removing old ingest file: $($_.Name)"
    Remove-Item $_.FullName -Force
}

# --- Zip Handling ---
Get-ChildItem -Path $IncomingDir -Filter "*.zip" | ForEach-Object {
    try {
        $tempDir = Join-Path $IncomingDir "_extract_$($_.BaseName)"
        Expand-Archive -Path $_.FullName -DestinationPath $tempDir -Force
        Get-ChildItem $tempDir -File | Move-Item -Destination $IncomingDir -Force
        Remove-Item $tempDir -Recurse -Force
        Remove-Item $_.FullName -Force

        Write-Host "[ZIP] Extracted: $($_.Name)"
    }
    catch {
        $errorCount++
        Write-Host "[ERROR] ZIP extraction failed: $($_.Name)"
        Add-Content -Path $LogFile -Value "[$((Get-Date).ToString('u'))] UNZIP ERROR: $($_.Name)"
    }
}

# --- GZ Handling ---
Get-ChildItem -Path $IncomingDir -Filter "*.gz" | ForEach-Object {
    try {
        $outFile = Join-Path $IncomingDir ([IO.Path]::GetFileNameWithoutExtension($_.Name))

        $inStream  = [IO.File]::OpenRead($_.FullName)
        $gzip      = New-Object IO.Compression.GzipStream($inStream, [IO.Compression.CompressionMode]::Decompress)
        $outStream = [IO.File]::Create($outFile)

        $gzip.CopyTo($outStream)

        $gzip.Close()
        $inStream.Close()
        $outStream.Close()

        Remove-Item $_.FullName -Force

        Write-Host "[GZ] Extracted: $($_.Name)"
    }
    catch {
        $errorCount++
        Write-Host "[ERROR] GZ extraction failed: $($_.Name)"
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
        # --- File Stability Check (avoid partial reads) ---
        $initialSize = (Get-Item $src).Length
        Start-Sleep -Milliseconds 500
        $finalSize = (Get-Item $src).Length

        if ($initialSize -ne $finalSize) {
            Write-Host "[SKIP] File still being written: $origName"
            return
        }

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

        $fileSize = (Get-Item $src).Length
        $processedCount++
        $totalBytes += $fileSize
        
        Write-Host "[PROCESS] $origName -> $newName ($fileSize bytes)"
        Add-Content -Path $LogFile -Value "[$($start.ToString('u'))] PROCESSED: $origName -> $newName"
        Remove-Item -Path $src -Force
    }
    catch {
        $errorCount++
        Write-Host "[ERROR] Processing failed: $origName"
        Add-Content -Path $LogFile -Value "[$((Get-Date).ToString('u'))] ERROR: ${origName} | $($_.Exception.Message)"
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        if ($null -ne $writer) { $writer.Dispose() }
    }
    
    # --- Throughput Control ---
    $delay = [Math]::Min(2000, [Math]::Max(200, ($_.Length / 1MB) * 200))
    Start-Sleep -Milliseconds $delay
}

# --- Summary Metrics ---
$summary = "SUMMARY: Files=$processedCount Bytes=$totalBytes Errors=$errorCount"
Write-Host "[SUMMARY] $summary"
Add-Content -Path $LogFile -Value "[$((Get-Date).ToString('u'))] $summary"
