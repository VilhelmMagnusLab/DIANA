# Zenodo Files Guide for nWGS Pipeline

## Overview

This guide documents all files that should be uploaded to Zenodo and how the setup script handles them.

---

## Zenodo Record 15916972 (Main Reference Files)

### Required Core Files (Always Downloaded)

#### 1. `reference_core.tar.gz`
- **Size**: ~20-25 GB
- **Action**: Download → Extract → Delete archive
- **Contains**:
  - `data/reference/GRCh38.fa`
  - `data/reference/GRCh38.fa.fai`
  - `data/reference/*.bed` files
  - `data/reference/CNV_genes_tuned.csv`
  - `data/reference/gencode.v48.annotation.gff3`
  - Other reference files

#### 2. `humandb.tar.gz`
- **Size**: ~8-10 GB
- **Action**: Download → Extract → Delete archive
- **Contains**:
  - `data/humandb/hg38_refGene.txt`
  - `data/humandb/hg38_refGeneMrna.fa`
  - `data/humandb/hg38_clinvar_20240611.txt`
  - `data/humandb/hg38_cosmic100coding2024.txt`
  - Other ANNOVAR database files

#### 3. `general.zip` ⚠️ **KEEP AS ZIP**
- **Size**: ~2-3 GB
- **Action**: Download → **Keep as .zip (DO NOT EXTRACT)**
- **Location**: `data/reference/general.zip`
- **Purpose**: Sturgeon classifier model (expects zip format)
- **Note**: Pipeline uses this file directly in zip format

#### 4. `Assembly.zip` ✅ **EXTRACT**
- **Size**: ~1-2 GB
- **Action**: Download → Extract → Archive can be kept or deleted
- **Extracts to**: `data/reference/Assembly/`
- **Purpose**: vcfcircos assembly data for visualization
- **Contains**: Assembly files for chromosome visualization

#### 5. `r1041_e82_400bps_sup_v420.zip` ✅ **EXTRACT**
- **Size**: ~1-2 GB
- **Action**: Download → Extract → Archive can be kept or deleted
- **Extracts to**: `data/reference/r1041_e82_400bps_sup_v420/`
- **Purpose**: Dorado basecalling model
- **Contains**: Model files for ONT basecalling

### Optional Files (Skipped with `--skip-optional`)

#### 6. `svanna-data.zip` ✅ **EXTRACT**
- **Size**: ~10-15 GB (zip), ~15-20 GB (extracted)
- **Action**: Download → Extract → Keep zip (user can delete manually)
- **Extracts to**: `data/reference/svanna-data/`
- **Purpose**: Structural variant annotation database
- **Contains**: Svanna database files for SV pathogenicity scoring

---

## Zenodo Record 14006255 (nanoDx Classifier)

### nanoDx Model Files (Downloaded separately)

#### 1. `Capper_et_al.h5`
- **Size**: ~500 MB
- **Action**: Download directly to `data/reference/nanoDx/static/`
- **Purpose**: HDF5 model file for brain tumor classification

#### 2. `Capper_et_al.h5.md5`
- **Size**: ~100 bytes
- **Action**: Download → Used for verification → Kept
- **Purpose**: MD5 checksum for file integrity verification

#### 3. `Capper_et_al_NN.pkl`
- **Size**: ~10 MB
- **Action**: Download directly to `data/reference/nanoDx/static/`
- **Purpose**: Pickled neural network weights

---

## File Handling Summary Table

| File | Zenodo | Size | Download | Extract | Keep Archive | Final Location |
|------|--------|------|----------|---------|--------------|----------------|
| **reference_core.tar.gz** | 15916972 | ~25 GB | ✅ | ✅ | ❌ | `data/reference/` |
| **humandb.tar.gz** | 15916972 | ~10 GB | ✅ | ✅ | ❌ | `data/humandb/` |
| **general.zip** | 15916972 | ~3 GB | ✅ | ❌ | ✅ | `data/reference/general.zip` |
| **Assembly.zip** | 15916972 | ~2 GB | ✅ | ✅ | Optional | `data/reference/Assembly/` |
| **r1041_e82_400bps_sup_v420.zip** | 15916972 | ~2 GB | ✅ | ✅ | Optional | `data/reference/r1041_e82_400bps_sup_v420/` |
| **svanna-data.zip** | 15916972 | ~15 GB | ✅* | ✅ | ✅ | `data/reference/svanna-data/` |
| **Capper_et_al.h5** | 14006255 | 500 MB | ✅ | N/A | N/A | `data/reference/nanoDx/static/` |
| **Capper_et_al.h5.md5** | 14006255 | 100 B | ✅ | N/A | ✅ | `data/reference/nanoDx/static/` |
| **Capper_et_al_NN.pkl** | 14006255 | 10 MB | ✅ | N/A | N/A | `data/reference/nanoDx/static/` |

