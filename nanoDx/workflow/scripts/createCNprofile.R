library(QDNAseq)
library(QDNAseq.hg19)
library(PSCBS)
library(matrixStats)

createCNprofile <- function(bam, bed, pdf.file, rplot.file, bin.size = 500, alpha = 0.001) {
  
  print(paste(bam,bed,pdf.file,bin.size))

  bins <- getBinAnnotations(binSize = as.numeric(bin.size))
  
  r <- binReadCounts(bins, bamfiles = bam, minMapq=20, isSecondaryAlignment=FALSE)
  
  r <- applyFilters(r, residual = F, blacklist = F, mappability = F, bases = 100, chromosomes = "Y")
  r <- estimateCorrection(r)
  
  r <- correctBins(r, method = "none")
  r <- normalizeBins(r, method = "mean")

  #r <- compareToReference(r, c(2, FALSE), force=T)

  # renormalize after substracting germline
  #r <- normalizeBins(r, method = "mean", force=T)

  x <- data.frame(r@featureData@data$chromosome, r@featureData@data$start, r@assayData$copynumber, r@featureData@data$use)
  xx <- subset(x, r.featureData.data.use==T)
  xx$r.featureData.data.use <- NULL
  colnames(xx) <- c("chromosome","x","y")
  xx$chromosome <- as.numeric(as.character(xx$chromosome))
  
  # transform counts (Anscombe transformation as in QDNAseq)
  # xx$y <- sqrt(xx$y * 3/8)
  
  gaps <- findLargeGaps(xx, minLength = 5e+06)
  knownSegments <- gapsToSegments(gaps)
  
  fit <- segmentByCBS(xx, knownSegments = knownSegments, alpha = as.numeric(alpha))
  
  # reverse transform
  # fit$output$mean <- (fit$output$mean^2) * 8/3
  
  r <- segmentBins(r, transformFun="sqrt", alpha = as.numeric(alpha), min.width=2, undo.splits="none")
  r <- callBins(r, method="cutoff")

  save(r, file = rplot.file)
  exportBins(r, file = snakemake@output[["bed1"]], type="segments", format="bed")

  #pdf(pdf.file)
  #plot(r)
  #plotTracks(fit, Clim = c(0,100))
  #plotTracks(fit, Clim = c(0,4))
  #dev.off()
  snakemake@source("CNplot.R")
  CNplot(r)
  ggsave(pdf.file, width=225, height=45, units = "mm")
  
  ### simplify segments
  segments=data.frame(chr = as.character(r@featureData@data$chromosome), start = r@featureData@data$start, end = r@featureData@data$end, seg.mean=r@assayData$segmented[,1], call=r@assayData$calls[,1])
    
  library(dplyr)
    
  shortSeg <- segments %>% arrange(chr,start) %>% 
      mutate(identical=as.integer(seg.mean != lag(seg.mean))) %>% 
      mutate(identical=ifelse(is.na(identical),1,identical)) %>% 
      mutate(segmentNo = cumsum(identical)) %>% 
      group_by(segmentNo) %>%
      summarise(chr=first(chr), start=min(start), end=max(end), seg.mean=log2(max(seg.mean)),call=first(call)) %>%
      select(-segmentNo)
    
  # write .seg file for IGV
  write.table(data.frame(sample=sub(".*(\\d{4}T).*","\\1",bam), shortSeg), file=bed, quote=F,row.names = F,sep="\t")
}

createCNprofile(bam=snakemake@input[["bam"]],  
                bed=snakemake@output[["bed"]], 
                pdf.file=snakemake@output[["pdf"]], 
                rplot.file=snakemake@output[["rplot"]],
                bin.size=snakemake@wildcards[["binsize"]],
                alpha=snakemake@wildcards[["alpha"]])
