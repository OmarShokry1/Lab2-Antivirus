# Antivirus Lab

## 1. Overview

This project implements a basic antivirus-style file monitoring system using Bash.
It detects suspicious files, moves them into quarantine, and provides an interactive
tool to restore or permanently delete quarantined files.

The project also includes a persistent whitelist and a script for scheduled scans.

## 2. Project Structure

```text
antivirus_lab/
├── antivirusd.sh
├── antivirus-cron.sh
├── restore.sh
├── Makefile
├── README.md
├── whitelist.txt
├── directory-info.last
├── directory-info.new
├── test_source/
└── test_quarantine/
```

- `antivirusd.sh`: Monitors the source directory and scans when its listing changes.
- `antivirus-cron.sh`: Performs one scan and exits.
- `restore.sh`: Restores, permanently deletes, or leaves quarantined files unchanged.
- `Makefile`: Provides commands for preparing and running the project.
- `whitelist.txt`: Stores SHA-256 fingerprints of restored files.
- `directory-info.last` and `directory-info.new`: Store directory snapshots.

## 3. Prerequisites

The project is designed for Ubuntu/Linux and requires Bash and standard utilities.

Install the required packages:

```bash
sudo apt update
sudo apt install bash coreutils findutils grep make cron
```

## 4. Detection Rules

A file is considered malicious if its filename ends with one of these case-sensitive
extensions:

- `.exe`
- `.bat`
- `.vbs`
- `.scr`
- `.ps1`

A file is also considered malicious if its content contains one of these
case-insensitive keywords:

- `virus`
- `trojan`
- `malware`
- `worm`
- `ransomware`

Only regular files directly inside the source directory are scanned.
Subdirectories are not scanned recursively.

The detection logic is implemented in the `is_malicious()` function in
`antivirusd.sh` and `antivirus-cron.sh`.

## 5. Prepare the Project

Navigate to the project directory:

```bash
cd ~/antivirus_lab
```

Make the scripts executable:

```bash
chmod +x antivirusd.sh antivirus-cron.sh restore.sh
```

Create the default test directories and whitelist file:

```bash
make prepare
```

## 6. Run the Monitoring Daemon

Run:

```bash
make antivirus
```

The default source directory is `test_source`, the quarantine directory is
`test_quarantine`, and the scan interval is three seconds.

You can override the defaults:

```bash
make antivirus SOURCE_DIR=source QUARANTINE_DIR=quarantine INTERVAL=5
```

The daemon scans immediately on startup. It then compares directory snapshots
and scans again when it detects a change. Press `Ctrl+C` to stop it.

## 7. Restore or Delete Quarantined Files

Run:

```bash
make restore
```

Or specify the directories directly:

```bash
bash restore.sh test_source test_quarantine
```

Select a file by its displayed number, then choose:

1. Restore the file.
2. Permanently delete the file.
3. Leave the file unchanged.

If quarantine is empty when the script starts, it prints:

`No malicious files to review.`

When a file is restored, the script records its SHA-256 fingerprint in
`whitelist.txt`. The scanner skips files whose current content matches a
whitelisted fingerprint, including after the daemon is restarted.

If the file content changes, its fingerprint changes and it can be scanned again.

## 8. Run a Single Scan

Run:

```bash
make cron
```

Or:

```bash
bash antivirus-cron.sh test_source test_quarantine
```

This performs one scan and exits.

## 9. Schedule Scans with Cron

Edit the current user's crontab:

```bash
crontab -e
```

To run a scan every minute with an approximate 23-second delay after the minute
begins, add the following line, replacing `/home/shokry` if your home directory
is different:

```cron
* * * * * sleep 23; /home/shokry/antivirus_lab/antivirus-cron.sh /home/shokry/antivirus_lab/test_source /home/shokry/antivirus_lab/test_quarantine >> /home/shokry/antivirus_lab/cron.log 2>&1
```

Cron itself has minute-level scheduling; `sleep 23` introduces the approximate
delay after the job starts.

To run a command every third Friday of the month at 12:31 AM, use:

```cron
31 0 * * 5 [ "$(date +\%d)" -ge 15 ] && [ "$(date +\%d)" -le 21 ] && command
```

Replace `command` with the command you want to execute. The date check ensures
that the Friday falls between the 15th and 21st, which identifies the third Friday.

## 10. Test Safely

Use harmless test files:

```bash
printf 'This is a normal file.\n' > test_source/normal.txt
printf 'Harmless test containing the word trojan.\n' > test_source/detection_test.txt
```

Run `make antivirus`. The detection test should be moved into quarantine.
Stop the daemon with `Ctrl+C`, then run `make restore` to test restoration.

Do not use real malware for testing.

## 11. Limitations

This is an educational project, not a production antivirus solution.
Extension and keyword checks can produce false positives and cannot detect all malware.
