# Global Command Setup for smart_sample_monitor

This document describes how to set up `smart_sample_monitor_v2.sh` as a global command that can be executed from any directory.

## Overview

By default, `smart_sample_monitor_v2.sh` must be run from the pipeline directory (`/data/routine_nWGS_pipeline/nWGS_pipeline`). This setup guide enables you to run the monitoring script from anywhere on your system using a simple command: `smart_sample_monitor`.

## Setup Methods

### Method 1: User-Level Installation (Recommended - No sudo required)

This method installs the command for the current user only.

#### Step 1: Create Symbolic Link

```bash
mkdir -p ~/bin
ln -sf /data/routine_nWGS_pipeline/nWGS_pipeline/smart_sample_monitor_v2.sh ~/bin/smart_sample_monitor
```

#### Step 2: Add ~/bin to PATH

Add the following to your `~/.bashrc` file:

```bash
# Add user's bin directory to PATH
if [ -d "$HOME/bin" ]; then
    export PATH="$HOME/bin:$PATH"
fi
```

Or run this one-liner:

```bash
cat >> ~/.bashrc << 'EOF'

# Add user's bin directory to PATH
if [ -d "$HOME/bin" ]; then
    export PATH="$HOME/bin:$PATH"
fi
EOF
```

#### Step 3: Activate Changes

```bash
source ~/.bashrc
```

#### Step 4: Verify Installation

```bash
which smart_sample_monitor
# Expected output: /home/USERNAME/bin/smart_sample_monitor

smart_sample_monitor --help
# Should display the help message
```

---

### Method 2: System-Wide Installation (Requires sudo)

This method installs the command for all users on the system.

```bash
sudo ln -sf /data/routine_nWGS_pipeline/nWGS_pipeline/smart_sample_monitor_v2.sh /usr/local/bin/smart_sample_monitor
```

Verify:
```bash
which smart_sample_monitor
# Expected output: /usr/local/bin/smart_sample_monitor
```

---

## Usage

Once installed globally, you can run the command from any directory:

### Basic Usage

```bash
# Display help
smart_sample_monitor --help

# Run with default config
smart_sample_monitor

# Run with verbose output
smart_sample_monitor -v

# Override data directory
smart_sample_monitor -d /data/WGS_Dummy

# Enable resume mode (use cached results)
smart_sample_monitor -r

# Combination of options
smart_sample_monitor -d /data/WGS_Dummy -r -v
```

### Common Use Cases

#### 1. Monitor samples from a specific directory

```bash
smart_sample_monitor -d /data/WGS_27102025 -v
```

#### 2. Resume a previous run

```bash
smart_sample_monitor -d /data/WGS_Dummy -r
```

#### 3. Run with custom work directory

```bash
smart_sample_monitor -d /data/WGS_Dummy -w /custom/work/dir
```

#### 4. Monitor with custom check interval

```bash
smart_sample_monitor -d /data/WGS_Dummy -i 600  # Check every 10 minutes
```

---

## Command-Line Options

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-d` | `--data-dir` | Base data directory (overrides config) | Auto-detect from config |
| `-p` | `--pipeline` | Pipeline base directory | Current directory |
| `-w` | `--workdir` | Nextflow work directory | `/data/trash` |
| `-c` | `--config` | Config file to parse | `conf/mergebam.config` |
| `-i` | `--interval` | Check interval in seconds | 300 (5 minutes) |
| `-t` | `--timeout` | Maximum wait time in seconds | 432000 (5 days) |
| `-r` | `--resume` | Enable Nextflow resume | Disabled |
| `-v` | `--verbose` | Enable verbose logging | Disabled |
| `-h` | `--help` | Show help message | - |

---

## Key Features

### 1. Hardcoded Sample IDs File

The sample IDs file is hardcoded to:
```
/data/routine_nWGS/sample_ids_bam.txt
```

This cannot be changed via command-line options (version 2 feature).

### 2. Data Directory Override

When you specify `-d` option, it:
- Takes precedence over `input_dir` in `conf/mergebam.config`
- Is passed to the pipeline as `--input_dir` parameter
- Overrides the config value for that run only

### 3. Resume Mode

By default, resume is **disabled** to ensure fresh runs. Use `-r` flag to enable caching:

```bash
# Fresh run (default)
smart_sample_monitor -d /data/WGS_Dummy

