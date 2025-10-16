# My Pipeline: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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