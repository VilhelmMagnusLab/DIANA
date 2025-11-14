#!/bin/bash

#==============================================================================
# Smart Sample Monitor v2 - Robust ONT BAM Processing Monitor
#==============================================================================
#
# Version 2 Changes:
# - Hardcoded sample_ids file path: /data/routine_nWGS/sample_ids_bam.txt
# - Command-line --data-dir takes precedence over input_dir from mergebam.config
#   (passed to pipeline as --input_dir override)
# - Resume disabled by default, use --resume flag to enable caching
#
# Monitors ONT basecalled individual BAM files independently and triggers
# the nWGS pipeline immediately when ANY sample's final_summary file becomes ready.
# Features intelligent config parsing, dynamic subdirectory detection, and
# robust error handling. This script should be run once the ONT sequencing is started
#
# Directory structure supported:
#   ${BASE_DATA_DIR}/
#   ├── T001/[any_subdirectory]/final_summary_*_*_*.txt
#   ├── T002/[any_subdirectory]/final_summary_*_*_*.txt
#   └── ...
#
# Usage: ./smart_sample_monitor_v2.sh [options]
#
# Options:
#   -d, --data-dir DIR      Base data directory (TAKES PRECEDENCE over config)
#   -p, --pipeline DIR      Pipeline base directory (default: current)
#   -w, --workdir DIR       Nextflow work directory base (default: /tmp/nextflow_work)
#   -c, --config FILE       Config file to parse (default: conf/mergebam.config)
#   -i, --interval SEC      Check interval in seconds (default: 300)
#   -t, --timeout SEC       Timeout per sample in seconds (default: 432000)
#   -r, --resume            Enable Nextflow resume (use cached results)
#   -v, --verbose           Verbose logging
#   -h, --help              Show help
#
# Examples:
#   ./smart_sample_monitor_v2.sh
#   ./smart_sample_monitor_v2.sh -v
#   ./smart_sample_monitor_v2.sh -d /custom/data
#   ./smart_sample_monitor_v2.sh -r  # Enable resume
#==============================================================================

set -eo pipefail

# Script metadata
readonly SCRIPT_NAME="Smart Sample Monitor v2"
readonly SCRIPT_VERSION="2.0"
readonly SCRIPT_DATE="2025-11-11"

# HARDCODED CONFIGURATION
readonly HARDCODED_SAMPLE_IDS_FILE="/data/routine_nWGS/sample_ids_bam.txt"

# Detect script location for finding pipeline directory
# Resolve symlinks to find the actual script location
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

# Default configuration
readonly DEFAULT_CONFIG_FILE="conf/mergebam.config"
readonly DEFAULT_PIPELINE_DIR="$SCRIPT_DIR"
readonly DEFAULT_NEXTFLOW_WORK_DIR="/data/trash"
readonly DEFAULT_CHECK_INTERVAL=300
readonly DEFAULT_TIMEOUT=432000

# Global variables
CONFIG_FILE="$DEFAULT_CONFIG_FILE"
PIPELINE_DIR="$DEFAULT_PIPELINE_DIR"
NEXTFLOW_WORK_DIR="$DEFAULT_NEXTFLOW_WORK_DIR"
CHECK_INTERVAL="$DEFAULT_CHECK_INTERVAL"
TIMEOUT="$DEFAULT_TIMEOUT"
VERBOSE=false
BASE_DATA_DIR=""
SAMPLE_IDS_FILE="$HARDCODED_SAMPLE_IDS_FILE"
USER_SPECIFIED_DATA_DIR=false
RESUME_ENABLED=false

# Tracking arrays
declare -A SAMPLE_STATUS=()      # "pending", "ready", "running", "completed", "failed"
declare -A SAMPLE_START_TIME=()  # When sample monitoring started
declare -A SAMPLE_READY_TIME=()  # When sample became ready

# Colors for output (if terminal supports it)
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m' # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly NC=''
fi

#==============================================================================
# Utility Functions
#==============================================================================

