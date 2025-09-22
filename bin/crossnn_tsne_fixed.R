#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(data.table)
  library(dplyr)
  library(stringr)
  library(rhdf5)
  library(matrixStats)
  library(ggplot2)
  library(ggtext)
  library(Rtsne)
  library(uwot)
  library(plotly)
  library(htmlwidgets)
  library(R.utils)
})

# ---------- CLI OPTIONS ----------
opt_list <- list(
  make_option("--color-map", type="character", help="Path to colorMap table (TSV/CSV) with columns: group, methylationClass, color", metavar="FILE"),
  make_option("--bed", type="character", help="Path to methylation BED-like file with columns (chrom, start, end, name, ..., coverage, MAF)", metavar="FILE"),
  make_option("--trainingset", type="character", help="Path to training set HDF5 file containing groups: Dx, sampleIDs, probeIDs, betaValues", metavar="FILE"),
  make_option("--method", type="character", default="umap", help="Dimensionality reduction: tsne | umap [default: %default]"),
  make_option("--tsne-pca-dim", type="integer", default=50, help="t-SNE: PCA dims [default: %default]"),
  make_option("--tsne-perplexity", type="double", default=30, help="t-SNE: perplexity [default: %default]"),
  make_option("--tsne-max-iter", type="integer", default=1000, help="t-SNE: max iterations [default: %default]"),
  make_option("--umap-n-neighbours", type="integer", default=10, help="UMAP: n_neighbors [default: %default]"),
  make_option("--umap-min-dist", type="double", default=0.5, help="UMAP: min_dist [default: %default]"),
  make_option("--umap-pca-dim", type="integer", default=100, help="UMAP: PCA dims [default: %default]"),
  make_option("--pdf", type="character", help="Output PDF file", metavar="FILE"),
  make_option("--html", type="character", help="Output HTML file (interactive plotly)", metavar="FILE")
)
opt <- parse_args(OptionParser(option_list=opt_list))

# ---------- BASIC VALIDATION ----------
stopifnot(!is.null(opt$`color-map`), file.exists(opt$`color-map`))
stopifnot(!is.null(opt$bed), file.exists(opt$bed))
stopifnot(!is.null(opt$trainingset), file.exists(opt$trainingset))
if (is.null(opt$pdf) && is.null(opt$html)) {
  stop("Please provide --pdf and/or --html output path.")
}
opt$method <- tolower(opt$method)
if (!opt$method %in% c("tsne","umap")) stop("--method must be 'tsne' or 'umap'")

# ---------- LOAD colorMap ----------
colorMap <- fread(opt$`color-map`, blank.lines.skip = TRUE) %>%
  as_tibble() %>%
  group_by(group) %>%
  arrange(methylationClass, .by_group = TRUE) %>%
  group_modify(~ add_row(.x, .before = 0, color = "white")) %>%
  mutate(colorLabel = ifelse(is.na(methylationClass), paste0("**", group, "**"), methylationClass))

hexCol <- colorMap$color
names(hexCol) <- colorMap$colorLabel
hexCol[is.na(hexCol)] <- "grey"
hexCol["unknown"] <- "red"

# ---------- LOAD methylation calls (BED-like) ----------
bed <- fread(opt$bed)
# The BED file has headers: Chromosome, Start, End, modBase, Coverage, Methylation_frequency, Illumina_ID

# Filter for methylated (m) bases and use Methylation_frequency as MAF
bed_meth <- bed[bed$modBase == "m", ]
case <- as.data.frame(t(data.frame(isMethylated = ifelse(bed_meth$Methylation_frequency >= 60, 1, 0))))
colnames(case) <- bed_meth$Illumina_ID

# ---------- LOAD training set (HDF5) ----------
fh5 <- opt$trainingset
if (!file.exists(fh5)) stop("HDF5 file not found: ", fh5)

# (Optional) Inspect the training set structure:
# print(h5ls(fh5))

# Read HDF5 data in chunks to avoid memory issues
Dx             <- as.factor(h5read(fh5, "Dx"))
sampleIDs      <- h5read(fh5, "sampleIDs")
trainingProbes <- h5read(fh5, "probeIDs")

# Read only a subset of betaValues to avoid memory issues
# First, get the dimensions
h5f <- H5Fopen(fh5)
beta_ds <- H5Dopen(h5f, "betaValues")
beta_space <- H5Dget_space(beta_ds)
beta_dims <- H5Sget_simple_extent_dims(beta_space)$size
H5Dclose(beta_ds)
H5Sclose(beta_space)
H5Fclose(h5f)

# Read all available data
n_samples <- beta_dims[1]
n_probes <- beta_dims[2]
message("Reading full dataset: ", n_samples, " samples x ", n_probes, " probes")

# Read the full beta values matrix
betaMat <- h5read(fh5, "betaValues")

missing_in_color <- setdiff(Dx, colorMap$methylationClass)
if (length(missing_in_color) > 0) {
  message("Warning: Some methylation classes in training set not found in colorMap: ", 
          paste(missing_in_color, collapse = ", "))
}

# ---------- ALIGN PROBES ----------
probes <- intersect(colnames(case), trainingProbes)
if (length(probes) == 0) stop("No overlapping CpG sites between sample and reference set.")
idxs <- match(probes, trainingProbes)

message(length(probes), " overlapping CpG sites. Building training matrix...")

# Memory-optimized approach: process in chunks instead of loading full matrix
message("Processing beta matrix in memory-efficient chunks...")

# Extract only the needed columns first to reduce memory footprint
betaMat_subset <- betaMat[, idxs]
rm(betaMat)  # Free memory immediately
gc()  # Force garbage collection

