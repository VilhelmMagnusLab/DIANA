#!/bin/bash

#==============================================================================
# Pipeline Monitor and Auto-Runner Script
#==============================================================================
# 
# This script monitors a specified directory for the completion of reference 
# summary files (final_summary_*_*_*) and automatically triggers the nWGS 
# pipeline in run_mode_order when all BAM files are ready.
#
# Usage:
#   ./monitor_and_run_pipeline.sh [OPTIONS]
#
# Options:
#   -d, --directory DIR     Directory to monitor (default: /home/chbope/extension/trash/)
#   -p, --pipeline DIR      Pipeline base directory (default: current directory)
#   -w, --workdir DIR       Nextflow working directory (default: /home/chbope/extension/trash/)
#   -i, --interval SEC      Check interval in seconds (default: 30)
#   -t, --timeout SEC       Maximum wait time in seconds (default: 3600, 1 hour)
#   -l, --log-file FILE     Log file path (default: ./monitor_pipeline.log)
#   -v, --verbose           Enable verbose output
#   -h, --help              Show this help message
#
# Examples:
#   # Monitor default directory with default settings
#   ./monitor_and_run_pipeline.sh
#
#   # Monitor custom directory with 60-second intervals
#   ./monitor_and_run_pipeline.sh -d /path/to/monitor -i 60
#
#   # Monitor with custom pipeline and nextflow directories
#   ./monitor_and_run_pipeline.sh -d /path/to/monitor -p /path/to/pipeline -w /path/to/nextflow_work
#
#   # Monitor with verbose output and custom log file
#   ./monitor_and_run_pipeline.sh -v -l /tmp/pipeline_monitor.log
#
#==============================================================================

set -e

# Default configuration
DEFAULT_MONITOR_DIR="/home/chbope/extension/trash/"
DEFAULT_PIPELINE_DIR="$(pwd)"
DEFAULT_NEXTFLOW_WORK_DIR="/home/chbope/extension/trash/"
DEFAULT_CHECK_INTERVAL=300  # 5 minutes between checks
DEFAULT_TIMEOUT=432000     # 5 days (covers 1-3 day processing time)
DEFAULT_LOG_FILE="./monitor_pipeline.log"

# Initialize variables with defaults
MONITOR_DIR="$DEFAULT_MONITOR_DIR"
PIPELINE_DIR="$DEFAULT_PIPELINE_DIR"
NEXTFLOW_WORK_DIR="$DEFAULT_NEXTFLOW_WORK_DIR"
CHECK_INTERVAL="$DEFAULT_CHECK_INTERVAL"
TIMEOUT="$DEFAULT_TIMEOUT"
LOG_FILE="$DEFAULT_LOG_FILE"
VERBOSE=false

