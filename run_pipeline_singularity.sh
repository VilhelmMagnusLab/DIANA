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

# Check if epi2me mode is specified
if [[ "$*" == *"--run_mode_epi2me"* ]]; then
    CONFIG="conf/epi2me.config"
    echo " Using Epi2me configuration: $CONFIG"
elif [[ "$*" == *"--run_mode_mergebam"* ]]; then
    CONFIG="conf/mergebam.config"
    echo " Using Mergebam configuration: $CONFIG"
else
    echo " Using default analysis configuration: $CONFIG"
fi

echo " Starting nWGS pipeline with Singularity/Apptainer containers..."
echo "   Configuration: $CONFIG"
echo "   Arguments: $@"

# Run the pipeline with Singularity/Apptainer
# Note: Apptainer is enabled in nextflow.config, so we don't use -with-singularity flag
nextflow run main.nf \
    -c "$CONFIG" \
    "$@"

echo " Pipeline completed successfully!"
