#!/bin/bash

# nWGS Pipeline Runner Script for Docker
set -e

# Configurable log paths with defaults
LOG_BASE_DIR="${LOG_BASE_DIR:-$PWD}"  # Default to current directory

# Parse command line arguments for paths
NEXTFLOW_ARGS=()
ANALYSIS_MODE="all"
CUSTOM_RUN_NAME=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --log-dir)
            LOG_BASE_DIR="$2"
            shift 2
            ;;
        --run_mode_annotation)
            ANALYSIS_MODE="$2"
            NEXTFLOW_ARGS+=("$1" "$2")
            shift 2
            ;;
        --run-name)
            CUSTOM_RUN_NAME="$2"
            shift 2
            ;;
        *)
            NEXTFLOW_ARGS+=("$1")
            shift
            ;;
    esac
done

# Check if Nextflow is installed
if ! command -v nextflow &> /dev/null; then
    echo " Nextflow is not installed. Installing Nextflow..."
    curl -s https://get.nextflow.io | bash
    export PATH="$PWD:$PATH"
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo " Docker is not available."
    echo "   Please install Docker or run setup_docker.sh first."
    exit 1
fi

echo "Using: docker"

# Auto-detect config file based on arguments
CONFIG="conf/annotation.config"  # Default config
USE_CONFIG_FILE=false

# Check if run_mode_order is specified (highest priority)
if printf '%s\n' "${NEXTFLOW_ARGS[@]}" | grep -q "--run_mode_order"; then
    CONFIG="conf/annotation.config"
    USE_CONFIG_FILE=true
    echo " Using Analysis configuration for run_mode_order: $CONFIG"
# Check if epi2me mode is specified
elif printf '%s\n' "${NEXTFLOW_ARGS[@]}" | grep -q "--run_mode_epi2me"; then
    CONFIG="conf/epi2me.config"
    USE_CONFIG_FILE=false
    echo " Using Epi2me configuration (via nextflow.config): $CONFIG"
elif printf '%s\n' "${NEXTFLOW_ARGS[@]}" | grep -q "--run_mode_mergebam"; then
    CONFIG="conf/mergebam.config"
    USE_CONFIG_FILE=false
    echo " Using Mergebam configuration (via nextflow.config): $CONFIG"
else
    echo " Using default analysis configuration: $CONFIG"
fi

echo " Starting nWGS pipeline with Docker containers..."
echo "   Log directory: ${LOG_BASE_DIR}"

if [ "$USE_CONFIG_FILE" = true ]; then
    echo "   Configuration: $CONFIG (explicit)"
    echo "   Arguments: ${NEXTFLOW_ARGS[*]}"
    # Run the pipeline with explicit config file
    nextflow run main.nf \
        -c "$CONFIG" \
        -profile docker \
        "${NEXTFLOW_ARGS[@]}"
else
    echo "   Configuration: $CONFIG (via nextflow.config)"
    echo "   Arguments: ${NEXTFLOW_ARGS[*]}"
    # Run the pipeline without explicit config file (let nextflow.config handle it)
    nextflow run main.nf \
        -profile docker \
        "${NEXTFLOW_ARGS[@]}"
fi

