#!/bin/bash

#==============================================================================
# Independent Sample Monitor Script
#==============================================================================
# 
# Monitors each ONT basecalled individual bam file independently and triggers the pipeline immediately
# when ANY individual sample's final_summary file becomes ready.
# Multiple samples can be processed in parallel as they complete.
#
# Directory structure expected:
#   ${BASE_DATA_DIR}/
#   ├── T001/Dummy/final_summary_*_*_*.txt
#   ├── T002/Dummy/final_summary_*_*_*.txt
#   └── ...
#
# Usage: ./independent_sample_monitor.sh [options]
#
# Options:
#   -d, --data-dir DIR      Base data directory (default: auto-detect from config)
#   -s, --samples FILE      Sample IDs file (default: auto-detect from config)  
#   -p, --pipeline DIR      Pipeline base directory (default: current directory)
#   -w, --workdir DIR       Nextflow work directory base (default: /home/chbope/extension/trash/)
#   -c, --config FILE       Pipeline config file to read paths from (default: conf/mergebam.config)
#   -i, --interval SEC      Check interval in seconds (default: 300)
#   -t, --timeout SEC       Maximum wait time per sample in seconds (default: 432000 = 5 days)
#   --subdir DIR            Specific subdirectory name to look for (default: auto-detect)
#   --parallel              Allow multiple samples to run pipeline simultaneously
#   -v, --verbose           Enable verbose output
#   -h, --help              Show this help message
#
# Examples:
#   ./independent_sample_monitor.sh
#   ./independent_sample_monitor.sh --parallel -v
#   ./independent_sample_monitor.sh -d /path/to/data -s /path/to/sample_ids.txt
#==============================================================================

set -e

# Default configuration
DEFAULT_CONFIG_FILE="conf/mergebam.config"
DEFAULT_PIPELINE_DIR="$(pwd)"
DEFAULT_NEXTFLOW_WORK_DIR="/home/chbope/extension/trash"
DEFAULT_CHECK_INTERVAL=300  # 5 minutes
DEFAULT_TIMEOUT=432000      # 5 days
# Initialize variables
CONFIG_FILE="$DEFAULT_CONFIG_FILE"
PIPELINE_DIR="$DEFAULT_PIPELINE_DIR"
NEXTFLOW_WORK_DIR="$DEFAULT_NEXTFLOW_WORK_DIR"
CHECK_INTERVAL="$DEFAULT_CHECK_INTERVAL"
TIMEOUT="$DEFAULT_TIMEOUT"
AUTO_DETECT_SUBDIR=true
VERBOSE=false
PARALLEL_MODE=false
BASE_DATA_DIR=""
SAMPLE_IDS_FILE=""

# Track processed samples and running jobs
declare -A processed_samples=()
declare -A running_jobs=()
declare -A job_pids=()

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

# Function to run pipeline for a specific sample
run_sample_pipeline() {
    local sample_id="$1"
    local sample_work_dir="${NEXTFLOW_WORK_DIR}/${sample_id}_work"
    
    log_message "INFO" "Starting pipeline for sample: $sample_id"
    log_message "INFO" "Sample work directory: $sample_work_dir"
    
    # Create sample-specific work directory
    mkdir -p "$sample_work_dir"
    
    # Pipeline command
    local pipeline_cmd="bash $PIPELINE_DIR/run_pipeline_singularity.sh --run_mode_order -w '$sample_work_dir'"
    log_message "INFO" "Command: $pipeline_cmd"
    
    # Run in background if parallel mode, otherwise foreground
    if [[ "$PARALLEL_MODE" == true ]]; then
        log_message "INFO" "Running sample $sample_id in background (parallel mode)"
        (
            cd "$PIPELINE_DIR"
            if bash run_pipeline_singularity.sh --run_mode_order -w "$sample_work_dir" > "${sample_work_dir}/pipeline.log" 2>&1; then
                log_message "SUCCESS" "Sample $sample_id pipeline completed successfully!"
                echo "SUCCESS" > "${sample_work_dir}/status"
            else
                log_message "ERROR" "Sample $sample_id pipeline failed!"
                echo "FAILED" > "${sample_work_dir}/status"
            fi
        ) &
        
        local job_pid=$!
        job_pids["$sample_id"]=$job_pid
        running_jobs["$sample_id"]="RUNNING"
        log_message "INFO" "Sample $sample_id pipeline started with PID: $job_pid"
    else
        log_message "INFO" "Running sample $sample_id in foreground (sequential mode)"
        cd "$PIPELINE_DIR"
        if bash run_pipeline_singularity.sh --run_mode_order -w "$sample_work_dir"; then
            log_message "SUCCESS" "Sample $sample_id pipeline completed successfully!"
            running_jobs["$sample_id"]="COMPLETED"
        else
            log_message "ERROR" "Sample $sample_id pipeline failed!"
            running_jobs["$sample_id"]="FAILED"
        fi
    fi
}