# Use cached results
smart_sample_monitor -d /data/WGS_Dummy -r
```

---

## Workflow

1. **Monitor**: Script monitors for `final_summary_*_*_*.txt` files in sample directories
2. **Detect**: When a sample becomes ready, it's automatically queued
3. **Execute**: Pipeline runs with `--run_mode_order` for that sample
4. **Validate**: Checks for successful markdown report generation
5. **Report**: Displays final status summary

---

## Directory Structure Expected

```
data_directory/
├── SAMPLE_01/
│   └── [any_subdirectory]/
│       └── final_summary_*_*_*.txt
├── SAMPLE_02/
│   └── [different_subdirectory]/
│       └── final_summary_*_*_*.txt
└── ...
```

---

## Troubleshooting

### Command Not Found

**Problem**: `bash: smart_sample_monitor: command not found`

**Solutions**:
1. Ensure you've run `source ~/.bashrc` after setup
2. Check if symlink exists:
   ```bash
   ls -l ~/bin/smart_sample_monitor
   ```
3. Verify PATH contains ~/bin:
   ```bash
   echo $PATH | grep "$HOME/bin"
   ```

### Permission Denied

**Problem**: `Permission denied` when running the command

**Solution**: Ensure the original script is executable:
```bash
chmod +x /data/routine_nWGS_pipeline/nWGS_pipeline/smart_sample_monitor_v2.sh
```

### Wrong Pipeline Directory

**Problem**: Script can't find pipeline files

**Solution**: Use the `-p` option to specify the correct pipeline directory:
```bash
smart_sample_monitor -d /data/WGS_Dummy -p /data/routine_nWGS_pipeline/nWGS_pipeline
```

Or navigate to the pipeline directory first:
```bash
cd /data/routine_nWGS_pipeline/nWGS_pipeline
smart_sample_monitor -d /data/WGS_Dummy
```

---

## Advantages of Symbolic Link Approach

1. ✅ **No duplication**: Only one script file exists
2. ✅ **Automatic updates**: Changes to the original script are immediately available
3. ✅ **Easy maintenance**: Update script in place, no need to reinstall
4. ✅ **Version control**: Original script remains in git repository
5. ✅ **Clean naming**: Use `smart_sample_monitor` instead of full path
6. ✅ **Location independent**: Script automatically finds pipeline directory by resolving symlinks

---

## Uninstallation

### Remove User-Level Command

```bash
rm ~/bin/smart_sample_monitor
```

Remove from PATH (edit `~/.bashrc` and remove the added lines).

### Remove System-Wide Command

```bash
sudo rm /usr/local/bin/smart_sample_monitor
```

---

## Additional Notes

- The symbolic link points to the actual script, so all updates are automatically reflected
- **Smart symlink resolution**: The script automatically resolves the symlink and finds the correct pipeline directory, config files, and resources
- Pipeline directory is automatically detected from the script's location (even when called via symlink)
- Sample IDs file path is hardcoded and cannot be changed (v2 design decision)
- You can run the command from any directory without specifying `-p` thanks to automatic path detection

---

## Quick Reference Card

```bash
# One-time setup
mkdir -p ~/bin
ln -sf /data/routine_nWGS_pipeline/nWGS_pipeline/smart_sample_monitor_v2.sh ~/bin/smart_sample_monitor
source ~/.bashrc

# Verify
which smart_sample_monitor

# Common commands
smart_sample_monitor --help                          # Show help
smart_sample_monitor -d /data/WGS_Dummy              # Monitor specific directory
smart_sample_monitor -d /data/WGS_Dummy -r           # With resume enabled
smart_sample_monitor -d /data/WGS_Dummy -v           # With verbose output
smart_sample_monitor -d /data/WGS_Dummy -r -v        # Resume + verbose
```

---

## Version Information

- Script Version: 2.0
- Documentation Date: 2025-11-11
- Author: Claude Code Assistant
- Script Location: `/data/routine_nWGS_pipeline/nWGS_pipeline/smart_sample_monitor_v2.sh`

---

## See Also

- [smart_sample_monitor_v2.sh](../smart_sample_monitor_v2.sh) - The actual script
- [conf/mergebam.config](../conf/mergebam.config) - Mergebam configuration
- [README.md](../README.md) - Main pipeline documentation
