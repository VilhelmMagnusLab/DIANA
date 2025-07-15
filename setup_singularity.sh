#!/bin/bash

# nWGS Pipeline Singularity/Apptainer Setup Script
set -e

echo "=========================================="
echo "nWGS Pipeline Singularity/Apptainer Setup"
echo "=========================================="

# Check if Singularity or Apptainer is installed
SINGULARITY_CMD=""
if command -v apptainer &> /dev/null; then
    SINGULARITY_CMD="apptainer"
    echo "✓ Apptainer found"
elif command -v singularity &> /dev/null; then
    SINGULARITY_CMD="singularity"
    echo "✓ Singularity found"
else
    echo "   Neither Singularity nor Apptainer is installed."
    echo "   Please install one of them:"
    echo "   - Apptainer: https://apptainer.org/docs/admin/main/installation.html"
    echo "   - Singularity: https://sylabs.io/guides/latest/admin-guide/installation.html"
    exit 1
fi

echo "Using: $SINGULARITY_CMD"

# Create necessary directories
echo "Creating necessary directories..."
mkdir -p data/reference
mkdir -p data/humandb
mkdir -p data/testdata
mkdir -p data/results
mkdir -p containers

# Pull Singularity/Apptainer images
echo "   Pulling Singularity/Apptainer images..."
echo "   This may take several minutes on first run..."

# Function to pull image if it doesn't exist
pull_if_not_exists() {
    local image_name=$1
    # Extract just the image name from the repository path (e.g., "vilhelmmagnuslab/nwgs_default_images" -> "nwgs_default_images")
    local image_basename=$(basename "$image_name")
    local image_file="containers/${image_basename}_latest.sif"
    
    if [ -f "$image_file" ]; then
        echo "   ✓ $image_name already exists, skipping..."
    else
        echo "   Pulling $image_name..."
        $SINGULARITY_CMD pull --dir containers/ docker://$image_name:latest
    fi
}

# Core analysis images
echo "Pulling core analysis images..."
pull_if_not_exists "vilhelmmagnuslab/nwgs_default_images"
pull_if_not_exists "vilhelmmagnuslab/ace_1.24.0"
pull_if_not_exists "vilhelmmagnuslab/annotcnv_images_27feb1025"
pull_if_not_exists "vilhelmmagnuslab/clair3_amd64"
pull_if_not_exists "vilhelmmagnuslab/igv_report_amd64"
pull_if_not_exists "vilhelmmagnuslab/vcf2circos"
pull_if_not_exists "vilhelmmagnuslab/nanodx_images_3feb25"
pull_if_not_exists "vilhelmmagnuslab/markdown_images_28feb2025"
pull_if_not_exists "vilhelmmagnuslab/mgmt_nanopipe_amd64_18feb2025_cramoni"
pull_if_not_exists "vilhelmmagnuslab/gviz_amd64"

# Epi2me images
echo "Pulling Epi2me analysis images..."
pull_if_not_exists "vilhelmmagnuslab/snifflesv252_update"
pull_if_not_exists "vilhelmmagnuslab/qdnaseq_amd64"
pull_if_not_exists "vilhelmmagnuslab/modkit"

echo "✓ All Singularity/Apptainer images pulled successfully"

# Create a user-friendly run script
cat > run_pipeline_singularity.sh << 'EOF'
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
nextflow run main.nf \
    -c "$CONFIG" \
    -with-singularity \
    "$@"

echo " Pipeline completed successfully!"
EOF

chmod +x run_pipeline_singularity.sh

# Create a quick test script
cat > test_pipeline_singularity.sh << 'EOF'
#!/bin/bash

# Quick test script for the nWGS pipeline with Singularity/Apptainer
set -e

echo " Running quick pipeline test with Singularity/Apptainer..."

# Create a minimal test sample file
mkdir -p data/testdata
echo "test_sample" > data/testdata/sample_ids.txt

# Run with test profile (if available)
if [ -f "conf/test.config" ]; then
    ./run_pipeline_singularity.sh -profile test
else
    echo " No test configuration found. Running with default config..."
    ./run_pipeline_singularity.sh -profile test
fi

echo " Test completed!"
EOF

chmod +x test_pipeline_singularity.sh

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Place your reference files in: data/reference/"
echo "2. Place your input data in: data/testdata/"
echo "3. Update the configuration in: conf/analysis.config"
echo "4. Run the pipeline with: ./run_pipeline_singularity.sh"
echo "5. Test the setup with: ./test_pipeline_singularity.sh"
echo ""
echo "For more information, see the README.md file."
echo ""
echo "Happy analyzing! 🧬" 