# Function to check running jobs status
check_running_jobs() {
    if [[ "$PARALLEL_MODE" != true ]]; then
        return
    fi
    
    for sample_id in "${!job_pids[@]}"; do
        local job_pid="${job_pids[$sample_id]}"
        local sample_work_dir="${NEXTFLOW_WORK_DIR}/${sample_id}_work"
        
        # Check if job is still running
        if ! kill -0 "$job_pid" 2>/dev/null; then
            # Job finished, check status
            if [[ -f "${sample_work_dir}/status" ]]; then
                local status=$(cat "${sample_work_dir}/status")
                running_jobs["$sample_id"]="$status"
                log_message "INFO" "Sample $sample_id job finished: $status"
            else
                running_jobs["$sample_id"]="UNKNOWN"
                log_message "WARNING" "Sample $sample_id job finished but status unknown"
            fi
            unset job_pids["$sample_id"]
        fi
    done
}

# Function to find subdirectory containing final_summary files
find_summary_subdir() {
    local sample_id="$1"
    local sample_dir="$BASE_DATA_DIR/$sample_id"
    
    # If AUTO_DETECT_SUBDIR is false, use the specified SUMMARY_SUBDIR
    if [[ "$AUTO_DETECT_SUBDIR" != true && -n "$SUMMARY_SUBDIR" ]]; then
        echo "$SUMMARY_SUBDIR"
        return
    fi
    
    # Auto-detect by searching for final_summary files in any subdirectory
    local summary_files=($(find "$sample_dir" -name "final_summary_*_*_*" -type f 2>/dev/null))
    
    if [[ ${#summary_files[@]} -gt 0 ]]; then
        # Get the directory containing the first summary file
        local summary_file="${summary_files[0]}"
        local summary_dir=$(dirname "$summary_file")
        local subdir=$(basename "$summary_dir")
        
        # If it's directly in sample_dir, return empty (no subdirectory)
        if [[ "$summary_dir" == "$sample_dir" ]]; then
            echo ""
        else
            echo "$subdir"
        fi
    else
        # No summary files found, return empty
        echo ""
    fi
}

# Function to check a single sample's summary files
check_sample_summary() {
    local sample_id="$1"
    local sample_dir="$BASE_DATA_DIR/$sample_id"
    
    # Skip if already processed
    if [[ "${processed_samples[$sample_id]}" == "true" ]]; then
        return 1
    fi
    
    # Check if sample directory exists
    if [[ ! -d "$sample_dir" ]]; then
        log_message "VERBOSE" "Sample directory not found: $sample_dir"
        return 1
    fi
    
    # Find the subdirectory containing summary files
    local detected_subdir=$(find_summary_subdir "$sample_id")
    local summary_dir="$sample_dir"
    
    if [[ -n "$detected_subdir" ]]; then
        summary_dir="$sample_dir/$detected_subdir"
        log_message "VERBOSE" "Sample $sample_id: detected summary subdirectory: $detected_subdir"
    else
        log_message "VERBOSE" "Sample $sample_id: looking for summary files directly in sample directory"
    fi
    
    # Find final_summary files in the determined directory
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
            
            log_message "SUCCESS" "Sample $sample_id READY: $(basename "$file") in $summary_dir (${file_age_hours}h ago)"
            return 0
        fi
    done
    
    log_message "VERBOSE" "Sample $sample_id: final_summary files found but are empty in $summary_dir"
    return 1
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
        --subdir)
            SUMMARY_SUBDIR="$2"
            AUTO_DETECT_SUBDIR=false
            shift 2
            ;;
        --parallel)
            PARALLEL_MODE=true
            shift
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

log_message "INFO" "=== Independent Sample Monitor ==="
log_message "INFO" "Base data directory: $BASE_DATA_DIR"
log_message "INFO" "Sample IDs file: $SAMPLE_IDS_FILE"
log_message "INFO" "Pipeline directory: $PIPELINE_DIR"
log_message "INFO" "Nextflow work directory: $NEXTFLOW_WORK_DIR"
if [[ "$AUTO_DETECT_SUBDIR" == true ]]; then
    log_message "INFO" "Summary subdirectory: auto-detect"
else
    log_message "INFO" "Summary subdirectory: $SUMMARY_SUBDIR"
fi
log_message "INFO" "Check interval: ${CHECK_INTERVAL}s"
log_message "INFO" "Max wait time per sample: $((TIMEOUT / 3600))h"
log_message "INFO" "Parallel mode: $PARALLEL_MODE"
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
        processed_samples["$sample_id"]="false"
        log_message "VERBOSE" "Added sample: $sample_id"
    fi
done < "$SAMPLE_IDS_FILE"

if [[ ${#sample_ids[@]} -eq 0 ]]; then
    log_message "ERROR" "No valid sample IDs found in $SAMPLE_IDS_FILE"
    exit 1
fi

log_message "INFO" "Found ${#sample_ids[@]} sample(s) to monitor: ${sample_ids[*]}"

# Calculate max checks based on timeout
max_checks=$((TIMEOUT / CHECK_INTERVAL))

log_message "INFO" "Starting independent monitoring loop (max $max_checks checks per sample)..."

# Main monitoring loop
start_time=$(date +%s)
check_count=0

while true; do
    check_count=$((check_count + 1))
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    
    log_message "INFO" "=== Check $check_count (${elapsed_time}s elapsed) ==="
    
    # Check for running job status updates
    check_running_jobs
    
    ready_count=0
    processed_count=0
    running_count=0
    
    # Check each sample
    for sample_id in "${sample_ids[@]}"; do
        # Count processed samples
        if [[ "${processed_samples[$sample_id]}" == "true" ]]; then
            processed_count=$((processed_count + 1))
            
            # Check running job status
            if [[ "${running_jobs[$sample_id]}" == "RUNNING" ]]; then
                running_count=$((running_count + 1))
            fi
            continue
        fi
        
        log_message "VERBOSE" "Checking sample: $sample_id"
        if check_sample_summary "$sample_id"; then
            ready_count=$((ready_count + 1))
            processed_samples["$sample_id"]="true"
            
            log_message "INFO" "🚀 Triggering pipeline for sample: $sample_id"
            run_sample_pipeline "$sample_id"
            processed_count=$((processed_count + 1))
            
            if [[ "$PARALLEL_MODE" == true ]]; then
                running_count=$((running_count + 1))
            fi
        fi
    done
    
    # Status summary
    pending_count=$((${#sample_ids[@]} - processed_count))
    log_message "INFO" "Status: $processed_count processed, $running_count running, $pending_count pending"
    
    # Check if all samples are processed
    if [[ $processed_count -eq ${#sample_ids[@]} ]]; then
        if [[ "$PARALLEL_MODE" == true ]]; then
            if [[ $running_count -eq 0 ]]; then
                log_message "SUCCESS" "All samples completed!"
                break
            else
                log_message "INFO" "All samples triggered, waiting for $running_count jobs to finish..."
            fi
        else
            log_message "SUCCESS" "All samples completed!"
            break
        fi
    fi
    
    # Check timeout
    if [[ $elapsed_time -gt $TIMEOUT ]]; then
        log_message "WARNING" "Global timeout reached. Processed: $processed_count/${#sample_ids[@]}"
        break
    fi
    
    # Show progress every 12 checks (every hour at 5-min intervals)
    if [[ $((check_count % 12)) -eq 0 ]]; then
        elapsed_hours=$((elapsed_time / 3600))
        log_message "INFO" "Progress: $check_count checks completed (${elapsed_hours}h elapsed)"
    fi
    
    # Wait before next check
    sleep "$CHECK_INTERVAL"
done

# Final summary
completed_count=0
failed_count=0
for sample_id in "${sample_ids[@]}"; do
    case "${running_jobs[$sample_id]}" in
        "COMPLETED"|"SUCCESS")
            completed_count=$((completed_count + 1))
            ;;
        "FAILED")
            failed_count=$((failed_count + 1))
            ;;
    esac
done

log_message "INFO" "=== Final Summary ==="
log_message "INFO" "Total samples: ${#sample_ids[@]}"
log_message "INFO" "Processed: $processed_count"
log_message "INFO" "Completed successfully: $completed_count"
log_message "INFO" "Failed: $failed_count"
log_message "INFO" "Pending: $((${#sample_ids[@]} - processed_count))"

if [[ $failed_count -gt 0 ]]; then
    log_message "WARNING" "Some samples failed processing"
    exit 1
else
    log_message "SUCCESS" "All processed samples completed successfully!"
    exit 0
fi
