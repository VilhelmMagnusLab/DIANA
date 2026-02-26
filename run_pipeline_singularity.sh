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
# For epiannotation and order modes, nextflow.config handles loading multiple configs
CONFIG=""

# Check if specific mode is specified
if [[ "$*" == *"--run_mode_epiannotation"* ]]; then
    echo " Using combined Epi2me + Annotation mode (configs loaded by nextflow.config)"
    CONFIG=""  # Let nextflow.config handle it
elif [[ "$*" == *"--run_mode_order"* ]]; then
    echo " Using sequential order mode (configs loaded by nextflow.config)"
    CONFIG=""  # Let nextflow.config handle it
elif [[ "$*" == *"--run_mode_epi2me"* ]]; then
    CONFIG="conf/epi2me.config"
    echo " Using Epi2me configuration: $CONFIG"
elif [[ "$*" == *"--run_mode_mergebam"* ]]; then
    CONFIG="conf/mergebam.config"
    echo " Using Mergebam configuration: $CONFIG"
else
    CONFIG="conf/annotation.config"
    echo " Using default annotation configuration: $CONFIG"
fi

echo " Starting nWGS pipeline with Singularity/Apptainer containers..."
if [ -n "$CONFIG" ]; then
    echo "   Configuration: $CONFIG"
fi
echo "   Arguments: $@"

# Run the pipeline with Singularity/Apptainer
# Note: Apptainer is enabled in nextflow.config, so we don't use -with-singularity flag
if [ -n "$CONFIG" ]; then
    nextflow run main.nf -c "$CONFIG" "$@"
else
    nextflow run main.nf "$@"
fi

echo " Pipeline completed successfully!"
