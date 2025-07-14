#!/bin/bash

# Quick test script for the nWGS pipeline with Singularity/Apptainer
# This will run a comprehensive test to verify everything is working

set -e

echo "=========================================="
echo "nWGS Pipeline Singularity/Apptainer Test"
echo "=========================================="

# Test 1: Environment Check
echo "1. Testing Environment..."
SINGULARITY_CMD=""
if command -v apptainer &> /dev/null; then
    SINGULARITY_CMD="apptainer"
    echo "   ✓ Apptainer found"
    apptainer --version
elif command -v singularity &> /dev/null; then
    SINGULARITY_CMD="singularity"
    echo "   ✓ Singularity found"
    singularity --version
else
    echo "   ❌ Neither Singularity nor Apptainer found. Please install one of them."
    exit 1
fi

if command -v nextflow &> /dev/null; then
    echo "   ✓ Nextflow found"
    nextflow --version
else
    echo "   Installing Nextflow..."
    curl -s https://get.nextflow.io | bash
    export PATH="$PWD:$PATH"
    echo "   ✓ Nextflow installed"
fi

# Test 2: Container Images
echo ""
echo "2. Testing Container Images..."
echo "   Checking for required images..."
required_images=(
    "nwgs_default_images_latest.sif"
    "ace_1.24.0_latest.sif"
    "clair3_amd64_latest.sif"
    "nanodx_images_3feb25_latest.sif"
)

missing_images=()
for image in "${required_images[@]}"; do
    if [ -f "containers/$image" ]; then
        echo "   ✓ $image"
    else
        echo "   ❌ $image (missing)"
        missing_images+=("$image")
    fi
done

if [ ${#missing_images[@]} -gt 0 ]; then
    echo ""
    echo "   Some images are missing. Running setup..."
    ./setup_singularity.sh
fi

# Test 3: Configuration Files
echo ""
echo "3. Testing Configuration Files..."
if [ -f "conf/analysis.config" ]; then
    echo "   ✓ analysis.config found"
else
    echo "   ❌ analysis.config missing"
    exit 1
fi

if [ -f "conf/epi2me.config" ]; then
    echo "   ✓ epi2me.config found"
else
    echo "   ❌ epi2me.config missing"
    exit 1
fi

if [ -f "conf/mergebam.config" ]; then
    echo "   ✓ mergebam.config found"
else
    echo "   ❌ mergebam.config missing"
    exit 1
fi

# Test 4: Directory Structure
echo ""
echo "4. Testing Directory Structure..."
mkdir -p data/{reference,humandb,testdata,results}
echo "   ✓ Data directories created"

# Test 5: Test Data Creation
echo ""
echo "5. Creating Test Data..."
mkdir -p data/testdata
echo "test_sample" > data/testdata/sample_ids.txt
echo "   ✓ Test sample file created"

# Test 6: Pipeline Help
echo ""
echo "6. Testing Pipeline Help..."
if ./run_pipeline_singularity.sh --help &> /dev/null; then
    echo "   ✓ Pipeline help command works"
else
    echo "   ❌ Pipeline help command failed"
    exit 1
fi

# Test 7: Configuration Validation
echo ""
echo "7. Testing Configuration Validation..."
if nextflow config conf/analysis.config &> /dev/null; then
    echo "   ✓ analysis.config is valid"
else
    echo "   ❌ analysis.config has errors"
    exit 1
fi

# Test 8: Container Test
echo ""
echo "8. Testing Container Access..."
if $SINGULARITY_CMD exec containers/nwgs_default_images_latest.sif --help &> /dev/null; then
    echo "   ✓ Default container is accessible"
else
    echo "   ❌ Default container test failed"
    exit 1
fi

# Test 9: Image Pull Test
echo ""
echo "9. Testing Image Pull Capability..."
if $SINGULARITY_CMD pull docker://hello-world &> /dev/null; then
    echo "   ✓ Image pulling works"
    rm -f hello-world.sif  # Clean up test image
else
    echo "   ❌ Image pulling failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "Singularity/Apptainer Test Complete!"
echo "=========================================="
echo ""
echo "✅ All tests passed! Your Singularity/Apptainer setup is ready."
echo ""
echo "Next steps:"
echo "1. Place your reference files in: data/reference/"
echo "2. Place your input data in: data/testdata/"
echo "3. Update the configuration in: conf/analysis.config"
echo "4. Run the pipeline: ./run_pipeline_singularity.sh --run_mode_order --sample_id YOUR_SAMPLE_ID"
echo ""
echo "For more information, see:"
echo "- README.md"
echo "- SINGULARITY_SETUP.md"
echo "- TESTING_GUIDE.md" 