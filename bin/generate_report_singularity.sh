#!/bin/bash

#==============================================================================
# Diana Pipeline Report Generator (Singularity Version)
#==============================================================================
#
# DESCRIPTION:
#   This script generates comprehensive PDF reports for nanopore whole genome 
#   sequencing (Diana) analysis results using R Markdown within a Singularity 
#   container. It processes multiple samples and creates detailed reports 
#   containing methylation analysis, structural variant annotation, copy number 
#   variation analysis, SNV calling results, and quality assessment metrics. 
#   This script must be used after the pipeline has finished running and the 
#   user can re-run specific process to generate the report.
#
# USAGE:
#   ./generate_report_singularity.sh [path_to_singularity_image]
#
# ARGUMENTS:
#   path_to_singularity_image: Optional path to the Singularity image file
#                             Defaults to: markdown_images_28feb2025_latest.sif
#
# REQUIREMENTS:
#   - Singularity container with R and required packages
#   - Sample IDs file with tumor content information
#   - All analysis results from the Diana pipeline
#   - R Markdown template file
#
# INPUT FILES:
#   - sample_ids.txt: Two-column file with sample ID and tumor content (decimal)
#     Location: /data/routine_diana/sample_ids.txt
#   - Various analysis result files from routine_analysis/{sample_id}/ directories
#   - The PATH for each analysis result file is configured in the script.
#
# OUTPUT:
#   - PDF reports for each sample in routine_results/{sample_id}/ directory
#   - Format: {sample_id}_markdown_pipeline_report.pdf
#
# DEPENDENCIES:
#   - Singularity container with R and required packages
#   - Container must include: rmarkdown, data.table, kableExtra, and other R packages
#   - Default image: markdown_images_28feb2025_latest.sif
#
# AUTHOR: Diana Pipeline Development Team
# DATE: 2024
#==============================================================================

# Set the Singularity image path
SINGULARITY_IMAGE="${1:-markdown_images_28feb2025_latest.sif}"

# Check if Singularity image exists
if [ ! -f "$SINGULARITY_IMAGE" ]; then
    echo "Error: Singularity image '$SINGULARITY_IMAGE' not found!"
    echo "Please provide the correct path to the Singularity image as an argument:"
    echo "  ./generate_report_singularity.sh /path/to/markdown_images_28feb2025_latest.sif"
    exit 1
fi

echo "Using Singularity image: $SINGULARITY_IMAGE"

# Define base paths based on current pipeline structure
PIPELINE_DIR="/data/routine_diana/Diana"
REFERENCE_PATH="${PIPELINE_DIR}/data/reference"
OUTPUT_PATH="/data/routine_diana"

# Sample IDs file path (hardcoded location for routine processing)
samples_file="${OUTPUT_PATH}/sample_ids.txt"

# RMarkdown template file path
rmd_template="${PIPELINE_DIR}/bin/nextflow_markdown_pipeline_update_final.Rmd"

# Check if required files exist
if [ ! -f "$samples_file" ]; then
    echo "Error: Sample IDs file not found at: $samples_file"
    exit 1
fi

if [ ! -f "$rmd_template" ]; then
    echo "Error: R Markdown template not found at: $rmd_template"
    exit 1
fi

