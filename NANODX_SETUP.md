# nanoDx Classifier Setup

## Overview

The nanoDx classifier is used for brain tumor classification based on methylation data. It requires both:
1. **Code/scripts** (included in the pipeline repository)
2. **Model files** (large files downloaded from Zenodo)

## Automated Setup (Recommended)

When you run `./setup_pipeline.sh`, the script automatically:

✅ **Creates directory structure**: `data/reference/nanoDx/static/`
✅ **Moves existing nanoDx folder** from pipeline root to `data/reference/` (if needed)
✅ **Downloads model files** from Zenodo (record 14006255)
✅ **Verifies file integrity** using MD5 checksums

### Model Files Downloaded:
- `Capper_et_al.h5` (~500 MB) - HDF5 model file
- `Capper_et_al.h5.md5` - MD5 checksum for verification
- `Capper_et_al_NN.pkl` (~10 MB) - Pickled neural network

## Directory Structure

After setup, your structure should be:

```
data/reference/nanoDx/
├── static/
│   ├── Capper_et_al.h5           # Model file (from Zenodo)
│   ├── Capper_et_al.h5.md5       # Checksum (from Zenodo)
│   └── Capper_et_al_NN.pkl       # Neural network (from Zenodo)
└── [other nanoDx scripts/files]
```

## Manual Setup (If Needed)

If you prefer to set up manually or if automatic setup fails:

### 1. Create Directory
```bash
mkdir -p data/reference/nanoDx/static
```

### 2. Move nanoDx Folder (if in pipeline root)
```bash
# If nanoDx exists in pipeline root
mv nanoDx data/reference/
```

### 3. Download Model Files
```bash
cd data/reference/nanoDx/static/

# Download from Zenodo
wget https://zenodo.org/record/14006255/files/Capper_et_al.h5
wget https://zenodo.org/record/14006255/files/Capper_et_al.h5.md5
wget https://zenodo.org/record/14006255/files/Capper_et_al_NN.pkl
```

### 4. Verify Checksum
```bash
md5sum -c Capper_et_al.h5.md5
```

Expected output:
```
Capper_et_al.h5: OK
```

## Troubleshooting

### "nanoDx files not found" error

**Check if files exist:**
```bash
ls -lh data/reference/nanoDx/static/
```

Should show:
```
Capper_et_al.h5       (~500 MB)
Capper_et_al.h5.md5   (small text file)
Capper_et_al_NN.pkl   (~10 MB)
```

**Re-download if missing:**
```bash
cd data/reference/nanoDx/static/
rm -f Capper_et_al.*  # Remove corrupted files
# Then re-run setup_pipeline.sh or download manually
```

### MD5 Checksum Mismatch

This indicates file corruption during download.

**Fix:**
```bash
cd data/reference/nanoDx/static/
rm Capper_et_al.h5  # Remove corrupted file
wget https://zenodo.org/record/14006255/files/Capper_et_al.h5
md5sum -c Capper_et_al.h5.md5  # Verify
```

### nanoDx Still in Pipeline Root

The setup script should automatically move it, but if not:

```bash
# Check if it exists in root
ls -ld nanoDx

# Move it manually
mv nanoDx data/reference/

# Verify
ls -ld data/reference/nanoDx
```

## References

- **Zenodo Record**: https://zenodo.org/records/14006255
- **Model**: Capper et al. brain tumor classifier
- **Pipeline Integration**: Used by crossNN process in annotation workflow

## File Sizes

| File | Size | Purpose |
|------|------|---------|
| Capper_et_al.h5 | ~500 MB | Main HDF5 model file |
| Capper_et_al.h5.md5 | ~100 bytes | MD5 checksum for verification |
| Capper_et_al_NN.pkl | ~10 MB | Pickled neural network weights |

## Validation

To verify nanoDx is correctly set up:

```bash
# Run validation script
./validate_setup.sh

# Or manually check
test -f data/reference/nanoDx/static/Capper_et_al.h5 && echo "✓ nanoDx model found" || echo "✗ nanoDx model missing"
test -f data/reference/nanoDx/static/Capper_et_al_NN.pkl && echo "✓ nanoDx NN found" || echo "✗ nanoDx NN missing"
```

## Notes

- The nanoDx classifier is **required** for methylation-based tumor classification
- Model files are **not included in git** due to their large size
- Files are downloaded **once** and reused across pipeline runs
- The setup script **skips download** if files already exist
