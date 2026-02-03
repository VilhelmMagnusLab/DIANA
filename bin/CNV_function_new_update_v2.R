#!/usr/bin/env Rscript

# Parse command-line arguments
args <- commandArgs(trailingOnly = TRUE)
if(length(args) < 7){
  stop("Usage: CNV_function_new_update_v2.R <calls_file> <cnv_genes_tuned> <segs_file> <out_new_cnv_plot> <out_chr9_plot> <out_chr7_plot> <sample_id>")
}

calls_file       <- args[1]
cnv_genes_tuned  <- args[2]
segs_file        <- args[3]
out_new_cnv_plot <- args[4]
out_chr9_plot    <- args[5]
out_chr7_plot    <- args[6]
sample_id        <- args[7]

# Load required libraries
library(ggplot2)
library(caTools)
library(dplyr)
library(ggrepel)
library(tidyr)
library(ggpp)

# Helper function to save plots in both PDF and TIFF formats
save_plot_dual_format <- function(plot, base_filename, width, height) {
  # Save as PDF
  ggsave(filename = base_filename, plot = plot, width = width, height = height, device = "pdf")

  # Create TIFF filename by replacing .pdf with .tiff
  tiff_filename <- sub("\\.pdf$", ".tiff", base_filename)

  # Save as TIFF with high resolution (300 DPI)
  ggsave(filename = tiff_filename, plot = plot, width = width, height = height,
         device = "tiff", dpi = 300, compression = "lzw")

  cat(sprintf("Saved plots: %s and %s\n", base_filename, tiff_filename))
}

