# Optional Files Setup Guide

## Overview

The nWGS pipeline includes several optional large files that provide additional analysis capabilities. These files are **not required** for basic pipeline operation but enable advanced features.

## Optional Components

### 1. **nanoDx Classifier** (Required for brain tumor classification)
- **Size**: ~510 MB
- **Zenodo Record**: [14006255](https://zenodo.org/records/14006255)
- **Purpose**: Methylation-based brain tumor classification (Capper et al. model)
- **Location**: `data/reference/nanoDx/static/`

**Files:**
- `Capper_et_al.h5` (~500 MB) - HDF5 model file
- `Capper_et_al.h5.md5` - MD5 checksum
- `Capper_et_al_NN.pkl` (~10 MB) - Neural network weights

### 2. **Svanna Database** (Required for structural variant annotation)
- **Size**: ~15-20 GB
- **Zenodo Record**: [15916972](https://zenodo.org/records/15916972)
- **Purpose**: Structural variant pathogenicity annotation
- **Location**: `data/reference/svanna-data/`

**Files:**
- `svanna-data.zip` - Compressed database (downloads and auto-extracts)

---

## Automated Setup (Recommended)

### Download All Optional Files

```bash
# Setup with optional files (default behavior)
./setup_pipeline.sh docker

# Setup without optional files
./setup_pipeline.sh docker --skip-optional
```

When running without `--skip-optional`, the script automatically:
1. ✅ Downloads nanoDx model files from Zenodo 14006255
2. ✅ Downloads and extracts svanna-data.zip from Zenodo 15916972
3. ✅ Verifies file integrity (MD5 checksums)
4. ✅ Places files in correct directories

---

## Manual Setup

If you prefer manual setup or need to troubleshoot:

### 1. nanoDx Classifier

```bash
# Create directory
mkdir -p data/reference/nanoDx/static
cd data/reference/nanoDx/static

# Download files from Zenodo 14006255
wget https://zenodo.org/record/14006255/files/Capper_et_al.h5
wget https://zenodo.org/record/14006255/files/Capper_et_al.h5.md5
wget https://zenodo.org/record/14006255/files/Capper_et_al_NN.pkl

# Verify checksum
md5sum -c Capper_et_al.h5.md5

# Return to pipeline root
cd ../../../../
```

### 2. Svanna Database

```bash
# Create directory
mkdir -p data/reference
cd data/reference

# Download from Zenodo 15916972
wget https://zenodo.org/record/15916972/files/svanna-data.zip

# Extract
unzip svanna-data.zip

# Optionally remove zip to save space
rm svanna-data.zip

# Return to pipeline root
cd ../..
```

---

## Directory Structure

After setup, your optional files should be organized as:

```
data/reference/
├── nanoDx/
│   └── static/
│       ├── Capper_et_al.h5           (~500 MB)
│       ├── Capper_et_al.h5.md5       (checksum)
│       └── Capper_et_al_NN.pkl       (~10 MB)
│
└── svanna-data/                       (~15-20 GB after extraction)
    ├── svanna_db/
    ├── hg38/
    └── [other Svanna database files]
```

---

## When Do You Need These Files?

### nanoDx Classifier
**Required for:**
- Methylation-based tumor classification
- Brain tumor type prediction
- crossNN analysis workflow

**Skip if:**
- You only analyze non-brain tumors
- You don't use methylation data
- You're running basic SNV/CNV analysis only

### Svanna Database
**Required for:**
- Structural variant (SV) pathogenicity annotation
- Detailed SV functional impact analysis
- Clinical interpretation of large variants

**Skip if:**
- You only analyze SNVs (single nucleotide variants)
- You don't need SV annotation
- You use alternative SV annotation tools

---

## Troubleshooting

### nanoDx Files Missing

**Check if files exist:**
```bash
ls -lh data/reference/nanoDx/static/
```

**Expected output:**
```
Capper_et_al.h5       (~500 MB)
Capper_et_al.h5.md5   (small)
Capper_et_al_NN.pkl   (~10 MB)
```

**Re-download:**
```bash
cd data/reference/nanoDx/static/
rm -f Capper_et_al.*
wget https://zenodo.org/record/14006255/files/Capper_et_al.h5
wget https://zenodo.org/record/14006255/files/Capper_et_al.h5.md5
wget https://zenodo.org/record/14006255/files/Capper_et_al_NN.pkl
md5sum -c Capper_et_al.h5.md5
```

### Svanna Database Missing

**Check if directory exists:**
```bash
ls -ld data/reference/svanna-data/
```

**Re-download and extract:**
```bash
cd data/reference/
rm -rf svanna-data svanna-data.zip  # Remove corrupted files
wget https://zenodo.org/record/15916972/files/svanna-data.zip
unzip svanna-data.zip
```

### Extraction Failed

**For svanna-data.zip:**
```bash
# Check if unzip is installed
which unzip

# Install if missing (Ubuntu/Debian)
sudo apt-get install unzip

# Or (CentOS/RHEL)
sudo yum install unzip

# Try extraction again
cd data/reference/
unzip svanna-data.zip
```

### MD5 Checksum Mismatch (nanoDx)

This indicates file corruption during download.

```bash
cd data/reference/nanoDx/static/
rm Capper_et_al.h5  # Remove corrupted file
wget https://zenodo.org/record/14006255/files/Capper_et_al.h5
md5sum -c Capper_et_al.h5.md5  # Verify again
```

### Disk Space Issues

**Check available space:**
```bash
df -h data/reference/
```

**Optional files require:**
- nanoDx: ~510 MB
- Svanna: ~15-20 GB after extraction
- **Total: ~20-21 GB**

**To save space:**
```bash
# Remove zip files after extraction (Svanna)
rm data/reference/svanna-data.zip

# Or skip optional files entirely
./setup_pipeline.sh docker --skip-optional
```

---

## Validation

### Check All Optional Files

```bash
# Validate setup
./validate_setup.sh

# Or manually check
echo "Checking nanoDx..."
test -f data/reference/nanoDx/static/Capper_et_al.h5 && \
    echo "✓ nanoDx model found" || echo "✗ Missing"

echo "Checking Svanna..."
test -d data/reference/svanna-data && \
    echo "✓ Svanna database found" || echo "✗ Missing"
```

### Re-download Specific Component

**Re-download only nanoDx:**
```bash
# Remove marker file
rm data/reference/nanoDx/static/Capper_et_al.h5

# Re-run setup (only missing files will download)
./setup_pipeline.sh docker --skip-reference --skip-containers
```

**Re-download only Svanna:**
```bash
# Remove directory
rm -rf data/reference/svanna-data

# Re-run setup
./setup_pipeline.sh docker --skip-reference --skip-containers
```

---

## Skip Optional Files During Setup

If you want to skip optional files:

```bash
# Setup without optional files
./setup_pipeline.sh docker --skip-optional
```

**Later, if you need them:**
```bash
# Download optional files only (skip reference core and containers)
./setup_pipeline.sh docker --skip-reference --skip-containers
```

This downloads only the optional files without re-downloading the entire reference bundle.

---

## Storage Optimization

### Option 1: Remove Zip Files After Extraction
```bash
# Svanna (saves ~10-15 GB)
rm data/reference/svanna-data.zip
```

### Option 2: Use External Storage
```bash
# Move to external drive
mv data/reference/svanna-data /mnt/external/svanna-data

# Create symlink
ln -s /mnt/external/svanna-data data/reference/svanna-data
```

### Option 3: Skip Entirely
```bash
# Run setup without optional files
./setup_pipeline.sh docker --skip-optional

# Pipeline will work but without:
# - Brain tumor classification (nanoDx)
# - Advanced SV annotation (Svanna)
```

---

## References

- **nanoDx Zenodo**: https://zenodo.org/records/14006255
- **Svanna Zenodo**: https://zenodo.org/records/15916972
- **Main Reference Files**: https://zenodo.org/records/15916972
- **Capper et al. Paper**: Brain tumor classification via methylation

---

## File Sizes Summary

| Component | Compressed | Extracted | Total |
|-----------|------------|-----------|-------|
| nanoDx models | ~510 MB | ~510 MB | ~510 MB |
| Svanna database | ~10 GB (zip) | ~15-20 GB | ~20-30 GB* |
| **Total** | **~10.5 GB** | **~20 GB** | **~20-30 GB** |

*Depends on whether you keep the zip file after extraction

---

## Quick Commands

```bash
# Setup with all optional files
./setup_pipeline.sh docker

# Setup without optional files
./setup_pipeline.sh docker --skip-optional

# Check if optional files are present
ls -lh data/reference/nanoDx/static/Capper_et_al.h5
ls -ld data/reference/svanna-data/

# Re-download only optional files
./setup_pipeline.sh docker --skip-reference --skip-containers

# Remove optional files to free space
rm -rf data/reference/svanna-data
rm -rf data/reference/nanoDx/static/Capper_et_al.*
```
