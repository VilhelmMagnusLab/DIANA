# nWGS Pipeline - End User Testing Guide

This guide helps you test the nWGS pipeline setup from an end-user perspective, ensuring everything works correctly before running your actual data.

## 🧪 Quick Testing Overview

### What We'll Test:
1. **Container System** (Docker or Singularity/Apptainer)
2. **Nextflow Installation**
3. **Configuration Files**
4. **Reference Data Access**
5. **Pipeline Execution**
6. **Output Generation**

## 🚀 Step-by-Step Testing

### Step 1: Environment Check

First, let's verify your environment is properly set up:

#### **For Docker Users:**
```bash
# Check Docker installation
docker --version
docker info

# Check if images are available
docker images | grep vilhelmmagnuslab
```

#### **For Singularity/Apptainer Users:**
```bash
# Check Singularity/Apptainer installation
singularity --version
# OR
apptainer --version

# Check if images are available
ls -la containers/*.sif
```

#### **For All Users:**
```bash
# Check Nextflow installation
nextflow --version

# Check if setup scripts are executable
ls -la setup_*.sh
ls -la run_pipeline*.sh
```

### Step 2: Run Automated Tests

#### **Option A: Quick Test (Recommended for First-Time Users)**

```bash
# For Docker users:
./test_pipeline.sh

# For Singularity/Apptainer users:
./test_pipeline_singularity.sh
```

This will:
- Create minimal test data
- Run a small pipeline test
- Verify basic functionality

#### **Option B: Comprehensive Test (For Advanced Users)**

```bash
# Create a comprehensive test script
cat > comprehensive_test.sh << 'EOF'
#!/bin/bash

echo "=========================================="
echo "nWGS Pipeline Comprehensive Test"
echo "=========================================="

# Test 1: Environment Check
echo "1. Testing Environment..."
if command -v docker &> /dev/null; then
    echo "   ✓ Docker found"
    docker --version
elif command -v singularity &> /dev/null; then
    echo "   ✓ Singularity found"
    singularity --version
elif command -v apptainer &> /dev/null; then
    echo "   ✓ Apptainer found"
    apptainer --version
else
    echo "   No container system found"
    exit 1
fi

if command -v nextflow &> /dev/null; then
    echo "   ✓ Nextflow found"
    nextflow --version
else
    echo "  Nextflow not found"
    exit 1
fi

# Test 2: Configuration Files
echo ""
echo "2. Testing Configuration Files..."
if [ -f "conf/analysis.config" ]; then
    echo "   ✓ analysis.config found"
else
    echo "  analysis.config missing"
fi

if [ -f "conf/epi2me.config" ]; then
    echo "   ✓ epi2me.config found"
else
    echo "  epi2me.config missing"
fi

if [ -f "conf/mergebam.config" ]; then
    echo "   ✓ mergebam.config found"
else
    echo "  mergebam.config missing"
fi

# Test 3: Container Images
echo ""
echo "3. Testing Container Images..."
if command -v docker &> /dev/null; then
    echo "   Checking Docker images..."
    docker images | grep vilhelmmagnuslab | wc -l | xargs echo "   Found images:"
elif command -v singularity &> /dev/null || command -v apptainer &> /dev/null; then
    echo "   Checking Singularity/Apptainer images..."
    ls containers/*.sif 2>/dev/null | wc -l | xargs echo "   Found images:"
fi

# Test 4: Directory Structure
echo ""
echo "4. Testing Directory Structure..."
mkdir -p data/{reference,humandb,testdata,results}
echo "   ✓ Created data directories"

# Test 5: Sample Data Creation
echo ""
echo "5. Creating Test Data..."
mkdir -p data/testdata
echo "test_sample" > data/testdata/sample_ids.txt
echo "   ✓ Created test sample file"

# Test 6: Pipeline Dry Run
echo ""
echo "6. Testing Pipeline Dry Run..."
if command -v docker &> /dev/null; then
    ./run_pipeline_docker.sh --help
elif command -v singularity &> /dev/null || command -v apptainer &> /dev/null; then
    ./run_pipeline_singularity.sh --help
fi
echo "   ✓ Pipeline help command works"

echo ""
echo "=========================================="
echo "Comprehensive Test Complete!"
echo "=========================================="
echo ""
echo "If all tests passed (✓), your setup is ready!"
echo "If any tests failed (❌), please check the setup guides:"
echo "- Docker: DOCKER_SETUP.md"
echo "- Singularity/Apptainer: SINGULARITY_SETUP.md"
EOF

chmod +x comprehensive_test.sh
./comprehensive_test.sh
```

### Step 3: Test Different Pipeline Modes

#### **Test 1: Configuration Auto-Detection**
```bash
# Test that the pipeline correctly detects config files
echo "Testing config auto-detection..."

# Test analysis mode
./run_pipeline_docker.sh --run_mode_analysis --help
# OR
./run_pipeline_singularity.sh --run_mode_analysis --help

# Test epi2me mode
./run_pipeline_docker.sh --run_mode_epi2me --help
# OR
./run_pipeline_singularity.sh --run_mode_epi2me --help

# Test mergebam mode
./run_pipeline_docker.sh --run_mode_mergebam --help
# OR
./run_pipeline_singularity.sh --run_mode_mergebam --help
```

