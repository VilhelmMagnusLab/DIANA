#!/bin/bash

#==============================================================================
# Flexible Sample-Based Pipeline Monitor Script
#==============================================================================
# 
# Monitors for final_summary_*_*_* files within individual sample directories.
# Supports both single-column and tab-separated sample ID files.
# Triggers pipeline when ALL samples have completed BAM processing.
#
# Directory structure expected:
#   ${BASE_DATA_DIR}/
#   ├── T001/Dummy/final_summary_*_*_*.txt
#   ├── T002/Dummy/final_summary_*_*_*.txt
#   └── ...
#
# Sample ID file formats supported:
#   Format 1 (single column): T001
#   Format 2 (tab-separated): T001    flow_cell_id
#
# Usage: ./flexible_sample_monitor.sh [options]
#
# Options:
#   -d, --data-dir DIR      Base data directory (default: auto-detect from config)
#   -s, --samples FILE      Sample IDs file (default: auto-detect from config)  
#   -p, --pipeline DIR      Pipeline base directory (default: current directory)
#   -w, --workdir DIR       Nextflow work directory (default: /home/chbope/extension/trash/)
#   -c, --config FILE       Pipeline config file to read paths from (default: conf/mergebam.config)
#   -i, --interval SEC      Check interval in seconds (default: 300)
#   -t, --timeout SEC       Maximum wait time in seconds (default: 432000 = 5 days)
#   -v, --verbose           Enable verbose output
#   -h, --help              Show this help message
#
# Examples:
#   ./flexible_sample_monitor.sh
#   ./flexible_sample_monitor.sh -d /path/to/data -s /path/to/sample_ids.txt
#   ./flexible_sample_monitor.sh -c conf/analysis.config -v
#==============================================================================

set -e

# Default configuration
DEFAULT_CONFIG_FILE="conf/mergebam.config"
DEFAULT_PIPELINE_DIR="$(pwd)"
DEFAULT_NEXTFLOW_WORK_DIR="/home/chbope/extension/trash/"
DEFAULT_CHECK_INTERVAL=300  # 5 minutes
DEFAULT_TIMEOUT=432000      # 5 days
DEFAULT_SUMMARY_SUBDIR="Dummy"

# Initialize variables
CONFIG_FILE="$DEFAULT_CONFIG_FILE"
PIPELINE_DIR="$DEFAULT_PIPELINE_DIR"
NEXTFLOW_WORK_DIR="$DEFAULT_NEXTFLOW_WORK_DIR"
CHECK_INTERVAL="$DEFAULT_CHECK_INTERVAL"
TIMEOUT="$DEFAULT_TIMEOUT"
SUMMARY_SUBDIR="$DEFAULT_SUMMARY_SUBDIR"
VERBOSE=false
BASE_DATA_DIR=""
SAMPLE_IDS_FILE=""

# Function to display help
show_help() {
    sed -n '3,40p' "$0" | sed 's/^# //g' | sed 's/^#//g'
}

# Function to log messages
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$level" == "VERBOSE" && "$VERBOSE" != true ]]; then
        return
    fi
    
    echo "[$timestamp] [$level] $message"
}

# Function to extract path from config file
extract_config_path() {
    local config_file="$1"
    local param_name="$2"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    # Extract parameter value, handling quotes and variable substitutions
    grep -E "^\s*${param_name}\s*=" "$config_file" | \
        sed -E 's/^[^=]*=\s*"?([^"]*)"?.*/\1/' | \
        head -1
}

# Function to resolve config variables
resolve_config_path() {
    local path="$1"
    local config_file="$2"
    
    # Replace ${params.path} with actual path value
    if [[ "$path" =~ \$\{params\.path\} ]]; then
        local base_path=$(extract_config_path "$config_file" "path")
        if [[ -n "$base_path" ]]; then
            path="${path//\$\{params.path\}/$base_path}"
        fi
    fi
    
    echo "$path"
}

