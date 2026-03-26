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

### Installation

1. Clone the repository:
   ```powershell
   git clone [https://github.com/datryx-Q/ama-log-ingester.git](https://github.com/datryx-Q/ama-log-ingester.git)
   cd ama-log-ingester
   ```

### Usage

Run the script manually or via a Scheduled Task. You can optionally provide a tag to help identify specific batches of logs.
```powershell
# Standard run
.\Invoke-AMALogIngest.ps1

# Run with a specific tag for easier Sentinel filtering
.\Invoke-AMALogIngest.ps1 -FileTag "Incident01"
```

### Configuration & Paths

By default, the script utilizes the following paths on the Bridge device:

   * Staging: C:\ProgramData\ama-log-ingestor\Log Staging

   * Ingest (AMA Target): C:\ProgramData\ama-log-ingestor\Ingest

   * Logs: C:\ProgramData\ama-log-ingestor\Script Logs

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
