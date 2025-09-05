#!/bin/bash

#==============================================================================
# Sample-Based Pipeline Monitor Script
#==============================================================================
# 
# Monitors for final_summary_*_*_* files within individual sample directories
# and triggers the pipeline when ALL samples have completed BAM processing.
#
# Directory structure expected:
#   ${BASE_DATA_DIR}/
#   ├── T001/Dummy/final_summary_*_*_*.txt
#   ├── T002/Dummy/final_summary_*_*_*.txt
#   └── ...
#
# Usage: ./sample_monitor.sh [base_data_directory] [sample_ids_file] [pipeline_base_directory] [nextflow_work_directory]
#
# Examples:
#   ./sample_monitor.sh
#   ./sample_monitor.sh /path/to/data /path/to/sample_ids.txt
#   ./sample_monitor.sh /path/to/data /path/to/sample_ids.txt /path/to/pipeline /path/to/work
#==============================================================================

set -e

# Configuration
BASE_DATA_DIR="${1:-/home/chbope/extension/nWGS_manuscript_data/data/testdata}"
SAMPLE_IDS_FILE="${2:-/home/chbope/Documents/nanopore/nWGS_manuscript/nWGS_pipeline_docker_test/assets/sample_ids.txt}"
PIPELINE_BASE_DIR="${3:-/home/chbope/Documents/nanopore/nWGS_manuscript/nWGS_pipeline_docker_test/}"
NEXTFLOW_WORK_DIR="${4:-/home/chbope/extension/trash/}"
CHECK_INTERVAL=300  # 5 minutes between checks
MAX_CHECKS=1440    # 1440 checks * 5min = 5 days max wait

echo "=== Sample-Based nWGS Pipeline Monitor ==="
echo "Base data directory: $BASE_DATA_DIR"
echo "Sample IDs file: $SAMPLE_IDS_FILE"
echo "Pipeline base directory: $PIPELINE_BASE_DIR"
echo "Nextflow work directory (-w): $NEXTFLOW_WORK_DIR"
echo "Check interval: ${CHECK_INTERVAL}s"
echo "Max wait time: $((MAX_CHECKS * CHECK_INTERVAL / 3600))h"
echo

# Check if directories and files exist
if [[ ! -d "$BASE_DATA_DIR" ]]; then
    echo "ERROR: Base data directory does not exist: $BASE_DATA_DIR"
    exit 1
fi

if [[ ! -f "$SAMPLE_IDS_FILE" ]]; then
    echo "ERROR: Sample IDs file does not exist: $SAMPLE_IDS_FILE"
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

# Read sample IDs from file
echo "Reading sample IDs from: $SAMPLE_IDS_FILE"
sample_ids=()
while IFS= read -r line; do
    # Remove whitespace and skip empty lines
    sample_id=$(echo "$line" | xargs)
    if [[ -n "$sample_id" && ! "$sample_id" =~ ^# ]]; then
        sample_ids+=("$sample_id")
    fi
done < "$SAMPLE_IDS_FILE"

if [[ ${#sample_ids[@]} -eq 0 ]]; then
    echo "ERROR: No valid sample IDs found in $SAMPLE_IDS_FILE"
    exit 1
fi

echo "Found ${#sample_ids[@]} sample(s) to monitor:"
for sample_id in "${sample_ids[@]}"; do
    echo "  - $sample_id"
done
echo

# Function to check a single sample's summary files
check_sample_summary() {
    local sample_id="$1"
    local sample_dir="$BASE_DATA_DIR/$sample_id"
    local dummy_dir="$sample_dir/Dummy"
    
    # Check if sample directory exists
    if [[ ! -d "$sample_dir" ]]; then
        echo "    ⚠ Sample directory not found: $sample_dir"
        return 1
    fi
    
    # Check if Dummy directory exists
    if [[ ! -d "$dummy_dir" ]]; then
        echo "    ⚠ Dummy directory not found: $dummy_dir"
        return 1
    fi
    
    # Find final_summary files in Dummy directory
    local summary_files=($(find "$dummy_dir" -maxdepth 1 -name "final_summary_*_*_*" -type f 2>/dev/null))
    
    if [[ ${#summary_files[@]} -eq 0 ]]; then
        echo "    ⚠ No final_summary files found in $dummy_dir"
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
            
            echo "    ✓ Ready: $(basename "$file") (${file_age_hours}h ago)"
            return 0
        fi
    done
    
    echo "    ⚠ Final_summary files found but are empty (processing in progress)"
    return 1
}

echo "Starting monitoring loop..."
echo

# Monitoring loop
for ((i=1; i<=MAX_CHECKS; i++)); do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Check $i/$MAX_CHECKS - Checking sample summary files..."
    
    ready_samples=()
    pending_samples=()
    
    # Check each sample
    for sample_id in "${sample_ids[@]}"; do
        echo "  Checking sample: $sample_id"
        if check_sample_summary "$sample_id"; then
            ready_samples+=("$sample_id")
        else
            pending_samples+=("$sample_id")
        fi
    done
    
    echo
    echo "  Summary: ${#ready_samples[@]}/${#sample_ids[@]} samples ready"
    
    if [[ ${#ready_samples[@]} -gt 0 ]]; then
        echo "    Ready samples: ${ready_samples[*]}"
    fi
    
    if [[ ${#pending_samples[@]} -gt 0 ]]; then
        echo "    Pending samples: ${pending_samples[*]}"
    fi
    
    # Check if all samples are ready
    if [[ ${#ready_samples[@]} -eq ${#sample_ids[@]} ]]; then
        echo
        echo "✓ ALL SAMPLES ARE READY!"
        echo "✓ BAM processing appears to be complete for all samples!"
        break
    fi
    
    # Show progress every 12 checks (every hour)
    if [[ $((i % 12)) -eq 0 ]]; then
        elapsed=$((i * CHECK_INTERVAL))
        remaining=$(((MAX_CHECKS - i) * CHECK_INTERVAL))
        elapsed_hours=$((elapsed / 3600))
        remaining_hours=$((remaining / 3600))
        echo "    Progress: $i/$MAX_CHECKS checks completed (${elapsed_hours}h elapsed, ${remaining_hours}h remaining)"
    fi
    
    echo
    
    # Wait before next check (except on last iteration)
    if [[ $i -lt $MAX_CHECKS ]]; then
        sleep "$CHECK_INTERVAL"
    fi
done

# Check final status
if [[ ${#ready_samples[@]} -lt ${#sample_ids[@]} ]]; then
    echo
    echo "=== TIMEOUT: Not all samples completed after maximum wait time ==="
    echo "Ready samples (${#ready_samples[@]}/${#sample_ids[@]}): ${ready_samples[*]}"
    echo "Pending samples: ${pending_samples[*]}"
    echo "Please check that BAM processing is running for all samples"
    exit 2
fi

echo
echo "✓ All samples have completed BAM processing!"
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
