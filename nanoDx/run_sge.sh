#!/bin/sh

mkdir -p logs
snakemake --jobs 500 --local-cores 24 --resources pdfReport=1 --use-conda --cluster-config cluster_sge.json --drmaa " -V -cwd -pe smp {threads} -l h_vmem={cluster.mem} -l h_rt={cluster.time} -j y -o logs/" $*
