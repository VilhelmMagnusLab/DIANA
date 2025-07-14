circosPlot <- function(bedpe, pdfFile, sample) {

  library(circlize)
  library(data.table)
  
  ### read Sniffles BEDPE
  
  bedpe <- fread(bedpe, check.names = T)
  
  ### filter contigs
  
  chrNames <- paste("chr",c(1:22,"X","Y"),sep="")
  bedpe <- subset(bedpe, X.Chrom %in% chrNames & chrom2 %in% chrNames & start2 >= 0)
  
  ### plot
  
  pdf(pdfFile)
  
  circos.par(start.degree = 90, gap.degree = 2)
  circos.initializeWithIdeogram()
  
  circos.genomicLink(bedpe[,1:3], bedpe[,4:6], col = ifelse(bedpe$type=="TRA","red","grey"), border = NA)
  
  text(0, 0, sample)
  
  dev.off()
  
  circos.clear()
}

circosPlot(snakemake@input[[1]],snakemake@output[[1]],snakemake@wildcards[["sample"]])

