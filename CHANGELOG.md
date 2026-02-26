# My Pipeline: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### `Added`
- Added configurable SNV filtering thresholds in annotation configuration
  - `snv_depth_threshold` parameter (default: 10) for minimum sequencing depth filtering
  - `snv_gq_threshold` parameter (default: 10) for minimum Genotype Quality filtering
  - Filters variants in Markdown PDF reports while preserving all variants in raw VCF files
  - GQ filtering supports multiple values from different callers (keeps variant if ANY value meets threshold)
- Added comprehensive software version documentation
  - `SOFTWARE_VERSIONS.md` - Human-readable documentation of all tools and versions
  - `versions.yml` - Machine-readable YAML format for automation
  - `CONTAINERS.md` - Quick reference guide for container usage and troubleshooting
- Added VCF indexing (.tbi files) to epi2me:run_clairs_to process
  - Automatically creates tabix index files for ClairS-TO VCF outputs
  - Ensures downstream annotation processes can access indexed VCF files
  - Handles empty VCF files gracefully when no variants are found
- Added automatic log file organization
  - All Nextflow logs now written to `logs/` directory
  - Log filenames include run mode and sample ID for easy identification
  - Format: `trace-{mode}_{sample_id}_{timestamp}.txt`
  - HTML reports: `execution_report-{mode}_{sample_id}_{timestamp}.html`

### `Changed`
- **BREAKING**: Renamed "analysis" to "annotation" throughout the entire pipeline
  - Module renamed: `modules/analysis.nf` → `modules/annotation.nf`
  - Config renamed: `conf/analysis.config` → `conf/annotation.config`
  - Run mode renamed: `--run_mode_analysis` → `--run_mode_annotation`
  - Run mode renamed: `--run_mode_epianalyse` → `--run_mode_epiannotation`
  - Directory renamed: `routine_analysis/` → `routine_annotation/`
  - Updated all documentation, scripts, and configuration files
- Updated SNV variant caller abbreviations in reports
  - Changed ClairS-TO abbreviation from "C" to "S_TO" for clarity
  - Updated legend: "P:Clair3 Pileup, M:Clair3 Merged and S_TO:ClairS-TO Somatic tumour-only"
- Renamed process `run_nn_classifier` to `crossNN` for clarity
  - Updated in `modules/annotation.nf` (7 occurrences)
  - Updated in `conf/annotation.config`
  - Updated in `conf/example.config`
- Updated smart_sample_monitor scripts for consistency
  - `smart_sample_monitor_v2.sh`: Changed variable names from `analysis_config` → `annotation_config`
  - `smart_sample_monitor.sh`: Changed variable names from `analysis_config` → `annotation_config`
- Updated setup scripts
  - `setup_docker.sh`: Updated pipeline mode examples and config file references
  - `setup_singularity.sh`: Updated default config, directory structure, and mode examples
  - `run_pipeline_conda.sh`: Updated variable names and config file references
- Enhanced README.md documentation
  - Added SNV Filtering Configuration section with examples
  - Updated all pipeline mode references to use "annotation" terminology
  - Added SNV mode to epi2me and annotation module options
  - Updated container and configuration file references
- Modified ClairS-TO VCF file access in annotation workflow
  - Changed from passing individual VCF files to using clairsto_output_dir
  - Ensures .tbi index files are accessible alongside VCF files
  - Fixes "could not retrieve index file" errors in run_mode_order

### `Fixed`
- Fixed "tabix: command not found" error in run_mode_order
  - Root cause: VCF files from epi2me lacked .tbi index files in run_mode_order
  - Solution: Added tabix indexing to epi2me:run_clairs_to process
  - Removed redundant tabix calls from annotation:clairs_to_annotate process
- Fixed bcftools concat index file access issues
  - Updated annotation:clairs_to_annotate to reference VCF files via clairsto_output_dir
  - Ensures both .vcf.gz and .vcf.gz.tbi files are accessible in same directory
- Fixed trace-*.txt files cluttering pipeline root directory
  - Implemented automatic log organization to `logs/` directory
  - Moved 197+ existing trace files to organized location

## [1.0.1] - 2024-11-14

### `Added`
- Added `--run_mode_epianalyse` pipeline execution mode to run Epi2me and Analysis modules sequentially when merged BAM files already exist
- Added comprehensive "Pipeline Run Modes" documentation table in README.md
- Added BED file format validation notes in README.md

### `Fixed`
- Fixed tumor content not appearing in PDF report when user provides 2-column `sample_ids.txt` file (sample_id + tumor_content)
  - Updated `modules/analysis.nf` (lines 862-895) to always create local `sample_file.txt` in work directory
  - Implemented priority logic: user-provided tumor content → ACE-calculated tumor content → no tumor content
  - Resolved issue where `sample_ids.txt` was passed as string value instead of staged file in `run_mode_analysis`
- Fixed circos plot always generating empty output files
  - Updated `modules/analysis.nf` (lines 437-468) to properly detect gzipped VCF files (.vcf.gz)
  - Added gzip detection: uses `zcat` for compressed files, `grep` for uncompressed files
  - Added graceful error handling when vcf2circos fails (creates empty placeholder instead of pipeline failure)
- Fixed BED file formatting errors in `OCC.protein_coding.bed`
  - Corrected line 204: Removed trailing tab character (was causing 11 fields error)
  - Corrected line 206: Converted spaces to tabs for proper BED format
  - Corrected line 208: Removed extra field (11th field)
  - Corrected line 209: Removed extra fields (11th and 12th fields)
  - All 208 lines now have proper 10-field BED format required by bedtools

