#!/bin/bash

# Quick test script for the nWGS pipeline with Singularity/Apptainer
set -e

echo " Running quick pipeline test with Singularity/Apptainer..."

# Run with test profile (if available)
if [ -f "conf/test.config" ]; then
    ./run_pipeline_singularity.sh -profile test
else
    echo " No test configuration found. Running with default config..."
    ./run_pipeline_singularity.sh -profile test
fi

echo " Test completed!"
