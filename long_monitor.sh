#!/bin/bash

#==============================================================================
# Long-Running Process Monitor Script
#==============================================================================
# 
# Optimized for processes that take 1-3 days to complete.
# Uses adaptive checking intervals to balance responsiveness with resource usage.
#
# Usage: ./long_monitor.sh [monitor_directory] [pipeline_base_directory] [nextflow_work_directory]
#
# Features:
# - Adaptive intervals: starts frequent, becomes less frequent over time
# - Designed for 1-3 day processing times
# - Minimal system resource usage
# - Clear progress reporting in hours/days
#==============================================================================

set -e

# Configuration
MONITOR_DIR="${1:-/home/chbope/extension/trash/}"
PIPELINE_BASE_DIR="${2:-/home/chbope/Documents/nanopore/diana_manuscript/Diana_docker_test/}"
NEXTFLOW_WORK_DIR="${3:-/home/chbope/extension/trash/}"

# Adaptive checking intervals (in seconds)
INITIAL_INTERVAL=60    # 1 minute for first hour
SHORT_INTERVAL=300     # 5 minutes for next 5 hours  
MEDIUM_INTERVAL=900    # 15 minutes for next 18 hours
LONG_INTERVAL=1800     # 30 minutes for remaining time

# Thresholds (in checks, not time)
INITIAL_CHECKS=60      # First 60 checks = 1 hour at 1min intervals
SHORT_CHECKS=60        # Next 60 checks = 5 hours at 5min intervals  
MEDIUM_CHECKS=72       # Next 72 checks = 18 hours at 15min intervals
MAX_TOTAL_CHECKS=432   # Remaining checks = ~90 hours at 30min intervals
                       # Total: ~114 hours = ~4.75 days

echo "=== Long-Running Process Monitor ==="
echo "Monitor directory: $MONITOR_DIR"
echo "Pipeline base directory: $PIPELINE_BASE_DIR"
echo "Nextflow work directory (-w): $NEXTFLOW_WORK_DIR"
echo
echo "Adaptive checking schedule:"
echo "  First hour:     every 1 minute   (60 checks)"
echo "  Next 5 hours:   every 5 minutes  (60 checks)" 
echo "  Next 18 hours:  every 15 minutes (72 checks)"
echo "  Remaining time: every 30 minutes (240 checks)"
echo "  Total max time: ~4.75 days"
echo

# Check if directories exist
if [[ ! -d "$MONITOR_DIR" ]]; then
    echo "ERROR: Monitor directory does not exist: $MONITOR_DIR"
    exit 1
fi

if [[ ! -d "$PIPELINE_BASE_DIR" ]]; then
    echo "ERROR: Pipeline base directory does not exist: $PIPELINE_BASE_DIR"
    exit 1
fi

if [[ ! -d "$NEXTFLOW_WORK_DIR" ]]; then
    echo "ERROR: Nextflow work directory does not exist: $NEXTFLOW_WORK_DIR"
    exit 1
fi

# Check if pipeline script exists
if [[ ! -f "$PIPELINE_BASE_DIR/run_pipeline_singularity.sh" ]]; then
    echo "ERROR: Pipeline script not found: $PIPELINE_BASE_DIR/run_pipeline_singularity.sh"
    echo "Please check the pipeline base directory path"
    exit 1
fi

# Function to get appropriate interval and phase description
get_check_interval() {
    local check_num=$1
    
    if [[ $check_num -le $INITIAL_CHECKS ]]; then
        echo "$INITIAL_INTERVAL|Initial phase (1min intervals)"
    elif [[ $check_num -le $((INITIAL_CHECKS + SHORT_CHECKS)) ]]; then
        echo "$SHORT_INTERVAL|Short phase (5min intervals)"
    elif [[ $check_num -le $((INITIAL_CHECKS + SHORT_CHECKS + MEDIUM_CHECKS)) ]]; then
        echo "$MEDIUM_INTERVAL|Medium phase (15min intervals)"
    else
        echo "$LONG_INTERVAL|Long phase (30min intervals)"
    fi
}

# Function to calculate total elapsed time
calculate_elapsed_time() {
    local check_num=$1
    local total_seconds=0
    
    if [[ $check_num -le $INITIAL_CHECKS ]]; then
        total_seconds=$((check_num * INITIAL_INTERVAL))
    elif [[ $check_num -le $((INITIAL_CHECKS + SHORT_CHECKS)) ]]; then
        total_seconds=$((INITIAL_CHECKS * INITIAL_INTERVAL + (check_num - INITIAL_CHECKS) * SHORT_INTERVAL))
    elif [[ $check_num -le $((INITIAL_CHECKS + SHORT_CHECKS + MEDIUM_CHECKS)) ]]; then
        total_seconds=$((INITIAL_CHECKS * INITIAL_INTERVAL + SHORT_CHECKS * SHORT_INTERVAL + (check_num - INITIAL_CHECKS - SHORT_CHECKS) * MEDIUM_INTERVAL))
    else
        total_seconds=$((INITIAL_CHECKS * INITIAL_INTERVAL + SHORT_CHECKS * SHORT_INTERVAL + MEDIUM_CHECKS * MEDIUM_INTERVAL + (check_num - INITIAL_CHECKS - SHORT_CHECKS - MEDIUM_CHECKS) * LONG_INTERVAL))
    fi
    
    echo $total_seconds
}

