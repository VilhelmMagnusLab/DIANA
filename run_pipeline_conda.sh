#!/bin/bash

# nWGS Pipeline Runner Script for Conda Environment
set -e

# Configurable log paths with defaults
LOG_BASE_DIR="${LOG_BASE_DIR:-$PWD}"  # Default to current directory/logs

# Parse command line arguments for paths
NEXTFLOW_ARGS=()
ANNOTATION_MODE="all"  # Default annotation mode
CUSTOM_RUN_NAME=""   # Custom run name if specified
while [[ $# -gt 0 ]]; do
    case $1 in
        --log-dir)
            LOG_BASE_DIR="$2"
            shift 2
            ;;
        --run_mode_annotation)
            ANNOTATION_MODE="$2"
            # Still pass this argument to Nextflow
            NEXTFLOW_ARGS+=("$1" "$2")
            shift 2
            ;;
        --run-name)
            CUSTOM_RUN_NAME="$2"
            shift 2
            ;;
        *)
            # Pass other arguments to Nextflow
            NEXTFLOW_ARGS+=("$1")
            shift
            ;;
    esac
done

# Activate conda environment
echo "Activating conda environment: nwgs_env"
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate nwgs_env

# Check if Nextflow is installed in the conda environment
if ! command -v nextflow &> /dev/null; then
    echo " ERROR: Nextflow is not installed in the conda environment."
    echo "   Please install it with: conda install -c bioconda nextflow"
    exit 1
fi

echo "Using: conda environment (nwgs_env) - no containers"

# Auto-detect config file based on arguments
CONFIG="conf/annotation.config"  # Default config
USE_CONFIG_FILE=false

# Check if run_mode_order is specified (highest priority)
if [[ " ${NEXTFLOW_ARGS[*]} " =~ " --run_mode_order " ]]; then
    CONFIG="conf/annotation.config"
    USE_CONFIG_FILE=true
    echo " Using Annotation configuration for run_mode_order: $CONFIG"
# Check if epi2me mode is specified
elif [[ " ${NEXTFLOW_ARGS[*]} " =~ " --run_mode_epi2me " ]]; then
    CONFIG="conf/epi2me.config"
    USE_CONFIG_FILE=false
    echo " Using Epi2me configuration (via nextflow.config): $CONFIG"
elif [[ " ${NEXTFLOW_ARGS[*]} " =~ " --run_mode_mergebam " ]]; then
    CONFIG="conf/mergebam.config"
    USE_CONFIG_FILE=false
    echo " Using Mergebam configuration (via nextflow.config): $CONFIG"
else
    echo " Using default annotation configuration: $CONFIG"
fi

echo " Starting nWGS pipeline with conda environment (no containers)..."
echo "   Log directory: ${LOG_BASE_DIR}"

# Store the original directory
ORIGINAL_DIR=$(pwd)

# Change to log directory before running Nextflow so logs are written there
cd "${LOG_BASE_DIR}"

if [ "$USE_CONFIG_FILE" = true ]; then
    echo "   Configuration: $CONFIG (explicit)"
    echo "   Arguments: ${NEXTFLOW_ARGS[*]}"
    # Run the pipeline with explicit config file (NO containers)
    nextflow run "${ORIGINAL_DIR}/main.nf" \
        -c "${ORIGINAL_DIR}/$CONFIG" \
        -with-report "report.html" \
        -with-timeline "timeline.html" \
        -with-trace "trace.txt" \
        "${NEXTFLOW_ARGS[@]}"
else
    echo "   Configuration: $CONFIG (via nextflow.config)"
    echo "   Arguments: ${NEXTFLOW_ARGS[*]}"
    # Run the pipeline without explicit config file (let nextflow.config handle it) (NO containers)
    nextflow run "${ORIGINAL_DIR}/main.nf" \
        -with-report "report.html" \
        -with-timeline "timeline.html" \
        -with-trace "trace.txt" \
        "${NEXTFLOW_ARGS[@]}"
fi

# Return to original directory
cd "${ORIGINAL_DIR}"

# NEW: Add logging organization here
if [ $? -eq 0 ]; then
    echo " Pipeline completed successfully!"
    
    # Wait a moment for files to be fully written
    sleep 2
    
    # Find log files - check both timestamped and non-timestamped names
    REPORT_FILE=""
    TIMELINE_FILE=""
    TRACE_FILE=""
    NEXTFLOW_LOG=""
    
    # Check for non-timestamped files first (from nextflow.config) - look in log directory
    if [ -f "${LOG_BASE_DIR}/report.html" ]; then
        REPORT_FILE="${LOG_BASE_DIR}/report.html"
    elif [ -f "${LOG_BASE_DIR}/execution_report*.html" ]; then
        REPORT_FILE=$(ls -t "${LOG_BASE_DIR}"/execution_report*.html 2>/dev/null | head -1)
    fi
    
    if [ -f "${LOG_BASE_DIR}/timeline.html" ]; then
        TIMELINE_FILE="${LOG_BASE_DIR}/timeline.html"
    elif [ -f "${LOG_BASE_DIR}/execution_timeline*.html" ]; then
        TIMELINE_FILE=$(ls -t "${LOG_BASE_DIR}"/execution_timeline*.html 2>/dev/null | head -1)
    fi
    
    if [ -f "${LOG_BASE_DIR}/trace.txt" ]; then
        TRACE_FILE="${LOG_BASE_DIR}/trace.txt"
    elif [ -f "${LOG_BASE_DIR}/execution_trace*.txt" ]; then
        TRACE_FILE=$(ls -t "${LOG_BASE_DIR}"/execution_trace*.txt 2>/dev/null | head -1)
    fi
    
    if [ -f "${LOG_BASE_DIR}/.nextflow.log" ]; then
        NEXTFLOW_LOG="${LOG_BASE_DIR}/.nextflow.log"
    fi
    
    # Report the locations
    echo ""
    echo " Log files:"
    [ -n "$REPORT_FILE" ] && echo "   Report: $REPORT_FILE"
    [ -n "$TIMELINE_FILE" ] && echo "   Timeline: $TIMELINE_FILE"
    [ -n "$TRACE_FILE" ] && echo "   Trace: $TRACE_FILE"
    [ -n "$NEXTFLOW_LOG" ] && echo "   Nextflow log: $NEXTFLOW_LOG"
    
else
    echo " Pipeline execution failed"
    echo "        ---------------------------"
    
    # Enhanced error reporting for better debugging
    echo ""
    echo " For debugging:"
    echo "   - Check the Nextflow log file: ${LOG_BASE_DIR}/.nextflow.log"
    if [ -f "${LOG_BASE_DIR}/.nextflow.log" ]; then
        echo "   - Last few lines of the log:"
        tail -10 "${LOG_BASE_DIR}/.nextflow.log" 2>/dev/null | sed 's/^/     /'
    fi
    echo ""
    echo " -- Check '.nextflow.log' file for details"
    exit 1
fi
