#!/usr/bin/env Rscript
# Generate heatmap PNGs from pre-computed similarity metrics JSON files.
# Usage:
#   Rscript make_heatmaps.R similarity_metrics_engineering_top10.json
#   Rscript make_heatmaps.R   # processes all similarity_metrics_*.json files

library(jsonlite)
library(pheatmap)
library(stringr)

# ── Configuration ──────────────────────────────────────────────
fontsize_base   <- 17   # base font size (title, legend)
fontsize_number <- 17   # numbers inside cells
fontsize_axis   <- 14   # row/column labels
img_width       <- 7    # PNG width in inches (displayed at ~3.25in = 0.5\columnwidth)
img_height      <- 7    # PNG height in inches
img_res         <- 300  # PNG resolution (DPI)
# ───────────────────────────────────────────────────────────────

# Color palettes per metric
palettes <- list(
  jaccard    = colorRampPalette(c("white", "#feedde", "#fd8d3c"))(100),
  tfidf      = colorRampPalette(c("white", "#deebf7", "#08306b"))(100),
  overlap    = colorRampPalette(c("white", "#e5f5e0", "#31a354"))(100),
  pmi        = colorRampPalette(c("white", "#fff7bc", "#d95f0e"))(100),
  max_scaled = colorRampPalette(c("white", "#f7fcf0", "#4eb3d3"))(100),
  dice       = colorRampPalette(c("white", "#f2f0f7", "#6a51a3"))(100),
  kulczynski = colorRampPalette(c("white", "#fff5f0", "#cb181d"))(100)
)

# Display names for each metric
metric_titles <- list(
  jaccard    = "Jaccard\n(Curricular Width)",
  tfidf      = "TF-IDF\n(Specialized Identity)",
  overlap    = "Overlap\n(Subset Relations)",
  pmi        = "PMI\n(Signature Bonds)",
  max_scaled = "Max-Scaled\n(Core Structure)",
  dice       = "Dice\n(Intersection Weighted)",
  kulczynski = "Kulczynski\n(Mutual Fit)"
)

clean_label <- function(x) {
  # Strip degree prefixes
  x <- str_remove(x, "Bachelor of Science in ")
  x <- str_remove(x, "Bachelor of ")
  x <- str_remove(x, "Bachelor Arts in ")
  # Full phrase replacements first (before words get shortened)
  x <- str_replace_all(x, "Computer and Informational Sciences", "CIS")
  x <- str_replace_all(x, "International and Global Studies", "Intl Studies")
  x <- str_replace_all(x, "Interdisciplinary Studies", "Interdisc Studies")
  x <- str_replace_all(x, "Environmental Studies", "Env Studies")
  x <- str_replace_all(x, "Biological Sciences", "Bio Sci")
  x <- str_replace_all(x, "Animal Sciences", "Animal Sci")
  x <- str_replace_all(x, "Computer Engineering Technology", "Comp Eng Tech")
  x <- str_replace_all(x, "Construction Engineering Technology", "Constr Eng Tech")
  x <- str_replace_all(x, "Electrical Engineering Technology", "Elec Eng Tech")
  # Single word abbreviations
  x <- str_replace_all(x, "Engineering", "Eng")
  x <- str_replace_all(x, "Technology", "Tech")
  x <- str_replace_all(x, "Mechanical", "Mech")
  x <- str_replace_all(x, "Electrical", "Elec")
  x <- str_replace_all(x, "Chemical", "Chem")
  x <- str_replace_all(x, "Industrial", "Ind")
  x <- str_replace_all(x, "Aerospace", "Aero")
  x <- str_replace_all(x, "Computer", "Comp")
  x <- str_replace_all(x, "Information", "Info")
  x <- str_replace_all(x, "Software", "SW")
  x <- str_replace_all(x, "Mathematics", "Math")
  x <- str_replace_all(x, "Chemistry", "Chem")
  x <- str_replace_all(x, "Biochemistry", "Biochem")
  x <- str_replace_all(x, "Physiology", "Physiol")
  x <- str_replace_all(x, "Science", "Sci")
  x <- str_replace_all(x, "Graphics", "Graph")
  str_wrap(x, 16)
}

process_json <- function(json_path) {
  dat <- fromJSON(json_path)

  mode      <- dat$metadata$mode
  top_limit <- dat$metadata$top_limit
  labels    <- dat$labels
  cip_ids   <- names(labels)
  nice      <- sapply(labels, clean_label)

  prefix <- paste0(toupper(substring(mode, 1, 1)), substring(mode, 2))
  if (mode == "interdisciplinary") prefix <- "STEM Branches"

  for (metric in names(dat$matrices)) {
    pal <- palettes[[metric]]
    title <- metric_titles[[metric]]
    if (is.null(pal) || is.null(title)) next

    mat <- as.matrix(dat$matrices[[metric]])
    rownames(mat) <- nice[cip_ids]
    colnames(mat) <- nice[cip_ids]

    suffix <- if (!is.null(top_limit)) paste0("_top", top_limit) else ""
    fname <- paste0("heatmap_", mode, suffix, "_", metric, ".png")

    pheatmap(mat,
             labels_row      = rownames(mat),
             labels_col      = colnames(mat),
             display_numbers = TRUE,
             number_format   = "%.0f",
             main            = paste(prefix, ":", title),
             fontsize        = fontsize_base,
             fontsize_number = fontsize_number,
             fontsize_row    = fontsize_axis,
             fontsize_col    = fontsize_axis,
             color           = pal,
             filename        = fname,
             width           = img_width,
             height          = img_height)

    message("Wrote ", fname)
  }
}

# ── Main ───────────────────────────────────────────────────────
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  json_files <- Sys.glob("similarity_metrics_*.json")
  if (length(json_files) == 0) stop("No similarity_metrics_*.json files found.")
} else {
  json_files <- args
}

for (f in json_files) {
  message("Processing ", f, " ...")
  process_json(f)
}

message("Done.")
