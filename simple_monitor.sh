#!/bin/bash

#==============================================================================
# Simple Pipeline Monitor Script
#==============================================================================
# 
# Simplified version that monitors for final_summary_*_*_* files and runs
# the pipeline when detected.
#
# Usage: ./simple_monitor.sh [monitor_directory] [pipeline_base_directory] [nextflow_work_directory]
#
# Examples:
#   ./simple_monitor.sh
#   ./simple_monitor.sh /path/to/monitor
#   ./simple_monitor.sh /path/to/monitor /path/to/pipeline /path/to/nextflow_work
#==============================================================================

set -e

# Configuration
MONITOR_DIR="${1:-/home/chbope/extension/trash/}"
PIPELINE_BASE_DIR="${2:-/home/chbope/Documents/nanopore/nWGS_manuscript/nWGS_pipeline_docker_test/}"
NEXTFLOW_WORK_DIR="${3:-/home/chbope/extension/trash/}"
CHECK_INTERVAL=300  # 5 minutes between checks  
MAX_CHECKS=1440    # 1440 checks * 5min = 5 days max wait (covers 1-3 day processing time)

echo "=== Simple nWGS Pipeline Monitor ==="
echo "Monitor directory: $MONITOR_DIR"
echo "Pipeline base directory: $PIPELINE_BASE_DIR"
echo "Nextflow work directory (-w): $NEXTFLOW_WORK_DIR"
echo "Check interval: ${CHECK_INTERVAL}s"
echo "Max wait time: $((MAX_CHECKS * CHECK_INTERVAL))s"
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

echo "Starting monitoring loop..."

# Monitoring loop
for ((i=1; i<=MAX_CHECKS; i++)); do
    echo "[$(date '+%H:%M:%S')] Check $i/$MAX_CHECKS - Looking for final_summary files..."
    
    # Find final_summary files
    summary_files=($(find "$MONITOR_DIR" -maxdepth 1 -name "final_summary_*_*_*" -type f 2>/dev/null))
    
    if [[ ${#summary_files[@]} -gt 0 ]]; then
        echo "Found ${#summary_files[@]} final_summary file(s):"
        for file in "${summary_files[@]}"; do
            echo "  - $(basename "$file")"
        done
        
        # Check if any file is recent and not empty
        for file in "${summary_files[@]}"; do
            if [[ -s "$file" ]]; then
                # Get file modification time safely
                file_mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo 0)
                current_time=$(date +%s)
                file_age=$((current_time - file_mtime))
                
                # If file exists and is not empty, consider it ready
                # (You can adjust the age threshold as needed)
                if [[ $file_age -lt 3600 ]]; then  # Within last hour
                    echo "✓ Final_summary file detected: $(basename "$file") (${file_age}s ago)"
                    echo "✓ BAM files appear to be ready!"
                    echo
                    echo "Waiting 10 seconds before starting pipeline..."
                    sleep 10
                    
                    echo "=== Starting nWGS Pipeline ==="
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
                fi
            fi
        done
    fi
    
    # Show progress every 12 checks (every hour)
    if [[ $((i % 12)) -eq 0 ]]; then
        elapsed=$((i * CHECK_INTERVAL))
        remaining=$(((MAX_CHECKS - i) * CHECK_INTERVAL))
        elapsed_hours=$((elapsed / 3600))
        remaining_hours=$((remaining / 3600))
        echo "Progress: $i/$MAX_CHECKS checks completed (${elapsed_hours}h elapsed, ${remaining_hours}h remaining)"
    fi
    
    # Wait before next check (except on last iteration)
    if [[ $i -lt $MAX_CHECKS ]]; then
        sleep "$CHECK_INTERVAL"
    fi
done

echo
echo "=== TIMEOUT: No recent final_summary files found after $((MAX_CHECKS * CHECK_INTERVAL)) seconds ==="
echo "Please check that:"
echo "1. BAM processing is running and will create final_summary_*_*_* files"
echo "2. The monitor directory is correct: $MONITOR_DIR"
echo "3. The processing is not taking longer than expected"
exit 2
