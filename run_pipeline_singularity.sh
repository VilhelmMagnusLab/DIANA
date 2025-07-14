#!/bin/bash
set -e

# Usage: ./run_pipeline_singularity.sh <run_mode> <other_nextflow_args>
# Example: ./run_pipeline_singularity.sh analysis -profile singularity --input samplesheet.csv

# Handle help and version flags
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    nextflow run main.nf --help
    exit 0
fi

if [[ "$1" == "--version" || "$1" == "-v" ]]; then
    nextflow --version
    exit 0
fi

if [ $# -lt 1 ]; then
  echo "Usage: $0 <run_mode> [other nextflow args]"
  echo "Run modes: analysis, epi2me, ..."
  echo ""
  echo "Examples:"
  echo "  $0 analysis --input samplesheet.csv"
  echo "  $0 epi2me --input samplesheet.csv"
  echo "  $0 --help    # Show Nextflow help"
  echo "  $0 --version # Show Nextflow version"
  exit 1
fi

RUN_MODE="$1"
shift

CONFIG_FILE=""
case "$RUN_MODE" in
  analysis)
    CONFIG_FILE="conf/analysis.config"
    ;;
  epi2me)
    CONFIG_FILE="conf/epi2me.config"
    ;;
  *)
    echo "Unknown run mode: $RUN_MODE"
    exit 1
    ;;
esac

# Run Nextflow with Singularity/Apptainer profile and selected config
nextflow run main.nf -c "$CONFIG_FILE" -profile singularity "$@" 