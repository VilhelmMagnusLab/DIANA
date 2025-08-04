#!/bin/bash

# nWGS Pipeline Runner Script for Singularity/Apptainer
set -e

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
if echo "$*" | grep -q "--run_mode_order"; then
    CONFIG="conf/analysis.config"
    USE_CONFIG_FILE=true
    echo " Using Analysis configuration for run_mode_order: $CONFIG"
# Check if epi2me mode is specified
elif echo "$*" | grep -q "--run_mode_epi2me"; then
    CONFIG="conf/epi2me.config"
    USE_CONFIG_FILE=false
    echo " Using Epi2me configuration (via nextflow.config): $CONFIG"
elif echo "$*" | grep -q "--run_mode_mergebam"; then
    CONFIG="conf/mergebam.config"
    USE_CONFIG_FILE=false
    echo " Using Mergebam configuration (via nextflow.config): $CONFIG"
else
    echo " Using default analysis configuration: $CONFIG"
fi

echo " Starting nWGS pipeline with Singularity/Apptainer containers..."
if [ "$USE_CONFIG_FILE" = true ]; then
    echo "   Configuration: $CONFIG (explicit)"
    echo "   Arguments: $@"
    # Run the pipeline with explicit config file
    nextflow run main.nf \
        -c "$CONFIG" \
        -with-apptainer \
        "$@"
else
    echo "   Configuration: $CONFIG (via nextflow.config)"
    echo "   Arguments: $@"
    # Run the pipeline without explicit config file (let nextflow.config handle it)
    nextflow run main.nf \
        -with-apptainer \
        "$@"
fi

echo " Pipeline completed successfully!"