*\* = Only with default setup (skipped with `--skip-optional`)*

---

## Setup Script Behavior

### Core Files (Always Downloaded)
```bash
./setup_pipeline.sh docker

# Downloads and processes:
1. reference_core.tar.gz   → Extracts to data/reference/ → Deletes .tar.gz
2. humandb.tar.gz          → Extracts to data/humandb/ → Deletes .tar.gz
3. general.zip             → Downloads to data/reference/general.zip → KEEPS AS IS
4. Assembly.zip            → Extracts to data/reference/Assembly/ → Keeps .zip
5. r1041_e82_400bps_sup_v420.zip → Extracts to data/reference/r1041_e82_400bps_sup_v420/
6. nanoDx files (3 files) → Downloads to data/reference/nanoDx/static/
7. svanna-data.zip         → Extracts to data/reference/svanna-data/ → Keeps .zip
```

### Skip Optional Files
```bash
./setup_pipeline.sh docker --skip-optional

# Downloads and processes:
1-6. Same as above
7. svanna-data.zip → SKIPPED
```

---

## Final Directory Structure

```
data/
├── reference/
│   ├── GRCh38.fa
│   ├── GRCh38.fa.fai
│   ├── gencode.v48.annotation.gff3
│   ├── *.bed files
│   ├── CNV_genes_tuned.csv
│   │
│   ├── general.zip                          ⚠️ KEPT AS ZIP (not extracted)
│   │
│   ├── Assembly/                             ✅ EXTRACTED
│   │   └── [assembly files]
│   │
│   ├── r1041_e82_400bps_sup_v420/            ✅ EXTRACTED
│   │   └── [model files]
│   │
│   ├── nanoDx/                               ✅ DOWNLOADED INDIVIDUALLY
│   │   └── static/
│   │       ├── Capper_et_al.h5
│   │       ├── Capper_et_al.h5.md5
│   │       └── Capper_et_al_NN.pkl
│   │
│   └── svanna-data/                          ✅ EXTRACTED (optional)
│       ├── svanna_db/
│       ├── hg38/
│       └── ...
│
└── humandb/
    ├── hg38_refGene.txt
    ├── hg38_refGeneMrna.fa
    ├── hg38_clinvar_20240611.txt
    └── hg38_cosmic100coding2024.txt
```

---

## Preparing Files for Zenodo Upload

### For Zenodo Record 15916972

#### Step 1: Package Core Reference Files
```bash
cd /home/godzilla/nWGS_pipeline

# Package reference files (exclude optional and zip files we'll upload separately)
tar -czf reference_core.tar.gz \
    data/reference/GRCh38.fa \
    data/reference/GRCh38.fa.fai \
    data/reference/*.bed \
    data/reference/CNV_genes_tuned.csv \
    data/reference/gencode.v48.annotation.gff3 \
    --exclude='data/reference/general.zip' \
    --exclude='data/reference/Assembly' \
    --exclude='data/reference/svanna-data' \
    --exclude='data/reference/nanoDx' \
    --exclude='data/reference/r1041_e82_400bps_sup_v420'
```

#### Step 2: Package ANNOVAR Databases
```bash
tar -czf humandb.tar.gz data/humandb/
```

#### Step 3: Package Assembly (create zip)
```bash
cd data/reference/
zip -r Assembly.zip Assembly/
cd ../..
```

#### Step 4: Package Svanna Data (create zip)
```bash
cd data/reference/
zip -r svanna-data.zip svanna-data/
cd ../..
```

