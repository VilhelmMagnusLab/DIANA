#!/bin/bash

# Quick test script for the nWGS pipeline with Docker
# This will run a comprehensive test to verify everything is working

set -e

echo "=========================================="
echo "nWGS Pipeline Docker Test"
echo "=========================================="

# Test 1: Environment Check
echo "1. Testing Environment..."
if command -v docker &> /dev/null; then
    echo "   ✓ Docker found"
    docker --version
else
    echo "   ❌ Docker not found. Please install Docker first."
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

# Test 2: Docker Daemon
echo ""
echo "2. Testing Docker Daemon..."
if docker info &> /dev/null; then
    echo "   ✓ Docker daemon is running"
else
    echo "   ❌ Docker daemon is not running. Please start Docker first."
    exit 1
fi

# Test 3: Docker Images
echo ""
echo "3. Testing Docker Images..."
echo "   Checking for required images..."
required_images=(
    "vilhelmmagnuslab/nwgs_default_images:latest"
    "vilhelmmagnuslab/ace_1.24.0:latest"
    "vilhelmmagnuslab/clair3_amd64:latest"
    "vilhelmmagnuslab/nanodx_images_3feb25:latest"
)

missing_images=()
for image in "${required_images[@]}"; do
    if docker images | grep -q "$(echo $image | cut -d: -f1)"; then
        echo "   ✓ $image"
    else
        echo "   ❌ $image (missing)"
        missing_images+=("$image")
    fi
done

if [ ${#missing_images[@]} -gt 0 ]; then
    echo ""
    echo "   Some images are missing. Running setup..."
    ./setup_docker.sh
fi

# Test 4: Configuration Files
echo ""
echo "4. Testing Configuration Files..."
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

# Test 5: Directory Structure
echo ""
echo "5. Testing Directory Structure..."
mkdir -p data/{reference,humandb,testdata,results}
echo "   ✓ Data directories created"

# Test 6: Test Data Creation
echo ""
echo "6. Creating Test Data..."
mkdir -p data/testdata
echo "test_sample" > data/testdata/sample_ids.txt
echo "   ✓ Test sample file created"

# Test 7: Pipeline Help
echo ""
echo "7. Testing Pipeline Help..."
if ./run_pipeline_docker.sh --help &> /dev/null; then
    echo "   ✓ Pipeline help command works"
else
    echo "   ❌ Pipeline help command failed"
    exit 1
fi

# Test 8: Configuration Validation
echo ""
echo "8. Testing Configuration Validation..."
if nextflow config conf/analysis.config &> /dev/null; then
    echo "   ✓ analysis.config is valid"
else
    echo "   ❌ analysis.config has errors"
    exit 1
fi

# Test 9: Container Test
echo ""
echo "9. Testing Container Access..."
if docker run --rm vilhelmmagnuslab/nwgs_default_images:latest --help &> /dev/null; then
    echo "   ✓ Default container is accessible"
else
    echo "   ❌ Default container test failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "Docker Test Complete!"
echo "=========================================="
echo ""
echo "✅ All tests passed! Your Docker setup is ready."
echo ""
echo "Next steps:"
echo "1. Place your reference files in: data/reference/"
echo "2. Place your input data in: data/testdata/"
echo "3. Update the configuration in: conf/analysis.config"
echo "4. Run the pipeline: ./run_pipeline_docker.sh --run_mode_order --sample_id YOUR_SAMPLE_ID"
echo ""
echo "For more information, see:"
echo "- README.md"
echo "- DOCKER_SETUP.md"
echo "- TESTING_GUIDE.md" 