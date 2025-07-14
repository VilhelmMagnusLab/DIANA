#!/bin/sh

snakemake --cores all --resources pdfReport=1 --resources gpu=1 --use-conda $*