# NEW: Add logging organization here (mirror singularity behavior)
if [ $? -eq 0 ]; then
    echo " Pipeline completed successfully!"
    
    # Wait a moment for files to be fully written
    sleep 2
    
    # Find log files (non-timestamped preferred, fallback to timestamped)
    REPORT_FILE=""; TIMELINE_FILE=""; TRACE_FILE=""; NEXTFLOW_LOG=""
    [ -f "report.html" ] && REPORT_FILE="report.html" || REPORT_FILE=$(ls report-*.html 2>/dev/null | tail -1 || echo "")
    [ -f "timeline.html" ] && TIMELINE_FILE="timeline.html" || TIMELINE_FILE=$(ls timeline-*.html 2>/dev/null | tail -1 || echo "")
    [ -f "trace.txt" ] && TRACE_FILE="trace.txt" || TRACE_FILE=$(ls trace-*.txt 2>/dev/null | tail -1 || echo "")
    NEXTFLOW_LOG=$(ls .nextflow.log* 2>/dev/null | tail -1 || echo "")
    
    # Organize logs if they exist
    if [ -n "$REPORT_FILE" ] || [ -n "$TIMELINE_FILE" ] || [ -n "$TRACE_FILE" ] || [ -n "$NEXTFLOW_LOG" ]; then
        echo " Organizing execution logs..."
        
        # Verify files are not empty before processing
        if [ -n "$REPORT_FILE" ] && [ ! -s "$REPORT_FILE" ]; then
            echo "   Warning: Report file is empty, skipping..."
            REPORT_FILE=""
        fi
        if [ -n "$TIMELINE_FILE" ] && [ ! -s "$TIMELINE_FILE" ]; then
            echo "   Warning: Timeline file is empty, skipping..."
            TIMELINE_FILE=""
        fi
        if [ -n "$TRACE_FILE" ] && [ ! -s "$TRACE_FILE" ]; then
            echo "   Warning: Trace file is empty, skipping..."
            TRACE_FILE=""
        fi
        if [ -n "$NEXTFLOW_LOG" ] && [ ! -s "$NEXTFLOW_LOG" ]; then
            echo "   Warning: Nextflow log is empty, skipping..."
            NEXTFLOW_LOG=""
        fi
        
    # Create timestamp + unique id for this run
    if [ -n "$CUSTOM_RUN_NAME" ]; then
        RUN_NAME="$CUSTOM_RUN_NAME"
    else
        RUN_NAME="$(date +%Y%m%d_%H%M%S)"
        UNIQUE_ID=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 8 | head -n 1)
        RUN_NAME="${RUN_NAME}_${UNIQUE_ID}"
    end
        
        # Determine process type for log organization
        PROCESS_TYPE="analysis"  # Default
        if printf '%s\n' "${NEXTFLOW_ARGS[@]}" | grep -q "--run_mode_epi2me"; then
            PROCESS_TYPE="epi2me"
        elif printf '%s\n' "${NEXTFLOW_ARGS[@]}" | grep -q "--run_mode_mergebam"; then
            PROCESS_TYPE="mergebam"
        elif printf '%s\n' "${NEXTFLOW_ARGS[@]}" | grep -q "--run_mode_order"; then
            PROCESS_TYPE="full_pipeline"
        fi
        
    # For Analysis mode, include sub-mode in folder name
    if [ "$PROCESS_TYPE" = "analysis" ] && [ -n "$ANALYSIS_MODE" ]; then
        PROCESS_TYPE="analysis_${ANALYSIS_MODE}"
    fi
        
    # Do not split epi2me into sub-modes; keep epi2me_*
        
        LOG_DIR="${LOG_BASE_DIR}/${PROCESS_TYPE}_${RUN_NAME}"
        
    # Create log directory
        mkdir -p "${LOG_DIR}"
        
    # Determine sample IDs from Nextflow log first; fallback to assets/sample_ids.txt; else T001
    SAMPLE_IDS=""
    if [ -n "$NEXTFLOW_LOG" ] && [ -f "$NEXTFLOW_LOG" ]; then
        # Try multiple extraction patterns for different run modes
        # Pattern 1: "Processing for sample: T25-256" or "Sample_id T25-256"
        SAMPLE_IDS=$(grep -E "Processing (completed )?for sample:|Processing sample:|Sample ID:|Sample_id " "$NEXTFLOW_LOG" \
            | sed -E 's/.*(sample:?|Sample_id) *([A-Za-z0-9._-]+).*/\2/' \
            | grep -E '^[A-Za-z0-9._-]+' \
            | sort -u | tr '\n' ' ')

        # Pattern 2: "Sample thresholds: [T25-256:null]" (for run_mode_annotation)
        if [ -z "$SAMPLE_IDS" ]; then
            SAMPLE_IDS=$(grep -E "Sample thresholds:" "$NEXTFLOW_LOG" \
                | sed -E 's/.*\[([A-Za-z0-9._-]+):.*/\1/' \
                | grep -E '^[A-Za-z0-9._-]+' \
                | sort -u | tr '\n' ' ')
        fi
    fi
    if [ -z "$SAMPLE_IDS" ] && [ -f "assets/sample_ids.txt" ]; then
        SAMPLE_IDS=$(grep -E '^[A-Za-z0-9._-]+' assets/sample_ids.txt | tr '\n' ' ')
    fi
    [ -z "$SAMPLE_IDS" ] && SAMPLE_IDS="T001"

    # Create sample-specific logs
    for sample_id in ${SAMPLE_IDS}; do
        SAMPLE_LOG_DIR="${LOG_DIR}/${sample_id}"
        mkdir -p "${SAMPLE_LOG_DIR}"
        [ -n "$REPORT_FILE" ] && cp "$REPORT_FILE" "${SAMPLE_LOG_DIR}/${sample_id}_report.html"
        [ -n "$TIMELINE_FILE" ] && cp "$TIMELINE_FILE" "${SAMPLE_LOG_DIR}/${sample_id}_timeline.html"
        [ -n "$TRACE_FILE" ] && cp "$TRACE_FILE" "${SAMPLE_LOG_DIR}/${sample_id}_trace.txt"
        [ -n "$NEXTFLOW_LOG" ] && cp "$NEXTFLOW_LOG" "${SAMPLE_LOG_DIR}/${sample_id}_nextflow.log"
    done
    echo "   Sample-specific logs created for: ${SAMPLE_IDS}"
        
        # Delete original logs after copying
        [ -n "$REPORT_FILE" ] && rm "$REPORT_FILE"
        [ -n "$TIMELINE_FILE" ] && rm "$TIMELINE_FILE"
        [ -n "$TRACE_FILE" ] && rm "$TRACE_FILE"
        [ -n "$NEXTFLOW_LOG" ] && rm "$NEXTFLOW_LOG"
        
    echo "   Logs organized in: ${LOG_DIR}"
    else
        echo "   No log files found to organize"
    fi
else
    echo " Pipeline failed!"
    exit 1
fi 