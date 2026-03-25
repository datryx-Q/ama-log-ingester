# ama-log-ingester 

### Utility to bridge the gap for offline systems by re-processing manual log uploads through an internet-connected Azure Monitor Agent (AMA) for Sentinel ingestion.

---

## Overview

In high-security or disconnected environments, critical devices often lack the outbound internet connectivity required to stream logs directly to **Microsoft Sentinel**. 

This utility provides a "Log Relay" workflow. It allows logs from offline systems—manually transferred to an internet-connected "Bridge" device—to be ingested into Sentinel. The script monitors a staging directory, re-processes the files to trigger the **Azure Monitor Agent (AMA)**, and ensures the data is successfully uploaded to your **Log Analytics Workspace**.

## How It Works

1. **Manual Transfer:** Logs are moved from offline devices to a "Staging" folder on a Bridge device (Linux/Windows) where the AMA is installed.
2. **Detection & Processing:** This script monitors the Staging folder for new files.
3. **AMA Ingestion Trigger:** Because the AMA typically ignores static or "cold" files, this script reads and re-writes the log data into a stream that the AMA is actively monitoring via a **Data Collection Rule (DCR)**.
4. **Cloud Ingestion:** The AMA detects the activity and pushes the logs to Sentinel.

---

## Getting Started

### Prerequisites

* **Bridge Device:** An internet-connected machine with the [Azure Monitor Agent installed](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview).
* **Data Collection Rule (DCR):** A configured DCR in Azure pointing to the specific local file path used by this script.
* **Permissions:** Sufficient local privileges to read/write in the staging and target log directories.

### Installation

1. Clone the repository:
   ```bash
   git clone [https://github.com/your-username/ama-log-ingester.git](https://github.com/your-username/ama-log-ingester.git)
   cd ama-log-ingester
   ```
2. (Optional) Create a virtual environment and install dependencies:
   ```bash
   python3 -m venv venv
    source venv/bin/activate
    # No external dependencies required for the base script 
    ```
### Usage

Run the script by pointing it to your staging directory and your AMA-monitored target file:
```bash
python3 ingest_logs.py --source /path/to/offline/logs --target /var/log/ama-ingest.log
```

### Configuration
Parameter,Description
--source,The directory where you manually upload offline logs.
--target,The file path that your Azure DCR is configured to watch.
--interval,(Optional) How often to check for new files (default: 60s).

### Security & Privacy

  * No Credentials Stored: This script does not require Azure Service Principals or Keys; it relies on the local AMA's Managed Identity for authentication.

  * Sanitization: Ensure offline logs do not contain sensitive plaintext passwords before moving them to the bridge device.

  * Air-Gap Integrity: This script only moves data out of the staging area; it does not create a reverse path back to the offline systems.

### License

This project is licensed under the MIT License - see the LICENSE file for details.

### Disclaimer

This tool is provided "as-is" without warranty of any kind. Always test log ingestion workflows in a development or sandbox Azure environment before deploying to production SecOps pipelines.
