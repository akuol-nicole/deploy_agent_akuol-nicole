# deploy_agent_akuol-nicole
# Attendance Tracker Deploy Agent

An interactive Bash deployment and management tool (`deploy_agent.sh`) designed to automate provisioning, execution, permission hardening, and log lifecycle management for isolated instances of the **Attendance Tracker** application.

---

## Overview

The deployment agent provisions standalone environment instances using the folder naming convention `attendance_tracker_<suffix>/`. It manages the full operational lifecycle:

1. **Pre-flight Environment Validation**: Checks required binaries, source templates, and workspace write permissions before modifying any files.
2. **Instance Provisioning & Scaffolding**: Builds workspace structures, configures student rosters, sets up runtime configurations, and applies least-privilege POSIX file permissions.
3. **Safe Interruption Handling**: Traps `Ctrl+C` (`SIGINT`) and `Ctrl+Z` (`SIGTSTP`) signals to bundle partially configured workspaces into `.zip` archives and clean up dangling files.
4. **Interactive Execution**: Runs marking sessions and handles exit codes gracefully.
5. **Timestamped Log Archival**: Migrates active session logs into structured archive folders.

---

## Project Structure

```text
.
├── deploy_agent.sh              # Interactive CLI agent script
├── README.md                    # Project documentation
├── templates/                   # Base blueprint files used for deployments
│   ├── assets.csv               # Source student roster template
│   ├── attendance_checker.py    # Main attendance logic application
│   └── config.json              # Source configuration (sessions & thresholds)
└── attendance_tracker_<suffix>/ # Provisioned instance directory (e.g. attendance_tracker_v1)
    ├── attendance_checker.py    # Executable application copy (chmod +x)
    ├── Helpers/
    │   ├── assets.csv           # Configured student records for this instance
    │   └── config.json          # Instance configuration (chmod 600)
    ├── reports/                 # Output logs generated during marking
    │   ├── attendance.log       # Records of attending students
    │   └── absent.log           # Records of absent students
    └── archives/                # Backups created by log archiving
        ├── attendance/          # attendance_YYYYMMDD_HHMMSS.log

video
video link: https://drive.google.com/file/d/1fmRAlR8dcoAPxhHEhSgpzQoq1TKJVJMg/view?usp=sharing
