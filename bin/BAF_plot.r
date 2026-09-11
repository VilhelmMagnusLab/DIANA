#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly=TRUE)

if (length(args) != 4) {
  stop("Four arguments must be supplied (germline txt, somatic txt, output pdf, sample id).\n", call. = FALSE)
}

germline_file = args[1]
somatic_file = args[2]
output_pdf = args[3]
sample_id = args[4]

germline <- read.csv(germline_file, header=TRUE, sep="\t", quote="")
somaticline <- read.csv(somatic_file, header=TRUE, sep="\t", quote="")

data <- data.frame(Position = seq_along(germline$baf), BAF = germline$baf)
som <- data.frame(Position = seq_along(somaticline$baf), VAF = somaticline$baf)

# plot()'s default xlim is derived from the data via min()/max(), which return
# non-finite Inf/-Inf on zero-row input (e.g. a sample with no qualifying SNVs)
# and crash plot.window(). Fall back to a fixed placeholder range in that case.
germline_xlim <- if (nrow(data) > 0) c(1, nrow(data)) else c(0, 1)
som_xlim <- if (nrow(som) > 0) c(1, nrow(som)) else c(0, 1)

pdf(file=output_pdf)
nf <- layout( matrix(c(1,2), ncol=1) )

# Plot the BAF values
plot(data$Position, data$BAF, pch=1, col=adjustcolor("black", alpha.f=0.3), cex=0.5, cex.lab=0.8, cex.axis=0.6, xlim=germline_xlim, ylim=c(0, 1), xlab="Variant order based on genomic position", ylab="B allele frequency (BAF)", main=paste0("BAF plot of ", sample_id, " assumed germline variants in the ROI genes"))
abline(h = c(0, 0.5, 1), col = "pink", lty = 2)

# Plot the BAF values
plot(som$Position, som$VAF, pch=21, col=adjustcolor("blue", alpha.f=0.5), cex=0.5, cex.lab=0.8, cex.axis=0.6, xlim=som_xlim, ylim=c(0, 1), xlab="Variant order based on genomic position", ylab="Variant allele fraction (VAF)", main=paste0("VAF plot of ", sample_id, " assumed somatic variants in the ROI genes"))
abline(h = c(0, 0.5, 1), col = "pink", lty = 2)
dev.off()
