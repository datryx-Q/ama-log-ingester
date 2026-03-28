# ama-log-ingester 

### Utility to bridge the gap for offline systems by re-processing manual log uploads through an internet-connected Azure Monitor Agent (AMA) for Sentinel ingestion.

---

## Overview

In high-security or disconnected environments, critical devices often lack the outbound internet connectivity required to stream logs directly to **Microsoft Sentinel**. 

This utility provides a "Log Relay" workflow. It allows logs from offline systems—manually transferred to an internet-connected "Bridge" device—to be ingested into Sentinel. The script monitors a staging directory, re-processes the files to trigger the **Azure Monitor Agent (AMA)**, and ensures the data is successfully uploaded to your **Log Analytics Workspace**.

## How It Works

1. **Manual Transfer:** Logs are moved from offline devices to a "Staging" folder on a Bridge device (Windows) where the AMA is installed.
2. **Detection & Processing:** This script monitors the Staging folder for new files, including automatic extraction of `.zip` archives.
3. **AMA Ingestion Trigger:** Because the AMA typically ignores static or "cold" files, this script reads and re-writes the log data using .NET stream classes into a directory the AMA is actively monitoring via a **Data Collection Rule (DCR)**.
4. **Cloud Ingestion:** The AMA detects the new file activity and pushes the logs to Sentinel.

---

## Getting Started

### Prerequisites

* **Bridge Device:** A Windows machine with the [Azure Monitor Agent installed](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview).
* **Data Collection Rule (DCR):** A configured DCR in Azure pointing to `C:\ProgramData\ama-log-ingestor\Ingest\*.txt` (or preferred extensions).
* **Permissions:** Administrator privileges are recommended to write to `CommonApplicationData`.

## Key Improvements in v2.0

* **File Stability Check:** Prevents partial ingestion by ensuring files are completely written to disk (no active handles) before processing.
* **Smart Extraction:** Supports both `.zip` and `.gz` formats using isolated temporary directories to prevent staging area pollution.
* **Non-Destructive Maintenance:** Replaced "wipe-on-run" logic with age-based cleanup, allowing AMA ample time to finish ingestion before files are archived.
* **High-Volume Regulation:** Implements dynamic throughput control (adjustable sleep cycles) to prevent overwhelming the local AMA service.
* **Operational Visibility:** Real-time console output (Write-Host) and detailed end-of-run metrics (Total Bytes, File Counts, Errors).
* **GUI Launcher:** New lightweight wrapper (`ama-ingestor-launcher.ps1`) provides a graphical "FileTag" prompt for manual runs.

---

## Directory Structure

Upon execution, the script automatically manages the following hierarchy within `C:\ProgramData\ama-log-ingestor`:

* **`Log Staging/`**: Drop your raw `.txt`, `.log`, `.zip`, or `.gz` files here.
* **`Ingest/`**: The "Hot" directory monitored by the Azure Monitor Agent.
* **`Script Logs/`**: Contains `ama-log-ingestor.log` with historical execution data and archives.

---

## Installation & Setup

### 1. File Placement
Place the following files into a dedicated directory on your bridge device:
* `Invoke-AMALogIngest.ps1` (The Engine)
* `ama-ingestor-launcher.ps1` (The GUI Launcher)

### 2. Configure Azure Monitor Agent (AMA)
Create a **Data Collection Rule (DCR)** in the Azure Portal or via Bicep/ARM, pointing the file-watch path to:
`C:\ProgramData\ama-log-ingestor\Ingest\*.txt` (or your specific log extension).

### 3. Create a Desktop Shortcut (Manual Use)
1.  Right-click your **Desktop** > **New** > **Shortcut**.
2.  Paste the following into the location box:
    ```cmd
    powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Path\To\ama-ingestor-launcher.ps1"
    ```
3.  Name it **"Run AMA Ingestor"**.

---

## Usage

### Manual Ingestion
Double-click the **Run AMA Ingestor** shortcut. 
1.  A prompt will ask for an optional **FileTag** (e.g., `Site-Alpha` or `Incident-402`).
2.  The script will identify all logs in `Log Staging`, extract them if necessary, and move them to `Ingest` with a timestamp and your tag appended to the filename.

### Automated Ingestion (Scheduled Task)
To run the script every 30 minutes in the background, run this in an Admin PowerShell terminal:
```powershell
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-ExecutionPolicy Bypass -File "C:\Path\To\Invoke-AMALogIngest.ps1" -FileTag "AutoInbound"'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30)
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "AMA-Log-Ingestor-Task" -Description "Relays offline logs to AMA Ingest folder."
```

### Known Limitations

   * Hostname Attribution: Because the logs are re-written on the Bridge device, Microsoft Sentinel will associate the ingestion with the Bridge device's hostname. It is recommended to include the original source hostname within the log content itself or use the -FileTag parameter to identify the source.

   * Log Overwrite / Data Persistence: To ensure a clean ingestion environment, the script clears all files in the Ingest folder prior to processing a new batch. Ensure the AMA has had sufficient time to upload previous batches before starting a new run.

   * Log Rotation: The internal script log (ama-log-ingestor-log-file.txt) is automatically cleared if it exceeds 10MB to prevent storage exhaustion.

### Security & Privacy

   * No Credentials Stored: This script does not require Azure Service Principals or Keys; it relies on the local AMA's Managed Identity for authentication.

   * Sanitization: Ensure offline logs do not contain sensitive plaintext passwords before moving them to the bridge device.

   * Air-Gap Integrity: This script only moves data out of the staging area; it does not create a reverse path back to the offline systems.

### License

This project is licensed under the MIT License - see the LICENSE file for details.

### Disclaimer

This tool is provided "as-is" without warranty of any kind. Always test log ingestion workflows in a development or sandbox Azure environment before deploying to production SecOps pipelines.
