#!/bin/bash

# Quick validation script for nWGS pipeline setup
# This script provides a quick health check of your setup

set -e

echo "=========================================="
echo "nWGS Pipeline Setup Validation"
echo "=========================================="

# Determine container system
CONTAINER_SYSTEM=""
if command -v docker &> /dev/null && docker info &> /dev/null; then
    CONTAINER_SYSTEM="docker"
    echo "Container System: Docker"
elif command -v apptainer &> /dev/null; then
    CONTAINER_SYSTEM="apptainer"
    echo "Container System: Apptainer"
elif command -v singularity &> /dev/null; then
    CONTAINER_SYSTEM="singularity"
    echo "Container System: Singularity"
else
    echo " No container system found"
    exit 1
fi

# Check Nextflow
if command -v nextflow &> /dev/null; then
    echo "✓ Nextflow: $(nextflow --version | head -n1)"
else
    echo " Nextflow not found"
    exit 1
fi

# Check configuration files
echo ""
echo "Configuration Files:"
for config in conf/annotation.config conf/epi2me.config conf/mergebam.config; do
    if [ -f "$config" ]; then
        echo "  ✓ $(basename $config)"
    else
        echo " $(basename $config) missing"
    fi
done

# Check containers
echo ""
echo "Container Images:"
if [ "$CONTAINER_SYSTEM" = "docker" ]; then
    count=$(docker images | grep vilhelmmagnuslab | wc -l)
    echo "  Found $count Docker images"
elif [ "$CONTAINER_SYSTEM" = "apptainer" ] || [ "$CONTAINER_SYSTEM" = "singularity" ]; then
    count=$(ls containers/*.sif 2>/dev/null | wc -l)
    echo "  Found $count Singularity/Apptainer images"
fi

# Check data directories
echo ""
echo "Data Directories:"
for dir in data/reference data/humandb data/testdata data/results; do
    if [ -d "$dir" ]; then
        echo "  ✓ $dir"
    else
        echo "  $dir (will be created when needed)"
    fi
done

# Check for run scripts
if [ -f "run_pipeline_docker.sh" ]; then
    echo "  ✓ run_pipeline_docker.sh"
else
    echo "  run_pipeline_docker.sh missing"
fi

if [ -f "run_pipeline_singularity.sh" ]; then
    echo "  ✓ run_pipeline_singularity.sh"
else
    echo "  run_pipeline_singularity.sh missing"
fi

# Test run script functionality
echo ""
echo "Testing run script functionality..."
if ./run_pipeline_docker.sh --help &> /dev/null; then
    echo "  ✓ Docker pipeline script works"
else
    echo "  Docker pipeline script failed"
fi

if [ "$CONTAINER_SYSTEM" = "apptainer" ] || [ "$CONTAINER_SYSTEM" = "singularity" ]; then
    if ./run_pipeline_singularity.sh --help &> /dev/null; then
        echo "  ✓ Singularity/Apptainer pipeline script works"
    else
        echo "  Singularity/Apptainer pipeline script failed"
    fi
fi

echo ""
echo "=========================================="
echo "Validation Complete!"
echo "=========================================="
echo ""
echo "If you see mostly ✓ marks, your setup is ready!"
echo "If you see marks, please run the appropriate setup script:"
echo ""
if [ "$CONTAINER_SYSTEM" = "docker" ]; then
    echo "  ./setup_docker.sh"
elif [ "$CONTAINER_SYSTEM" = "apptainer" ] || [ "$CONTAINER_SYSTEM" = "singularity" ]; then
    echo "  ./setup_singularity.sh"
fi
echo ""
echo "For detailed testing, run:"
echo "  ./test_pipeline_docker.sh (Docker)"
echo "  ./test_pipeline_singularity.sh (Singularity/Apptainer)"
echo ""
echo "For comprehensive testing guide, see: TESTING_GUIDE.md" 