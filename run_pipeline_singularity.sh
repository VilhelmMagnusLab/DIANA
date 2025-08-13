#!/bin/bash

# nWGS Pipeline Runner Script for Singularity/Apptainer
set -e

# Configurable log paths with defaults
LOG_BASE_DIR="${LOG_BASE_DIR:-$PWD}"  # Default to current directory/logs

# Parse command line arguments for paths
NEXTFLOW_ARGS=()
ANALYSIS_MODE="all"  # Default analysis mode
CUSTOM_RUN_NAME=""   # Custom run name if specified
while [[ $# -gt 0 ]]; do
    case $1 in
        --log-dir)
            LOG_BASE_DIR="$2"
            shift 2
            ;;
        --run_mode_analysis)
            ANALYSIS_MODE="$2"
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

# Check if Nextflow is installed
if ! command -v nextflow &> /dev/null; then
    echo " Nextflow is not installed. Installing Nextflow..."
    curl -s https://get.nextflow.io | bash
    export PATH="$PWD:$PATH"
fi

# Check if Singularity/Apptainer is available
SINGULARITY_CMD=""
if command -v apptainer &> /dev/null; then
    SINGULARITY_CMD="apptainer"
elif command -v singularity &> /dev/null; then
    SINGULARITY_CMD="singularity"
else
    echo " Neither Singularity nor Apptainer is available."
    echo "   Please run setup_singularity.sh first."
    exit 1
fi

echo "Using: $SINGULARITY_CMD"

# Auto-detect config file based on arguments
CONFIG="conf/analysis.config"  # Default config
USE_CONFIG_FILE=false

# Check if run_mode_order is specified (highest priority)
if [[ " ${NEXTFLOW_ARGS[*]} " =~ " --run_mode_order " ]]; then
    CONFIG="conf/analysis.config"
    USE_CONFIG_FILE=true
    echo " Using Analysis configuration for run_mode_order: $CONFIG"
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
    echo " Using default analysis configuration: $CONFIG"
fi

echo " Starting nWGS pipeline with Singularity/Apptainer containers..."
echo "   Log directory: ${LOG_BASE_DIR}"

# Store the original directory
ORIGINAL_DIR=$(pwd)

# Change to log directory before running Nextflow so logs are written there
cd "${LOG_BASE_DIR}"

if [ "$USE_CONFIG_FILE" = true ]; then
    echo "   Configuration: $CONFIG (explicit)"
    echo "   Arguments: ${NEXTFLOW_ARGS[*]}"
    # Run the pipeline with explicit config file
    nextflow run "${ORIGINAL_DIR}/main.nf" \
        -c "${ORIGINAL_DIR}/$CONFIG" \
        -with-apptainer \
        -with-report "report.html" \
        -with-timeline "timeline.html" \
        -with-trace "trace.txt" \
        "${NEXTFLOW_ARGS[@]}"
