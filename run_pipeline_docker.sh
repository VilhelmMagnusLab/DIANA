#!/bin/bash

# Diana Pipeline Runner Script for Docker
set -e

# Parse command line arguments
NEXTFLOW_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
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
    CONFIG=""
    USE_CONFIG_FILE=false
    echo " Using sequential order mode (configs loaded by nextflow.config)"
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

echo " Starting Diana pipeline with Docker containers..."

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

echo " Pipeline completed successfully!"