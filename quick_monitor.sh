#!/bin/bash

#==============================================================================
# Quick Pipeline Monitor Script
#==============================================================================
# 
# Simplified version that triggers immediately when ANY final_summary_*_*_*
# file is found (regardless of age).
#
# Usage: ./quick_monitor.sh [monitor_directory] [pipeline_base_directory] [nextflow_work_directory]
#
# Examples:
#   ./quick_monitor.sh
#   ./quick_monitor.sh /path/to/monitor
#   ./quick_monitor.sh /path/to/monitor /path/to/pipeline /path/to/nextflow_work
#==============================================================================

set -e

# Configuration
MONITOR_DIR="${1:-/home/chbope/extension/trash/}"
PIPELINE_BASE_DIR="${2:-/home/chbope/Documents/nanopore/nWGS_manuscript/nWGS_pipeline_docker_test/}"
NEXTFLOW_WORK_DIR="${3:-/home/chbope/extension/trash/}"
CHECK_INTERVAL=30  # seconds
MAX_CHECKS=120     # 120 checks * 30s = 1 hour max wait

echo "=== Quick nWGS Pipeline Monitor ==="
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
        
        # Check if any file is not empty
        found_ready=false
        for file in "${summary_files[@]}"; do
            if [[ -s "$file" ]]; then
                # Get file modification time for display
                file_mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo 0)
                current_time=$(date +%s)
                file_age=$((current_time - file_mtime))
                
                echo "✓ Final_summary file ready: $(basename "$file") (${file_age}s ago)"
                found_ready=true
                break
            fi
        done
        
        if [[ "$found_ready" == true ]]; then
            echo "✓ BAM files appear to be ready!"
            break
        else
            echo "⚠ Final_summary files found but are empty (BAM processing still in progress)"
        fi
    else
        echo "⚠ No final_summary files found yet (waiting for BAM processing to start/complete)"
    fi
    
    # Show progress every 10 checks
    if [[ $((i % 10)) -eq 0 ]]; then
        elapsed=$((i * CHECK_INTERVAL))
        remaining=$(((MAX_CHECKS - i) * CHECK_INTERVAL))
        echo "Progress: $i/$MAX_CHECKS checks completed (${elapsed}s elapsed, ${remaining}s remaining)"
    fi
    
    # Wait before next check (except on last iteration)
    if [[ $i -lt $MAX_CHECKS ]]; then
        sleep "$CHECK_INTERVAL"
    fi
done

# Check if we found ready files
if [[ ${#summary_files[@]} -eq 0 ]]; then
    echo
    echo "=== TIMEOUT: No final_summary files found after $((MAX_CHECKS * CHECK_INTERVAL)) seconds ==="
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
    echo "=== TIMEOUT: final_summary files found but remain empty after $((MAX_CHECKS * CHECK_INTERVAL)) seconds ==="
    echo "BAM processing may be taking longer than expected or may have failed"
    exit 2
fi

echo "✓ BAM files appear to be ready!"
echo

echo "Waiting 5 seconds before starting pipeline..."
sleep 5

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
