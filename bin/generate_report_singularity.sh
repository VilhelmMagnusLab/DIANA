#!/bin/bash

#==============================================================================
# nWGS Pipeline Report Generator (Singularity Version)
#==============================================================================
#
# DESCRIPTION:
#   This script generates comprehensive PDF reports for nanopore whole genome 
#   sequencing (nWGS) analysis results using R Markdown within a Singularity 
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
#   - All analysis results from the nWGS pipeline
#   - R Markdown template file
#
# INPUT FILES:
#   - sample_ids.txt: Two-column file with sample ID and tumor content (decimal)
#   - Various analysis result files for each sample (see paths below)
#   - The PATH for each analysis result file must be provided in the script.
#
# OUTPUT:
#   - PDF reports for each sample in the results/report/ directory
#
# DEPENDENCIES:
#   - Singularity container: markdown_images_28feb2025_latest.sif
#   - Container must include: rmarkdown, data.table, kableExtra, and other R packages
#
# AUTHOR: nWGS Pipeline Development Team
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

# Define the file containing the sample IDs. The sample_ids.txt must be two columns, 
#the first column is the sample ID and the second column is the tumor content  in decimal format.
samples_file="/home/chbope/extension/nWGS_manuscript_data/data/testdata/sample_ids.txt"

# RMarkdown template file path
rmd_template="/home/chbope/Documents/nanopore/nWGS_manuscript/nWGS_pipeline_docker_test/bin/nextflow_markdown_pipeline_update_final.Rmd"

# Define base paths to avoid repetition
BASE_DATA_PATH="/home/chbope/extension/nWGS_manuscript_data/data"
RESULTS_PATH="${BASE_DATA_PATH}/results"
REFERENCE_PATH="${BASE_DATA_PATH}/reference"
TESTDATA_PATH="${BASE_DATA_PATH}/testdata"

samples_file="${TESTDATA_PATH}/sample_ids.txt"

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

    # Build dynamic input paths for this sample using base paths
    craminoreport="${RESULTS_PATH}/cramino/${sample_id}_cramino_statistics.txt"
    sample_ids_file="${TESTDATA_PATH}/sample_ids.txt"
    nanodx="${RESULTS_PATH}/classifier/nanodx/${sample_id}_nanodx_classifier.tsv"
    dictionaire="${REFERENCE_PATH}/nanoDx/static/Capper_et_al_dictionary.txt"
    logo="${BASE_DATA_PATH}/log_update.pdf"
    cnv_plot="${RESULTS_PATH}/cnv/${sample_id}_cnv_plot_full.pdf"
    tumor_number="${RESULTS_PATH}/cnv/${sample_id}_tumor_copy_number.txt"
    annotatecnv="${RESULTS_PATH}/cnv/${sample_id}_annotatedcnv_filter_header.csv"
    cnv_chr9="${RESULTS_PATH}/cnv/${sample_id}_cnv_chr9.pdf"
    cnv_chr7="${RESULTS_PATH}/cnv/${sample_id}_cnv_chr7.pdf"
    mgmt_results="${RESULTS_PATH}/methylation/${sample_id}_MGMT_results.csv"
    merge_results="${RESULTS_PATH}/merge_annot_clair3andclairsto/${sample_id}_merge_annotation_filter_snvs_allcall_filter.csv"
    fusion_events="${RESULTS_PATH}/structure_variant/svannasv/${sample_id}_filter_fusion_event.tsv"
    tertphtml="${RESULTS_PATH}/coverage/${sample_id}_tertp_id1.html"
    svannahtml="${RESULTS_PATH}/structure_variant/svannasv/${sample_id}_occ_svanna_annotation.html"
    egfr_coverage="${RESULTS_PATH}/coverage/${sample_id}_egfr_coverage.pdf"
    idh1_coverage="${RESULTS_PATH}/coverage/${sample_id}_idh1_coverage.pdf"
    idh2_coverage="${RESULTS_PATH}/coverage/${sample_id}_idh2_coverage.pdf"
    tertp_coverage="${RESULTS_PATH}/coverage/${sample_id}_tertp_coverage.pdf"
    tsneplot="${RESULTS_PATH}/classifier/nanodx/${sample_id}_tsne_plot.pdf"
    
    # Output PDF path
    output_file="${RESULTS_PATH}/report/${sample_id}_markdown_pipeline_report_final5.pdf"

    # Create output directory if it doesn't exist
    mkdir -p "$(dirname "$output_file")"

    # Now call the Rscript using Singularity container
    singularity exec "$SINGULARITY_IMAGE" Rscript -e "rmarkdown::render('${rmd_template}', output_file=commandArgs(trailingOnly=TRUE)[22])" \
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
      "${output_file}"
    
    # Clean up temporary R files
    rm -rf /tmp/Rtmp*

    echo "Finished sample: $sample_id"

done < "${samples_file}"

echo "All samples processed successfully!"