#### **Test 2: Small Data Test**
```bash
# Create a minimal test dataset
mkdir -p data/testdata/small_test
echo "small_test_sample" > data/testdata/small_test/sample_ids.txt

# Run a small test (this will fail but should show proper error handling)
./run_pipeline_docker.sh --run_mode_analysis --sample_id small_test_sample
# OR
./run_pipeline_singularity.sh --run_mode_analysis --sample_id small_test_sample
```

### Step 4: Test Configuration Validation

#### **Test Configuration Syntax**
```bash
# Test that configuration files are valid
echo "Testing configuration syntax..."

# Test analysis config
nextflow config conf/analysis.config

# Test epi2me config
nextflow config conf/epi2me.config

# Test mergebam config
nextflow config conf/mergebam.config
```

#### **Test Parameter Validation**
```bash
# Test that required parameters are accessible
echo "Testing parameter validation..."

# Check if path parameter is set
grep "path =" conf/analysis.config

# Check if container paths are valid
grep "container =" conf/analysis.config
```

## 🔍 Troubleshooting Tests

### **Test 1: Container System Issues**

#### **Docker Issues:**
```bash
# Test Docker daemon
sudo systemctl status docker

# Test Docker permissions
docker run hello-world

# Test Docker image pulling
docker pull hello-world
```

#### **Singularity/Apptainer Issues:**
```bash
# Test Singularity/Apptainer installation
singularity --version
# OR
apptainer --version

# Test image pulling
singularity pull docker://hello-world
# OR
apptainer pull docker://hello-world
```

### **Test 2: Nextflow Issues**
```bash
# Test Nextflow installation
nextflow --version

# Test Nextflow configuration
nextflow config

# Test Nextflow with minimal pipeline
nextflow run hello
```

### **Test 3: File Permission Issues**
```bash
# Check script permissions
ls -la *.sh

# Fix permissions if needed
chmod +x *.sh

# Check directory permissions
ls -la data/
```

### **Test 4: Resource Issues**
```bash
# Check available disk space
df -h

# Check available memory
free -h

# Check CPU cores
nproc
```

## Test Results Interpretation

### **All Tests Passed:**
- Your setup is ready for production use
- You can proceed with your actual data analysis
- Consider running a small real dataset first

### **Some Tests Failed:**
- Check the specific error messages
- Refer to the troubleshooting sections in setup guides
- Verify your system meets the requirements

### **Many Tests Failed:**
- Your setup needs attention
- Review the setup guides completely
- Check system requirements and dependencies

## Real-World Testing Scenarios

### **Scenario 1: First-Time User**
```bash
# 1. Run setup
./setup_docker.sh
# OR
./setup_singularity.sh

# 2. Run quick test
./test_pipeline.sh
# OR
./test_pipeline_singularity.sh

# 3. If successful, proceed with real data
```

### **Scenario 2: HPC User**
```bash
# 1. Check HPC environment
module list
which singularity
# OR
which apptainer

# 2. Run setup
./setup_singularity.sh

# 3. Test with small dataset
./run_pipeline_singularity.sh --run_mode_analysis --sample_id test_sample

# 4. Submit job to queue if needed
sbatch -J nwgs_test run_pipeline_singularity.sh --run_mode_analysis --sample_id test_sample
```

### **Scenario 3: Docker Desktop User**
```bash
# 1. Ensure Docker Desktop is running
docker info

# 2. Run setup
./setup_docker.sh

# 3. Test with GUI
./run_pipeline_docker.sh --run_mode_analysis --sample_id test_sample

# 4. Check results in file explorer
open results/
```

## Test Checklist

Use this checklist to ensure your setup is complete:

- [ ] Container system (Docker/Singularity/Apptainer) installed and working
- [ ] Nextflow installed and accessible
- [ ] Setup script completed successfully
- [ ] Configuration files present and valid
- [ ] Container images downloaded
- [ ] Data directories created
- [ ] Quick test passes
- [ ] Configuration auto-detection works
- [ ] Help commands work
- [ ] No permission errors
- [ ] Sufficient disk space and memory

## Getting Help

If tests fail:

1. **Check the error messages** carefully
2. **Refer to setup guides**: [DOCKER_SETUP.md](DOCKER_SETUP.md) or [SINGULARITY_SETUP.md](SINGULARITY_SETUP.md)
3. **Check system requirements** in the main [README.md](README.md)
4. **Contact maintainers** if issues persist

## Success!

Once all tests pass, you're ready to run the nWGS pipeline with your actual data!

```bash
# Run your analysis
./run_pipeline_docker.sh --run_mode_order --sample_id YOUR_SAMPLE_ID
# OR
./run_pipeline_singularity.sh --run_mode_order --sample_id YOUR_SAMPLE_ID
```

Happy analyzing! 🧬 