### `Changed`
- Consolidated BED file usage: replaced `occ_snv_screening` parameter with `occ_protein_coding_bed` throughout pipeline
  - Updated `modules/analysis.nf`: Replaced all 4 occurrences of `occ_snv_screening` with `occ_protein_coding_bed`
  - Updated `conf/analysis.config`: Removed `occ_snv_screening` parameter definition
  - Updated `conf/example.config`: Removed `occ_snv_screening` parameter definition
  - Unified protein-coding region file usage across mergebam, SNV screening, and analysis modules
- Enhanced README.md documentation
  - Added pipeline execution mode flags to module headers
  - Added usage examples for `--run_mode_epianalyse` mode
  - Updated reference files section to document `OCC.protein_coding.bed` usage and requirements
  - Improved directory structure examples to reflect current file naming
  - Fixed typo: "Zenado" → "Zenodo"
  - Improved tool name capitalization consistency (Clair3, ClairS-TO)

### `Removed`
- Removed redundant `OCC.SNV.screening.bed` reference file parameter (consolidated into `OCC.protein_coding.bed`)

## [1.0dev] - 2025-01-16

### `Added`
- Fusion event exon/intron annotation pipeline with new Python scripts:
  - `bin/breaking_point_bed_translocation_exon.py` - Extract breakpoints from VCF to BED format
  - `bin/create_gff3_with_introns.py` - Calculate intron regions from exon boundaries in GFF3 files
  - `bin/remove_duplicate_report_exon.py` - Process intersectBed output to extract gene and feature information
  - `bin/summarize_fusion_features.py` - Consolidate fusion annotations with exon/intron/CDS/UTR/intergenic features
  - `bin/annotate_intergenic_breakpoints.py` - Add intergenic annotations for unannotated breakpoints
- Enhanced report generation (`bin/nextflow_markdown_pipeline_update_finalexecsummary.Rmd`) with:
  - Conditional EGFR section (only shown if EGFR is in CNV table)
  - Conditional SNV explanatory text (only shown if SNVs are detected)
  - Italic formatting for all gene names in tables (SNV, CNV, Fusion Events)
  - *TERT*p formatting for TERT promoter variants
  - LaTeX packages for preventing title/content page break separation (`needspace`, `etoolbox`, `titlesec`)
- Enhanced t-SNE plotting script (`bin/crossnn_tsne_fixedupdate.R`) with improved styling and bigger/bolder unknown cross symbols
- Singularity-based report generation script (`bin/generate_report_singularity.sh`)
- Crossnnumap container image support in setup scripts (`setup_singularity.sh`, `setup_docker.sh`)
- Dockerfile for crossnnumap container (`dockerfiles/Dockerfile_tsne`)
- Enhanced MGMT methylation table in reports with percentage values and improved headers
- Comprehensive `.gitignore` patterns to exclude large output directories and temporary files
- Added AA Change column to SNV summary table in executive summary report (`bin/nextflow_markdown_pipeline_update_finalexecsummary.Rmd`)
- Added placeholder regions for acrocentric chromosome p-arms (chr13, chr14, chr15, chr21, chr22) in CNV plots to display empty space instead of missing data

### `Fixed`
- Fixed t-SNE plot process failure in `--run_mode_analysis rmd` mode
- Corrected R environment handling in Nextflow configuration to prevent conda conflicts
- Fixed memory allocation for t-SNE plot process (increased to 75 GB)
- Corrected UMAP parameters in t-SNE plotting (`--umap-n-neighbours 10`, `--umap-min-dist 0.5`, `--umap-pca-dim 100`)
- Fixed data loading in enhanced t-SNE script to use correct probe IDs (`Illumina_ID`)
- Resolved plotting issues with unknown cross symbols in t-SNE visualizations

### `Changed`
- Updated `modules/analysis.nf`:
  - Enhanced `svannasv_fusion_events` process to add exon/intron annotation pipeline
  - Integrated new Python scripts for fusion feature extraction
  - Added GFF3 enhancement step to include calculated introns
  - Added fusion event filtering to report only complete events (with both start and end breakpoints)
- Updated `modules/epi2me.nf` with fusion annotation workflow
- Updated `modules/analysis.nf` to use enhanced t-SNE script with corrected parameters
- Modified `nextflow.config` to conditionally disable R environment clearing for RMD mode
- Updated MGMT table headers in reports:
  - "Mean Methylation Pyro" → "Mean Methylation, CpG 76–79 (%)"
  - "Mean Methylation Full" → "Mean Methylation, CpG 1–98 (%)"
  - "Classification by Pyro" → "Classification by CpG 76–79"
  - "Classification by Full" → "Classification by CpG 1–98"
- Converted MGMT methylation values to percentages in final reports
- Enhanced SNV summary table processing to extract and display protein changes (p.XXX notation) in AA Change column
- Improved CNV visualization (`bin/CNV_function_new_update.R`) to correctly represent acrocentric chromosomes with visual empty space for missing p-arm regions

### `Removed`
- Obsolete `bin/generate_report.sh` (replaced by Singularity version)
- Obsolete `bin/nextflow_markdown_pipeline_update_final9sep.Rmd` (replaced by updated version)

### `Dependencies`
- Added crossnnumap container image for enhanced t-SNE plotting
- Updated R package dependencies for improved visualization

### `Deprecated`

---

## Release Links

[Unreleased]: https://github.com/VilhelmMagnusLab/nWGS_pipeline/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/VilhelmMagnusLab/nWGS_pipeline/compare/v1.0dev...v1.0.1
[1.0dev]: https://github.com/VilhelmMagnusLab/nWGS_pipeline/releases/tag/v1.0dev 