# Function to display help
show_help() {
    sed -n '3,36p' "$0" | sed 's/^# //g' | sed 's/^#//g'
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
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to check if pipeline script exists
check_pipeline_script() {
    local pipeline_script="$PIPELINE_DIR/run_pipeline_singularity.sh"
    
    if [[ ! -f "$pipeline_script" ]]; then
        log_message "ERROR" "Pipeline script not found: $pipeline_script"
        log_message "ERROR" "Please check the pipeline directory path: $PIPELINE_DIR"
        exit 1
    fi
    
    if [[ ! -x "$pipeline_script" ]]; then
        log_message "WARNING" "Pipeline script is not executable, making it executable..."
        chmod +x "$pipeline_script"
    fi
}

# Function to validate directories
validate_directories() {
    if [[ ! -d "$MONITOR_DIR" ]]; then
        log_message "ERROR" "Monitor directory does not exist: $MONITOR_DIR"
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
    
    log_message "INFO" "Monitor directory: $MONITOR_DIR"
    log_message "INFO" "Pipeline directory: $PIPELINE_DIR"
    log_message "INFO" "Nextflow work directory: $NEXTFLOW_WORK_DIR"
}

# Function to find final_summary files
find_summary_files() {
    find "$MONITOR_DIR" -maxdepth 1 -name "final_summary_*_*_*" -type f 2>/dev/null
}

# Function to check if summary files indicate completion
check_completion_status() {
    local summary_files=($(find_summary_files))
    
    if [[ ${#summary_files[@]} -eq 0 ]]; then
        log_message "VERBOSE" "No final_summary files found in $MONITOR_DIR"
        return 1
    fi
    
    log_message "VERBOSE" "Found ${#summary_files[@]} final_summary file(s):"
    for file in "${summary_files[@]}"; do
        log_message "VERBOSE" "  - $(basename "$file")"
        
        # Check if file is not empty and recently modified (indicating completion)
        if [[ -s "$file" ]]; then
            local file_mtime
            if command -v stat >/dev/null 2>&1; then
                # Try Linux stat format first, then macOS format
                file_mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo 0)
            else
                # Fallback if stat is not available
                file_mtime=0
            fi
            
            local current_time=$(date +%s)
            local file_age=$((current_time - file_mtime))
            
            # If file exists and is not empty, consider it ready (adjust threshold as needed)
            if [[ $file_age -lt 3600 ]]; then  # Within last hour
                log_message "INFO" "Found final_summary file: $(basename "$file") (${file_age}s ago)"
                return 0
            else
                log_message "VERBOSE" "Final_summary file exists but is older: $(basename "$file") (${file_age}s ago)"
            fi
        else
            log_message "VERBOSE" "Final_summary file is empty: $(basename "$file")"
        fi
    done
    
    return 1
}

# Function to run the pipeline
run_pipeline() {
    log_message "INFO" "Starting nWGS pipeline with --run_mode_order..."
    log_message "INFO" "Command: bash $PIPELINE_DIR/run_pipeline_singularity.sh --run_mode_order -w '$NEXTFLOW_WORK_DIR'"
    
    # Create a unique log file for this pipeline run
    local pipeline_log="${LOG_FILE%.log}_pipeline_$(date +%Y%m%d_%H%M%S).log"
    
    # Change to pipeline directory and run the pipeline
    cd "$PIPELINE_DIR"
    
    # Run the pipeline and capture both stdout and stderr
    if bash "$PIPELINE_DIR/run_pipeline_singularity.sh" --run_mode_order -w "$NEXTFLOW_WORK_DIR" 2>&1 | tee "$pipeline_log"; then
        log_message "SUCCESS" "Pipeline completed successfully!"
        log_message "INFO" "Pipeline logs saved to: $pipeline_log"
        return 0
    else
        local exit_code=$?
        log_message "ERROR" "Pipeline failed with exit code: $exit_code"
        log_message "ERROR" "Pipeline logs saved to: $pipeline_log"
        return $exit_code
    fi
}

# Function to handle script interruption
cleanup() {
    log_message "INFO" "Script interrupted. Cleaning up..."
    exit 130
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directory)
            MONITOR_DIR="$2"
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
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -l|--log-file)
            LOG_FILE="$2"
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

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main script execution
main() {
    log_message "INFO" "=== nWGS Pipeline Monitor Started ==="
    log_message "INFO" "Monitor directory: $MONITOR_DIR"
    log_message "INFO" "Pipeline directory: $PIPELINE_DIR"
    log_message "INFO" "Nextflow work directory: $NEXTFLOW_WORK_DIR"
    log_message "INFO" "Check interval: ${CHECK_INTERVAL}s"
    log_message "INFO" "Timeout: ${TIMEOUT}s"
    log_message "INFO" "Log file: $LOG_FILE"
    log_message "INFO" "Verbose mode: $VERBOSE"
    
    # Validate setup
    check_pipeline_script
    validate_directories
    
    # Initialize monitoring
    local start_time=$(date +%s)
    local end_time=$((start_time + TIMEOUT))
    local check_count=0
    
    log_message "INFO" "Starting monitoring loop..."
    log_message "INFO" "Will check for final_summary_*_*_* files every ${CHECK_INTERVAL} seconds"
    log_message "INFO" "Timeout set to ${TIMEOUT} seconds ($(date -d "@$end_time" '+%Y-%m-%d %H:%M:%S'))"
    
    # Monitoring loop
    while true; do
        check_count=$((check_count + 1))
        local current_time=$(date +%s)
        
        log_message "VERBOSE" "Check #$check_count - $(date '+%Y-%m-%d %H:%M:%S')"
        
        # Check if timeout reached
        if [[ $current_time -gt $end_time ]]; then
            log_message "WARNING" "Timeout reached after ${TIMEOUT} seconds"
            log_message "WARNING" "No qualifying final_summary files found within timeout period"
            exit 2
        fi
        
        # Check for completion
        if check_completion_status; then
            log_message "SUCCESS" "BAM files appear to be ready (final_summary file detected)"
            
            # Give a brief delay to ensure file writing is complete
            log_message "INFO" "Waiting 10 seconds to ensure file completion..."
            sleep 10
            
            # Run the pipeline
            if run_pipeline; then
                log_message "SUCCESS" "=== Pipeline execution completed successfully ==="
                exit 0
            else
                log_message "ERROR" "=== Pipeline execution failed ==="
                exit 1
            fi
        fi
        
        # Calculate time remaining
        local time_remaining=$((end_time - current_time))
        local time_elapsed=$((current_time - start_time))
        
        if [[ $((check_count % 10)) -eq 0 ]] || [[ "$VERBOSE" == true ]]; then
            log_message "INFO" "Check #$check_count completed. Time elapsed: ${time_elapsed}s, remaining: ${time_remaining}s"
        fi
        
        # Wait before next check
        sleep "$CHECK_INTERVAL"
    done
}

# Start the main function
main "$@"