# Loop through each sample ID in the samples file
while read -r sample_id tumor_content; do
    echo "Processing sample: $sample_id"

    # Build dynamic input paths for this sample based on routine_analysis structure
    ANALYSIS_PATH="${OUTPUT_PATH}/routine_analysis/${sample_id}"

    craminoreport="${ANALYSIS_PATH}/cramino/${sample_id}_cramino_statistics.txt"
    sample_ids_file="${samples_file}"
    nanodx="${ANALYSIS_PATH}/classifier/nanodx/${sample_id}_nanodx_classifier.tsv"
    dictionaire="${REFERENCE_PATH}/nanoDx/static/Capper_et_al_dictionary.txt"
    logo="${REFERENCE_PATH}/log_update.pdf"
    cnv_plot="${ANALYSIS_PATH}/cnv/${sample_id}_cnv_plot_full.pdf"
    tumor_number="${ANALYSIS_PATH}/cnv/${sample_id}_tumor_copy_number.txt"
    annotatecnv="${ANALYSIS_PATH}/cnv/${sample_id}_annotatedcnv_filter_header.csv"
    cnv_chr9="${ANALYSIS_PATH}/cnv/${sample_id}_cnv_chr9.pdf"
    cnv_chr7="${ANALYSIS_PATH}/cnv/${sample_id}_cnv_chr7.pdf"
    mgmt_results="${ANALYSIS_PATH}/methylation/${sample_id}_MGMT_results.csv"
    merge_results="${ANALYSIS_PATH}/merge_annot_clair3andclairsto/${sample_id}_merge_annotation_filter_snvs_allcall.csv"
    fusion_events="${ANALYSIS_PATH}/structure_variant/svannasv/${sample_id}_filter_fusion_event.tsv"
    tertphtml="${ANALYSIS_PATH}/coverage/${sample_id}_tertp_id1.html"
    svannahtml="${ANALYSIS_PATH}/structure_variant/svannasv/${sample_id}_occ_svanna_annotation.html"
    egfr_coverage="${ANALYSIS_PATH}/coverage/${sample_id}_egfr_coverage.pdf"
    idh1_coverage="${ANALYSIS_PATH}/coverage/${sample_id}_idh1_coverage.pdf"
    idh2_coverage="${ANALYSIS_PATH}/coverage/${sample_id}_idh2_coverage.pdf"
    tertp_coverage="${ANALYSIS_PATH}/coverage/${sample_id}_tertp_coverage.pdf"
    tsneplot="${ANALYSIS_PATH}/classifier/nanodx/${sample_id}_tsne_plot.pdf"
    snv_target_genes="${REFERENCE_PATH}/snv_target_genes.txt"

    # Output PDF path - routine_results for final reports
    output_file="${OUTPUT_PATH}/routine_results/${sample_id}/${sample_id}_markdown_pipeline_report.pdf"

    # Create output directory if it doesn't exist
    mkdir -p "$(dirname "$output_file")"

    # Now call the Rscript using Singularity container
    singularity exec --bind /data:/data "$SINGULARITY_IMAGE" \
  	Rscript -e "rmarkdown::render('${rmd_template}', output_file=commandArgs(trailingOnly=TRUE)[23])" \
      "${sample_id}" \
      "${craminoreport}" \
      "${sample_ids_file}" \
      "${nanodx}" \
      "${dictionaire}" \
      "${logo}" \
      "${cnv_plot}" \
      "${tumor_number}" \
      "${annotatecnv}" \
      "${cnv_chr9}" \
      "${cnv_chr7}" \
      "${mgmt_results}" \
      "${merge_results}" \
      "${fusion_events}" \
      "${tertphtml}" \
      "${svannahtml}" \
      "${egfr_coverage}" \
      "${idh1_coverage}" \
      "${idh2_coverage}" \
      "${tertp_coverage}" \
      "${tsneplot}" \
      "${snv_target_genes}" \
      "${output_file}"
    
    # Clean up temporary R files
    rm -rf /tmp/Rtmp*

    # Clean up RMarkdown temporary files and folders in the output directory
    output_dir="$(dirname "$output_file")"
    output_basename="${sample_id}_markdown_pipeline_report"

    # Remove temporary files created by RMarkdown
    rm -rf "${output_dir}/${output_basename}_files"
    rm -f "${output_dir}/${output_basename}.tex"
    rm -f "${output_dir}/${output_basename}.log"
    rm -f "${output_dir}/${output_basename}.aux"

    echo "Finished sample: $sample_id (temporary files cleaned up)"

done < "${samples_file}"

echo "All samples processed successfully!"