show_help() {
    cat << EOF
${CYAN}$SCRIPT_NAME v$SCRIPT_VERSION${NC}
Intelligent monitoring for ONT BAM processing with automatic pipeline triggering

${YELLOW}VERSION 2 CHANGES:${NC}
  - Sample IDs file hardcoded to: ${HARDCODED_SAMPLE_IDS_FILE}
  - Command-line --data-dir takes precedence over config input_dir
    (overrides mergebam.config by passing --input_dir to pipeline)
  - Resume disabled by default (use --resume flag to enable caching)

${YELLOW}USAGE:${NC}
    $0 [OPTIONS]

${YELLOW}OPTIONS:${NC}
    -d, --data-dir DIR      Base data directory (TAKES PRECEDENCE over config)
    -p, --pipeline DIR      Pipeline base directory (default: current directory)
    -w, --workdir DIR       Nextflow work directory base (default: /tmp/nextflow_work)
    -c, --config FILE       Configuration file to parse (default: conf/mergebam.config)
    -i, --interval SEC      Check interval in seconds (default: 300)
    -t, --timeout SEC       Maximum wait time per sample (default: 432000 = 5 days)
    -r, --resume            Enable Nextflow resume (use cached results)
    -v, --verbose           Enable verbose logging
    -h, --help              Show this help message

${YELLOW}EXAMPLES:${NC}
    # Basic usage with config input_dir (fresh run)
    $0

    # Verbose output
    $0 -v

    # Override data directory (takes precedence over config)
    $0 -d /path/to/data

    # Enable resume to use cached results
    $0 -r

    # Different config file with resume
    $0 -c conf/analysis.config -r -v

${YELLOW}DIRECTORY STRUCTURE:${NC}
    The script expects sample directories with final_summary files:

    data_directory/
    ├── SAMPLE_01/
    │   └── [any_subdirectory]/
    │       └── final_summary_*_*_*.txt
    ├── SAMPLE_02/
    │   └── [different_subdirectory]/
    │       └── final_summary_*_*_*.txt
    └── ...

${YELLOW}SAMPLE IDS FILE (HARDCODED):${NC}
    Location: ${HARDCODED_SAMPLE_IDS_FILE}

    Single column:          Tab-separated:
    T001                    T001    flow_cell_1
    T002                    T002    flow_cell_2
    T003                    T003    flow_cell_3

For more information, see the documentation.
EOF
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=""

    case "$level" in
        ERROR)   color="$RED" ;;
        WARNING) color="$YELLOW" ;;
        SUCCESS) color="$GREEN" ;;
        INFO)    color="$BLUE" ;;
        VERBOSE) color="$CYAN" ;;
        *)       color="" ;;
    esac

    if [[ "$level" == "VERBOSE" && "$VERBOSE" != true ]]; then
        return
    fi

    echo -e "${color}[$timestamp] [$level]${NC} $message"
}

die() {
    log "ERROR" "$*"
    exit 1
}

#==============================================================================
# Configuration Parsing Functions
#==============================================================================

extract_config_value() {
    local config_file="$1"
    local param_name="$2"

    [[ -f "$config_file" ]] || return 1

    # Extract parameter value, handling various quote styles and comments
    grep -E "^\s*${param_name}\s*=" "$config_file" | \
        sed -E 's|^\s*[^=]*=\s*"?([^"#]*)"?.*|\1|' | \
        sed 's|//.*||' | \
        xargs | \
        head -1
}

resolve_variables() {
    local input_path="$1"
    local config_file="$2"
    local resolved_path="$input_path"

    # Extract base variables
    local base_path=$(extract_config_value "$config_file" "path")
    local nwgs_dir=$(extract_config_value "$config_file" "nWGS_dir")

    # Replace variable patterns
    if [[ -n "$base_path" ]]; then
        resolved_path="${resolved_path//\$\{params.path\}/$base_path}"
        resolved_path="${resolved_path//\$\{path\}/$base_path}"
    fi

    if [[ -n "$nwgs_dir" ]]; then
        resolved_path="${resolved_path//\$\{params.nWGS_dir\}/$nwgs_dir}"
        resolved_path="${resolved_path//\$\{nWGS_dir\}/$nwgs_dir}"
    fi

    echo "$resolved_path"
}