plot_CNV_data <- function(calls_file, cnv_genes_tuned, segs_file, out_new_cnv_plot, out_chr9_plot, out_chr7_plot, sample_id) {

  # Read segmentation data
  Segs <- read.delim(segs_file, skip = 1, header = FALSE)
  names(Segs) <- c("Chr", "Start", "End", "Bin", "Seg", "Strand")

  # Read Calls data
  Calls <- read.delim(calls_file, skip = 1, header = FALSE)
  names(Calls) <- c("Chr", "Start", "End", "Bin", "Log2ratio", "Strand")

  # Merge calls and segs
  Calls <- left_join(Calls, Segs)

  # Load custom gene annotation file (replaces the old annot_file)
  CNV_annotations <- read.delim(cnv_genes_tuned, header = TRUE, sep = ",")

  # Merge Calls and CNV annotations
  Calls <- left_join(Calls, CNV_annotations)
  Calls$Chr <- factor(Calls$Chr, levels = c(1:22, "X", "Y"))

  # Set plot limits and flag bins outside of limits
  lim <- 2
  offset <- 0.1
  Calls$Log2ratio_Capped <- ifelse(abs(Calls$Log2ratio) > lim, sign(Calls$Log2ratio)*lim + sign(Calls$Log2ratio)*offset, Calls$Log2ratio)
  Calls$Segs_Capped <- ifelse(abs(Calls$Seg) > lim, sign(Calls$Seg)*lim + sign(Calls$Seg)*offset, Calls$Seg)
  Calls$flag <- abs(Calls$Log2ratio) > lim
  Calls$flagSegs <- abs(Calls$Seg) > lim

  # Add named column to identify genes with labels
  Calls <- Calls %>%
    mutate(named = !is.na(Gene) & nzchar(Gene))

  # Plot CNV data for all chromosomes
  p <- ggplot(Calls, aes(x = Start, y = Log2ratio_Capped, label = Gene)) +
    # Non-flag, NOT named -> gradient
    geom_point(
      data = subset(Calls, !flag & !named),
      aes(x = Start, y = Log2ratio, color = Log2ratio_Capped),
      size = 1, alpha = 0.7
    ) +
    # Non-flag, named -> black
    geom_point(
      data = subset(Calls, !flag & named),
      aes(x = Start, y = Log2ratio_Capped),
      colour = "black", size = 1, alpha = 0.9
    ) +
    # Flag, NOT named -> red triangles
    geom_point(
      data = subset(Calls, flag & !named),
      aes(x = Start, y = Log2ratio_Capped),
      colour = "red", shape = 17, size = 1
    ) +
    # Flag, named -> black triangles
    geom_point(
      data = subset(Calls, flag & named),
      aes(x = Start, y = Log2ratio_Capped),
      colour = "black", shape = 17, size = 1
    ) +
    facet_grid(~ Chr, scales = "free_x", space = "free_x") +
    geom_line(data = subset(Calls, !flagSegs), aes(x = Start, y = Seg), colour = "#e41a1c") +
    ylab("Log2ratio") +
    theme_classic() +
    theme(axis.line = element_blank(),
          axis.title.x = element_blank(),
          axis.text.x = element_blank(),
          axis.ticks.x = element_blank(),
          panel.grid.minor.y = element_line(colour = "black", size = 0.5),
          panel.spacing.x = unit(0, "lines"),
          strip.text.x = element_text(size = 12),
          strip.background = element_blank(),
          panel.background = element_rect(colour = "grey", size = 0.4)) +
    scale_y_continuous(minor_breaks = 0, limits = c(-2, 2.5)) +
    scale_color_gradient2(
      name = "Log2ratio",
      low = "blue",
      mid = "lightgrey",
      high = "red",
      midpoint = 0,
      guide = "none"
    )

  p2 <- p +
    geom_text_repel(
      size = 4,
      color = "black",
      max.overlaps = Inf,
      angle = 270
    ) +
    ggtitle(sample_id)

  # Save full CNV plot in both PDF and TIFF formats
  save_plot_dual_format(p2, out_new_cnv_plot, 18, 5)

  ################## Chrom 9 Plot

  chrom9 <- Calls %>% filter(Chr == 9)

  p9 <- ggplot(chrom9, aes(x = Start, y = Log2ratio_Capped, label = Gene)) +
    # Non-flag, NOT named -> gradient
    geom_point(
      data = subset(chrom9, !flag & !named),
      aes(x = Start, y = Log2ratio, color = Log2ratio_Capped),
      size = 1, alpha = 0.7
    ) +
    # Non-flag, named -> black
    geom_point(
      data = subset(chrom9, !flag & named),
      aes(x = Start, y = Log2ratio),
      colour = "black", size = 1, alpha = 0.9
    ) +
    # Flag, NOT named -> red triangles
    geom_point(
      data = subset(chrom9, flag & !named),
      aes(x = Start, y = Log2ratio_Capped),
      colour = "red", shape = 17, size = 1
    ) +
    # Flag, named -> black triangles
    geom_point(
      data = subset(chrom9, flag & named),
      aes(x = Start, y = Log2ratio_Capped),
      colour = "black", shape = 17, size = 1
    ) +
    facet_grid(~ Chr, scales = "free_x", space = "free_x") +
    geom_line(data = subset(chrom9, !flagSegs), aes(x = Start, y = Seg), colour = "#e41a1c") +
    ylab("Log2ratio") +
    theme_classic() +
    theme(axis.line = element_blank(),
          axis.title.x = element_blank(),
          axis.text.x = element_blank(),
          axis.ticks.x = element_blank(),
          panel.grid.minor.y = element_line(colour = "black", size = 0.5),
          panel.spacing.x = unit(0, "lines"),
          strip.text.x = element_text(size = 12),
          strip.background = element_blank(),
          panel.background = element_rect(colour = "grey", size = 0.4)) +
    scale_y_continuous(minor_breaks = 0) +
    scale_color_gradient2(
      name = "Log2ratio",
      low = "blue",
      mid = "lightgrey",
      high = "red",
      midpoint = 0,
      guide = "none"
    )

  p92 <- p9 +
    geom_text_repel(
      size = 4,
      color = "black",
      max.overlaps = Inf,
      angle = 270
    ) +
    ggtitle(paste0(sample_id, " chromosome 9"))

  # Save chromosome 9 plot in both PDF and TIFF formats
  save_plot_dual_format(p92, out_chr9_plot, 18, 5)

  ####################### Chrom 7 Plot

  chrom7 <- Calls %>% filter(Chr == 7)

  p7 <- ggplot(chrom7, aes(x = Start, y = Log2ratio, label = Gene)) +
    # Non-flag, NOT named -> gradient
    geom_point(
      data = subset(chrom7, !flag & !named),
      aes(color = Log2ratio_Capped),
      size = 1, alpha = 0.7
    ) +
    # Non-flag, named -> black
    geom_point(
      data = subset(chrom7, !flag & named),
      aes(x = Start, y = Log2ratio),
      colour = "black", size = 1, alpha = 0.9
    ) +
    # Flag, NOT named -> red triangles
    geom_point(
      data = subset(chrom7, flag & !named),
      aes(x = Start, y = Log2ratio),
      colour = "red", size = 1, alpha = 0.7
    ) +
    # Flag, named -> black triangles
    geom_point(
      data = subset(chrom7, flag & named),
      aes(x = Start, y = Log2ratio),
      colour = "black", size = 1, alpha = 0.9
    ) +
    facet_grid(~ Chr, scales = "free_x", space = "free_x") +
    geom_line(data = subset(chrom7, !flagSegs), aes(x = Start, y = Seg), colour = "#e41a1c") +
    ylab("Log2ratio") +
    theme_classic() +
    theme(axis.line = element_blank(),
          axis.title.x = element_blank(),
          axis.text.x = element_blank(),
          axis.ticks.x = element_blank(),
          panel.grid.minor.y = element_line(colour = "black", size = 0.5),
          panel.spacing.x = unit(0, "lines"),
          strip.text.x = element_text(size = 12),
          strip.background = element_blank(),
          panel.background = element_rect(colour = "grey", size = 0.4)) +
    scale_y_continuous(minor_breaks = 0, limits = c(-1, NA)) +
    scale_color_gradient2(
      name = "Log2ratio",
      low = "blue",
      mid = "lightgrey",
      high = "red",
      midpoint = 0,
      guide = "none"
    )

  p72 <- p7 +
    geom_text_repel(
      size = 4,
      color = "black",
      max.overlaps = Inf,
      angle = 270
    ) +
    ggtitle(paste0(sample_id, " chromosome 7"))

  # Save chromosome 7 plot in both PDF and TIFF formats
  save_plot_dual_format(p72, out_chr7_plot, 18, 5)
}

# Call the function with the parsed arguments
plot_CNV_data(calls_file, cnv_genes_tuned, segs_file, out_new_cnv_plot, out_chr9_plot, out_chr7_plot, sample_id)