# Function to auto-detect paths from config
auto_detect_paths() {
    log_message "INFO" "Auto-detecting paths from config file: $CONFIG_FILE"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_message "ERROR" "Config file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Extract base data directory
    if [[ -z "$BASE_DATA_DIR" ]]; then
        local input_dir=$(extract_config_path "$CONFIG_FILE" "input_dir")
        if [[ -n "$input_dir" ]]; then
            BASE_DATA_DIR=$(resolve_config_path "$input_dir" "$CONFIG_FILE")
            log_message "INFO" "Auto-detected base data directory: $BASE_DATA_DIR"
        fi
    fi
    
    # Extract sample IDs file
    if [[ -z "$SAMPLE_IDS_FILE" ]]; then
        # Try different sample file parameter names
        for param in "bam_sample_id_file" "analyse_sample_id_file" "epi2me_sample_id_file"; do
            local sample_file=$(extract_config_path "$CONFIG_FILE" "$param")
            if [[ -n "$sample_file" ]]; then
                SAMPLE_IDS_FILE=$(resolve_config_path "$sample_file" "$CONFIG_FILE")
                log_message "INFO" "Auto-detected sample IDs file: $SAMPLE_IDS_FILE (from $param)"
                break
            fi
        done
    fi
    
    # Validate auto-detected paths
    if [[ -z "$BASE_DATA_DIR" ]]; then
        log_message "ERROR" "Could not auto-detect base data directory from config"
        exit 1
    fi
    
    if [[ -z "$SAMPLE_IDS_FILE" ]]; then
        log_message "ERROR" "Could not auto-detect sample IDs file from config"
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--data-dir)
            BASE_DATA_DIR="$2"
            shift 2
            ;;
        -s|--samples)
            SAMPLE_IDS_FILE="$2"
            shift 2
            ;;
        -p|--pipeline)
            PIPELINE_DIR="$2"
            shift 2
            ;;
        -w|--workdir)
            NEXTFLOW_WORK_DIR="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --summary-subdir)
            SUMMARY_SUBDIR="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use -h or --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Auto-detect paths if not provided
if [[ -z "$BASE_DATA_DIR" || -z "$SAMPLE_IDS_FILE" ]]; then
    auto_detect_paths
fi

log_message "INFO" "=== Flexible Sample-Based nWGS Pipeline Monitor ==="
log_message "INFO" "Base data directory: $BASE_DATA_DIR"
log_message "INFO" "Sample IDs file: $SAMPLE_IDS_FILE"
log_message "INFO" "Pipeline directory: $PIPELINE_DIR"
log_message "INFO" "Nextflow work directory: $NEXTFLOW_WORK_DIR"
log_message "INFO" "Summary subdirectory: $SUMMARY_SUBDIR"
log_message "INFO" "Check interval: ${CHECK_INTERVAL}s"
log_message "INFO" "Max wait time: $((TIMEOUT / 3600))h"
log_message "INFO" "Verbose mode: $VERBOSE"

# Validate directories and files
if [[ ! -d "$BASE_DATA_DIR" ]]; then
    log_message "ERROR" "Base data directory does not exist: $BASE_DATA_DIR"
    exit 1
fi

if [[ ! -f "$SAMPLE_IDS_FILE" ]]; then
    log_message "ERROR" "Sample IDs file does not exist: $SAMPLE_IDS_FILE"
    exit 1
fi

if [[ ! -d "$PIPELINE_DIR" ]]; then
    log_message "ERROR" "Pipeline directory does not exist: $PIPELINE_DIR"
    exit 1
fi

if [[ ! -d "$NEXTFLOW_WORK_DIR" ]]; then
    log_message "ERROR" "Nextflow work directory does not exist: $NEXTFLOW_WORK_DIR"
    exit 1
fi

if [[ ! -f "$PIPELINE_DIR/run_pipeline_singularity.sh" ]]; then
    log_message "ERROR" "Pipeline script not found: $PIPELINE_DIR/run_pipeline_singularity.sh"
    exit 1
fi