echo "Starting monitoring loop..."
echo

# Monitoring loop
for ((i=1; i<=MAX_TOTAL_CHECKS; i++)); do
    # Get current interval and phase
    interval_info=$(get_check_interval $i)
    current_interval=$(echo "$interval_info" | cut -d'|' -f1)
    phase_desc=$(echo "$interval_info" | cut -d'|' -f2)
    
    # Calculate elapsed time
    elapsed_seconds=$(calculate_elapsed_time $i)
    elapsed_hours=$((elapsed_seconds / 3600))
    elapsed_days=$((elapsed_hours / 24))
    remaining_hours=$((elapsed_hours % 24))
    
    if [[ $elapsed_days -gt 0 ]]; then
        time_str="${elapsed_days}d ${remaining_hours}h"
    else
        time_str="${elapsed_hours}h"
    fi
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Check $i/$MAX_TOTAL_CHECKS (${time_str} elapsed) - $phase_desc"
    
    # Find final_summary files
    summary_files=($(find "$MONITOR_DIR" -maxdepth 1 -name "final_summary_*_*_*" -type f 2>/dev/null))
    
    if [[ ${#summary_files[@]} -gt 0 ]]; then
        echo "  Found ${#summary_files[@]} final_summary file(s):"
        for file in "${summary_files[@]}"; do
            echo "    - $(basename "$file")"
        done
        
        # Check if any file is not empty
        found_ready=false
        for file in "${summary_files[@]}"; do
            if [[ -s "$file" ]]; then
                # Get file modification time for display
                file_mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo 0)
                current_time=$(date +%s)
                file_age=$((current_time - file_mtime))
                file_age_hours=$((file_age / 3600))
                
                echo "  ✓ Final_summary file ready: $(basename "$file") (${file_age_hours}h ago)"
                found_ready=true
                break
            fi
        done
        
        if [[ "$found_ready" == true ]]; then
            echo "  ✓ BAM files appear to be ready!"
            break
        else
            echo "  ⚠ Final_summary files found but are empty (BAM processing still in progress)"
        fi
    else
        echo "  ⚠ No final_summary files found yet (waiting for BAM processing to start)"
    fi
    
    # Show detailed progress every phase transition or every 24 checks in long phase
    show_progress=false
    if [[ $i -eq $INITIAL_CHECKS ]] || [[ $i -eq $((INITIAL_CHECKS + SHORT_CHECKS)) ]] || [[ $i -eq $((INITIAL_CHECKS + SHORT_CHECKS + MEDIUM_CHECKS)) ]]; then
        show_progress=true
    elif [[ $i -gt $((INITIAL_CHECKS + SHORT_CHECKS + MEDIUM_CHECKS)) ]] && [[ $((i % 24)) -eq 0 ]]; then
        show_progress=true
    fi
    
    if [[ "$show_progress" == true ]]; then
        echo "  📊 Progress: $i/$MAX_TOTAL_CHECKS checks completed (${time_str} elapsed)"
    fi
    
    # Wait before next check (except on last iteration)
    if [[ $i -lt $MAX_TOTAL_CHECKS ]]; then
        sleep "$current_interval"
    fi
done

# Check final status
if [[ ${#summary_files[@]} -eq 0 ]]; then
    echo
    echo "=== TIMEOUT: No final_summary files found after maximum wait time ==="
    echo "Please check that BAM processing is running and will create final_summary_*_*_* files"
    exit 2
fi

# Check if files are ready
found_ready=false
for file in "${summary_files[@]}"; do
    if [[ -s "$file" ]]; then
        found_ready=true
        break
    fi
done

if [[ "$found_ready" != true ]]; then
    echo
    echo "=== TIMEOUT: final_summary files found but remain empty after maximum wait time ==="
    echo "BAM processing may be taking longer than expected or may have failed"
    exit 2
fi

echo
echo "✓ BAM files appear to be ready!"
echo

echo "Waiting 10 seconds before starting pipeline..."
sleep 10

echo "=== Starting Diana Pipeline ==="
echo "Command: bash $PIPELINE_BASE_DIR/run_pipeline_singularity.sh --run_mode_order -w '$NEXTFLOW_WORK_DIR'"
echo

cd "$PIPELINE_BASE_DIR"
if bash run_pipeline_singularity.sh --run_mode_order -w "$NEXTFLOW_WORK_DIR"; then
    echo
    echo "=== SUCCESS: Pipeline completed successfully! ==="
    exit 0
else
    echo
    echo "=== ERROR: Pipeline failed! ==="
    exit 1
fi