#### Step 5: Copy Existing Zips
```bash
# general.zip - should already exist
# r1041_e82_400bps_sup_v420.zip - should already exist
cp data/reference/general.zip ./
cp data/reference/r1041_e82_400bps_sup_v420.zip ./
```

### Upload to Zenodo 15916972
```
Upload these files:
├── reference_core.tar.gz                 (~25 GB)
├── humandb.tar.gz                        (~10 GB)
├── general.zip                           (~3 GB)
├── Assembly.zip                          (~2 GB)
├── r1041_e82_400bps_sup_v420.zip        (~2 GB)
└── svanna-data.zip                       (~15 GB)
```

### For Zenodo Record 14006255

These files should already exist from nanoDx:
```
Upload these files:
├── Capper_et_al.h5                       (~500 MB)
├── Capper_et_al.h5.md5                   (~100 B)
└── Capper_et_al_NN.pkl                   (~10 MB)
```

**Create MD5 checksum:**
```bash
cd data/reference/nanoDx/static/
md5sum Capper_et_al.h5 > Capper_et_al.h5.md5
```

---

## Total Download Sizes

### With Optional Files (Default)
- **Core files**: ~42 GB
- **Optional files**: ~15-20 GB
- **Total**: ~57-62 GB

### Without Optional Files (`--skip-optional`)
- **Core files**: ~42 GB
- **Total**: ~42 GB

---

## Important Notes

### ⚠️ **general.zip Must NOT Be Extracted**
- The Sturgeon classifier expects `general.zip` in zip format
- DO NOT extract this file
- The pipeline reads the model directly from the zip file
- Setup script downloads and keeps it as `.zip`

### ✅ **Files That Should Be Extracted**
- `Assembly.zip` → Extract to create `Assembly/` directory
- `r1041_e82_400bps_sup_v420.zip` → Extract to create model directory
- `svanna-data.zip` → Extract to create `svanna-data/` directory
- `reference_core.tar.gz` → Extract to populate `data/reference/`
- `humandb.tar.gz` → Extract to populate `data/humandb/`

### 📦 **Archives Deleted After Extraction**
The setup script automatically deletes these after extraction to save space:
- `reference_core.tar.gz` (saves ~25 GB)
- `humandb.tar.gz` (saves ~10 GB)

### 📦 **Archives Kept After Extraction**
These are kept by default (user can manually delete):
- `Assembly.zip` (saves ~2 GB if deleted)
- `r1041_e82_400bps_sup_v420.zip` (saves ~2 GB if deleted)
- `svanna-data.zip` (saves ~15 GB if deleted)
- `general.zip` (MUST be kept - not extracted)

---

## Troubleshooting

### "general.zip was extracted"
If general.zip was accidentally extracted:
```bash
# Re-download
rm -rf data/reference/general/
wget https://zenodo.org/record/15916972/files/general.zip -O data/reference/general.zip
```

### "Assembly directory not found"
```bash
# Re-download and extract
cd data/reference/
wget https://zenodo.org/record/15916972/files/Assembly.zip
unzip Assembly.zip
```

### "Disk space issues"
```bash
# Remove archives after confirming extraction worked
rm data/reference/Assembly.zip
rm data/reference/r1041_e82_400bps_sup_v420.zip
rm data/reference/svanna-data.zip  # Only if you're sure svanna-data/ works

# DO NOT delete general.zip - it's needed!
```

---

## Validation Commands

```bash
# Verify general.zip exists and is NOT extracted
test -f data/reference/general.zip && echo "✓ general.zip present (correct)"
test -d data/reference/general && echo "✗ general/ directory exists (WRONG - should be zip only)"

# Verify Assembly is extracted
test -d data/reference/Assembly && echo "✓ Assembly directory present"

# Verify Dorado model is extracted
test -d data/reference/r1041_e82_400bps_sup_v420 && echo "✓ Dorado model present"

# Verify svanna-data is extracted (if not using --skip-optional)
test -d data/reference/svanna-data && echo "✓ Svanna database present"

# Verify nanoDx files
test -f data/reference/nanoDx/static/Capper_et_al.h5 && echo "✓ nanoDx model present"
```
