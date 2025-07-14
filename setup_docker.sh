#!/bin/bash

# nWGS Pipeline Docker Setup Script
# This script helps users set up and run the nWGS pipeline using Docker images

set -e

echo "=========================================="
echo "nWGS Pipeline Docker Setup"
echo "=========================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo " Docker is not installed. Please install Docker first."
    echo "   Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo " Docker daemon is not running. Please start Docker first."
    exit 1
fi

echo "Docker is available and running"

# Create necessary directories
echo "Creating necessary directories..."
mkdir -p data/reference
mkdir -p data/humandb
mkdir -p data/testdata
mkdir -p data/results

# Pull Docker images (this will take some time on first run)
echo "🐳 Pulling Docker images from vilhelmmagnuslab repository..."
echo "   This may take several minutes on first run..."

# Core analysis images
docker pull vilhelmmagnuslab/nwgs_default_images_latest:latest
docker pull vilhelmmagnuslab/ace_1.24.0:latest
docker pull vilhelmmagnuslab/annotcnv_images_27feb1025:latest
docker pull hkubal/clairs-to:latest
docker pull vilhelmmagnuslab/clair3_amd64:latest
docker pull vilhelmmagnuslab/sturgeon_amd64_21jan_latest:latest
docker pull vilhelmmagnuslab/igv_report_amd64:latest
docker pull vilhelmmagnuslab/vcf2circos:latest
docker pull vilhelmmagnuslab/nanodx_env:latest
docker pull vilhelmmagnuslab/markdown_images_28feb2025:latest
docker pull vilhelmmagnuslab/mgmt_nanopipe_amd64_18feb2025_cramoni:latest
docker pull vilhelmmagnuslab/gviz_amd64_latest:latest

# Epi2me images
docker pull vilhelmmagnuslab/snifflesv252_update_latest:latest
docker pull vilhelmmagnuslab/qdnaseq_amd64_latest:latest
docker pull vilhelmmagnuslab/modkit_latest:latest

echo " All Docker images pulled successfully"

# Create a simple run script
cat > run_pipeline.sh << 'EOF'
#!/bin/bash

# nWGS Pipeline Runner Script
# Usage: ./run_pipeline.sh [run_mode] [other_nextflow_options]

set -e

# Check if Nextflow is installed
if ! command -v nextflow &> /dev/null; then
    echo " Nextflow is not installed. Installing Nextflow..."
    curl -s https://get.nextflow.io | bash
    export PATH="$PWD:$PATH"
fi

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
    echo "Using default analysis configuration: $CONFIG"
fi

echo " Starting nWGS pipeline with Docker containers..."
echo "   Configuration: $CONFIG"
echo "   Arguments: $@"

# Run the pipeline
nextflow run main.nf \
    -c "$CONFIG" \
    -with-docker \
    "$@"

echo "Pipeline completed successfully!"
EOF

chmod +x run_pipeline.sh

# Create a quick test script
cat > test_pipeline.sh << 'EOF'
#!/bin/bash

# Quick test script for the nWGS pipeline
# This will run a minimal test to verify everything is working

set -e

echo "🧪 Running quick pipeline test..."

# Create a minimal test sample file
mkdir -p data/testdata
echo "test_sample" > data/testdata/sample_ids.txt

# Run with test profile (if available)
if [ -f "conf/test.config" ]; then
    ./run_pipeline.sh conf/test.config -profile test
else
    echo " No test configuration found. Running with default config..."
    ./run_pipeline.sh conf/analysis.config -profile test
fi

echo " Test completed!"
EOF

chmod +x test_pipeline.sh

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Place your reference files in: data/reference/"
echo "2. Place your input data in: data/testdata/"
echo "3. Update the configuration in: conf/analysis.config"
echo "4. Run the pipeline with: ./run_pipeline.sh"
echo "5. Test the setup with: ./test_pipeline.sh"
echo ""
echo "For more information, see the README.md file."
echo ""
echo "Happy analyzing! 🧬" 