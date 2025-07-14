#!/bin/sh

snakemake --jobs 500 \
          --use-conda \
          --default-resources "mem_mb=8192" "runtime=240" \
          --resources pdfReport=1 \
          --slurm \
          $*
