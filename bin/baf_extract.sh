#!/bin/bash

#=========================================================================================================
# baf_extract.sh - make a beta allele fraction (BAF) plot from a ClairS-TO snv.vcf.gz
#=========================================================================================================
#
# Usage: bash baf_extract.sh <snv_vcf.gz> <output_dir> <sample_id>
#   snv_vcf.gz - path to a ClairS-TO snv.vcf.gz file
#   output_dir - directory to write outputs into (created if missing)
#   sample_id  - sample ID, used to name outputs and label the plot
#
# Outputs (all written into output_dir):
#   <sample_id>_germline.txt - BAF table for assumed germline (NonSomatic) SNVs
#   <sample_id>_somatic.txt  - VAF table for assumed somatic (PASS) SNVs
#   <sample_id>_baf.pdf      - the BAF/VAF plot
#

set -e

if [ $# -ne 3 ]; then
    echo "Usage: bash baf_extract.sh <snv_vcf.gz> <output_dir> <sample_id>" >&2
    exit 1
fi

snv_vcf=$1
output_dir=$2
id=$3

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$snv_vcf" ]; then
    echo "Error: VCF file not found: $snv_vcf" >&2
    exit 1
fi

mkdir -p "$output_dir"

germline_file="$output_dir/${id}_germline.txt"
somatic_file="$output_dir/${id}_somatic.txt"
output_pdf="$output_dir/${id}_baf.pdf"

echo -e "chr\tstart\tend\tbaf" > "$germline_file"
zgrep -v '#' "$snv_vcf" | grep -P '\tNonSomatic\t' | cut -s -f1,2,4,5,10 | \
	awk -F "\t" 'OFS="\t" { split($5,tag,":"); chr=$1; pos=$2; ref=$3; alt=$4;
		if (length(ref)==length(alt)) {
			af=tag[4];
			ad=tag[5];
			split(ad,dp,",");
			ref_dp=dp[1];
			alt_dp=dp[2];
			if ( (ref_dp+alt_dp) > 15 ) {
				af1=alt_dp/(ref_dp+alt_dp);
				print chr,pos,pos,af1;
			}
		}
	}' >> "$germline_file"

echo -e "chr\tstart\tend\tbaf" > "$somatic_file"
zgrep -v '#' "$snv_vcf" | grep -P '\tPASS\t' | cut -s -f1,2,4,5,10 | \
	awk -F "\t" 'OFS="\t" { split($5,tag,":"); chr=$1; pos=$2; ref=$3; alt=$4;
		if (length(ref)==length(alt)) {
			af=tag[4];
			ad=tag[5];
			split(ad,dp,",");
			ref_dp=dp[1];
			alt_dp=dp[2];
			if ( (ref_dp+alt_dp) > 15 ) {
				af1=alt_dp/(ref_dp+alt_dp);
				print chr,pos,pos,af1;
			}
		}
	}' >> "$somatic_file"

Rscript "${SCRIPT_DIR}/BAF_plot.r" "$germline_file" "$somatic_file" "$output_pdf" "$id"