validate_config() {
    local config_file="$1"

    # If config file is relative, make it relative to pipeline directory
    if [[ ! "$config_file" =~ ^/ ]]; then
        config_file="${PIPELINE_DIR}/${config_file}"
    fi

    if [[ ! -f "$config_file" ]]; then
        die "Configuration file not found: $config_file"
    fi

    local base_path=$(extract_config_value "$config_file" "path")
    if [[ -z "$base_path" ]]; then
        die "Required 'path' variable not found in config: $config_file"
    fi

    log "VERBOSE" "Configuration validation passed for: $config_file"
    log "VERBOSE" "Base path: $base_path"

    # Update CONFIG_FILE to the resolved path
    CONFIG_FILE="$config_file"
}

auto_detect_paths() {
    validate_config "$CONFIG_FILE"

    local base_path=$(extract_config_value "$CONFIG_FILE" "path")

    # VERSION 2 CHANGE: Check if user specified data directory via command line
    if [[ "$USER_SPECIFIED_DATA_DIR" == true ]]; then
        log "INFO" "Using user-specified data directory (takes precedence): $BASE_DATA_DIR"
    else
        # Auto-detect base data directory from config
        if [[ -z "$BASE_DATA_DIR" ]]; then
            # VERSION 2 CHANGE: Priority order is now:
            # 1. User-specified --data-dir (already handled above)
            # 2. input_dir from config
            # 3. Fallback search patterns

            local input_dir=$(extract_config_value "$CONFIG_FILE" "input_dir")
            if [[ -n "$input_dir" ]]; then
                BASE_DATA_DIR=$(resolve_variables "$input_dir" "$CONFIG_FILE")
                log "INFO" "Auto-detected data directory from config input_dir: $BASE_DATA_DIR"
            else
                # Search for common data directory patterns
                log "VERBOSE" "No input_dir in config, searching for data directories..."

                local candidate_dirs=()

                # Look for common directory names under base_path
                for subdir in "testdata" "data" "samples" "input" "bam_data"; do
                    local candidate="$base_path/$subdir"
                    if [[ -d "$candidate" ]]; then
                        candidate_dirs+=("$candidate")
                    fi
                done

                # Also check if base_path itself contains sample directories
                if [[ -d "$base_path" ]]; then
                    local sample_like_dirs=($(find "$base_path" -maxdepth 1 -type d -name "*[0-9]*" 2>/dev/null | head -3))
                    if [[ ${#sample_like_dirs[@]} -gt 0 ]]; then
                        candidate_dirs+=("$base_path")
                    fi
                fi

                # Use the first valid candidate
                for candidate in "${candidate_dirs[@]}"; do
                    if [[ -d "$candidate" ]]; then
                        BASE_DATA_DIR="$candidate"
                        log "INFO" "Auto-detected data directory by search: $BASE_DATA_DIR"
                        break
                    fi
                done

                # Final fallback - use base_path itself
                if [[ -z "$BASE_DATA_DIR" ]]; then
                    BASE_DATA_DIR="$base_path"
                    log "WARNING" "Using base path as data directory: $BASE_DATA_DIR"
                fi
            fi
        fi
    fi

    # VERSION 2: Sample IDs file is hardcoded - just log it
    log "INFO" "Using hardcoded sample IDs file: $SAMPLE_IDS_FILE"

    # Validate results
    [[ -n "$BASE_DATA_DIR" ]] || die "Could not determine base data directory"
    [[ -n "$SAMPLE_IDS_FILE" ]] || die "Sample IDs file path not set"

    # Check for unresolved variables
    if [[ "$BASE_DATA_DIR" =~ \$\{ ]]; then
        die "Unresolved variables in data directory: $BASE_DATA_DIR"
    fi

    if [[ "$SAMPLE_IDS_FILE" =~ \$\{ ]]; then
        die "Unresolved variables in sample file: $SAMPLE_IDS_FILE"
    fi
}

#==============================================================================
# Sample Management Functions
#==============================================================================

load_samples() {
    local samples=()
    local line_count=0
    local valid_count=0

    if [[ ! -f "$SAMPLE_IDS_FILE" ]]; then
        die "Sample IDs file not found: $SAMPLE_IDS_FILE"
    fi

    # Send log messages to stderr so they don't interfere with return value
    log "VERBOSE" "Reading sample IDs from: $SAMPLE_IDS_FILE" >&2

    while IFS=$'\t' read -r sample_id flow_cell_id || [[ -n "$sample_id" ]]; do
        ((line_count++))
        sample_id=$(echo "$sample_id" | xargs)  # Trim whitespace

        log "VERBOSE" "Line $line_count: raw='$sample_id' flow_cell='${flow_cell_id:-}'" >&2

        # Skip empty lines and comments
        if [[ -n "$sample_id" && ! "$sample_id" =~ ^# ]]; then
            samples+=("$sample_id")
            SAMPLE_STATUS["$sample_id"]="pending"
            SAMPLE_START_TIME["$sample_id"]=$(date +%s)
            ((valid_count++))
            log "VERBOSE" "Added valid sample #$valid_count: $sample_id" >&2
        else
            log "VERBOSE" "Skipped line $line_count: empty or comment" >&2
        fi
    done < "$SAMPLE_IDS_FILE"

    log "INFO" "Processed $line_count lines from sample file" >&2
    log "INFO" "Found $valid_count valid samples" >&2

    if [[ ${#samples[@]} -eq 0 ]]; then
        die "No valid samples found in: $SAMPLE_IDS_FILE"
    fi

    log "INFO" "Loaded samples: ${samples[*]}" >&2
    # Only output the samples to stdout for capture
    echo "${samples[@]}"
}

find_summary_file() {
    local sample_id="$1"
    local sample_dir="$BASE_DATA_DIR/$sample_id"

    # Find all final_summary files recursively
    local summary_files=($(find "$sample_dir" -name "final_summary_*_*_*" -type f 2>/dev/null))

    # Return the first non-empty file found
    for file in "${summary_files[@]}"; do
        if [[ -s "$file" ]]; then
            echo "$file"
            return 0
        fi
    done

    return 1
}

check_sample_ready() {
    local sample_id="$1"

    # Skip if already processed
    case "${SAMPLE_STATUS[$sample_id]}" in
        "ready"|"running"|"completed"|"failed")
            return 1
            ;;
    esac

    local sample_dir="$BASE_DATA_DIR/$sample_id"

    # Check if sample directory exists
    if [[ ! -d "$sample_dir" ]]; then
        log "VERBOSE" "Sample directory not found: $sample_dir"
        return 1
    fi

    # Look for summary file (created by another process)
    local summary_file
    if summary_file=$(find_summary_file "$sample_id"); then
        local file_age=$(( $(date +%s) - $(stat -c %Y "$summary_file" 2>/dev/null || echo 0) ))
        local file_age_hours=$((file_age / 3600))
        local relative_path="${summary_file#$BASE_DATA_DIR/}"

        log "SUCCESS" "Sample $sample_id READY: Found new summary file $relative_path (${file_age_hours}h ago)"
        SAMPLE_STATUS["$sample_id"]="ready"
        SAMPLE_READY_TIME["$sample_id"]=$(date +%s)
        return 0
    else
        log "VERBOSE" "Sample $sample_id: No summary file found yet - waiting for external process to create it"
    fi

    return 1
}

#==============================================================================
# Pipeline Execution Functions
#==============================================================================

run_sample_pipeline() {
    local sample_id="$1"
    local work_dir="$NEXTFLOW_WORK_DIR/${sample_id}_work"

    # Create work directory
    mkdir -p "$work_dir"

    SAMPLE_STATUS["$sample_id"]="running"
    log "INFO" "🚀 Starting pipeline for sample: $sample_id"
    log "INFO" "Work directory: $work_dir"

    local log_file="$work_dir/pipeline.log"
    local status_file="$work_dir/status"

    # Run pipeline directly
    cd "$PIPELINE_DIR"
    log "INFO" "Running pipeline for sample: $sample_id"

    # Build resume flag based on configuration
    local resume_flag=""
    if [[ "$RESUME_ENABLED" == true ]]; then
        resume_flag="-resume"
        log "INFO" "Resume enabled - will use cached results if available"
    else
        log "INFO" "Resume disabled - running fresh pipeline"
    fi

    # Build command with optional input_dir override
    local pipeline_cmd="bash run_pipeline_singularity.sh --run_mode_order -w \"$work_dir\" $resume_flag"

    if [[ "$USER_SPECIFIED_DATA_DIR" == true ]]; then
        pipeline_cmd="$pipeline_cmd --input_dir=\"$BASE_DATA_DIR\""
        log "INFO" "Overriding config input_dir with: $BASE_DATA_DIR"
    fi

    log "VERBOSE" "Pipeline command: $pipeline_cmd"

    # Run pipeline using singularity containers - output shown directly
    if eval "$pipeline_cmd" ; then

        # Check if markdown report was generated successfully
        # The markdown report is published using result_path from analysis.config
        # Try to get result_path from analysis.config, or construct it
        local analysis_config="${PIPELINE_DIR}/conf/analysis.config"
        local result_path=$(extract_config_value "$analysis_config" "result_path")

        # If result_path has variables, resolve them
        if [[ "$result_path" =~ \$\{ ]]; then
            local analysis_base_path=$(extract_config_value "$analysis_config" "path")
            result_path="${result_path//\$\{params.path\}/$analysis_base_path}"
            result_path="${result_path//\$\{path\}/$analysis_base_path}"
        fi

        local report_pattern="${result_path}/${sample_id}/${sample_id}_markdown_pipeline_report.pdf"

        if [[ -f "$report_pattern" ]]; then
            SAMPLE_STATUS["$sample_id"]="completed"
            echo "COMPLETED" > "$status_file"
            log "SUCCESS" "Sample $sample_id pipeline completed successfully - markdown report generated"
        else
            SAMPLE_STATUS["$sample_id"]="failed"
            echo "FAILED" > "$status_file"
            log "ERROR" "Sample $sample_id pipeline failed - markdown report not found at $report_pattern"
        fi
    else
        SAMPLE_STATUS["$sample_id"]="failed"
        echo "FAILED" > "$status_file"
        log "ERROR" "Sample $sample_id pipeline failed - nextflow execution error"
    fi
}


#==============================================================================
# Main Monitoring Logic
#==============================================================================

show_status_summary() {
    local pending=0 ready=0 running=0 completed=0 failed=0

    for sample_id in "${!SAMPLE_STATUS[@]}"; do
        case "${SAMPLE_STATUS[$sample_id]}" in
            "pending")   pending=$((pending + 1)) ;;
            "ready")     ready=$((ready + 1)) ;;
            "running")   running=$((running + 1)) ;;
            "completed") completed=$((completed + 1)) ;;
            "failed")    failed=$((failed + 1)) ;;
        esac
    done

    local total=${#SAMPLE_STATUS[@]}
    log "INFO" "Status: $total total | $pending pending | $ready ready | $running running | $completed completed | $failed failed"
}

monitor_samples() {
    log "VERBOSE" "Starting load_samples function..."
    local samples_string=$(load_samples)
    local samples=($samples_string)

    log "VERBOSE" "Received samples string: '$samples_string'"
    log "VERBOSE" "Parsed into array: ${samples[*]}"
    log "VERBOSE" "Array length: ${#samples[@]}"

    local start_time=$(date +%s)
    local check_count=0
    local max_checks=$((TIMEOUT / CHECK_INTERVAL))

    log "VERBOSE" "Initialized variables: start_time=$start_time, check_count=$check_count, max_checks=$max_checks"

    # Initialize all samples as pending
    for sample_id in "${samples[@]}"; do
        SAMPLE_STATUS["$sample_id"]="pending"
        SAMPLE_START_TIME["$sample_id"]=$start_time
        log "VERBOSE" "Initialized sample $sample_id as pending"
    done

    log "INFO" "🔍 Starting monitoring for ${#samples[@]} samples"
    log "INFO" "Check interval: ${CHECK_INTERVAL}s | Max time: $((TIMEOUT/60))min"

    log "VERBOSE" "About to enter monitoring loop..."
    log "VERBOSE" "Max checks: $max_checks, Timeout: $TIMEOUT, Interval: $CHECK_INTERVAL"

    while true; do
        log "VERBOSE" "Inside while loop, iteration starting..."
        check_count=$((check_count + 1))
        log "VERBOSE" "Check count incremented to: $check_count"
        local current_time=$(date +%s)
        log "VERBOSE" "Got current time: $current_time"
        local elapsed=$((current_time - start_time))
        log "VERBOSE" "Calculated elapsed time: ${elapsed}s"

        log "INFO" "=== Check $check_count (${elapsed}s elapsed) ==="
        log "VERBOSE" "Current time: $current_time, Start time: $start_time, Elapsed: ${elapsed}s"

        # Check each pending sample
        local new_ready_count=0
        for sample_id in "${samples[@]}"; do
            # Skip samples that are already running, completed, or failed
            local current_status="${SAMPLE_STATUS[$sample_id]}"
            if [[ "$current_status" == "running" || "$current_status" == "completed" || "$current_status" == "failed" ]]; then
                log "VERBOSE" "Skipping sample $sample_id (status: $current_status)"
                continue
            fi

            log "VERBOSE" "Checking sample: $sample_id"
            if check_sample_ready "$sample_id"; then
                log "VERBOSE" "Sample $sample_id is ready, incrementing count"
                new_ready_count=$((new_ready_count + 1))

                log "INFO" "About to start pipeline for sample: $sample_id"
                run_sample_pipeline "$sample_id"
                log "VERBOSE" "Pipeline start function completed for sample: $sample_id"
            else
                log "VERBOSE" "Sample $sample_id is not ready yet"
            fi
        done

        log "VERBOSE" "Finished checking samples, new_ready_count: $new_ready_count"

        # Show status summary
        log "VERBOSE" "SAMPLE_STATUS array size: ${#SAMPLE_STATUS[@]}"
        log "VERBOSE" "SAMPLE_STATUS contents: ${!SAMPLE_STATUS[@]}"
        for sid in "${!SAMPLE_STATUS[@]}"; do
            log "VERBOSE" "  $sid -> ${SAMPLE_STATUS[$sid]}"
        done
        show_status_summary

        # Check completion conditions
        local all_processed=true
        local any_running=false

        log "VERBOSE" "Checking completion conditions for ${#samples[@]} samples..."

        for sample_id in "${samples[@]}"; do
            local status="${SAMPLE_STATUS[$sample_id]}"
            log "VERBOSE" "Sample $sample_id status: $status"

            case "$status" in
                "pending"|"ready")
                    log "VERBOSE" "  Setting all_processed=false due to $sample_id being $status"
                    all_processed=false
                    ;;
                "running")
                    log "VERBOSE" "  Setting any_running=true due to $sample_id being running"
                    any_running=true
                    ;;
            esac
        done

        log "VERBOSE" "All processed: $all_processed, Any running: $any_running"

        if [[ "$all_processed" == true ]]; then
            if [[ "$any_running" == false ]]; then
                log "SUCCESS" "🎉 All samples completed!"
                break
            else
                log "INFO" "All samples triggered, waiting for running jobs to finish..."
            fi
        fi

        # Check timeout
        if [[ $elapsed -gt $TIMEOUT ]]; then
            log "WARNING" "Global timeout reached after $((TIMEOUT/3600))h"
            break
        fi

        # Progress report every hour
        if [[ $((check_count % 12)) -eq 0 ]]; then
            local elapsed_hours=$((elapsed / 3600))
            log "INFO" "Progress: $check_count checks, ${elapsed_hours}h elapsed"
        fi

        sleep "$CHECK_INTERVAL"
    done
}

#==============================================================================
# Main Script Logic
#==============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--data-dir)
                BASE_DATA_DIR="$2"
                USER_SPECIFIED_DATA_DIR=true  # VERSION 2: Track user specification
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
            -r|--resume)
                RESUME_ENABLED=true
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
            -s|--samples)
                # VERSION 2: Warn user that this option is ignored
                log "WARNING" "The -s/--samples option is ignored in version 2. Using hardcoded path: $HARDCODED_SAMPLE_IDS_FILE"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done
}

validate_environment() {
    # Check directories
    [[ -d "$PIPELINE_DIR" ]] || die "Pipeline directory not found: $PIPELINE_DIR"
    [[ -f "$PIPELINE_DIR/run_pipeline_singularity.sh" ]] || die "Pipeline script not found: $PIPELINE_DIR/run_pipeline_singularity.sh"

    # Create work directory
    mkdir -p "$NEXTFLOW_WORK_DIR" || die "Cannot create work directory: $NEXTFLOW_WORK_DIR"

    # Validate final paths
    [[ -d "$BASE_DATA_DIR" ]] || die "Data directory not found: $BASE_DATA_DIR"
    [[ -f "$SAMPLE_IDS_FILE" ]] || die "Sample IDs file not found: $SAMPLE_IDS_FILE"

    log "INFO" "Environment validation passed"
}

show_configuration() {
    log "INFO" "=== $SCRIPT_NAME v$SCRIPT_VERSION ==="
    log "INFO" "Configuration:"
    log "INFO" "  Data directory: $BASE_DATA_DIR"
    if [[ "$USER_SPECIFIED_DATA_DIR" == true ]]; then
        log "INFO" "    (user-specified via --data-dir, takes precedence)"
    else
        log "INFO" "    (from config file)"
    fi
    log "INFO" "  Sample IDs file: $SAMPLE_IDS_FILE (hardcoded)"
    log "INFO" "  Pipeline directory: $PIPELINE_DIR"
    log "INFO" "  Work directory: $NEXTFLOW_WORK_DIR"
    log "INFO" "  Config file: $CONFIG_FILE"
    log "INFO" "  Check interval: ${CHECK_INTERVAL}s"
    if [[ $((TIMEOUT/3600)) -gt 0 ]]; then
        log "INFO" "  Timeout: $((TIMEOUT/3600))h"
    else
        log "INFO" "  Timeout: $((TIMEOUT/60))min"
    fi
    log "INFO" "  Resume mode: $RESUME_ENABLED"
    log "INFO" "  Verbose: $VERBOSE"
}

generate_final_report() {
    local completed=0 failed=0 pending=0

    log "INFO" "=== Final Report ==="

    for sample_id in "${!SAMPLE_STATUS[@]}"; do
        local status="${SAMPLE_STATUS[$sample_id]}"
        local duration=""

        if [[ -n "${SAMPLE_READY_TIME[$sample_id]:-}" ]]; then
            local ready_time="${SAMPLE_READY_TIME[$sample_id]}"
            local start_time="${SAMPLE_START_TIME[$sample_id]}"
            duration=" (ready after $((ready_time - start_time))s)"
        fi

        case "$status" in
            "completed")
                ((completed++))
                log "SUCCESS" "$sample_id: $status$duration"
                ;;
            "failed")
                ((failed++))
                log "ERROR" "$sample_id: $status$duration"
                ;;
            *)
                ((pending++))
                log "WARNING" "$sample_id: $status$duration"
                ;;
        esac
    done

    local total=${#SAMPLE_STATUS[@]}
    log "INFO" "Summary: $total total, $completed completed, $failed failed, $pending pending"

    if [[ $failed -eq 0 && $pending -eq 0 ]]; then
        log "SUCCESS" "🎉 All samples completed successfully!"
        return 0
    elif [[ $failed -gt 0 ]]; then
        log "ERROR" "Some samples failed"
        return 1
    else
        log "WARNING" "Some samples still pending"
        return 2
    fi
}

main() {
    # Parse command line
    parse_arguments "$@"

    # VERSION 2: Auto-detect paths with precedence rules
    # (user-specified --data-dir takes precedence over config input_dir)
    auto_detect_paths

    # Validate environment
    validate_environment

    # Show configuration
    show_configuration

    # Start monitoring
    monitor_samples

    # Generate final report
    generate_final_report
}

# Handle script interruption
trap 'log "WARNING" "Script interrupted"; exit 130' SIGINT SIGTERM

# Run main function
main "$@"