# Read sample IDs from file (handle both single column and tab-separated formats)
log_message "INFO" "Reading sample IDs from: $SAMPLE_IDS_FILE"
sample_ids=()
while IFS=$'\t' read -r sample_id flow_cell_id || [[ -n "$sample_id" ]]; do
    # Remove whitespace and skip empty lines and comments
    sample_id=$(echo "$sample_id" | xargs)
    if [[ -n "$sample_id" && ! "$sample_id" =~ ^# ]]; then
        sample_ids+=("$sample_id")
        log_message "VERBOSE" "Added sample: $sample_id"
    fi
done < "$SAMPLE_IDS_FILE"

if [[ ${#sample_ids[@]} -eq 0 ]]; then
    log_message "ERROR" "No valid sample IDs found in $SAMPLE_IDS_FILE"
    exit 1
fi

log_message "INFO" "Found ${#sample_ids[@]} sample(s) to monitor: ${sample_ids[*]}"

# Function to check a single sample's summary files
check_sample_summary() {
    local sample_id="$1"
    local sample_dir="$BASE_DATA_DIR/$sample_id"
    local summary_dir="$sample_dir/$SUMMARY_SUBDIR"
    
    # Check if sample directory exists
    if [[ ! -d "$sample_dir" ]]; then
        log_message "VERBOSE" "Sample directory not found: $sample_dir"
        return 1
    fi
    
    # Check if summary subdirectory exists
    if [[ ! -d "$summary_dir" ]]; then
        log_message "VERBOSE" "Summary directory not found: $summary_dir"
        return 1
    fi
    
    # Find final_summary files in summary directory
    local summary_files=($(find "$summary_dir" -maxdepth 1 -name "final_summary_*_*_*" -type f 2>/dev/null))
    
    if [[ ${#summary_files[@]} -eq 0 ]]; then
        log_message "VERBOSE" "No final_summary files found in $summary_dir"
        return 1
    fi
    
    # Check if any file is not empty
    for file in "${summary_files[@]}"; do
        if [[ -s "$file" ]]; then
            # Get file modification time for display
            file_mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo 0)
            current_time=$(date +%s)
            file_age=$((current_time - file_mtime))
            file_age_hours=$((file_age / 3600))
            
            log_message "VERBOSE" "Sample $sample_id ready: $(basename "$file") (${file_age_hours}h ago)"
            return 0
        fi
    done
    
    log_message "VERBOSE" "Sample $sample_id: final_summary files found but are empty"
    return 1
}

# Calculate max checks based on timeout
max_checks=$((TIMEOUT / CHECK_INTERVAL))

log_message "INFO" "Starting monitoring loop (max $max_checks checks)..."

# Monitoring loop
for ((i=1; i<=max_checks; i++)); do
    log_message "INFO" "Check $i/$max_checks - Checking sample summary files..."
    
    ready_samples=()
    pending_samples=()
    
    # Check each sample
    for sample_id in "${sample_ids[@]}"; do
        log_message "VERBOSE" "Checking sample: $sample_id"
        if check_sample_summary "$sample_id"; then
            ready_samples+=("$sample_id")
        else
            pending_samples+=("$sample_id")
        fi
    done
    
    log_message "INFO" "Summary: ${#ready_samples[@]}/${#sample_ids[@]} samples ready"
    
    if [[ ${#ready_samples[@]} -gt 0 ]]; then
        log_message "INFO" "Ready samples: ${ready_samples[*]}"
    fi
    
    if [[ ${#pending_samples[@]} -gt 0 ]]; then
        log_message "VERBOSE" "Pending samples: ${pending_samples[*]}"
    fi
    
    # Check if all samples are ready
    if [[ ${#ready_samples[@]} -eq ${#sample_ids[@]} ]]; then
        log_message "SUCCESS" "ALL SAMPLES ARE READY!"
        log_message "SUCCESS" "BAM processing appears to be complete for all samples!"
        break
    fi
    
    # Show progress every 12 checks (every hour at 5-min intervals)
    if [[ $((i % 12)) -eq 0 ]]; then
        elapsed=$((i * CHECK_INTERVAL))
        remaining=$(((max_checks - i) * CHECK_INTERVAL))
        elapsed_hours=$((elapsed / 3600))
        remaining_hours=$((remaining / 3600))
        log_message "INFO" "Progress: $i/$max_checks checks completed (${elapsed_hours}h elapsed, ${remaining_hours}h remaining)"
    fi
    
    # Wait before next check (except on last iteration)
    if [[ $i -lt $max_checks ]]; then
        sleep "$CHECK_INTERVAL"
    fi
done

# Check final status
if [[ ${#ready_samples[@]} -lt ${#sample_ids[@]} ]]; then
    log_message "ERROR" "TIMEOUT: Not all samples completed after maximum wait time"
    log_message "ERROR" "Ready samples (${#ready_samples[@]}/${#sample_ids[@]}): ${ready_samples[*]}"
    log_message "ERROR" "Pending samples: ${pending_samples[*]}"
    exit 2
fi

log_message "SUCCESS" "All samples have completed BAM processing!"

log_message "INFO" "Waiting 10 seconds before starting pipeline..."
sleep 10

log_message "INFO" "Starting nWGS Pipeline..."
log_message "INFO" "Command: bash $PIPELINE_DIR/run_pipeline_singularity.sh --run_mode_order -w '$NEXTFLOW_WORK_DIR'"

cd "$PIPELINE_DIR"
if bash run_pipeline_singularity.sh --run_mode_order -w "$NEXTFLOW_WORK_DIR"; then
    log_message "SUCCESS" "Pipeline completed successfully!"
    exit 0
else
    log_message "ERROR" "Pipeline failed!"
    exit 1
fi
