#!/usr/bin/env Rscript
# Corrected R script with empty file handling
merge_variant_caller_output <- function(Merged_file, Pileup_file, Somatic_file, output_file, occgenes, filtered_output_file) {
  
  library(dplyr)
  library(tidyr)
  
  # Helper function to check if file exists and has content
  check_file <- function(file_path, file_name) {
    if (!file.exists(file_path)) {
      print(paste("Warning:", file_name, "file does not exist:", file_path))
      return(FALSE)
    }
    
    file_size <- file.size(file_path)
    if (file_size == 0) {
      print(paste("Warning:", file_name, "file is empty:", file_path))
      return(FALSE)
    }
    
    # Try to read first few lines to check if file has content
    tryCatch({
      test_read <- readLines(file_path, n = 2)
      if (length(test_read) < 2) {
        print(paste("Warning:", file_name, "file has no data rows:", file_path))
        return(FALSE)
      }
      return(TRUE)
    }, error = function(e) {
      print(paste("Warning: Error reading", file_name, "file:", e$message))
      return(FALSE)
    })
  }
  
  # Helper function to create empty data frame with expected columns
  create_empty_df <- function(caller_type) {
    if (caller_type == "Merged") {
      return(data.frame(
        Chr = character(),
        Start = character(),
        End = character(),
        Ref = character(),
        Alt = character(),
        Func.refGene = character(),
        Gene.refGene = character(),
        GeneDetail.refGene = character(),
        ExonicFunc.refGene = character(),
        AAChange.refGene = character(),
        Otherinfo1 = character(),
        Otherinfo2 = character(),
        Otherinfo3 = character(),
        Otherinfo4 = character(),
        Otherinfo5 = character(),
        Otherinfo6 = character(),
        Otherinfo7 = character(),
        Otherinfo8 = character(),
        Otherinfo9 = character(),
        Otherinfo10 = character(),
        Otherinfo11 = character(),
        Otherinfo12 = character(),
        Otherinfo13 = character(),
        Otherinfo14 = character(),
        Otherinfo15 = character(),
        Otherinfo16 = character(),
        Otherinfo17 = character(),
        Otherinfo18 = character(),
        Otherinfo19 = character(),
        GT = character(),
        Merged_GQ = character(),
        Depth = character(),
        AD = character(),
        AF = character(),
        callerM = character(),
        stringsAsFactors = FALSE
      ))
    } else if (caller_type == "Pileup") {
      return(data.frame(
        Chr = character(),
        Start = character(),
        End = character(),
        Ref = character(),
        Alt = character(),
        Func.refGene = character(),
        Gene.refGene = character(),
        GeneDetail.refGene = character(),
        ExonicFunc.refGene = character(),
        AAChange.refGene = character(),
        Otherinfo1 = character(),
        Otherinfo2 = character(),
        Otherinfo3 = character(),
        Otherinfo4 = character(),
        Otherinfo5 = character(),
        Otherinfo6 = character(),
        Otherinfo7 = character(),
        Otherinfo8 = character(),
        Otherinfo9 = character(),
        Otherinfo10 = character(),
        Otherinfo11 = character(),
        Otherinfo12 = character(),
        Otherinfo13 = character(),
        Otherinfo14 = character(),
        Otherinfo15 = character(),
        Otherinfo16 = character(),
        Otherinfo17 = character(),
        Otherinfo18 = character(),
        Otherinfo19 = character(),
        GT = character(),
        Pileup_GQ = character(),
        Depth = character(),
        AD = character(),
        AF = character(),
        callerP = character(),
        stringsAsFactors = FALSE
      ))
    } else if (caller_type == "Somatic") {
      return(data.frame(
        Chr = character(),
        Start = character(),
        End = character(),
        Ref = character(),
        Alt = character(),
        Func.refGene = character(),
        Gene.refGene = character(),
        GeneDetail.refGene = character(),
        ExonicFunc.refGene = character(),
        AAChange.refGene = character(),
        Otherinfo1 = character(),
        Otherinfo2 = character(),
        Otherinfo3 = character(),
        Otherinfo4 = character(),
        Otherinfo5 = character(),
        Otherinfo6 = character(),
        Otherinfo7 = character(),
        Otherinfo8 = character(),
        Otherinfo9 = character(),
        Otherinfo10 = character(),
        Otherinfo11 = character(),
        Otherinfo12 = character(),
        Otherinfo13 = character(),
        Otherinfo14 = character(),
        Otherinfo15 = character(),
        Otherinfo16 = character(),
        Otherinfo17 = character(),
        Otherinfo18 = character(),
        Otherinfo19 = character(),
        GT = character(),
        ClairS_GQ = character(),
        ClairS_Depth = character(),
        ClairS_AF = character(),
        ClairS_AD = character(),
        AU = character(),
        CU = character(),
        GU = character(),
        TU = character(),
        callerS = character(),
        stringsAsFactors = FALSE
      ))
    }
  }
  
  # Check and load Merged file
  has_merged <- check_file(Merged_file, "Merged")
  if (has_merged) {
    tryCatch({
  Merged <- read.delim(Merged_file, header = TRUE, colClasses = c("character"))
      if (nrow(Merged) == 0) {
        print("Warning: Merged file has no data rows")
        has_merged <- FALSE
        Merged <- create_empty_df("Merged")
      } else {
  Merged <- Merged %>%
    select(7,1:6,8:16,19) %>%
    separate(Otherinfo13, c("GT","Merged_GQ","Depth","AD","AF"), sep = ":")
  Merged$callerM <- "Merged"
      }
    }, error = function(e) {
      print(paste("Error processing Merged file:", e$message))
      has_merged <- FALSE
      Merged <- create_empty_df("Merged")
    })
  } else {
    Merged <- create_empty_df("Merged")
  }
  
  # Check and load Pileup file
  has_pileup <- check_file(Pileup_file, "Pileup")
  if (has_pileup) {
    tryCatch({
  Pileup <- read.delim(Pileup_file, header = TRUE, colClasses = c("character"))
      if (nrow(Pileup) == 0) {
        print("Warning: Pileup file has no data rows")
        has_pileup <- FALSE
        Pileup <- create_empty_df("Pileup")
      } else {
  Pileup <- Pileup %>%
    select(7,1:6,8:16,19) %>%
    separate(Otherinfo13, c("GT","Pileup_GQ","Depth","AD","AF"), sep = ":")
  Pileup$callerP <- "Pileup"
      }
    }, error = function(e) {
      print(paste("Error processing Pileup file:", e$message))
      has_pileup <- FALSE
      Pileup <- create_empty_df("Pileup")
    })
  } else {
    Pileup <- create_empty_df("Pileup")
  }
  
  # Check and load Somatic file
  has_somatic <- check_file(Somatic_file, "Somatic")
  if (has_somatic) {
    tryCatch({
  Somatic <- read.delim(Somatic_file, header = TRUE, colClasses = c("character"))
  if (nrow(Somatic) == 0) {
        print("Warning: Somatic file has no data rows")
    has_somatic <- FALSE
        Somatic <- create_empty_df("Somatic")
  } else {
    Somatic <- Somatic %>%
      select(7,1:6,9:16,18) %>%
      separate(Otherinfo10, c("GT","ClairS_GQ","ClairS_Depth","ClairS_AF","ClairS_AD","AU","CU","GU","TU"), sep = ":") %>%
      select(1:15,17:19)
    Somatic$callerS <- "ClairS_TO"
  }
    }, error = function(e) {
      print(paste("Error processing Somatic file:", e$message))
      has_somatic <- FALSE
      Somatic <- create_empty_df("Somatic")
    })
  } else {
    Somatic <- create_empty_df("Somatic")
  }
  
  # Load OCC genes
  tryCatch({
  occgenes <- readRDS(occgenes)
    print(paste("Loaded", length(occgenes), "OCC genes"))
  }, error = function(e) {
    print(paste("Error loading OCC genes:", e$message))
    occgenes <- character(0)
  })
  
  # Check if we have any data to process
  if (!has_merged && !has_pileup && !has_somatic) {
    print("Warning: No valid data found in any input files. Creating empty output files.")
    
    # Create empty output files
    empty_df <- data.frame(
      cosmic100_ID = character(),
      Chr = character(),
      Start = character(),
      End = character(),
      Ref = character(),
      Alt = character(),
      Func.refGene = character(),
      Gene.refGene = character(),
      ExonicFunc.refGene = character(),
      AAChange.refGene = character(),
      Variant_caller = character(),
      GQ = character(),
      Depth = character(),
      stringsAsFactors = FALSE
    )
    
    write.table(empty_df, file = output_file, row.names = FALSE, sep = "\t", quote = FALSE, na = "0")
    write.table(empty_df, file = filtered_output_file, row.names = FALSE, sep = "\t", quote = FALSE, na = "0")
    
    print(paste("Empty output files created:", output_file, "and", filtered_output_file))
    return()
  }
  
  # Merge files - handle empty data frames
  if (has_pileup && has_merged) {
  All_calls <- full_join(Pileup, Merged) %>%
    unite(Variant_caller, callerP, callerM, sep = ", ", na.rm = TRUE)
  } else if (has_pileup) {
    All_calls <- Pileup %>%
      mutate(Variant_caller = callerP)
  } else if (has_merged) {
    All_calls <- Merged %>%
      mutate(Variant_caller = callerM)
  } else {
    All_calls <- data.frame()
  }
  
  # Only join with Somatic data if it exists and has data
  if (has_somatic && nrow(Somatic) > 0) {
    if (nrow(All_calls) > 0) {
    All_calls <- All_calls %>%
      full_join(Somatic) %>%
      unite(Variant_caller, Variant_caller, callerS, sep = ", ", na.rm = TRUE)
    } else {
      All_calls <- Somatic %>%
        mutate(Variant_caller = callerS)
    }
  }
  
  # Handle case where no data was merged
  if (nrow(All_calls) == 0) {
    print("Warning: No data after merging. Creating empty output files.")
    empty_df <- data.frame(
      cosmic100_ID = character(),
      Chr = character(),
      Start = character(),
      End = character(),
      Ref = character(),
      Alt = character(),
      Func.refGene = character(),
      Gene.refGene = character(),
      ExonicFunc.refGene = character(),
      AAChange.refGene = character(),
      Variant_caller = character(),
      GQ = character(),
      Depth = character(),
      stringsAsFactors = FALSE
    )
    
    write.table(empty_df, file = output_file, row.names = FALSE, sep = "\t", quote = FALSE, na = "0")
    write.table(empty_df, file = filtered_output_file, row.names = FALSE, sep = "\t", quote = FALSE, na = "0")
    
    print(paste("Empty output files created:", output_file, "and", filtered_output_file))
    return()
  }
  
  # Unite GQ values based on availability of data
  if (has_somatic && nrow(Somatic) > 0) {
    All_calls <- All_calls %>%
      unite(GQ, Pileup_GQ, Merged_GQ, sep = ",", na.rm = TRUE) %>%
      unite(GQ, GQ, ClairS_GQ, sep = ",", na.rm = TRUE)
  } else {
    # If no somatic data, do not unite ClairS_GQ
    All_calls <- All_calls %>%
      unite(GQ, Pileup_GQ, Merged_GQ, sep = ",", na.rm = TRUE)
  }
  
  # Handle COSMIC100 column if it exists
  if ("COSMIC100" %in% colnames(All_calls)) {
    All_calls <- All_calls %>%
      separate(COSMIC100, c("cosmic100_ID", "y"), sep = ";", remove = FALSE, fill = "right") %>%
      mutate(cosmic100_ID = gsub("ID=", "", cosmic100_ID))
  } else {
    print("COSMIC100 column is missing, skipping separation and mutation steps for this column.")
    All_calls$cosmic100_ID <- ""
  }
  
  # Continue with the rest of the pipeline
  All_calls <- All_calls %>%
    select(any_of(c(any_of(c(25,1:7,9,10,15,16,20:22,19,23,24)))))
  
  # Filter by OCC genes if we have any
  if (length(occgenes) > 0) {
  All_calls <- All_calls %>% filter(Gene.refGene %in% occgenes)
    print(paste("Filtered to", length(unique(All_calls$Gene.refGene)), "OCC genes"))
  } else {
    print("No OCC genes loaded, skipping gene filtering")
  }
  
  # Create filtered version for additional output
  All_calls_filtered <- All_calls %>%
    # Filter 1: Remove "Pileup only" from Variant_caller
    filter(!grepl("^Pileup$", Variant_caller)) %>%
    # Filter 2: Remove rows with depth below 10 (only if Depth column exists and has numeric values)
    filter(is.na(Depth) | Depth == "" | as.numeric(Depth) >= 10) %>%
    # Filter 3: Remove specific TERT variant row
    filter(!(Gene.refGene == "TERT" & Chr == "chr5" & Start == "1295957" & End == "1295957"))
  
  # Write original output
All_calls[] <- lapply(All_calls, function(x) {
  if (is.factor(x)) {
    x <- as.character(x)
  }
  # Replace empty strings with "0"
  x[x == ""] <- "0"
  return(x)
})

# Write the table, replacing any NA values with "0"
write.table(All_calls, 
            file = output_file, 
            row.names = FALSE, 
            sep = "\t", 
            quote = FALSE, 
            na = "0")
  
  # Write filtered output
  All_calls_filtered[] <- lapply(All_calls_filtered, function(x) {
    if (is.factor(x)) {
      x <- as.character(x)
    }
    # Replace empty strings with "0"
    x[x == ""] <- "0"
    return(x)
  })
  
  write.table(All_calls_filtered, 
              file = filtered_output_file, 
              row.names = FALSE, 
              sep = "\t", 
              quote = FALSE, 
              na = "0")
  
  print(paste("Original output written to:", output_file))
  print(paste("Filtered output written to:", filtered_output_file))
  print(paste("Original rows:", nrow(All_calls)))
  print(paste("Filtered rows:", nrow(All_calls_filtered)))
}

# Parsing arguments passed from the Nextflow process
args <- commandArgs(trailingOnly = TRUE)
Merged_file <- args[1]
Pileup_file <- args[2]
Somatic_file <- args[3]
output_file <- args[4]
occgenes <- args[5]
filtered_output_file <- args[6]

# Call the function with provided arguments
merge_variant_caller_output(Merged_file, Pileup_file, Somatic_file, output_file, occgenes, filtered_output_file)