else
    echo "   Configuration: $CONFIG (via nextflow.config)"
    echo "   Arguments: ${NEXTFLOW_ARGS[*]}"
    # Run the pipeline without explicit config file (let nextflow.config handle it)
    nextflow run "${ORIGINAL_DIR}/main.nf" \
        -with-apptainer \
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
    fi
    if [ -f "${LOG_BASE_DIR}/timeline.html" ]; then
        TIMELINE_FILE="${LOG_BASE_DIR}/timeline.html"
    fi
    if [ -f "${LOG_BASE_DIR}/trace.txt" ]; then
        TRACE_FILE="${LOG_BASE_DIR}/trace.txt"
    fi
    
    # Check for timestamped files as fallback - look in log directory
    if [ -z "$REPORT_FILE" ]; then
        REPORT_FILE=$(ls ${LOG_BASE_DIR}/report-*.html 2>/dev/null | tail -1 || echo "")
    fi
    if [ -z "$TIMELINE_FILE" ]; then
        TIMELINE_FILE=$(ls ${LOG_BASE_DIR}/timeline-*.html 2>/dev/null | tail -1 || echo "")
    fi
    if [ -z "$TRACE_FILE" ]; then
        TRACE_FILE=$(ls ${LOG_BASE_DIR}/trace-*.txt 2>/dev/null | tail -1 || echo "")
    fi
    
    NEXTFLOW_LOG=$(ls ${LOG_BASE_DIR}/.nextflow.log* 2>/dev/null | tail -1 || echo "")
    
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
        
        # Create timestamp for this run
        if [ -n "$CUSTOM_RUN_NAME" ]; then
            RUN_NAME="${CUSTOM_RUN_NAME}"
        else
            RUN_NAME="$(date +%Y%m%d_%H%M%S)"
            
            # Add unique identifier to prevent overwriting
            UNIQUE_ID=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 8 | head -n 1)
            RUN_NAME="${RUN_NAME}_${UNIQUE_ID}"
        fi
        
        # Determine process type for log organization; include analysis sub-mode
        PROCESS_TYPE="analysis"  # Default
        if [[ " ${NEXTFLOW_ARGS[*]} " =~ " --run_mode_epi2me " ]]; then
            PROCESS_TYPE="epi2me"
        elif [[ " ${NEXTFLOW_ARGS[*]} " =~ " --run_mode_mergebam " ]]; then
            PROCESS_TYPE="mergebam"
        elif [[ " ${NEXTFLOW_ARGS[*]} " =~ " --run_mode_order " ]]; then
            PROCESS_TYPE="full_pipeline"
        fi
        # Append analysis sub-mode (e.g., analysis_tertp)
        if [ "$PROCESS_TYPE" = "analysis" ] && [ -n "$ANALYSIS_MODE" ]; then
            PROCESS_TYPE="analysis_${ANALYSIS_MODE}"
        fi
        
        LOG_DIR="${LOG_BASE_DIR}/${PROCESS_TYPE}_${RUN_NAME}"
        
        # Create log directory
        mkdir -p "${LOG_DIR}"
        
        # Determine sample IDs from Nextflow log first; fallback to assets/sample_ids.txt; else T001
        SAMPLE_IDS=""
        if [ -n "$NEXTFLOW_LOG" ] && [ -f "$NEXTFLOW_LOG" ]; then
            SAMPLE_IDS=$(grep -E "Processing (completed )?for sample:|Processing sample:|Sample ID:" "$NEXTFLOW_LOG" \
                | sed -E 's/.*sample: *([A-Za-z0-9._-]+).*/\1/' \
                | grep -E '^[A-Za-z0-9._-]+' \
                | sort -u | tr '\n' ' ')
        fi
        # Fallback to sample IDs file from configs per mode
        if [ -z "$SAMPLE_IDS" ]; then
            SAMPLE_FILE=""
            if [ "$PROCESS_TYPE" = "analysis" ] || [[ "$PROCESS_TYPE" == analysis_* ]]; then
                SAMPLE_FILE=$(awk -F'=' '/analyse_sample_id_file/ {gsub(/^[ \t\"]+|[ \t\"]+$/,"",$2); print $2}' "${ORIGINAL_DIR}/conf/analysis.config" | head -1)
            elif [ "$PROCESS_TYPE" = "epi2me" ]; then
                SAMPLE_FILE=$(awk -F'=' '/epi2me_sample_id_file/ {gsub(/^[ \t\"]+|[ \t\"]+$/,"",$2); print $2}' "${ORIGINAL_DIR}/conf/epi2me.config" | head -1)
            elif [ "$PROCESS_TYPE" = "mergebam" ]; then
                SAMPLE_FILE=$(awk -F'=' '/bam_sample_id_file/ {gsub(/^[ \t\"]+|[ \t\"]+$/,"",$2); print $2}' "${ORIGINAL_DIR}/conf/mergebam.config" | head -1)
            fi
            if [ -n "$SAMPLE_FILE" ] && [ -f "$SAMPLE_FILE" ]; then
                SAMPLE_IDS=$(awk -F'[,\t ]+' 'NF {print $1}' "$SAMPLE_FILE" | grep -E '^[A-Za-z0-9._-]+' | sort -u | tr '\n' ' ')
            fi
        fi
        if [ -z "$SAMPLE_IDS" ]; then
            SAMPLE_IDS="T001"
        fi

        if [ -n "$SAMPLE_IDS" ]; then
            for sample_id in ${SAMPLE_IDS}; do
                SAMPLE_LOG_DIR="${LOG_DIR}/${sample_id}"
                mkdir -p "${SAMPLE_LOG_DIR}"
                [ -n "$REPORT_FILE" ] && cp "$REPORT_FILE" "${SAMPLE_LOG_DIR}/${sample_id}_report.html"
                [ -n "$TIMELINE_FILE" ] && cp "$TIMELINE_FILE" "${SAMPLE_LOG_DIR}/${sample_id}_timeline.html"
                [ -n "$TRACE_FILE" ] && cp "$TRACE_FILE" "${SAMPLE_LOG_DIR}/${sample_id}_trace.txt"
                [ -n "$NEXTFLOW_LOG" ] && cp "$NEXTFLOW_LOG" "${SAMPLE_LOG_DIR}/${sample_id}_nextflow.log"
            done
            echo "   Sample-specific logs created for: ${SAMPLE_IDS}"
        fi
        
        # Move original logs to main log directory
        [ -n "$REPORT_FILE" ] && rm "$REPORT_FILE"
        [ -n "$TIMELINE_FILE" ] && rm "$TIMELINE_FILE"
        [ -n "$TRACE_FILE" ] && rm "$TRACE_FILE"
        [ -n "$NEXTFLOW_LOG" ] && rm "$NEXTFLOW_LOG"
        
        #echo "   Logs organized in: ${LOG_DIR}"
    else
        echo " "
    fi
else
    echo " Pipeline failed!"
    exit 1
fi 