#!/usr/bin/env Rscript

# Try to load required packages, install if not available
if (!require(argparser, quietly = TRUE)) {
  cat("Installing argparser package...\n")
  install.packages("argparser", repos = "https://cran.r-project.org")
}

if (!require(QDNAseq, quietly = TRUE)) {
  cat("Installing QDNAseq package...\n")
  if (!requireNamespace("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager", repos = "https://cran.r-project.org")
  }
  BiocManager::install("QDNAseq")
}

suppressPackageStartupMessages({
library(argparser)
  library(QDNAseq)
  library(BiocManager)
})

# ---- Parse args ----
p <- arg_parser("Run QDNAseq CNV analysis")

p <- add_argument(p, "--bam", help="Input BAM file (hg38/hg19 aligned)")
p <- add_argument(p, "--out_prefix", help="Prefix for output files")
p <- add_argument(p, "--genome", help="Genome build: hg38 or hg19", default="hg38")
p <- add_argument(p, "--method", help="Method: cutoff or CGHcall", default="cutoff")
p <- add_argument(p, "--cutoff", help="CN cutoff modifier, 0.0-1.0 or none", default="0.5")
p <- add_argument(p, "--cutoffDEL", help="Cutoff for deletion", default=0.5)
p <- add_argument(p, "--cutoffLOSS", help="Cutoff for loss", default=1.5)
p <- add_argument(p, "--cutoffGAIN", help="Cutoff for gain", default=2.5)
p <- add_argument(p, "--cellularity", help="CGHcall cellularity", default=1.0)
p <- add_argument(p, "--binsize", help="Bin size in Kbp", default=500)

argv <- parse_args(p)

# ---- Manual required check ----
if (is.null(argv$bam) || is.null(argv$out_prefix)) {
  stop("ERROR: --bam and --out_prefix are required.", call.=FALSE)
}

# ---- Cutoff ----
if (argv$cutoff %in% c("none", "None", "NONE")) {
  argv$cutoff <- "none"
} else {
  argv$cutoff <- as.numeric(argv$cutoff)
}

# ---- Load bins ----
if (argv$genome == "hg38") {
  if (!require(QDNAseq.hg38, quietly = TRUE)) {
    cat("Installing QDNAseq.hg38 package...\n")
    BiocManager::install("QDNAseq.hg38")
  }
  library(QDNAseq.hg38)
  bins <- getBinAnnotations(binSize=argv$binsize, genome="hg38")
} else if (argv$genome == "hg19") {
  if (!require(QDNAseq.hg19, quietly = TRUE)) {
    cat("Installing QDNAseq.hg19 package...\n")
    BiocManager::install("QDNAseq.hg19")
  }
  library(QDNAseq.hg19)
  bins <- getBinAnnotations(binSize=argv$binsize, genome="hg19")
} else {
  stop("ERROR: --genome must be hg38 or hg19")
}

# ---- QDNAseq workflow ----

options(future.globals.maxSize = 1048576000)

pdf_file <- paste0(argv$out_prefix, "_plots.pdf")
pdf(pdf_file)

readCounts <- binReadCounts(bins, bamfiles=argv$bam)
plot(readCounts, logTransform=FALSE, ylim=c(-50, 200))
highlightFilters(readCounts, logTransform=FALSE, residual=TRUE, blacklist=TRUE)

autosomalReadCountsFiltered <- applyFilters(readCounts, residual=TRUE, blacklist=TRUE)
isobarPlot(autosomalReadCountsFiltered)
autosomalReadCountsFiltered <- estimateCorrection(autosomalReadCountsFiltered)
noisePlot(autosomalReadCountsFiltered)

readCountsFiltered <- applyFilters(autosomalReadCountsFiltered, chromosomes=NA)
copyNumbers <- correctBins(readCountsFiltered)
copyNumbersNormalized <- normalizeBins(copyNumbers)
copyNumbersSmooth <- smoothOutlierBins(copyNumbersNormalized)
plot(copyNumbersSmooth)

copyNumbersSegmented <- segmentBins(copyNumbersSmooth, transformFun="sqrt")
copyNumbersSegmented <- normalizeSegmentedBins(copyNumbersSegmented)
plot(copyNumbersSegmented)

if (argv$method == "cutoff") {
  if (argv$cutoff == "none") {
    copyNumbersCalled <- callBins(copyNumbersSegmented, method="cutoff")
    } else {
    cutoffDEL  <- argv$cutoffDEL + 0.5 - argv$cutoff
        cutoffLOSS <- argv$cutoffLOSS + 0.5 - argv$cutoff
        cutoffGAIN <- argv$cutoffGAIN + argv$cutoff - 0.5
    copyNumbersCalled <- callBins(copyNumbersSegmented, method="cutoff",
      cutoffs=log2(c(deletion=cutoffDEL, loss=cutoffLOSS, gain=cutoffGAIN, amplification=10)/2))
    }
} else if (argv$method == "CGHcall") {
  copyNumbersCalled <- callBins(copyNumbersSegmented, method="CGHcall", cellularity=argv$cellularity)
} else {
  stop("Invalid --method: must be cutoff or CGHcall")
}

plot(copyNumbersCalled)

exportBins(copyNumbersSmooth, file=paste0(argv$out_prefix, "_bins.bed"), format="bed")
exportBins(copyNumbersCalled, file=paste0(argv$out_prefix, "_calls.bed"), format="bed", type="calls")
exportBins(copyNumbersCalled, file=paste0(argv$out_prefix, "_calls.vcf"), format="vcf", type="calls")
exportBins(copyNumbersCalled, file=paste0(argv$out_prefix, "_segs.bed"), format="bed", type="segments")
exportBins(copyNumbersCalled, file=paste0(argv$out_prefix, "_segs.vcf"), format="vcf", type="segments")

saveRDS(copyNumbersCalled, file=paste0(argv$out_prefix, "_copyNumbersCalled.rds"))

png(paste0(argv$out_prefix, "_noise_plot.png"))
noisePlot(autosomalReadCountsFiltered)
dev.off()

png(paste0(argv$out_prefix, "_isobar_plot.png"))
isobarPlot(autosomalReadCountsFiltered)
dev.off()

dev.off()

cat("QDNAseq analysis completed!\n")