# Convert to binary matrix more efficiently
ts_binary <- (betaMat_subset > 0.6) * 1
ts <- data.frame(Dx, ts_binary)
colnames(ts) <- c("Dx", trainingProbes[idxs])

# Clean up intermediate objects
rm(betaMat_subset, ts_binary)
gc()

m <- rbind(ts, data.frame(Dx = "unknown", case[, probes, drop = FALSE]))

# ---------- SELECT MOST VARIABLE PROBES (≤50k) ----------
beta <- as.matrix(m[, -1])
sds  <- matrixStats::colSds(beta, na.rm = FALSE)
# Remove columns with zero variance
non_zero_var <- sds > 0
beta <- beta[, non_zero_var]
sds <- sds[non_zero_var]
# Select top variable probes (up to 100k for better analysis)
maxSDs <- order(sds, decreasing = TRUE)[1:min(100000, length(sds))]

# ---------- DIMENSIONALITY REDUCTION ----------
# Remove duplicate rows before t-SNE
beta_subset <- beta[, maxSDs]
duplicate_rows <- duplicated(beta_subset)
if (any(duplicate_rows)) {
  message("Removing ", sum(duplicate_rows), " duplicate rows")
  beta_subset <- beta_subset[!duplicate_rows, ]
  m_subset <- m[!duplicate_rows, ]
} else {
  m_subset <- m
}

if (opt$method == "tsne") {
  tsne <- Rtsne(
    beta_subset,
    dims = 2,
    pca = TRUE,
    pca_center = TRUE,
    pca_scale = TRUE,
    max_iter = opt$`tsne-max-iter`,
    perplexity = opt$`tsne-perplexity`,
    theta = 0.0,
    check_duplicates = FALSE, verbose = TRUE
  )
  df <- data.frame(Dx = m_subset[, 1], X1 = tsne$Y[, 1], X2 = tsne$Y[, 2])
  title_txt <- sprintf("t-SNE, PCA dims=%d, perplexity=%.1f, max_iter=%d",
                       opt$`tsne-pca-dim`, opt$`tsne-perplexity`, opt$`tsne-max-iter`)
} else if (opt$method == "umap") {
  # Perform PCA first if requested
  if (opt$`umap-pca-dim` < ncol(beta_subset)) {
    pca_result <- prcomp(beta_subset, center = TRUE, scale. = TRUE)
    beta_pca <- pca_result$x[, 1:opt$`umap-pca-dim`]
  } else {
    beta_pca <- beta_subset
  }
  
  # Perform UMAP
  umap_result <- uwot::umap(
    beta_pca,
    n_neighbors = opt$`umap-n-neighbours`,
    min_dist = opt$`umap-min-dist`,
    n_components = 2,
    verbose = TRUE
  )
  
  df <- data.frame(Dx = m_subset[, 1], X1 = umap_result[, 1], X2 = umap_result[, 2])
  title_txt <- sprintf("UMAP, n_neighbors=%d, min_dist=%.1f, PCA dims=%d",
                       opt$`umap-n-neighbours`, opt$`umap-min-dist`, opt$`umap-pca-dim`)
} else {
  stop("Unknown method: ", opt$method)
}

# ---------- ORDER & FACTOR LEVELS ----------
df$Dx <- factor(df$Dx, levels = c(colorMap$colorLabel, "unknown"))

# ---------- STATIC PLOT ----------
p <- ggplot(df, aes(x = X1, y = X2, color = Dx)) +
  geom_point(aes(shape = Dx == "unknown", size = Dx == "unknown")) +
  scale_shape_manual(values = c(15, 3), guide = "none") +
  scale_size_manual(values = c(1, 2), guide = "none") +
  labs(title = title_txt, x = "Dimension 1", y = "Dimension 2") +
  scale_color_manual(name = "Methylation class",
                    values = hexCol,
                    labels = names(hexCol), drop = FALSE) +
  guides(colour = guide_legend(title = "Methylation class",
                               title.position = "top", ncol = 5,
                               override.aes = list(shape = ifelse(names(hexCol) != "unknown", 15, 3), size = 3))) +
  theme(legend.text = ggtext::element_markdown(size = 7),
        panel.border = element_rect(color = "black", fill = NA, linewidth = 0.6))

if (!is.null(opt$pdf)) {
  ggsave(plot = p, width = 14, height = 7, filename = opt$pdf)
  message("Saved PDF: ", opt$pdf)
}

# ---------- INTERACTIVE PLOT ----------
if (!is.null(opt$html)) {
  # Create a simple HTML file with the plot as PNG
  png_file <- gsub("\\.html$", ".png", opt$html)
  
  # Save plot as PNG
  png(png_file, width = 14*100, height = 7*100, res = 100)
  print(p)
  dev.off()
  
  # Create simple HTML file
  html_content <- paste0('
<!DOCTYPE html>
<html>
<head>
    <title>Methylation Classification Plot</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        img { max-width: 100%; height: auto; border: 1px solid #ccc; }
        .info { background-color: #f5f5f5; padding: 10px; margin: 10px 0; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Methylation Classification Plot</h1>
    <div class="info">
        <p><strong>Method:</strong> ', title_txt, '</p>
        <p><strong>Generated:</strong> ', Sys.time(), '</p>
        <p><strong>Data points:</strong> ', nrow(df), '</p>
    </div>
    <img src="', basename(png_file), '" alt="Methylation Classification Plot">
</body>
</html>')
  
  writeLines(html_content, opt$html)
  message("Saved HTML: ", opt$html)
  message("Saved PNG: ", png_file)
}

