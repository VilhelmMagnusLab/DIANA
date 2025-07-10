# nWGS_pipeline: Nanopore Whole Genome Sequencing Pipeline

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed.svg?labelColor=000000)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Release](https://img.shields.io/badge/release-v1.0.0-blue.svg)](https://github.com/yourusername/nWGS_pipeline/releases)

## Introduction

nWGS_pipeline is a comprehensive bioinformatics pipeline for analyzing Central Nervous System (CNS) samples using Oxford Nanopore sequencing data. The pipeline integrates multiple analyses including CNV detection, methylation profiling, structural variant calling, and MGMT promoter status determination.

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
- **Output**: `*.vcf.gz` files with structural variants

#### **QDNAseq - Copy Number Variation Analysis**
- **Purpose**: Detects copy number variations using QDNAseq
- **Input**: BAM files, reference genome
- **Output**: Multiple files including:
  - `*_segs.bed`: Segmented copy number data
  - `*_bins.bed`: Binned copy number data
  - `*_segs.vcf`: Copy number variants in VCF format
  - `*_copyNumbersCalled.rds`: R data structure

#### **Key Improvements in Epi2me Pipeline**:

1. **Enhanced Error Handling**:
   - Comprehensive input file validation
   - Tool availability checks
   - Detailed error messages for troubleshooting

2. **Flexible Run Modes**:
   - `all`: Run all three analyses (default)
   - `modkit`: Run only modified base calling
   - `cnv`: Run only copy number analysis
   - `sv`: Run only structural variant calling

3. **Improved Input Handling**:
   - Support for both standalone and sequential execution
   - Automatic file discovery and validation
   - Reference genome validation

4. **Better Resource Management**:
   - Configurable CPU and memory limits
   - Process-specific resource allocation
   - Optimized container configurations

5. **Enhanced Output Organization**:
   - Structured output directories
   - Consistent file naming conventions
   - Comprehensive result tracking

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

## Required Containers

The following containers are required to run the complete nWGS pipeline. All containers should be downloaded and placed in your container directory:

```bash
# Core Analysis Containers
# The following containers are required to run the analysis pipeline. The containers are downloaded from the container registry (https://hub.docker.com/repositories/vilhelmmagnuslab/)
wget https://hub.docker.com/repositories/vilhelmmagnuslab/ace_1.24.0
wget https://hub.docker.com/repositories/vilhelmmagnuslab/clair3_amd64
wget https://hub.docker.com/r/hkubal/clairs-to
wget https://hub.docker.com/repositories/vilhelmmagnuslab/igv_report_amd64
wget https://hub.docker.com/repositories/vilhelmmagnuslab/vcf2circos
wget https://hub.docker.com/repositories/vilhelmmagnuslab/nanodx_env
wget https://hub.docker.com/repositories/vilhelmmagnuslab/markdown_images_28feb2025
wget https://hub.docker.com/repositories/vilhelmmagnuslab/annotcnv_images_27feb1025
wget https://hub.docker.com/repositories/vilhelmmagnuslab/mgmt_nanopipe_amd64_18feb2025_cramoni
wget https://hub.docker.com/repositories/vilhelmmagnuslab/nwgs_default_images_latest

# Epi2me Analysis Containers
# These containers are used for the Epi2me pipeline components (modified base calling, structural variant calling, and copy number variation analysis)
wget https://hub.docker.com/repositories/vilhelmmagnuslab/modkit_latest
wget https://hub.docker.com/repositories/vilhelmmagnuslab/snifflesv252_update_latest
wget https://hub.docker.com/repositories/vilhelmmagnuslab/qdnaseq_amd64_latest
```

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
```

These files are essential for:
- Methylation analysis (EPIC sites, MGMT)
- Structural variant analysis (Fusions)
- Copy number analysis
- SNV detection
- TERT promoter analysis

# Classifier Models

```bash
# The NanoDx model is downloaded from the following link: https://gitlab.com/pesk/nanoDx. The user need to download the model from the link and provide the path to the model in the analysis.config file (nanodx_workflow_dir). It is also required to make sure that the file Capper_et_al_NN.pkl is in the /$Path/nanoDx/static.

```

## Quick Start

1. Install dependencies:
```bash
# Install Nextflow
curl -s https://get.nextflow.io | bash

# Install Apptainer (formerly Singularity)
# Follow instructions at: https://apptainer.org/docs/admin/main/installation.html
```

## Configuration

### 1. Singularity Configuration

The pipeline uses Singularity containers. You need to configure the bind paths in the following files:

```nextflow
// In nextflow.config
profiles {
    epi2me_auto_singularity {
        singularity {
            enabled = true
            autoMounts = true
            // Update these paths to match your system
            runOptions = "-B /path/to/conda/env/bin:/usr/local/bin -B /path/to/user/home/"
            cacheDir = "singularity-images"
        }
    }
}
```

### 2. Path Configuration

Update the following paths in the configuration files:

#### In conf/analysis.config:
```nextflow
params {
    // Base paths
    path = "/path/to/base/directory"
    input_path = "${params.path}"
    output_path = "${params.path}/results"

    // Reference and annotation directories
    annotate_dir = "/path/to/annotations"
    ref_dir = "/path/to/reference"
    humandb_dir = "/path/to/annovar/humandb"

    // Tool-specific directories
    bin_dir = "/path/to/bin/"
    epi2me_dir = "/path/to/epi2me/wf-human-variation-master/"
}
```

#### In conf/epi2me.config:
The epi2me configuration has been updated with improved container management and parameter handling. Update the following paths:

```nextflow
params {
    // Base path
    path = "/path/to/base/directory"
    
    // Epi2me output directories
    episv = "${path}/results/epi2me/episv"
    epimodkit = "${path}/results/epi2me/modkit"
    epicnv = "${path}/results/epi2me/epicnv"
    
    // Reference files (required)
    reference_genome = "/path/to/reference/genome.fa"
    reference_genome_bai = "/path/to/reference/genome.fa.fai"
    
    // Input/Output paths
    merge_bam_folder = "/path/to/merge_bam/folder"
    epi2me_sample_id_file = "/path/to/sample_ids.txt"
    
    // Analysis-specific parameters
    binsize = 50                    // QDNAseq bin size in kb
    interval_size = 100000          // Modkit interval size
    modkit_threads = 4              // Number of threads for Modkit
    min_sv_length = 30              // Minimum SV length for Sniffles2
    min_read_support = "auto"       // Minimum read support for SVs
    cluster_merge_pos = 150         // SV cluster merge position
}
```

#### Container Configuration:
Update the container paths in the process section:

```nextflow
process {
    withName: run_epi2me_sv {
        container = '/path/to/containers/snifflesv252_update_latest.sif'
    }

    withName: run_epi2me_cnv {
        container = '/path/to/containers/qdnaseq_amd64_latest.sif'
    }

    withName: run_epi2me_modkit {
        container = '/path/to/containers/modkit_latest.sif'
        containerOptions = "--env PATH=/opt/custflow/epi2meuser/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    }
}
```

### 4. Sample Configuration

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

### Output results folder structure:

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
### Important Notes:

1. All paths should be absolute paths
2. Ensure read/write permissions for all directories
3. Container bind paths must include all required directories
4. The singularity cache directory needs sufficient storage space
5. Memory and CPU requirements can be adjusted in nextflow.config

## 2. **Running Pipeline**

### Pipeline Modes
```bash
# Run complete workflow in order (includes all analyses + markdown report)
nextflow run main.nf --run_mode_order

```
#### Epi2me Pipeline Modes
```bash
# Run all Epi2me analyses (default)
nextflow run main.nf --run_mode_epi2me all

# Run specific Epi2me analyses
nextflow run main.nf --run_mode_epi2me modkit  # Run only modified base calling
nextflow run main.nf --run_mode_epi2me cnv     # Run only copy number analysis
nextflow run main.nf --run_mode_epi2me sv      # Run only structural variant calling
```

#### Analysis Pipeline Modes
```bash
# Run all analyses (includes markdown report generation)
nextflow run main.nf --run_mode_analysis all

# Run specific analyses
nextflow run main.nf --run_mode_analysis occ     # Run only OCC analysis
nextflow run main.nf --run_mode_analysis mgmt    # Run only MGMT analysis
nextflow run main.nf --run_mode_analysis svannesv # Run only Svanna analysis
nextflow run main.nf --run_mode_analysis cnv     # Run only CNV analysis
nextflow run main.nf --run_mode_analysis tertp    # Run only TERTP analysis
nextflow run main.nf --run_mode_analysis rmd     # Generate only the markdown report
```

#### Markdown Report Generation

The pipeline automatically generates comprehensive markdown reports in the following scenarios:

- **`--run_mode_analysis all`**: Runs all analyses and generates a markdown report
- **`--run_mode_order`**: Runs the complete workflow sequentially and generates a markdown report
- **`--run_mode_analysis rmd`**: Generates only the markdown report (requires previous analysis outputs)

The markdown report includes:
- Sample information and quality metrics
- MGMT methylation analysis results
- Structural variant findings with Svanna annotations
- Copy number variation analysis with ACE tumor content
- SNV/indel results from Clair3 and ClairS-TO
- TERT promoter analysis
- Interactive visualizations and plots

Reports are saved in `results/analysis/report/` as PDF files.

## Error Handling and Validation

### Enhanced Error Handling in Epi2me Pipeline

The epi2me pipeline now includes comprehensive error handling and validation:

#### **Input Validation**
- **File Existence Checks**: All input files (BAM, BAI, reference genome) are validated before processing
- **Tool Availability**: Automatic detection of required tools (modkit, sniffles, Rscript)
- **Reference Genome Validation**: Ensures reference genome and index files are properly formatted

#### **Parameter Validation**
- **Run Mode Validation**: Validates that specified run modes are supported (`modkit`, `cnv`, `sv`, `all`)
- **Required Parameters**: Checks for essential parameters like `reference_genome` and `reference_genome_bai`
- **Parameter Range Validation**: Ensures parameters are within acceptable ranges

#### **Output Validation**
- **File Creation Checks**: Verifies that expected output files are created
- **File Size Validation**: Checks that output files have reasonable sizes
- **Format Validation**: Ensures output files are properly formatted

#### **Error Recovery**
- **Graceful Failures**: Pipeline continues processing other samples if one fails
- **Detailed Error Messages**: Provides specific error information for troubleshooting
- **Logging**: Comprehensive logging of all operations and errors

### ACE Tumor Content Calculation

The pipeline includes intelligent tumor content handling using ACE (Allele-specific Copy number Estimation):

#### **Automatic Tumor Content Detection**
- **Sample ID File Parsing**: Automatically detects whether tumor content is provided or needs calculation
- **Flexible Input Format**: Supports both single-column (auto-calculation) and two-column (provided value) formats
- **Validation**: Ensures provided tumor content values are between 0-1

#### **ACE Calculation Process**
- **QDNAseq Integration**: Uses copy number profiles from QDNAseq analysis as input
- **Allele-specific Analysis**: Analyzes allele-specific copy number patterns to estimate tumor cellularity
- **Robust Estimation**: Handles various tumor types and copy number profiles
- **Result Storage**: Saves calculated values in `${sample_id}_ace_results/threshold_value.txt`

#### **Error Handling for ACE**
- **Missing RDS Files**: Validates that QDNAseq RDS files exist before ACE calculation
- **Calculation Failures**: Provides detailed error messages if ACE calculation fails
- **Fallback Options**: Allows manual tumor content specification if automatic calculation fails

### Troubleshooting Common Issues

#### **Container Issues**
```bash
# Check if containers are accessible
ls -la /path/to/containers/*.sif

# Verify container permissions
chmod +x /path/to/containers/*.sif
```

#### **Reference Genome Issues**
```bash
# Check reference genome format
samtools faidx /path/to/reference/genome.fa

# Verify index file exists
ls -la /path/to/reference/genome.fa.fai
```

#### **Memory Issues**
```bash
# Adjust memory limits in nextflow.config
params {
    max_memory = '32.GB'  // Increase if needed
}
```

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