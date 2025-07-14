library(Rsamtools)

# get reference genome GC distribution
ref <- scanFa(snakemake@input[["ref_chopped"]])
gc <- letterFrequency(ref, letters="CG") / width(ref)
ref <- data.frame(quality="hg19", GC_content = as.numeric(gc), readlength = 1000, mapq = 0)

readBAM <- function(f) {
  bam <- BamFile(f, yieldSize = 10000)
  open(bam)
  reads <- NULL
  
  repeat {
    x <- scanBam(bam, what=bamWhat("mapq","seq"))
    if (length(x[[1]]$mapq) == 0) break

    #GC content        
    gc <- letterFrequency(x[[1]]$seq, letters="CG") / width(x[[1]]$seq)
    
    reads <- rbind(reads, data.frame(GC_content = as.numeric(gc), readlength = width(x[[1]]$seq),mapq = x[[1]]$mapq))
  }
 
  close(bam)
  return(reads)
}

sample <- readBAM(snakemake@input[["BAM"]])

all <- rbind(data.frame(quality="sample",sample),
             ref
             )

library(ggplot2)
library(scales)

### save read length distribution for statistics in report
length_distribution <- sample$readlength
save(length_distribution, file = snakemake@output[["length_dist"]])

### plot GC content histogram

pGC <- ggplot(all, aes(x=GC_content,group=quality,colour=quality)) + 
  geom_freqpoly(aes(y=..ncount..)) +
  theme_classic() + 
  scale_x_continuous(labels = percent) + 
  scale_colour_brewer(type = "qual", palette = "Set1") + 
  theme(aspect.ratio=1) + 
  xlab("GC content") +
  ylab("no. of mapped reads")

ggsave(plot = pGC, filename = snakemake@output[["GC_plot"]], width=4, height=3)


### plot read length distribution

pRL <- ggplot(sample, aes(x=readlength)) + 
  geom_freqpoly(aes(y=..ncount..)) +
  theme_classic() + 
  scale_x_log10() +
  theme(aspect.ratio=1) + 
  xlab("read length (bp)") +
  ylab("no. of mapped reads")

ggsave(plot = pRL, filename = snakemake@output[["readlength_plot"]], width=3, height=3)

