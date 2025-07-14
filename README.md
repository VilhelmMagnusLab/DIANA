# nWGS_pipeline: Nanopore Whole Genome Sequencing Pipeline

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed.svg?labelColor=000000)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Release](https://img.shields.io/badge/release-v1.0.0-blue.svg)](https://github.com/yourusername/nWGS_pipeline/releases)

## Introduction

nWGS_pipeline is a comprehensive bioinformatics pipeline for analyzing Central Nervous System (CNS) samples using Oxford Nanopore sequencing data. The pipeline integrates multiple analyses including CNV detection, methylation profiling, structural variant calling, and MGMT promoter status determination.

## 🐳 Quick Start with Docker (Recommended)

The easiest way to run the nWGS pipeline is using Docker containers. All required images are hosted at [https://hub.docker.com/repositories/vilhelmmagnuslab](https://hub.docker.com/repositories/vilhelmmagnuslab).

### Prerequisites
- Docker installed on your system
- Nextflow (will be auto-installed if missing)

### One-Command Setup
```bash
chmod +x setup_docker.sh
./setup_docker.sh
```

This will:
- Check Docker installation
- Create necessary directories  
- Pull all required Docker images
- Create convenient run scripts

### Run the Pipeline
```bash
./run_pipeline.sh
```

### For More Details
See [DOCKER_SETUP.md](DOCKER_SETUP.md) for comprehensive Docker setup instructions.

## Pipeline Summary

The pipeline consists of three main modules that can be run independently or sequentially:

### 1. Mergebam Pipeline
- Merges multiple BAM files per sample
- Extracts regions of interest using OCC.protein_coding.bed
- Quality control of merged BAMs
- Outputs merged and indexed BAM files

### 2. Epi2me Pipeline
The Epi2me pipeline has been significantly improved with enhanced error handling, validation, and modular design. It now supports three main analysis types that can be run independently or together:

#### **Modkit - Modified Base Calling**
- **Purpose**: Detects DNA modifications (5mC, 5hmC, etc.) using Modkit
- **Input**: BAM files, reference genome
- **Output**: `*_wf_mods.bedmethyl.gz` files

#### **Sniffles2 - Structural Variant Calling**
- **Purpose**: Detects structural variants using Sniffles2
- **Input**: BAM files
- **Output**: `*.vcf.gz` files with structural variants (standardized naming)

#### **QDNAseq - Copy Number Variation Analysis**
- **Purpose**: Detects copy number variations using QDNAseq
- **Input**: BAM files, reference genome
- **Output**: Multiple files including:
  - `*_segs.bed`: Segmented copy number data
  - `*_bins.bed`: Binned copy number data
  - `*_segs.vcf`: Copy number variants in VCF format
  - `*_copyNumbersCalled.rds`: R data structure

### 3. Analysis Pipeline
- MGMT promoter methylation analysis
  - Uses EPIC array sites
  - Methylation level calculation
- Methylation-based classification
  - NanoDx neural network classifier
- Structural variant annotation
  - Svanna pathogenicity prediction
  - Fusion gene detection
- CNV analysis
  - **ACE tumor content determination**: 
    - If tumor content is provided in sample ID file: Uses provided value directly
    - If tumor content is not provided: Automatically calculates using ACE (Allele-specific Copy number Estimation)
    - ACE analyzes copy number profiles to estimate tumor cellularity
  - Copy number annotation
  - Chromosome visualization
- Report generation
  - Interactive HTML reports
  - IGV snapshots
  - Circos plots
  - **Comprehensive markdown reports** (automatically generated in sequential mode)

## Required Containers

The nWGS pipeline uses Docker containers hosted at [https://hub.docker.com/repositories/vilhelmmagnuslab](https://hub.docker.com/repositories/vilhelmmagnuslab). All containers are automatically downloaded during setup.

### 🐳 **Docker Setup (Recommended)**

**One-command setup:**
```bash
./setup_docker.sh
```

This automatically downloads all required containers:
- Core analysis containers
- Epi2me analysis containers  
- Creates convenient run scripts
- Sets up directory structure

### **Available Docker Images**

#### **Core Analysis Containers:**
- `vilhelmmagnuslab/nwgs_default_images` - General analysis tools
- `vilhelmmagnuslab/ace_1.24.0` - ACE copy number analysis
- `vilhelmmagnuslab/annotcnv_images_27feb1025` - CNV annotation
- `hkubal/clairs-to` - Structural variant calling
- `vilhelmmagnuslab/clair3_amd64` - Variant calling
- `vilhelmmagnuslab/sturgeon_amd64_21jan_latest` - Methylation analysis
- `vilhelmmagnuslab/igv_report_amd64` - IGV report generation
- `vilhelmmagnuslab/vcf2circos` - Circos visualization
- `vilhelmmagnuslab/nanodx_images_3feb25` - NanoDx classification
- `vilhelmmagnuslab/markdown_images_28feb2025` - Report generation
- `vilhelmmagnuslab/mgmt_nanopipe_amd64_18feb2025_cramoni` - Quality assessment
- `vilhelmmagnuslab/gviz_amd64_latest` - Genomic visualization

#### **Epi2me Analysis Containers:**
- `vilhelmmagnuslab/snifflesv252_update_latest` - Structural variant calling
- `vilhelmmagnuslab/qdnaseq_amd64_latest` - Copy number variation analysis
- `vilhelmmagnuslab/modkit_latest` - Modified base calling

### **Manual Container Management (Advanced)**

If you prefer manual control, you can use either Docker or Singularity/Apptainer:

#### **Option 1: Docker (Recommended)**

```bash
# Pull all containers manually
docker pull vilhelmmagnuslab/nwgs_default_images:latest
docker pull vilhelmmagnuslab/ace_1.24.0:latest
docker pull vilhelmmagnuslab/annotcnv_images_27feb1025:latest
docker pull hkubal/clairs-to:latest
docker pull vilhelmmagnuslab/clair3_amd64:latest
docker pull vilhelmmagnuslab/sturgeon_amd64_21jan_latest:latest
docker pull vilhelmmagnuslab/igv_report_amd64:latest
docker pull vilhelmmagnuslab/vcf2circos:latest
docker pull vilhelmmagnuslab/nanodx_images_3feb25:latest
docker pull vilhelmmagnuslab/markdown_images_28feb2025:latest
docker pull vilhelmmagnuslab/mgmt_nanopipe_amd64_18feb2025_cramoni:latest
docker pull vilhelmmagnuslab/gviz_amd64_latest:latest
docker pull vilhelmmagnuslab/snifflesv252_update_latest:latest
docker pull vilhelmmagnuslab/qdnaseq_amd64_latest:latest
docker pull vilhelmmagnuslab/modkit_latest:latest
```

#### **Option 2: Singularity/Apptainer**

```bash
# Pull containers using Singularity/Apptainer
singularity pull --dir containers/ vilhelmmagnuslab/nwgs_default_images:latest
singularity pull --dir containers/ vilhelmmagnuslab/ace_1.24.0:latest
singularity pull --dir containers/ vilhelmmagnuslab/annotcnv_images_27feb1025:latest
singularity pull --dir containers/ hkubal/clairs-to:latest
singularity pull --dir containers/ vilhelmmagnuslab/clair3_amd64:latest
singularity pull --dir containers/ vilhelmmagnuslab/sturgeon_amd64_21jan_latest:latest
singularity pull --dir containers/ vilhelmmagnuslab/igv_report_amd64:latest
singularity pull --dir containers/ vilhelmmagnuslab/vcf2circos:latest
singularity pull --dir containers/ vilhelmmagnuslab/nanodx_images_3feb25:latest
singularity pull --dir containers/ vilhelmmagnuslab/markdown_images_28feb2025:latest
singularity pull --dir containers/ vilhelmmagnuslab/mgmt_nanopipe_amd64_18feb2025_cramoni:latest
singularity pull --dir containers/ vilhelmmagnuslab/gviz_amd64_latest:latest
singularity pull --dir containers/ vilhelmmagnuslab/snifflesv252_update_latest:latest
singularity pull --dir containers/ vilhelmmagnuslab/qdnaseq_amd64_latest:latest
singularity pull --dir containers/ vilhelmmagnuslab/modkit_latest:latest
```

**Note:** If using Singularity/Apptainer, you'll need to update the configuration files to use local `.sif` files instead of Docker images. See the "Legacy Singularity Support" section below.

### **Container Verification**

#### **Docker Verification:**
```bash
# Check that all containers are available
docker images | grep vilhelmmagnuslab

# Test a specific container
docker run --rm vilhelmmagnuslab/nwgs_default_images:latest --help
```

#### **Singularity/Apptainer Verification:**
```bash
# Check available .sif files
ls -la containers/*.sif

# Test a specific container
singularity exec containers/nwgs_default_images_latest.sif --help
```

### **Legacy Singularity Support**

If you need to use Singularity/Apptainer containers instead of Docker, follow these steps:

#### **1. Pull Singularity Images**
```bash
# Create containers directory
mkdir -p containers/

# Pull all required images
singularity pull --dir containers/ vilhelmmagnuslab/nwgs_default_images:latest
singularity pull --dir containers/ vilhelmmagnuslab/ace_1.24.0:latest
singularity pull --dir containers/ vilhelmmagnuslab/annotcnv_images_27feb1025:latest
singularity pull --dir containers/ hkubal/clairs-to:latest
singularity pull --dir containers/ vilhelmmagnuslab/clair3_amd64:latest
singularity pull --dir containers/ vilhelmmagnuslab/sturgeon_amd64_21jan_latest:latest
singularity pull --dir containers/ vilhelmmagnuslab/igv_report_amd64:latest
singularity pull --dir containers/ vilhelmmagnuslab/vcf2circos:latest
singularity pull --dir containers/ vilhelmmagnuslab/nanodx_images_3feb25:latest
singularity pull --dir containers/ vilhelmmagnuslab/markdown_images_28feb2025:latest
singularity pull --dir containers/ vilhelmmagnuslab/mgmt_nanopipe_amd64_18feb2025_cramoni:latest
singularity pull --dir containers/ vilhelmmagnuslab/gviz_amd64_latest:latest
singularity pull --dir containers/ vilhelmmagnuslab/snifflesv252_update_latest:latest
singularity pull --dir containers/ vilhelmmagnuslab/qdnaseq_amd64_latest:latest
singularity pull --dir containers/ vilhelmmagnuslab/modkit_latest:latest
```

#### **2. Update Configuration Files**

**conf/analysis.config:**
```groovy
process {
    // Change from Docker to Singularity
    container = '/path/to/containers/nwgs_default_images_latest.sif'
    
    withName: 'ace_tmc' {
        container = '/path/to/containers/ace_1.24.0_latest.sif'
    }
    // ... update other processes similarly
}

// Replace docker section with apptainer
apptainer {
    enabled = true
    autoMounts = true
    runOptions = '--bind /path/to/your/data:/path/to/your/data'
}
```

**conf/epi2me.config:**
```groovy
process {
    withName: run_epi2me_sv {
        container = '/path/to/containers/snifflesv252_update_latest_latest.sif'
    }
    // ... update other processes
}

apptainer {
    enabled = true
    autoMounts = true
    runOptions = '--bind /path/to/your/data:/path/to/your/data'
}
```

#### **3. Run with Singularity**
```bash
# Use Nextflow directly with Singularity
nextflow run main.nf -c conf/analysis.config --run_mode_order --sample_id T001

# Or create a custom run script
cat > run_pipeline_singularity.sh << 'EOF'
#!/bin/bash
nextflow run main.nf -c conf/analysis.config "$@"
EOF
chmod +x run_pipeline_singularity.sh
```

#### **4. Verify Singularity Images**
```bash
# Check available images
ls -la containers/*.sif

# Test individual containers
singularity exec containers/nwgs_default_images_latest.sif --help
```

**Note:** Docker is recommended for easier setup and maintenance, but Singularity/Apptainer is fully supported for HPC environments or when Docker is not available.

## Required Reference Data

The required reference files are provided in the `refdata` folder:

```bash
refdata/
├── OCC.fusions.bed           # Fusion genes bed file
├── EPIC_sites_NEW.bed       # EPIC methylation sites
├── MGMT_CpG_Island.hg38.bed # MGMT CpG islands
├── OCC.SNV.screening.bed    # SNV screening regions
├── TERTp_variants.bed       # TERT promoter variants
├── hg38_refGene.txt         # RefGene annotation
├── hg38_refGeneMrna.fa      # RefGene mRNA sequences
├── hg38_clinvar_20240611.txt # ClinVar annotations
├── hg38_cosmic100coding2024.txt # Cosmic annotations
└── human_GRCh38_trf.bed    # Tandem repeat regions

reference_genome = "${params.ref_dir}/ref.fa" need to be provided or downloaded from the following link: https://www.ncbi.nlm.nih.gov/datasets/docs/v2/reference-docs/reference-genomes/human-reference-genomes/

gencode.v48.annotation.gff3 need to be downloaded from the following link: https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_48/gencode.v48.annotation.gff3.gz

hg38_cosmic100coding2024.txt need to be downloaded from the following link: https://annovar.openbioinformatics.org/en/latest/user-guide/filter/#cosmic-annotations
```

These files are essential for:
- Methylation analysis (EPIC sites, MGMT)
- Structural variant analysis (Fusions)
- Copy number analysis
- SNV detection
- TERT promoter analysis

# Classifier Models

```bash
# NanoDx Model Setup
# The pipeline includes a modified version of NanoDx in the nanoDx/ folder as part of the download.
# Users only need to:
# 1. Download the required large model files separately (due to file size limitations)
# 2. Place the model files in the nanoDx/static/ folder

# Required large model files to download and place in nanoDx/static/:
# - Capper_et_al.h5 (large model file)
# - Capper_et_al.h5.md5 (checksum file)
# - Capper_et_al_NN.pkl (neural network model file)

# The nanoDx folder is already included in the pipeline download and contains:
# - All scripts and workflow files
# - Configuration files
# - Dictionary files (Capper_et_al_dictionary.txt, pancan_devel_v5i_dictionary.txt)
# - Reference bed files (hg19_450model.bed, 450K_hg19.bed)
# - Other supporting files

# The path to the nanoDx folder is automatically configured in conf/analysis.config:
# nanodx_workflow_dir = "${params.ref_dir}/nanoDx/workflow"
```

## Quick Start

### Prerequisites

1. **Docker**: Install Docker on your system
   - [Docker Desktop](https://docs.docker.com/desktop/) (Windows/Mac)
   - [Docker Engine](https://docs.docker.com/engine/install/) (Linux)

2. **Nextflow**: Will be automatically installed by the setup script

### Setup and Run

```bash
# 1. Clone the repository
git clone https://github.com/VilhelmMagnusLab/nWGS_pipeline.git
cd nWGS_pipeline

# 2. Run the Docker setup script
chmod +x setup_docker.sh
./setup_docker.sh

# 3. Configure your data paths
# Edit conf/analysis.config and update the 'path' parameter

# 4. Place your reference files in data/reference/
# Place your input data in data/testdata/

# 5. Run the pipeline (config file is auto-detected!)
./run_pipeline.sh --run_mode_order --sample_id YOUR_SAMPLE_ID
```

### Alternative: Manual Setup

If you prefer manual setup:

```bash
# Install Nextflow
curl -s https://get.nextflow.io | bash

# Pull Docker images manually
docker pull vilhelmmagnuslab/nwgs_default_images:latest
# ... (pull other images as needed)

# Run with Nextflow directly (config auto-detected)
nextflow run main.nf -with-docker --run_mode_order --sample_id T001
```

For detailed setup instructions, see [DOCKER_SETUP.md](DOCKER_SETUP.md).

## Configuration

### 1. Essential Path Configuration

The pipeline requires you to update the base path in the configuration files. This is the most important configuration step:

#### Update Base Path in All Config Files:

**conf/analysis.config:**
```nextflow
params {
    path = "/path/to/your/data/directory"  // ← Update this path
}
```

**conf/epi2me.config:**
```nextflow
params {
    path = "/path/to/your/data/directory"  // ← Update this path
}
```

**conf/mergebam.config:**
```nextflow
params {
    path = "/path/to/your/data/directory"  // ← Update this path
}
```

### 2. Container Configuration

Update the container paths in the configuration files to point to your container directory:

**conf/analysis.config:**
```nextflow
process {
    container = '/path/to/your/containers/mgmt_nanopipe_amd64_26spet_jdk_igv_python_plotly_latest.sif'
    
    withName: 'ace_tmc' {
        container = '/path/to/your/containers/ace_images_10mars2025_latest.sif'
    }
    // ... other process containers
}
```

**conf/epi2me.config:**
```nextflow
process {
    withName: run_epi2me_sv {
        container = '/path/to/your/containers/snifflesv252_update_latest.sif'
    }
    // ... other process containers
}
```

### 3. Required Directory Structure

Ensure your data directory has the following structure:
```
/path/to/your/data/directory/
├── reference/                    # Reference files (see Required Reference Data section)
├── humandb/                      # Annotation files
├── testdata/                     # Input data
│   ├── sample_ids.txt           # Sample ID file
│   └── single_bam_folder/       # BAM files
├── containers/                   # Container images
└── results/                      # Output directory (created automatically)
```

### 4. Container Bind Paths

Update the container bind paths in the configuration files to include your data and container directories:

**conf/analysis.config:**
```nextflow
apptainer {
    runOptions = '--bind /path/to/your/containers --bind /path/to/your/data'
}
```

**conf/epi2me.config:**
```nextflow
apptainer {
    runOptions = "--bind /path/to/your/containers --bind /path/to/your/data"
}
```

### 5. Quick Configuration Checklist

Before running the pipeline, ensure you have:

- **Base path** updated in all config files
- **Container paths** updated to your container directory
- **Container bind paths** configured correctly
- **Reference files** in the reference/ directory
- **Annotation files** in the humandb/ directory
- **Input data** in the testdata/ directory
- **Container images** downloaded and accessible

### 6. Advanced Configuration

For detailed configuration options, resource limits, and process-specific settings, consult the individual configuration files:

- `conf/analysis.config` - Analysis pipeline settings
- `conf/epi2me.config` - Epi2me pipeline settings  
- `conf/mergebam.config` - Mergebam pipeline settings
- `conf/base.config` - Base resource settings

**Note**: Most parameters are pre-configured and only require path updates. Advanced users can modify additional settings as needed.

### 5. Sample Configuration

#### Input structure for running directly from sample ID file:

1. Create a sample ID file with the following format: This file is used to run the analysis pipeline knowing the tumor content of the sample.
```
sample_id1   tumor content (float)
sample_id2   tumor content (float)
```

**Tumor Content Options:**
- **Provided tumor content**: If you know the tumor content (e.g., from pathology reports), provide it as a float between 0-1
  - Example: `V1001   0.75` (75% tumor content)
  - The pipeline will use this value directly for CNV analysis
- **Automatic calculation**: If you don't know the tumor content, provide only the sample ID
  - Example: `V1001`
  - The pipeline will automatically calculate tumor content using ACE (Allele-specific Copy number Estimation)
  - ACE analyzes copy number profiles from QDNAseq results to estimate tumor cellularity
  - **ACE provides multiple tumor content estimates - ACE best fit is selected**
  - Results are saved in `${sample_id}_ace_results/threshold_value.txt`

The file paths should follow this structure:
```
/path/to/base/directory/
├── sample_id1/
│   └── bam_pass/
│       ├── file1.bam
│       └── file2.bam
└── sample_id2/
    └── bam_pass/
        ├── file1.bam
        └── file2.bam
```

2. Sample ID file format used to merge the bam files: The sample ID and the flowcell ID is considered both to avoid mixing up the bam files from different flowcells. For this case the tumor content is calculated using ACE packages and inputted directly. The user can also analyse the tumur content generated by ACE and select the best fit and rerun the analyis with an updated tumor content has describes in step 1. 
```
sample_id1   flowcell_id1
sample_id2   flowcell_id2
```

#### Mergebam input structure:

```
input_dir/
├── V1001/
│   ├── 20231215_1340_3E_PAM69496_5c1d2ed7/bam_pass/
│   │   ├── PAM69496_pass_barcode01_*.bam
│   │   └── PAM69496_pass_barcode01_*.bam.bai
│   └── 20231216_1420_3E_PAM69496_7d4e9fc2/bam_pass/
│       ├── PAM69496_pass_barcode01_*.bam
│       └── PAM69496_pass_barcode01_*.bam.bai
└── V1002/
    └── 20231217_1510_3E_PAM69497_8f3g1hj4/bam_pass/
        ├── PAM69497_pass_barcode02_*.bam
        └── PAM69497_pass_barcode02_*.bam.bai
```

#### Expected from mergebam input:

```
results/
├── merged_bams/
│   ├── V1001.merged.bam
│   ├── V1001.merged.bam.bai
│   ├── V1002.merged.bam
│   └── V1002.merged.bam.bai
└── occ_bam/
    ├── V1001_roi.bam
    ├── V1001_roi.bam.bai
    ├── V1002_roi.bam
    └── V1002_roi.bam.bai
```

### 6. Output Results Folder Structure

```
results/
├── mergebam/
│   ├── merge_bam/
│   └── occ_bam/
├── epi2me/
│   ├── episv/                    # Structural variant results
│   │   ├── sample1.vcf.gz
│   │   └── sample1.vcf.gz.tbi
│   ├── modkit/                   # Modified base calling results
│   │   ├── sample1.wf_mods.bedmethyl.gz
│   │   └── sample1_modkit.log
│   └── epicnv/                   # Copy number variation results
│       ├── qdna_seq/
│       │   ├── sample1_segs.bed
│       │   ├── sample1_bins.bed
│       │   ├── sample1_segs.vcf
│       │   ├── sample1_copyNumbersCalled.rds
│       │   ├── sample1_calls.bed
│       │   ├── sample1_calls.vcf
│       │   ├── sample1_raw_bins.bed
│       │   ├── sample1_plots.pdf
│       │   ├── sample1_isobar_plot.png
│       │   └── sample1_cov.png
│       └── logs/
└── analysis/
    ├── cnv/
    │   ├── ace/                  # ACE tumor content calculation results
    │   │   ├── sample1_ace_results/
    │   │   │   └── threshold_value.txt  # Calculated tumor content
    │   │   └── sample1_CNV_plot.pdf
    │   └── sample1_annotatedcnv.csv
    ├── sv/
    ├── methylation/
    └── reports/
```

## Running the Pipeline

### Quick Start (Docker - Recommended)

After running the setup script (`./setup_docker.sh`), you can run the pipeline using the convenient wrapper script:

```bash
# Basic run with default configuration
./run_pipeline.sh

# Run complete pipeline
./run_pipeline.sh --run_mode_order --sample_id T001

# Run specific modules
./run_pipeline.sh --run_mode_epi2me all
./run_pipeline.sh --run_mode_analysis all
```

**Note:** The script automatically detects the appropriate configuration file based on your run mode - no need to specify config files manually!

### Pipeline Modes

The nWGS pipeline supports multiple run modes that can be executed using the Docker setup:

#### **1. Complete Sequential Pipeline (Recommended)**
Runs the entire workflow from start to finish automatically:

```bash
# Using the wrapper script (recommended)
./run_pipeline.sh --run_mode_order --sample_id T001

# Or directly with Nextflow
nextflow run main.nf -with-docker --run_mode_order --sample_id T001
```

**What this does:**
1. Runs mergebam pipeline
2. Runs epi2me pipeline (all analyses)
3. Runs analysis pipeline (all analyses)
4. Generates comprehensive markdown report

#### **2. Individual Module Execution**

**Mergebam Pipeline Only:**
```bash
./run_pipeline.sh --run_mode_mergebam
```

**Epi2me Pipeline Only:**
```bash
# Run all Epi2me analyses
./run_pipeline.sh --run_mode_epi2me all

# Run specific Epi2me analyses
./run_pipeline.sh --run_mode_epi2me modkit  # Modified base calling only
./run_pipeline.sh --run_mode_epi2me cnv     # Copy number analysis only
./run_pipeline.sh --run_mode_epi2me sv      # Structural variant calling only
```

**Analysis Pipeline Only:**
```bash
# Run all analyses (includes markdown report)
./run_pipeline.sh --run_mode_analysis all

# Run specific analyses
./run_pipeline.sh --run_mode_analysis occ      # OCC analysis only
./run_pipeline.sh --run_mode_analysis mgmt     # MGMT analysis only
./run_pipeline.sh --run_mode_analysis svannasv # Svanna analysis only
./run_pipeline.sh --run_mode_analysis cnv      # CNV analysis only
./run_pipeline.sh --run_mode_analysis terp     # TERTP analysis only
./run_pipeline.sh --run_mode_analysis rmd      # Markdown report only
```

### **Common Usage Examples**

#### **First-time Setup and Run:**
```bash
# 1. Setup Docker environment
./setup_docker.sh

# 2. Configure your data paths in conf/analysis.config
# 3. Place your reference files in data/reference/
# 4. Place your input data in data/testdata/

# 5. Run complete analysis
./run_pipeline.sh --run_mode_order --sample_id YOUR_SAMPLE_ID
```

#### **Testing the Setup:**
```bash
# Run a quick test to verify everything works
./test_pipeline.sh
```

#### **Running with Resume:**
```bash
# Resume a previous run
./run_pipeline.sh --run_mode_order --sample_id T001 -resume
```

#### **Running Specific Analyses:**
```bash
# Only methylation analysis
./run_pipeline.sh --run_mode_analysis mgmt

# Only structural variant calling
./run_pipeline.sh --run_mode_epi2me sv

# Only copy number analysis
./run_pipeline.sh --run_mode_epi2me cnv
```

### **Run Mode Reference**

| Mode | Command | Description |
|------|---------|-------------|
| **Complete** | `--run_mode_order` | Runs entire pipeline sequentially |
| **Mergebam** | `--run_mode_mergebam` | Merges BAM files only |
| **Epi2me All** | `--run_mode_epi2me all` | All Epi2me analyses (modkit + cnv + sv) |
| **Epi2me Modkit** | `--run_mode_epi2me modkit` | Modified base calling only |
| **Epi2me CNV** | `--run_mode_epi2me cnv` | Copy number analysis only |
| **Epi2me SV** | `--run_mode_epi2me sv` | Structural variant calling only |
| **Analysis All** | `--run_mode_analysis all` | All analysis modules |
| **Analysis OCC** | `--run_mode_analysis occ` | OCC analysis only |
| **Analysis MGMT** | `--run_mode_analysis mgmt` | MGMT methylation analysis only |
| **Analysis Svanna** | `--run_mode_analysis svannasv` | Svanna SV annotation only |
| **Analysis CNV** | `--run_mode_analysis cnv` | CNV analysis only |
| **Analysis TERTP** | `--run_mode_analysis terp` | TERT promoter analysis only |
| **Report Only** | `--run_mode_analysis rmd` | Generate markdown report only |

### **Advanced Usage**

#### **Adding Nextflow Options:**
```bash
# Run with specific profile
./run_pipeline.sh --run_mode_order --sample_id T001 -profile test

# Run with resume capability
./run_pipeline.sh --run_mode_order --sample_id T001 -resume

# Run with specific executor
./run_pipeline.sh --run_mode_order --sample_id T001 -executor slurm
```

#### **Custom Configuration (Advanced):**
If you need to use a custom configuration file:

```bash
# Direct Nextflow usage with custom config
nextflow run main.nf -c conf/my_custom.config -with-docker --run_mode_order --sample_id T001
```

### **Output and Reports**

#### **Automatic Report Generation:**
- **`--run_mode_order`**: Automatically generates comprehensive markdown report
- **`--run_mode_analysis all`**: Generates markdown report after all analyses
- **`--run_mode_analysis rmd`**: Generates report from existing results

#### **Report Contents:**
- Sample information and quality metrics
- MGMT methylation analysis results
- Structural variant findings with Svanna annotations
- Copy number variation analysis with ACE tumor content
- SNV/indel results from Clair3 and ClairS-TO
- TERT promoter analysis
- Interactive visualizations and plots

**Reports are saved in:** `results/analysis/report/` as PDF files.

### 🐳 **Docker-Specific Notes**

- All containers are automatically pulled from `vilhelmmagnuslab` repository
- No need to manage local Singularity images
- Containers are automatically updated when you pull the latest images
- Volume mounting is handled automatically for data access
- Configuration files are automatically selected based on run mode

### **Need Help?**

If you encounter issues:
1. Check the [DOCKER_SETUP.md](DOCKER_SETUP.md) troubleshooting section
2. Verify Docker is running: `docker info`
3. Check available images: `docker images | grep vilhelmmagnuslab`
4. Run the test script: `./test_pipeline.sh`

### ACE Tumor Content Calculation

The pipeline includes intelligent tumor content handling using ACE (Allele-specific Copy number Estimation):

#### **Automatic Tumor Content Detection**
- **Sample ID File Parsing**: Automatically detects whether tumor content is provided or needs calculation
- **Flexible Input Format**: Supports both single-column (auto-calculation) and two-column (provided value) formats
- **Validation**: Ensures provided tumor content values are between 0-1

#### **ACE Calculation Process**
- **QDNAseq Integration**: Uses copy number profiles from QDNAseq analysis as input
- **Allele-specific Analysis**: Analyzes allele-specific copy number patterns to estimate tumor cellularity
- **Multiple Estimates**: ACE provides several tumor content estimates based on different thresholds
- **Automatic Selection**: ACE automatically selects the best fit from the multiple estimates
- **Robust Estimation**: Handles various tumor types and copy number profiles
- **Result Storage**: Saves calculated values in `${sample_id}_ace_results/threshold_value.txt`

## Acknowledgment and General Information

### Citing this Workflow
If you use this pipeline in your research, please cite:
```
[Citation details to be added]
```

### Acknowledgments
We would like to thank:
- The Nextflow community for their excellent framework
- Oxford Nanopore Technologies for their sequencing technology and tools
- All contributors and testers of this pipeline

### License
This project is licensed under the MIT License - see the LICENSE file for details.

### Funding
This work was supported by:
- [Funding details to be added]
- [Grant numbers to be added]

### Download
The latest version of the pipeline can be downloaded from:
```bash
git clone https://github.com/VilhelmMagnusLab/nWGS_pipeline.git
```

## Questions and Feedback

For questions, bug reports, or feature requests, please contact:

**Maintainers:**
- Christian Bope (chbope@ous-hf.no / christianbope@gmail.com)
- Skabbi (skahal@ous-hf.no / skabbi@gmail.com)

You can also:
1. Open an issue on GitHub
2. Submit a pull request with improvements
3. Contact the maintainers directly via email

## Citations

If you use this pipeline, please cite:
- [Citations to be added]