library(ggplot2)
library(caTools)
library(dplyr)

CNplot <- function(r) {
  cn <- data.frame(chr = as.character(r@featureData@data$chromosome), start = r@featureData@data$start, end = r@featureData@data$end, counts = as.vector(r@assayData$copynumber), segmented = as.vector(r@assayData$segmented), use = r@featureData@data$use)
  
  cn$chr <- factor(cn$chr, levels = c(1:22,"X","Y"))
  
  cn <- subset(cn, use)
  
  transf <- function(x) log2(x + 1) - 1
  
  cn$counts <- transf(cn$counts)
  cn$segmented <- transf(cn$segmented)
  
  cn$movavg <- runmean(cn$counts, k=50)
  
  cn <- cn %>% 
    group_by(chr) %>% 
    arrange(start) %>%
    mutate(movavg = runmean(counts, k=50))
  
  ggplot(cn, aes(x = start, y = counts)) + 
    geom_point(colour = "grey", size = 1) + 
  #  ylim(-1,1) +
    facet_grid(~ chr, scales = "free_x", space = "free_x") + 
    geom_line(aes(y = movavg), colour="#e41a1c") +
  #  geom_line(aes(y = 0), color="yellow", size=0.5) +
    geom_line(aes(y = pmin(pmax(segmented,-1),1)), color="#377eb8", size=1) +
    theme_classic() +
    theme(axis.line=element_blank(),
          axis.title.x=element_blank(),
          axis.text.x=element_blank(),
          axis.ticks.x=element_blank(),
          panel.grid.minor.y=element_line(colour="black",size=0.5),
          panel.spacing.x=unit(0, "lines"),
          strip.text.x = element_text(size = 7),
          strip.background = element_blank(),
          panel.background = element_rect(colour = "grey", size=0.4)) +
    scale_y_continuous(minor_breaks = 0, limits = c(-1,1))
    
}
