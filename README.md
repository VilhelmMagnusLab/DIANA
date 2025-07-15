# nWGS_pipeline: Nanopore Whole Genome Sequencing Pipeline

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with apptainer](https://img.shields.io/badge/run%20with-apptainer-1d355c.svg?labelColor=000000)](https://apptainer.org/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed.svg?labelColor=000000)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Release](https://img.shields.io/badge/release-v1.0.0-blue.svg)](https://github.com/VilhelmMagnusLab/nWGS_pipeline/releases)

## Overview

nWGS_pipeline is a comprehensive bioinformatics pipeline for analyzing Central Nervous System (CNS) samples using Oxford Nanopore sequencing data. It integrates multiple analyses including CNV detection, methylation profiling, structural variant calling, and MGMT promoter status determination.

## Quick Start

### Prerequisites
- **Docker** (Desktop/Local) or **Singularity/Apptainer** (HPC)
- **Nextflow** (auto-installed by setup scripts)

### One-Command Setup & Run

**For Docker (Desktop/Local):**
```bash
git clone https://github.com/VilhelmMagnusLab/nWGS_pipeline.git
cd nWGS_pipeline
chmod +x setup_docker.sh
./setup_docker.sh
./run_pipeline_docker.sh --run_mode_order --sample_id YOUR_SAMPLE_ID
```

**For Singularity/Apptainer (HPC):**
```bash
git clone https://github.com/VilhelmMagnusLab/nWGS_pipeline.git
cd nWGS_pipeline
chmod +x setup_singularity.sh
./setup_singularity.sh
./run_pipeline_singularity.sh --run_mode_order --sample_id YOUR_SAMPLE_ID
```

## Pipeline Modules

The pipeline consists of three main modules that can be run independently or sequentially:

### 1. **Mergebam Pipeline**
- Merges multiple BAM files per sample
- Extracts regions of interest using OCC.protein_coding.bed
- Quality control of merged BAMs

### 2. **Epi2me Pipeline**
Three independent analysis types:

| Analysis | Tool | Purpose | Output |
|----------|------|---------|---------|
| **Modified Base Calling** | Modkit | DNA modifications (5mC, 5hmC) | `*_wf_mods.bedmethyl.gz` |
| **Structural Variants** | Sniffles2 | Structural variant detection | `*.vcf.gz` |
| **Copy Number Variation** | QDNAseq | CNV detection | `*_segs.bed`, `*_bins.bed`, `*_segs.vcf` |

### 3. **Analysis Pipeline**
- **MGMT methylation analysis** using EPIC array sites
- **NanoDx neural network classification**
- **Structural variant annotation** with Svanna
- **CNV analysis** with ACE tumor content determination
- **Comprehensive reporting** (HTML, IGV snapshots, Circos plots, Markdown)

## Container Systems

| Feature | Docker | Singularity/Apptainer |
|---------|--------|----------------------|
| **Best for** | Desktop/Local | HPC/Shared systems |
| **Setup Script** | `setup_docker.sh` | `setup_singularity.sh` |
| **Run Script** | `run_pipeline_docker.sh` | `run_pipeline_singularity.sh` |

All containers are automatically downloaded from [vilhelmmagnuslab Docker Hub](https://hub.docker.com/repositories/vilhelmmagnuslab).

## Usage Examples

### Complete Pipeline (Recommended)
```bash
# Docker
./run_pipeline_docker.sh --run_mode_order --sample_id T001

# Singularity/Apptainer
./run_pipeline_singularity.sh --run_mode_order --sample_id T001
```

### Individual Modules
```bash
# Mergebam only
./run_pipeline_docker.sh --run_mode_mergebam

# Epi2me analyses
./run_pipeline_docker.sh --run_mode_epi2me all          # All Epi2me analyses
./run_pipeline_docker.sh --run_mode_epi2me modkit       # Modified base calling only
./run_pipeline_docker.sh --run_mode_epi2me cnv          # CNV analysis only
./run_pipeline_docker.sh --run_mode_epi2me sv           # Structural variants only

# Analysis modules
./run_pipeline_docker.sh --run_mode_analysis all        # All analyses
./run_pipeline_docker.sh --run_mode_analysis mgmt       # MGMT analysis only
./run_pipeline_docker.sh --run_mode_analysis cnv        # CNV analysis only
./run_pipeline_docker.sh --run_mode_analysis svannasv   # Svanna SV annotation only
./run_pipeline_docker.sh --run_mode_analysis terp       # TERT promoter analysis only
./run_pipeline_docker.sh --run_mode_analysis occ        # OCC analysis only
./run_pipeline_docker.sh --run_mode_analysis rmd        # Markdown report only
```

## Input Requirements

### Sample ID File Format
```
# For analysis pipeline (with tumor content)
sample_id1   0.75    # 75% tumor content
sample_id2          # Auto-calculate with ACE

# For mergebam pipeline (with flowcell)
sample_id1   flowcell_id1
sample_id2   flowcell_id2
```

### Directory Structure
```
/path/to/data/
├── reference/                    # Reference files
├── humandb/                      # Annotation files
├── testdata/                     # Input data
│   ├── sample_ids.txt           # Sample ID file
│   └── single_bam_folder/       # BAM files
└── results/                      # Output (auto-created)
```

## Required Reference Data

### Included Files (`refdata/` folder)
- `OCC.fusions.bed` - Fusion genes
- `EPIC_sites_NEW.bed` - Methylation sites
- `MGMT_CpG_Island.hg38.bed` - MGMT CpG islands
- `OCC.SNV.screening.bed` - SNV screening regions
- `TERTp_variants.bed` - TERT promoter variants
- `hg38_refGene.txt` - RefGene annotation
- `hg38_refGeneMrna.fa` - RefGene mRNA sequences
- `hg38_clinvar_20240611.txt` - ClinVar annotations
- `hg38_cosmic100coding2024.txt` - Cosmic annotations
- `human_GRCh38_trf.bed` - Tandem repeat regions
 
### External Downloads Required
- **Reference genome**: [Human Reference Genomes](https://www.ncbi.nlm.nih.gov/datasets/docs/v2/reference-docs/reference-genomes/human-reference-genomes/)
- **Gencode annotation**: [Gencode v48](https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_48/gencode.v48.annotation.gff3.gz)
- **Cosmic annotations**: [ANNOVAR Cosmic](https://annovar.openbioinformatics.org/en/latest/user-guide/filter/#cosmic-annotations)

- **Other datasets** such as `hg38_refGene.txt`, `hg38_clinvar_20240611.txt`, `hg38_cosmic100coding2024.txt` and others can be found in [figshare](https://figshare.com/articles/dataset/nWGS_Pipeline_Reference_Files/12345678)

## NanoDx Model Setup

The pipeline includes NanoDx in the `nanoDx/` folder. Download these large model files to `nanoDx/static/`:
- `Capper_et_al.h5` (model file)
- `Capper_et_al.h5.md5` (checksum)
- `Capper_et_al_NN.pkl` (neural network)

## ACE Tumor Content Calculation

The pipeline intelligently handles tumor content:
- **Provided value**: Use directly if specified in sample ID file
- **Auto-calculation**: ACE analyzes copy number profiles to estimate tumor cellularity
- **Multiple estimates**: ACE provides several estimates and selects the best fit
- **Results**: Saved in `${sample_id}_ace_results/threshold_value.txt`

## Output Structure

```
results/
├── mergebam/
│   ├── merge_bam/               # Merged BAM files
│   └── occ_bam/                 # Regions of interest BAMs
├── epi2me/
│   ├── episv/                   # Structural variants
│   ├── modkit/                  # Modified base calling
│   └── epicnv/                  # Copy number variations
└── analysis/
    ├── cnv/                     # CNV analysis with ACE
    ├── sv/                      # Structural variant annotation
    ├── methylation/             # MGMT methylation analysis
    └── reports/                 # Comprehensive reports
```

## Configuration

Update the base path in all configuration files:
```groovy
// conf/analysis.config, conf/epi2me.config, conf/mergebam.config
params {
    path = "/path/to/your/data/directory"  // ← Update this
}
```

## Troubleshooting

### Common Issues
1. **Container engine conflict**: Ensure only one container system is enabled
2. **Missing reference files**: Download required external files
3. **Permission issues**: Check container and file permissions

### Verification Commands
```bash
# Check containers
docker images | grep vilhelmmagnuslab          # Docker
ls -la containers/*.sif                        # Singularity

# Test pipeline
./test_pipeline_docker.sh                            # Docker
./test_pipeline_singularity.sh                # Singularity
```

## Support

- **Documentation**: [DOCKER_SETUP.md](DOCKER_SETUP.md), [SINGULARITY_SETUP.md](SINGULARITY_SETUP.md)
- **Issues**: [GitHub Issues](https://github.com/VilhelmMagnusLab/nWGS_pipeline/issues)
- **Contact**: 
  - Christian Bope (chbope@ous-hf.no / christianbope@gmail.com)
  - Skabbi (skahal@ous-hf.no / skabbi@gmail.com)

## Citation

If you use this pipeline in your research, please cite:
```
[Citation details to be added]
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.