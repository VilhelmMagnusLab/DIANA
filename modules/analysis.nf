#!/usr/bin/env nextflow
nextflow.enable.dsl=2

//---------------------------------------------------------------------
// Analysis Pipeline: Comprehensive analysis of glioblastoma samples
// Includes MGMT methylation, structural variant annotation, CNV analysis, 
// SNV calling, and report generation
//---------------------------------------------------------------------

def start_time = new Date()

//---------------------------------------------------------------------
// Helper function definitions
//---------------------------------------------------------------------

def validateParameters() {
    params.run_mode = params.run_mode_analysis ?: 'all'
    println "Analysis run mode: ${params.run_mode}"
    if (!['mgmt', 'svannasv', 'cnv', 'occ', 'tertp', 'mgmt', 'rmd', 'stat', 'all'].contains(params.run_mode)) {
        error "ERROR: Invalid run_mode '${params.run_mode}' for analysis. Valid modes: svannasv, cnv, occ, tertp, mgmt, rmd, stat, all"
    }
}

def loadSampleThresholds() {
    return file(params.analyse_sample_id_file).readLines()
        .collectEntries { line ->
            def tokens = line.trim().split(/\s+/)  // Handle any whitespace
            if (tokens.size() == 2) {
                // User provided tumor content: [sample_id, tumor_content]
                def threshold = tokens[1].toFloat()
                if (threshold < 0 || threshold > 1) {
                    throw new IllegalArgumentException("Tumor content must be between 0-1: ${line}")
                }
                [(tokens[0]) : threshold]
            } else if (tokens.size() == 1) {
                // User needs ACE calculation: [sample_id]
                [(tokens[0]) : null]  // null indicates need ACE calculation
            } else {
                throw new IllegalArgumentException("Invalid line format in sample_id_file: ${line}")
            }
        }
}

//---------------------------------------------------------------------
// Process Definitions
//---------------------------------------------------------------------

// Extract EPIC methylation sites and MGMT CpG islands from bedmethyl data
process extract_epic {
    cpus 2
    memory '2 GB'
    label 'epic'
    tag "${sample_id}"
    publishDir "${params.output_path}/${sample_id}/methylation/", mode: "copy", overwrite: true
    publishDir "${params.path}/routine_results/${sample_id}", mode: "copy", overwrite: true, pattern: "*_mnpflex_input.bed"

    input:
    tuple val(sample_id), file(bedmethyl), file(epicsites), file(mgmt_cpg_island_hg38)

    output:
    tuple val(sample_id), path("${sample_id}_EpicSelect_header.bed"), emit: epicselectnanodxinput
    path("${sample_id}_MGMT.bed")
    tuple val(sample_id), path("${sample_id}_MGMT_header.bed"), emit: MGMTheaderout
    tuple val(sample_id), path("${sample_id}_wf_mods.bedmethyl_intersect.bed"), emit: sturgeonbedinput
    tuple val(sample_id), path("${sample_id}_EpicSelect_m.bed")
    tuple val(sample_id), path("${sample_id}_mnpflex_input.bed")

    script:
    """
    which intersectBed 
    intersectBed -a $bedmethyl -b $epicsites -wb | \
    awk -v OFS="\\t" '\$1=\$1' | awk -F'\\t' 'BEGIN{ OFS="\\t" }{print \$1,\$2,\$3,\$4,\$5,\$11,\$23}' > ${sample_id}_EpicSelect.bed

    intersectBed -a $bedmethyl -b $epicsites -wb | awk -v OFS="\\t" '\$1=\$1' | awk -F'\\t' 'BEGIN{ OFS="\\t" } {print \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10, \$11, \$12, \$13, \$14, \$15, \$16, \$17, \$18}' > ${sample_id}_wf_mods.bedmethyl_intersect.bed

    awk 'BEGIN {print "Chromosome\\tStart\\tEnd\\tmodBase\\tCoverage\\tMethylation_frequency\\tIllumina_ID"} 1' ${sample_id}_EpicSelect.bed > ${sample_id}_EpicSelect_header.bed

    grep -w 'm'  ${sample_id}_EpicSelect_header.bed >  ${sample_id}_EpicSelect_m.bed

    awk 'BEGIN{                       
    OFS="\\t";
    print "\\"chr\\"","\\"start\\"","\\"end\\"","\\"coverage\\"","\\"methylation_percentage\\"","\\"IlmnID\\""
    }
    {
    if (\$1 ~ /^chr/) {
        printf "\\"%s\\"\\t%s\t%s\\t%s\\t%s\\t\\"%s\\"\\n", \$1, \$2, \$3, \$5, \$6, \$7
    }
    }   ' ${sample_id}_EpicSelect_m.bed > ${sample_id}_mnpflex_input.bed


    intersectBed -a $bedmethyl -b $mgmt_cpg_island_hg38 | \
    awk -v OFS="\\t" '\$1=\$1' | awk -F'\\t' 'BEGIN{ OFS="\\t" }{print \$1,\$2,\$3,\$4,\$5,\$11,\$12,\$13,\$14,\$15,\$16}'  > ${sample_id}_MGMT.bed

    awk 'BEGIN {print "Chrom\\tStart\\tEnd\\tmodBase\\tDepth\\tMethylation\\tNmod\\tNcanon\\tNother\\tNdelete\\tNfail"} 1' ${sample_id}_MGMT.bed > ${sample_id}_MGMT_header.bed
    """
}


// Prepare nanoDX input for methylation data processing and CpG site intersection
process nanodx {
    label 'epic'
    publishDir "${params.output_path}/${sample_id}/classifier/nanodx", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(nanodx_bed), path(hg19_450model)

    output:
    tuple val(sample_id), path("${sample_id}_nanodx_bedmethyl.bed"), emit: nanodx450out

    script:
    """
    nanodx450intersectdataframe.py $hg19_450model $nanodx_bed ${sample_id}_output_cpg.bed ${sample_id}_nanodx_bedmethyl.bed ${sample_id}_nanodx_bedmethylfilter.bed
    """
}

//Sturgeon classifier
process sturgeon {
    cpus 4
    memory '2 GB'
    label 'epic'
    publishDir "${params.output_path}/${sample_id}/classifier/sturgeon", mode: "copy", overwrite: true
    publishDir "${params.path}/routine_results/${sample_id}", mode: "copy", overwrite: true, pattern: "*_bedmethyl_sturgeon_general.pdf"

    input:
    tuple val(sample_id), path(sturgeon_bed), path(sturgeon_model)

    output:
    path("${sample_id}_bedmethyl_sturgeon.bed")
    path("${sample_id}_bedmethyl_sturgeon_general.pdf"), optional: true
    path("${sample_id}_bedmethyl_sturgeon_general.csv"), optional: true


    """
    /sturgeon/venv/bin/sturgeon inputtobed -i $sturgeon_bed  -o ${sample_id}_bedmethyl_sturgeon.bed  -s modkit_pileup  --reference-genome hg38

    /sturgeon/venv/bin/sturgeon predict -i ${sample_id}_bedmethyl_sturgeon.bed   -o  ${sample_id}_bedmethyl_sturgeon --model-files $sturgeon_model  --plot-results

    # Copy the PDF and CSV files to the work directory for publishDir to find them
    if [ -f "${sample_id}_bedmethyl_sturgeon/${sample_id}_bedmethyl_sturgeon_general.pdf" ]; then
        cp "${sample_id}_bedmethyl_sturgeon/${sample_id}_bedmethyl_sturgeon_general.pdf" .
    fi
    if [ -f "${sample_id}_bedmethyl_sturgeon/${sample_id}_bedmethyl_sturgeon_general.csv" ]; then
        cp "${sample_id}_bedmethyl_sturgeon/${sample_id}_bedmethyl_sturgeon_general.csv" .
    fi
    # Note: ${sample_id}_bedmethyl_sturgeon.bed is already in the work directory (created at line 134)
    rm -rf ${sample_id}_bedmethyl_sturgeon
    """
    
}


// Neural network classification for tumor type prediction using NanoDx CrossNN classifier
process run_nn_classifier {
    label 'nanodx'
    publishDir "${params.output_path}/${sample_id}/classifier/nanodx", mode: "copy", overwrite: true
    
    input:
    tuple val(sample_id), path(bed_file), path(model_file), path(snakefile), path(nn_model)
    
    output:
    tuple val(sample_id), path("${sample_id}_nanodx_classifier.txt")
    tuple val(sample_id), path("${sample_id}_nanodx_classifier.tsv"), emit: rmdnanodx
    
    script:
    """
    #!/bin/bash
    export TMPDIR="\${PWD}/tmp/"
    export XDG_CACHE_HOME="\${TMPDIR}.cache"
    mkdir -p "\$TMPDIR/.cache"
    
    # Use container's conda environment
    source /opt/conda/etc/profile.d/conda.sh
    conda activate base
    conda activate nanodx_env2feb

    # Remove symlinked Snakefile to avoid overwriting the reference file
    rm -f Snakefile

    # Create Snakefile with correct paths and reduced memory
    cat << EOF > Snakefile
rule all:
    input:
        "${sample_id}_nanodx_classifier.txt",
        "${sample_id}_nanodx_classifier.tsv"

rule NN_classifier:
    input:
        bed = "${bed_file}",
        model = "${model_file}"
    output:
        txt = "${sample_id}_nanodx_classifier.txt",
        votes = "${sample_id}_nanodx_classifier.tsv"
    threads: 2
    resources:
        mem_mb = 2048
    script: "${params.nanodx_workflow_dir}/scripts/classify_NN_bedMethyl.py"
EOF

    # Run snakemake with error handling
    if ! snakemake --cores ${task.cpus} --verbose NN_classifier; then
        echo "Snakemake failed, creating empty output files"
        touch "${sample_id}_nanodx_classifier.txt"
        touch "${sample_id}_nanodx_classifier.tsv"
        echo "NN classifier failed - pickle compatibility issue" > "${sample_id}_nanodx_classifier.txt"
    fi
    """
}

// Dimensionality reduction plot generation using t-SNE/UMAP
process tsne_plot {
    label 'tsne'
    stageInMode 'copy'
    publishDir "${params.output_path}/${sample_id}/classifier/nanodx", mode: "copy", overwrite: true
    publishDir "${params.path}/routine_results/${sample_id}", mode: "copy", overwrite: true, pattern: "*_tsne_plot.html"

    input:
    tuple val(sample_id), path(epic_bed)
    path(color_map)
    path(training_set)

    output:
    tuple val(sample_id), path("${sample_id}_tsne_plot.pdf"), emit: tsne_out
    tuple val(sample_id), path("${sample_id}_tsne_plot.html")

    script:
    """
    #!/bin/bash
    set -e

    # Activate conda environment to access Rscript
    source /opt/conda/etc/profile.d/conda.sh
    conda activate tsneenv

    # Verify Rscript is available
    if ! command -v Rscript >/dev/null 2>&1; then
        echo "ERROR: Rscript not found after activating tsneenv"
        echo "Available conda environments:"
        conda env list
        echo "PATH: \$PATH"
        exit 1
    fi

    echo "Using Rscript from: \$(which Rscript)"

    # Run the memory-optimized t-SNE script (uses 30k probes instead of 100k to reduce RAM usage)
    Rscript ${params.nWGS_dir}/bin/crossnn_tsne_fixed.R \\
        --color-map ${color_map} \\
        --bed ${epic_bed} \\
        --trainingset ${training_set} \\
        --method umap \\
        --umap-n-neighbours 10 \\
        --umap-min-dist 0.5 \\
        --umap-pca-dim 100 \\
        --pdf ${sample_id}_tsne_plot.pdf \\
        --html ${sample_id}_tsne_plot.html

    echo "t-SNE plot generated for ${sample_id}"
    """
}

// MGMT promoter methylation analysis and quantification
process mgmt_promoter {
    label 'epic'
    publishDir "${params.output_path}/${sample_id}/methylation/", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(mgmt_bed)

    output:
    tuple val(sample_id), path("${sample_id}_MGMT_results.csv"), emit: mgmtresultsout
    
    script:
  """
    #!/bin/bash
    set -e  # Exit on error
    
    if [ ! -f "${mgmt_bed}" ]; then
        echo "Error: Input file ${mgmt_bed} not found"
        exit 1
    fi
    
    MGMT_Prospective2.R ${mgmt_bed} "${sample_id}_MGMT_results.csv"
    
    if [ ! -f "${sample_id}_MGMT_results.csv" ]; then
        echo "Error: Output file not generated"
        exit 1
    fi
    """
}

// Structural variant annotation using Svanna for region of interest genes (occ genes)
process svannasv {

  label 'svannasv'
   publishDir "${params.output_path}/${sample_id}/structure_variant/svannasv/", mode: "copy", overwrite: true
   publishDir "${params.path}/routine_results/${sample_id}", mode: "copy", overwrite: true, pattern: "*_occ_svanna_annotation.html"

   input:
   tuple val(sample_id), path(wf_sv), path(wf_sv_tbi),path(occ_protein_coding_bed)

   output:
   
   tuple val(sample_id), path("${sample_id}_occ_svanna_annotation.html"), emit:rmdsvannahtml
   tuple val(sample_id), path("${sample_id}_occ_svanna_annotation.vcf.gz"), emit: occsvannaannotationannotationvcf
   tuple val(sample_id), path("${sample_id}_sniffles2_under30mb.vcf.gz")

   script:
   """
   # Debug: List input files
   echo "Input files:"
   echo "SV file: $wf_sv"
   echo "SV index: $wf_sv_tbi"
   echo "OCC protein coding bed: $occ_protein_coding_bed"
   ls -la

   bcftools view -O z -o ${sample_id}_sniffles2_under30mb.vcf.gz   -i '(INFO/SVTYPE="DUP" || INFO/SVTYPE="INV" || INFO/SVTYPE="INS") && INFO/SVLEN < 30000000 || (INFO/SVTYPE="DEL" && INFO/SVLEN > -30000000)'   $wf_sv
   bcftools index -t ${sample_id}_sniffles2_under30mb.vcf.gz


   java -jar ${params.svanna_bin_dir}/svanna-cli-1.0.4.jar prioritize  \
   -d ${params.ref_dir}/svanna-data  \
   --vcf  $wf_sv \
   --phenotype-term HP:0100836 \
   --output-format html,vcf \
   --prefix ${sample_id}_occ_svanna_annotation

  # cp "${sample_id}_occ_svanna_annotation.html" "${params.output_path}/report/${sample_id}_svanna.html"

   """
}

// Fusion event analysis and filtering from structural variants
process svannasv_fusion_events {
    label 'svannasv'
    publishDir "${params.output_path}/${sample_id}/structure_variant/svannasv/", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(occ_svannavcf), path(genecode_bed), path(occ_fusions_genes)

    output:
    tuple val(sample_id), path("${sample_id}_filter_fusion_event.tsv"), emit: filterfusioneventout
    tuple val(sample_id), path("${sample_id}_filter_fusion_event_detailed.tsv")
    tuple val(sample_id), path("${sample_id}_filter_fusion_event_ensembl_only.tsv"), optional: true
    tuple val(sample_id), path("${sample_id}_filter_fusion_event_detailed_ensembl_only.tsv"), optional: true

    script:

    """
    # Create enhanced GFF3 with both exons and introns
    gunzip -c $occ_svannavcf > ${sample_id}_occ_svanna_annotation.vcf
   
    create_gff3_with_introns.py --gff3 $genecode_bed --out ${sample_id}_genecode_with_introns.gff3

    breaking_point_bed_translocation_exon.py --vcf ${sample_id}_occ_svanna_annotation.vcf --out ${sample_id}_breaking_bedpoints.bed

    awk 'BEGIN{OFS="\t"} {if (\$1 !~ /^chr/) \$1 = "chr"\$1; print}' ${sample_id}_breaking_bedpoints.bed > ${sample_id}_breaking_bedpoints_sort.bed

    # Intersect with enhanced GFF3 that includes introns
    intersectBed -a ${sample_id}_breaking_bedpoints_sort.bed  -b ${sample_id}_genecode_with_introns.gff3  -wb  > ${sample_id}_breaking_bedpoints_genecode.bed

    #remove duplicate bed points and add exon/intron annotations

    remove_duplicate_report_exon.py --in  ${sample_id}_breaking_bedpoints_genecode.bed  \
            --formatted ${sample_id}_breaking_bedpoints_genecode_format.bed \
             --out ${sample_id}_breaking_bedpoints_genecode_clean.bed    \
             --paired ${sample_id}_breaking_bedpoints_genecode_clean_paired.bed  \
             --gene-list $occ_fusions_genes \
             --filtered ${sample_id}_filter_fusion_event_detailed_temp.tsv

    # Add intergenic annotations for breakpoints that don't overlap any features
    annotate_intergenic_breakpoints.py --original-bed ${sample_id}_breaking_bedpoints_sort.bed \
             --annotated ${sample_id}_filter_fusion_event_detailed_temp.tsv \
             --out ${sample_id}_filter_fusion_event_detailed.tsv

    #summarize exon/intron/intergenic features into compact format

    summarize_fusion_features.py --in ${sample_id}_filter_fusion_event_detailed.tsv \
             --out ${sample_id}_filter_fusion_event_temp.tsv

    # Filter to keep only complete fusion pairs (IDs with both start and end breakpoints)
    # Then keep only one representative fusion per unique gene pair
    awk 'NR==1 {header=\$0; next}
         {id=\$4; breaking=\$6; gene=\$7;
          data[id,breaking]=\$0; ids[id]++;
          genes[id,breaking]=gene;
          if(breaking=="start") has_start[id]=1;
          if(breaking=="end") has_end[id]=1}
         END {print header;
              for(id in ids) {
                if(has_start[id] && has_end[id]) {
                  gene_start=genes[id,"start"];
                  gene_end=genes[id,"end"];
                  gene_pair=(gene_start < gene_end) ? gene_start"-"gene_end : gene_end"-"gene_start;
                  if(!seen_pair[gene_pair]++) {
                    if((id,"start") in data) print data[id,"start"];
                    if((id,"end") in data) print data[id,"end"]
                  }
                }
              }
         }' ${sample_id}_filter_fusion_event_temp.tsv > ${sample_id}_filter_fusion_event.tsv

    # Filter fusion events to keep only those with official Ensembl gene IDs (ENSG...)
    echo "Filtering for fusions with complete Ensembl gene IDs..."
    filter_fusion_complete_ensembl.py \
        --input ${sample_id}_filter_fusion_event_detailed.tsv \
        --output ${sample_id}_filter_fusion_event_detailed_ensembl_only.tsv \
        --gff3 $genecode_bed \
        --stats ${sample_id}_ensembl_filter_stats.txt

    # Annotate fusion breakpoints with exon coordinates and coding phase
    if [ -s ${sample_id}_filter_fusion_event_detailed_ensembl_only.tsv ]; then
        echo "Annotating breakpoints with exon coordinates and phase information..."
        annotate_fusion_exon_phase.py \
            --input ${sample_id}_filter_fusion_event_detailed_ensembl_only.tsv \
            --output ${sample_id}_filter_fusion_event_detailed_ensembl_only_exon_phase.tsv \
            --gff3 $genecode_bed \
            --stats ${sample_id}_exon_phase_stats.txt

        # Use the exon/phase annotated version as the detailed output
        mv ${sample_id}_filter_fusion_event_detailed_ensembl_only_exon_phase.tsv ${sample_id}_filter_fusion_event_detailed_ensembl_only.tsv

        # Create summarized version of Ensembl-filtered fusions
        summarize_fusion_features.py --in ${sample_id}_filter_fusion_event_detailed_ensembl_only.tsv \
             --out ${sample_id}_filter_fusion_event_ensembl_only_temp.tsv

        # Filter to keep only complete fusion pairs (IDs with both start and end breakpoints)
        # Then keep only one representative fusion per unique gene pair
        awk 'NR==1 {header=\$0; next}
             {id=\$4; breaking=\$6; gene=\$7;
              data[id,breaking]=\$0; ids[id]++;
              genes[id,breaking]=gene;
              if(breaking=="start") has_start[id]=1;
              if(breaking=="end") has_end[id]=1}
             END {print header;
                  for(id in ids) {
                    if(has_start[id] && has_end[id]) {
                      gene_start=genes[id,"start"];
                      gene_end=genes[id,"end"];
                      gene_pair=(gene_start < gene_end) ? gene_start"-"gene_end : gene_end"-"gene_start;
                      if(!seen_pair[gene_pair]++) {
                        if((id,"start") in data) print data[id,"start"];
                        if((id,"end") in data) print data[id,"end"]
                      }
                    }
                  }
             }' ${sample_id}_filter_fusion_event_ensembl_only_temp.tsv > ${sample_id}_filter_fusion_event_ensembl_only.tsv
    fi

    """

}

// Circos plot generation for structural variant visualization
process circosplot {
   label 'circos'
   publishDir "${params.output_path}/${sample_id}/structure_variant/svannasv/", mode: "copy", overwrite: true
   
   input:
   tuple val(sample_id), path(svanna_output), path(vcf2circos_json)

   output:
   tuple val(sample_id), path("${sample_id}_vcf2circo.html"), optional: true, emit: circosout

   script:
   """
   # Check if file is empty (excluding header)
   # Handle both gzipped and uncompressed VCF files
   if [[ ${svanna_output} == *.gz ]]; then
      # For gzipped files, use zcat
      VARIANT_COUNT=\$(zcat ${svanna_output} | grep -v '^#' | wc -l)
   else
      # For uncompressed files, use grep directly
      VARIANT_COUNT=\$(grep -v '^#' ${svanna_output} | wc -l)
   fi

   if [ \$VARIANT_COUNT -eq 0 ]; then
      echo "Warning: ${svanna_output} has no variants (0 non-header lines). Skipping vcf2circos plot generation."
      touch ${sample_id}_vcf2circo.html
      exit 0
   else
      echo "Found \$VARIANT_COUNT variants in ${svanna_output}. Generating circos plot..."
      # Try to generate circos plot, but create empty file if it fails
      set +e  # Don't exit on error
      vcf2circos -i $svanna_output -o ${sample_id}_vcf2circo.html -p $vcf2circos_json -a hg38
      CIRCOS_EXIT=\$?
      set -e  # Re-enable exit on error

      if [ \$CIRCOS_EXIT -ne 0 ]; then
          echo "Warning: vcf2circos failed with exit code \$CIRCOS_EXIT. Creating empty placeholder file."
          touch ${sample_id}_vcf2circo.html
      else
          echo "Circos plot generated successfully."
      fi
   fi
   """
}

// Copy number variant annotation and analysis with ACE
process annotatecnv {
   label 'annotatecnv'
    publishDir "${params.output_path}/${sample_id}/cnv/", mode: "copy", overwrite: true

   input:
    tuple val(sample_id),
          path(vcf_file),
          path(occ_protein_coding_bed),
          path(calls_bed),
          path(seg_bed),
          val(threshold),  // Now explicitly receiving threshold
          path(cnv_genes_tuned)  // CNV genes annotation file

   output:
   tuple val(sample_id), path("${sample_id}_calls_fixed.vcf"), emit: callsfixedout
   tuple val(sample_id), path("${sample_id}_annotatedcnv.csv"), emit:annotatedcnvcsvout
   tuple val(sample_id), path("${sample_id}_annotatedcnv_filter.csv"), emit:annotatedcnvfiltercsvout
   //tuple val(sample_id), path("${sample_id}_CNV_plot.pdf"), emit:cnvpdfout
   tuple val(sample_id), path("${sample_id}_annotatedcnv_filter_header.csv"), emit:rmdannotatedcnvfilter
   //tuple val(sample_id), path("${sample_id}_CNV_plot.html"), emit:rmdcnvhtml
   tuple val(sample_id), path("${sample_id}_tumor_copy.txt"), path("${sample_id}_bins_filter.bed"), emit:tumorcopyandbinsfilterout
   //tuple val(sample_id), path("${sample_id}_CNV_plot.pdf"), path("${sample_id}_annotatedcnv_filter.csv"), emit:cnvpdfandcsvout
   tuple val(sample_id), path("${sample_id}_cnv_plot_full.pdf"), path("${sample_id}_tumor_copy_number.txt"), path("${sample_id}_annotatedcnv_filter_header.csv"), path("${sample_id}_cnv_chr9.pdf"), path("${sample_id}_cnv_chr7.pdf"), emit: rmdcnvtumornumber

   script:
   """
    #!/bin/bash
    ##source /opt/conda/etc/profile.d/conda.sh
    ##conda activate annotatecnv_env

    # Check if we're in a container and use appropriate conda setup
    if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
        # Container environment
   source /opt/conda/etc/profile.d/conda.sh
   conda activate annotatecnv_env
    else
        # Local environment
        source activate annotatecnv_env
    fi

    # Debug output
    echo "Processing sample: ${sample_id}"
    echo "Using threshold: ${threshold}"
    
    # Process VCF file
    awk 'OFS="\\t" {if (NR > 13) \$1="chr"\$1; print}' $vcf_file > ${sample_id}_calls_fixed.vcf
    
    # Intersect and process
    intersectBed -a ${sample_id}_calls_fixed.vcf -b $occ_protein_coding_bed -wa -wb | \
        cut -f1,2,5,8,20 | awk '/protein_coding/' | \
        awk -v OFS=";" '\$1=\$1' | \
        awk 'BEGIN { FS=";"; OFS="\\t"} {\$1=\$1; print}' | \
   cut -f1,2,3,5,6,8,9,13 > ${sample_id}_annotatedcnv.csv

    # Generate plots and reports
   #cnv_html.R $calls_bed ${sample_id}_annotatedcnv.csv ${sample_id}_CNV_plot.pdf ${sample_id}_CNV_plot.html $sample_id

    CNV_function_new_update.R $calls_bed $cnv_genes_tuned $seg_bed \
        ${sample_id}_cnv_plot_full.pdf ${sample_id}_cnv_chr9.pdf ${sample_id}_cnv_chr7.pdf $sample_id

    # Process annotation files
    awk 'BEGIN { OFS="," } { gsub(/<[^>]+>/, substr(\$3, 2, length(\$3) - 2), \$3); print \$0 }' \
        ${sample_id}_annotatedcnv.csv > ${sample_id}_annotatedcnv_filter.csv

    awk 'BEGIN {print "Chrom,Start,Type,End,SVLEN,Score,LOG2CNT,Gene"} 1' \
        ${sample_id}_annotatedcnv_filter.csv > ${sample_id}_annotatedcnv_filter_header.csv

    # Run CNV mapping with threshold
    cnv_mapping_occfusion_update.py $seg_bed $occ_protein_coding_bed \
        ${sample_id}_tumor_copy.txt ${sample_id}_bins_filter.bed ${threshold}
    
    cnv_mapping_occfusion_update_nofilter.py $seg_bed \
        ${sample_id}_tumor_copy_number.txt ${threshold}
    """
}

// SNV calling and annotation using Clair3 for OCC (regions of interest) regions
process clair3 {
    label 'clair3'
    publishDir "${params.path}/routine_epi2me/${sample_id}", mode: "copy", overwrite: true
   
    input:
    tuple val(sample_id), path(occ_bam), path(occ_bam_bai), path(reference_genome), path(reference_genome_bai),  path(refGene), path(hg38_refGeneMrna), path(clinvar), path(clinvarindex),path(hg38_cosmic100),path(hg38_cosmic100index)

    output:
    tuple val(sample_id), path('output_clair3/')
    tuple val(sample_id), path("${sample_id}_occ_pileup_snvs_avinput")
    tuple val(sample_id), path("${sample_id}_occ_pileup_annotateandfilter.csv"), emit:occpileupannotateandfilterout
    tuple val(sample_id), path("${sample_id}_occ_merge_snv_avinpt")
    tuple val(sample_id), path("${sample_id}_occ_merge.hg38_multianno.txt")
    tuple val(sample_id), path("${sample_id}_merge_annotateandfilter.csv"), emit:mergeannotateandfilterout
    tuple val(sample_id), path("${sample_id}_occ_pileup_annotateandfilter.csv"), path("${sample_id}_merge_annotateandfilter.csv"), emit:clair3output 


    script:
   
   """ 
   # Activate conda environment for Clair3
   source /opt/conda/etc/profile.d/conda.sh
   conda activate clair3

   /opt/bin/run_clair3.sh \
    --bam_fn=$occ_bam \
    --ref_fn=$reference_genome  \
    --threads=8 \
    --var_pct_full=1 \
    --ref_pct_full=1 \
    --var_pct_phasing=1 \
    --platform="ont" \
    --no_phasing_for_fa \
    --model_path=/home/godzilla/nWGS_pipeline/data/reference/r1041_e82_400bps_sup_v420 \
    --output=output_clair3
 
 convert2annovar.pl output_clair3/pileup.vcf.gz \
    --format vcf4 \
	--withfreq \
	--filter pass \
	--fraction 0.1 \
	--includeinfo \
	--outfile ${sample_id}_occ_pileup_snvs_avinput

   
   table_annovar.pl  ${sample_id}_occ_pileup_snvs_avinput \
         -outfile occ_pileup \
         -buildver hg38 -protocol refGene,clinvar_20240611,cosmic100coding2024\
         -operation g,f,f \
         ${params.humandb_dir} \
         -otherinfo
      
    awk '/exonic/ && /nonsynonymous/ && !/Benign/ && !/Likely_benign/|| /upstream/ || /Func.refGene/ || /splicing/ && !/Benign/ && !/Likely_benign/ || /Pathogenic/' occ_pileup.hg38_multianno.txt \
| awk '/exonic/ || /TERT/ || /Func.refGene/ || /Pathogenic/'  \
| awk '!/dist=166/' \
| cut -f1-16,26,28,29 > ${sample_id}_occ_pileup_annotateandfilter.csv

convert2annovar.pl \
    output_clair3/merge_output.vcf.gz \
    --format vcf4 \
    --withfreq \
    --filter pass \
    --fraction 0.1 \
    --includeinfo \
    --outfile ${sample_id}_occ_merge_snv_avinpt

table_annovar.pl ${sample_id}_occ_merge_snv_avinpt \
    -outfile occ_merge \
    -buildver hg38 -protocol refGene,clinvar_20240611,cosmic100coding2024\
    -operation g,f,f \
    ${params.humandb_dir} \
    -otherinfo

    awk '/exonic/ && /nonsynonymous/ && !/Benign/ && !/Likely_benign/|| /upstream/ || /Func.refGene/ || /splicing/ && !/Benign/ && !/Likely_benign/ || /frameshift/ && !/Benign/ && !/Likely_benign/ || /stopgain/ && !/Benign/ && !/Likely_benign/ || /Pathogenic/' \
     occ_merge.hg38_multianno.txt \
    | awk '/exonic/ || /TERT/ || /Func.refGene/ || /Pathogenic/'  \
    | awk '!/dist=166/' \
    | cut -f1-16,26,28,29 \
    > ${sample_id}_merge_annotateandfilter.csv

    cp occ_merge.hg38_multianno.txt ${sample_id}_occ_merge.hg38_multianno.txt
    
    # remove tmp folder

    rm -rf output_clair3/tmp*
    """
   }



// Somatic variant calling using ClairS-TO for tumor-only samples
process clairs_to {
    label 'clairsto'
    publishDir "${params.path}/routine_epi2me/${sample_id}", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(occ_bam), path(occ_bam_bai), path(reference_genome), path(reference_genome_bai),  path(refGene), path(hg38_refGeneMrna), path(clinvar), path(clinvarindex),path(hg38_cosmic100),path(hg38_cosmic100index), path(occ_protein_coding_bed)
    
    output:
    tuple val(sample_id), path('clairsto_output/')
    tuple val(sample_id), path("${sample_id}_clairS_To_snv_avinput")
    tuple val(sample_id), path("${sample_id}_ClairS_TO_snv.hg38_multianno.txt")
    tuple val(sample_id), path("${sample_id}_annotateandfilter_clairsto.csv"), emit:annotateandfilter_clairstoout
    tuple val(sample_id), path("${sample_id}_merge_snv_indel_claisto.vcf.gz"), emit: clairsto_merged_vcf

    script:
    """
    # Set micromamba environment variables
    export MAMBA_ROOT_PREFIX=/opt/micromamba
    export MAMBA_EXE=/opt/micromamba/bin/micromamba

    # Set MKL variables before activation
    export MKL_INTERFACE_LAYER=LP64
    export MKL_THREADING_LAYER=SEQUENTIAL
    
    # Activate conda environment
    source /opt/micromamba/etc/profile.d/micromamba.sh
    micromamba activate clairs-to

    /opt/bin/run_clairs_to \
        --tumor_bam_fn=${occ_bam} \
        --ref_fn=${reference_genome} \
        --threads=${task.cpus} \
        --platform="ont_r10_dorado_4khz" \
        --output_dir=clairsto_output \
        --bed_fn=${occ_protein_coding_bed} \
        --conda_prefix /opt/micromamba/envs/clairs-to

    bcftools concat -a -d all clairsto_output/snv.vcf.gz clairsto_output/indel.vcf.gz -Oz -o ${sample_id}_merge_snv_indel_claisto.vcf.gz

    convert2annovar.pl ${sample_id}_merge_snv_indel_claisto.vcf.gz \
   --format vcf4 \
   --filter pass \
   --includeinfo \
   --outfile  ${sample_id}_clairS_To_snv_avinput


  table_annovar.pl ${sample_id}_clairS_To_snv_avinput \
   -outfile ClairS_TO_snv \
   -buildver hg38 -protocol refGene,clinvar_20240611,cosmic100coding2024\
   -operation g,f,f \
    ${params.humandb_dir} \
   -otherinfo  

   awk '/exonic/ && /nonsynonymous/ && !/Benign/ && !/Likely_benign/|| /upstream/ || /Func.refGene/ || /splicing/ && !/Benign/ && !/Likely_benign/ || /frameshift/ && !/Benign/ && !/Likely_benign/ || /stopgain/ && !/Benign/ && !/Likely_benign/ || /Pathogenic/' \
   ClairS_TO_snv.hg38_multianno.txt \
   | awk '/exonic/ || /TERT/ || /Func.refGene/ || /Pathogenic/'  \
  | awk '!/dist=166/' \
  | cut -f1-16,25,26  > ${sample_id}_annotateandfilter_clairsto.csv

   cp ClairS_TO_snv.hg38_multianno.txt ${sample_id}_ClairS_TO_snv.hg38_multianno.txt
 
    # remove tmp folder

   rm -rf clairsto_output/tmp*
    """
   }

// Merge and filter annotations from Clair3 and ClairS-TO results
process merge_annotation {
    debug true
    label 'merge_annotation'
    publishDir "${params.output_path}/${sample_id}/merge_annot_clair3andclairsto/", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(merge_file), path(pileup_file), path(clairsto_file), path(occ_genes)
    
    output:
    //tuple val(sample_id), path("${sample_id}_merge_annotation_filter_snvs_allcall_filter.csv")
    tuple val(sample_id), path("${sample_id}_merge_annotation_filter_snvs_allcall.csv"), emit: occmergeout
    

    script:
    """
    #!/bin/bash
    set -e  # Exit on error

    echo "Input files:"
    echo "Sample ID: ${sample_id}"
    echo "Merge file: ${merge_file}"
    echo "Pileup file: ${pileup_file}"
    echo "ClairSTo file: ${clairsto_file}"
    echo "OCC genes file: ${occ_genes}"

    merge_annotations_prospective.R \\
        "${merge_file}" \\
        "${pileup_file}" \\
        "${clairsto_file}" \\
        "${sample_id}_merge_annotation_filter_snvs_allcall.csv" \\
        "${occ_genes}" \\
        ${sample_id}_merge_annotation_filter_snvs_allcall_filter.csv

    """
}


// TERT promoter variant visualization using IGV tools
process igv_tools {
    label 'epic'
    publishDir "${params.output_path}/${sample_id}/coverage", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(occ_bam), path(occ_bam_bai), path(tertp_variants), path(ncbirefseq), path(reference_genome), path(reference_genome_bai)

    output:
    tuple val(sample_id), file("${sample_id}_tertp_id1.html"), emit: tertp_out_igv

    script:
    """
    # Activate conda environment in the container
    source /opt/conda/etc/profile.d/conda.sh
    conda activate base
    
    export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    create_report $tertp_variants --fasta $reference_genome --flanking 1000 --tracks $tertp_variants $occ_bam $ncbirefseq --output ${sample_id}_tertp_id1.html
    ##cp "${sample_id}_tertp_id1.html" "${params.output_path}/report/${sample_id}_tertp_id1.html"
    """
}

// Quality assessment and statistics using Cramino
process cramino_report {
        label 'epic'
        publishDir "${params.output_path}/${sample_id}/cramino", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(merge_bam), path(merge_bam_bai), path(reference_genome), path(reference_genome_bai)

    output:
    tuple val(sample_id), file("${sample_id}_cramino_statistics.txt"), emit:craminostatout
    
    script:
    """
   ### source /opt/conda/etc/profile.d/conda.sh
    ### conda init
    ### conda activate annotatecnv_env

      #!/bin/bash
    set -e
    
    # Check if we're in a container and use appropriate conda setup
    if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
        # Container environment
    source /opt/conda/etc/profile.d/conda.sh
    conda activate annotatecnv_env
    else
        # Local environment
        source activate annotatecnv_env
    fi
    cramino $merge_bam --reference $reference_genome > ${sample_id}_cramino_statistics.txt
   """
    }

// Genomic region coverage plotting for EGFR, IDH1, and TERTp
process plot_genomic_regions {
    publishDir "${params.output_path}/${sample_id}/coverage", mode: 'copy'
    label 'gviz'
    
    input:
    tuple val(sample_id), 
          path(gviz_data),
          path(bam_file),
          path(bam_index),
          path(cytoband_file)

    output:
    tuple val(sample_id), 
          path("${sample_id}_egfr_coverage.pdf"),
          path("${sample_id}_idh1_coverage.pdf"),
          path("${sample_id}_tertp_coverage.pdf"),
          path("${sample_id}_idh2_coverage.pdf"),
          emit: plot_genomic_regions_out

    script:
    """
    #!/bin/bash
    ls -l
    echo "Rscript path: \$(which Rscript)"
    echo "GViz file: ${gviz_data}"
    eval \"\$(micromamba shell hook --shell bash)\"
    micromamba activate gviz_env
    plot_genomic_regions.R \
        "${gviz_data}" \
        "${sample_id}" \
        "${bam_file}" \
        "${sample_id}_egfr_coverage.pdf" \
        "${sample_id}_idh1_coverage.pdf" \
        "${sample_id}_idh2_coverage.pdf" \
        "${sample_id}_tertp_coverage.pdf" \
        "${cytoband_file}"
    """
}

// Comprehensive PDF report generation using R Markdown
process markdown_report {
    publishDir "${params.result_path}/${sample_id}", mode: "copy", overwrite: true, pattern: "*.pdf"

    input:
    tuple val(sample_id),
          path(craminoreport),
          val(sample_id_file),
          path(dictionaire),
          path(logo),
          path(cnv_plot),
          path(tumor_number),
          path(annotatecnv),
          path(cnv_chr9),
          path(cnv_chr7),
          path(mgmt_results),
          path(merge_results),
          path(fusion_events),
          path(svannahtml),
          path(tertphtml),
          path(egfr_coverage),
          path(idh1_coverage),
          path(idh2_coverage),
          path(tertp_coverage),
          path(tsne_plot_file),
          path(nanodx_classifier),
          path(snv_target_genes),
          path(protein_coding_bed),
          path(rmd_template)

    output:
    file("${sample_id}_markdown_pipeline_report.pdf")

    script:
    """
    # Output PDF path
    output_file="${sample_id}_markdown_pipeline_report.pdf"

    # Handle different run modes
    if [ "${params.run_mode_order}" = "true" ]; then
        # For run_mode_order: Create sample_file.txt with sample_id and threshold_value
        THRESHOLD_VALUE=""
        if [ -f "${params.output_path}/${sample_id}/cnv/ace/${sample_id}_ace_results/threshold_value.txt" ]; then
            THRESHOLD_VALUE=\$(cat "${params.output_path}/${sample_id}/cnv/ace/${sample_id}_ace_results/threshold_value.txt")
            # Create sample_file.txt
            echo -e "${sample_id}\\t\${THRESHOLD_VALUE}" > sample_file.txt
            echo "Created sample_file.txt for run_mode_order with: ${sample_id} \${THRESHOLD_VALUE}"
            SAMPLE_FILE="\${PWD}/sample_file.txt"
        else
            echo "ERROR: ACE threshold file not found for ${sample_id} at ${params.output_path}/${sample_id}/cnv/ace/${sample_id}_ace_results/threshold_value.txt"
            exit 1
        fi
    else
        # For run_mode_analysis: Check if user provided tumor content first (takes priority)
        if [ ! -f "${sample_id_file}" ]; then
            echo "ERROR: Sample ID file not found: ${sample_id_file}"
            exit 1
        fi

        # Count columns in the sample_id_file
        NUM_COLS=\$(awk '{print NF; exit}' "${sample_id_file}")
        echo "Detected \$NUM_COLS columns in sample_id_file: ${sample_id_file}"

        if [ "\$NUM_COLS" -ge 2 ]; then
            # User provided 2 columns (sample_id + tumor content) - use user-provided value
            # Extract the line for this sample_id
            grep "^${sample_id}[[:space:]]" "${sample_id_file}" > sample_file.txt || {
                echo "WARNING: Sample ${sample_id} not found in ${sample_id_file}, creating file with sample_id only"
                echo "${sample_id}" > sample_file.txt
            }
            SAMPLE_FILE="\${PWD}/sample_file.txt"
            echo "Created local sample_file.txt with user-provided tumor content:"
            cat "\${SAMPLE_FILE}"
        elif [ -f "${params.output_path}/${sample_id}/cnv/ace/${sample_id}_ace_results/threshold_value.txt" ]; then
            # User provided only 1 column, but ACE results available - use ACE-calculated value
            THRESHOLD_VALUE=\$(cat "${params.output_path}/${sample_id}/cnv/ace/${sample_id}_ace_results/threshold_value.txt")
            echo -e "${sample_id}\\t\${THRESHOLD_VALUE}" > sample_file.txt
            echo "Created sample_file.txt with ACE-calculated tumor content: ${sample_id} \${THRESHOLD_VALUE}"
            SAMPLE_FILE="\${PWD}/sample_file.txt"
        else
            # Only 1 column and no ACE results - copy as-is
            cp "${sample_id_file}" sample_file.txt
            SAMPLE_FILE="\${PWD}/sample_file.txt"
            echo "Created local sample_file.txt (single column, no tumor content)"
            cat "\${SAMPLE_FILE}"
        fi
    fi

    # Now call the Rscript with the updated Rmd file using absolute paths
    # Activate conda environment and find Rscript
    source /opt/conda/etc/profile.d/conda.sh
    conda activate markdown_env
    
    # Try to find Rscript
    RSCRIPT_PATH=""
    if command -v Rscript >/dev/null 2>&1; then
        RSCRIPT_PATH="Rscript"
    elif [ -f "/opt/conda/envs/markdown_env/bin/Rscript" ]; then
        RSCRIPT_PATH="/opt/conda/envs/markdown_env/bin/Rscript"
    elif [ -f "/opt/conda/bin/Rscript" ]; then
        RSCRIPT_PATH="/opt/conda/bin/Rscript"
    elif [ -f "/usr/local/bin/Rscript" ]; then
        RSCRIPT_PATH="/usr/local/bin/Rscript"
    elif [ -f "/usr/bin/Rscript" ]; then
        RSCRIPT_PATH="/usr/bin/Rscript"
    else
        echo "ERROR: Rscript not found. Available R-related files:"
        find /opt/conda -name "*R*" 2>/dev/null | head -10
        find /usr -name "*Rscript*" 2>/dev/null | head -10
        exit 1
    fi
    
    echo "Using Rscript at: \$RSCRIPT_PATH"

    \$RSCRIPT_PATH -e "rmarkdown::render('\${PWD}/${rmd_template}', output_file=commandArgs(trailingOnly=TRUE)[24])" \
      "${sample_id}" \
      "\${PWD}/${craminoreport}" \
      "\${SAMPLE_FILE}" \
      "\${PWD}/${nanodx_classifier}" \
      "\${PWD}/${dictionaire}" \
      "\${PWD}/${logo}" \
      "\${PWD}/${cnv_plot}" \
      "\${PWD}/${tumor_number}" \
      "\${PWD}/${annotatecnv}" \
      "\${PWD}/${cnv_chr9}" \
      "\${PWD}/${cnv_chr7}" \
      "\${PWD}/${mgmt_results}" \
      "\${PWD}/${merge_results}" \
      "\${PWD}/${fusion_events}" \
      "\${PWD}/${tertphtml}" \
      "\${PWD}/${svannahtml}" \
      "\${PWD}/${egfr_coverage}" \
      "\${PWD}/${idh1_coverage}" \
      "\${PWD}/${idh2_coverage}" \
      "\${PWD}/${tertp_coverage}" \
      "\${PWD}/${tsne_plot_file}" \
      "\${PWD}/${snv_target_genes}" \
      "\${PWD}/${protein_coding_bed}" \
      "\${PWD}/\${output_file}" \
      "${workflow.manifest.version}"

    # Clean up intermediate files and folders created by R Markdown (belt and suspenders)
    echo "Cleaning up intermediate R Markdown files..."
    rm -rf *_files *.html *.log *.tex *_cache 2>/dev/null || true

    echo "RMD report generated successfully"


    # This removes any intermediate files that might have been published before pattern filter
    echo "Final cleanup of report directory..."
    find ${params.output_path}/report -type d -name "*_files" -exec rm -rf {} + 2>/dev/null || true
    find ${params.output_path}/report -type f -name "*.tex" -delete 2>/dev/null || true
    find ${params.output_path}/report -type f -name "*.html" -delete 2>/dev/null || true
    find ${params.output_path}/report -type f -name "*.log" -delete 2>/dev/null || true
    echo "Cleanup complete - only PDF files remain"
    """
}


// ACE tumor content calculation and copy number analysis
process ace_tmc {
    label 'ace_tmc'
    publishDir "${params.output_path}/${sample_id}/cnv/ace/", mode: "copy", overwrite: true
    
    input:
    tuple val(sample_id), path(rds_file)
    
    output:
        tuple val(sample_id), path("${sample_id}_ace_results"), emit: aceresults
    tuple val(sample_id), env(threshold_value), emit: threshold_value
    
    script:
    """
    #!/bin/bash
    set -e

    # Check if we're in a container and use appropriate conda setup
    if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
        source /opt/conda/etc/profile.d/conda.sh
        conda activate ace_env
    else
    source activate ace_env
    fi
    
    # Debug info
    echo "Processing sample: ${sample_id}"
    echo "Input RDS file: ${rds_file}"
    ls -l ${rds_file}

    # Create output directory
    mkdir -p ${sample_id}_ace_results
    
    # Run ACE TMC analysis
    ace_tmc.R "${rds_file}" "${sample_id}_ace_results" "${sample_id}"
    
    # Read and export the threshold value
    threshold_value=\$(cat "${sample_id}_ace_results/threshold_value.txt")
    echo "Threshold value for ${sample_id}: \$threshold_value"
    """
}

//---------------------------------------------------------------------
// Static Reference File Channels (Module Level - Created Once)
//---------------------------------------------------------------------
// Create value channels for static reference files at module level
// to prevent cache invalidation. These are created ONCE when the module
// is loaded, not every time the workflow runs for a new sample.

def occ_protein_coding_bed_ch = Channel.value(file(params.occ_protein_coding_bed))
def nanodx_450model_ch = Channel.value(file(params.nanodx_450model))
def snakefile_nanodx_ch = Channel.value(file(params.snakefile_nanodx))
def nn_model_ch = Channel.value(file(params.nn_model))
def nanodxcolormap_ch = Channel.value(file(params.nanodxcolormap))
def nanodxh5_ch = Channel.value(file(params.nanodxh5))
def hg19_450model_ch = Channel.value(file(params.hg19_450model))
def vcf2circos_json_ch = Channel.value(file(params.vcf2circos_json))
def genecode_bed_ch = Channel.value(file(params.genecode_bed))
def occ_fusion_genes_list_ch = Channel.value(file(params.occ_fusion_genes_list))
def occ_genes_ch = Channel.value(file(params.occ_genes))
def refgene_ch = Channel.value(file(params.refgene))
def hg38_refgenemrna_ch = Channel.value(file(params.hg38_refgenemrna))
def clinvar_ch = Channel.value(file(params.clinvar))
def clinvarindex_ch = Channel.value(file(params.clinvarindex))
def hg38_cosmic100_ch = Channel.value(file(params.hg38_cosmic100))
def hg38_cosmic100index_ch = Channel.value(file(params.hg38_cosmic100index))
def tertp_variants_ch = Channel.value(file(params.tertp_variants))
def ncbirefseq_ch = Channel.value(file(params.ncbirefseq))
def gviz_data_ch = Channel.value(file(params.gviz_data))
def cytoband_file_ch = Channel.value(file(params.cytoband_file))
def epicsites_ch = Channel.value(file(params.epicsites))
def mgmt_cpg_island_hg38_ch = Channel.value(file(params.mgmt_cpg_island_hg38))
def sturgeon_model_ch = Channel.value(file(params.sturgeon_model))

//---------------------------------------------------------------------
// Workflow definition
//---------------------------------------------------------------------

workflow analysis {
    take:
        input_data

    main:
        validateParameters()

        // Define fusion events channel conditionally to avoid undefined output errors
        def fusion_events_channel = Channel.empty()


        // Initialize channels as empty by default
        def annotatecnv_out = Channel.empty()
        def merge_annotation_out = Channel.empty()
        def run_nn_classifier_out = Channel.empty()
        def mgmt_promoter_out = Channel.empty()
        def svannasv_out = Channel.empty()
        def igv_tools_out = Channel.empty()
        def cramino_report_out = Channel.empty()

        // NOTE: Static reference file channels are now defined at module level (before workflow block)
        // to ensure they're created once and reused across all samples for optimal caching

        // Initialize sample_thresholds based on run mode
        def sample_thresholds = (params.run_mode_order || params.run_mode_epianalyse) ? [:] : loadSampleThresholds()
        println "Sample thresholds: ${sample_thresholds}"

        // Create segsfromepi2me channel based on mode
        boosts_segsfromepi2me_channel = (params.run_mode_order || params.run_mode_epianalyse) ?
            input_data.combine(occ_protein_coding_bed_ch).map { args ->
                def sample_id = args[0]
                def bam = args[1]
                def bai = args[2]
                def ref = args[3]
                def ref_bai = args[4]
                def tr_bed = args[5]
                def modkit = args[6]
                def segs_bed = args[7]
                def bins_bed = args[8]
                def segs_vcf = args[9]
                def rds_file = args[10]
                def sv = args[11]
                def occ_bed = args[12]

                tuple(
                    sample_id,
                    segs_vcf,
                    occ_bed,
                    bins_bed,
                    segs_bed,
                    sample_thresholds[sample_id]
                )
            } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .combine(occ_protein_coding_bed_ch)
                .map { sample_id, occ_bed ->
                    tuple(
                        sample_id,
                        file("${params.segsfromepi2me_folder}/${sample_id}/${sample_id}_segs.vcf"),
                        occ_bed,
                        file("${params.segsfromepi2me_folder}/${sample_id}/${sample_id}_bins.bed"),
                        file("${params.segsfromepi2me_folder}/${sample_id}/${sample_id}_segs.bed"),
                        sample_thresholds[sample_id]
                    )
                }

        boosts_svanna_channel = (params.run_mode_order || params.run_mode_epianalyse) ?
            input_data.combine(occ_protein_coding_bed_ch).map { args ->
                def sample_id = args[0]
                def bam = args[1]
                def bai = args[2]
                def ref = args[3]
                def ref_bai = args[4]
                def tr_bed = args[5]
                def modkit = args[6]
                def segs_bed = args[7]
                def bins_bed = args[8]
                def segs_vcf = args[9]
                def rds_file = args[10]
                def sv = args[11]
                def occ_bed = args[12]

                //log.info "Creating Svanna input for sample: ${sample_id} (order mode)"
                //log.info "SV file path: ${sv}"

                // Create index file path from the published SV file location
                def sv_file = file("${params.path}/routine_epi2me/${sample_id}/${sample_id}.sniffles.vcf.gz")
                def sv_index = file("${params.path}/routine_epi2me/${sample_id}/${sample_id}.sniffles.vcf.gz.tbi")

                tuple(
                    sample_id,
                    sv_file,               // SV VCF file from epi2me
                    sv_index,              // Index file
                    occ_bed
                )
            } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .combine(occ_protein_coding_bed_ch)
                .map { sample_id, occ_bed ->
                    //log.info "Creating Svanna input for sample: ${sample_id} (standalone mode)"
                    def sv_file = file("${params.sv_folder}/${sample_id}/${sample_id}.sniffles.vcf.gz")

                    //if (!sv_file.exists()) {
                    //    error "SV file not found: ${sv_file}"
                    //}

                    tuple(
                        sample_id,
                        sv_file,
                        file("${sv_file}.tbi"),
                        occ_bed
                    )
                }

        boosts_clair3_channel = (params.run_mode_order || params.run_mode_epianalyse) ?
            input_data.combine(refgene_ch).combine(hg38_refgenemrna_ch).combine(clinvar_ch)
                .combine(clinvarindex_ch).combine(hg38_cosmic100_ch).combine(hg38_cosmic100index_ch)
                .map { args ->
                def sample_id = args[0]
                def bam = args[1]
                def bai = args[2]
                def ref = args[3]
                def ref_bai = args[4]
                def tr_bed = args[5]
                def modkit = args[6]
                def segs_bed = args[7]
                def bins_bed = args[8]
                def segs_vcf = args[9]
                def rds_file = args[10]
                def sv = args[11]
                def refgene = args[12]
                def refgenemrna = args[13]
                def clinvar = args[14]
                def clinvarindex = args[15]
                def cosmic100 = args[16]
                def cosmic100index = args[17]

                tuple(
                    sample_id,
                    bam,
                    bai,
                    ref,
                    ref_bai,
                    refgene,
                    refgenemrna,
                    clinvar,
                    clinvarindex,
                    cosmic100,
                    cosmic100index
                )
            } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .combine(refgene_ch).combine(hg38_refgenemrna_ch).combine(clinvar_ch)
                .combine(clinvarindex_ch).combine(hg38_cosmic100_ch).combine(hg38_cosmic100index_ch)
                .map { sample_id, refgene, refgenemrna, clinvar, clinvarindex, cosmic100, cosmic100index ->
                    tuple(
                        sample_id,
                        file("${params.occ_bam_folder}/${sample_id}.roi.bam"),
                        file("${params.occ_bam_folder}/${sample_id}.roi.bam.bai"),
                        file(params.reference_genome),
                        file(params.reference_genome_bai),
                        refgene,
                        refgenemrna,
                        clinvar,
                        clinvarindex,
                        cosmic100,
                        cosmic100index
                    )
                }

        boosts_clairSTo_channel = (params.run_mode_order || params.run_mode_epianalyse) ?
            input_data.combine(refgene_ch).combine(hg38_refgenemrna_ch).combine(clinvar_ch)
                .combine(clinvarindex_ch).combine(hg38_cosmic100_ch).combine(hg38_cosmic100index_ch)
                .combine(occ_protein_coding_bed_ch).map { args ->
                def sample_id = args[0]
                def bam = args[1]
                def bai = args[2]
                def ref = args[3]
                def ref_bai = args[4]
                def tr_bed = args[5]
                def modkit = args[6]
                def segs_bed = args[7]
                def bins_bed = args[8]
                def segs_vcf = args[9]
                def rds_file = args[10]
                def sv = args[11]
                def refgene = args[12]
                def refgenemrna = args[13]
                def clinvar = args[14]
                def clinvarindex = args[15]
                def cosmic100 = args[16]
                def cosmic100index = args[17]
                def occ_bed = args[18]

                tuple(
                    sample_id,
                    bam,
                    bai,
                    ref,
                    ref_bai,
                    refgene,
                    refgenemrna,
                    clinvar,
                    clinvarindex,
                    cosmic100,
                    cosmic100index,
                    occ_bed
                )
            } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .combine(refgene_ch).combine(hg38_refgenemrna_ch).combine(clinvar_ch)
                .combine(clinvarindex_ch).combine(hg38_cosmic100_ch).combine(hg38_cosmic100index_ch)
                .combine(occ_protein_coding_bed_ch)
                .map { sample_id, refgene, refgenemrna, clinvar, clinvarindex, cosmic100, cosmic100index, occ_bed ->
                    tuple(
                        sample_id,
                        file("${params.occ_bam_folder}/${sample_id}.roi.bam"),
                        file("${params.occ_bam_folder}/${sample_id}.roi.bam.bai"),
                        file(params.reference_genome),
                        file(params.reference_genome_bai),
                        refgene,
                        refgenemrna,
                        clinvar,
                        clinvarindex,
                        cosmic100,
                        cosmic100index,
                        occ_bed

                    )
                }

        boosts_igv_channel = (params.run_mode_order || params.run_mode_epianalyse) ?
            input_data.combine(tertp_variants_ch).combine(ncbirefseq_ch).map { args ->
                def sample_id = args[0]
                def bam = args[1]
                def bai = args[2]
                def ref = args[3]
                def ref_bai = args[4]
                def tr_bed = args[5]
                def modkit = args[6]
                def segs_bed = args[7]
                def bins_bed = args[8]
                def segs_vcf = args[9]
                def rds_file = args[10]
                def sv = args[11]
                def tertp_var = args[12]
                def ncbi = args[13]

                tuple(sample_id, bam, bai, tertp_var, ncbi, ref, ref_bai)
            } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .combine(tertp_variants_ch).combine(ncbirefseq_ch)
                .map { sample_id, tertp_var, ncbi ->
                    tuple(sample_id, file("${params.occ_bam_folder}/${sample_id}.roi.bam"),
                          file("${params.occ_bam_folder}/${sample_id}.roi.bam.bai"),
                          tertp_var,
                          ncbi,
                          file(params.reference_genome),
                          file("${params.reference_genome}.fai"))
                }

        boosts_plot_genomic_regions_channel = (params.run_mode_order || params.run_mode_epianalyse) ?
            input_data.combine(gviz_data_ch).combine(cytoband_file_ch).map { args ->
                def sample_id = args[0]
                def bam = args[1]
                def bai = args[2]
                def ref = args[3]
                def ref_bai = args[4]
                def tr_bed = args[5]
                def modkit = args[6]
                def segs_bed = args[7]
                def bins_bed = args[8]
                def segs_vcf = args[9]
                def rds_file = args[10]
                def sv = args[11]
                def gviz = args[12]
                def cytoband = args[13]

                tuple(
                    sample_id,
                    gviz,
                    bam,
                    bai,
                    cytoband
                )
            } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .combine(gviz_data_ch).combine(cytoband_file_ch)
                .map { sample_id, gviz, cytoband ->
                    tuple(
                        sample_id,
                        gviz,
                        file("${params.occ_bam_folder}/${sample_id}.roi.bam"),
                        file("${params.occ_bam_folder}/${sample_id}.roi.bam.bai"),
                        cytoband
                    )
                }

        boosts_cramino = (params.run_mode_order || params.run_mode_epianalyse) ?
            input_data.map { args ->
                def sample_id = args[0]
                def occ_bam = args[1]    
                def occ_bai = args[2]
                def ref = args[3]
                def ref_bai = args[4]

                // IMPORTANT: Cramino should analyze the FULL merged BAM, not the ROI BAM
                // Read merged BAM from published directory
                def bam_file = file("${params.merge_bam_folder}/${sample_id}.merged.bam")
                def bai_file = file("${params.merge_bam_folder}/${sample_id}.merged.bam.bai")

                // If exact match doesn't exist, try .merge.bam specifically (legacy)
                if (!bam_file.exists()) {
                    bam_file = file("${params.merge_bam_folder}/${sample_id}.merged.bam")
                    bai_file = file("${params.merge_bam_folder}/${sample_id}.merged.bam.bai")
                }

                // If still not found, try wildcard but exclude .roi.bam files
                if (!bam_file.exists()) {
                    def pattern_files = file("${params.merge_bam_folder}/${sample_id}.*.bam")
                    def potential_bams = pattern_files instanceof List ? pattern_files : [pattern_files]
                    // Filter out .roi.bam files
                    def filtered_bams = potential_bams.findAll { !it.name.contains('.roi.') }
                    if (filtered_bams.size() > 0) {
                        bam_file = filtered_bams[0]
                        bai_file = file("${bam_file}.bai")
                    }
                }

                // Only return valid tuples
                if (bam_file.exists() && bai_file.exists()) {
                    tuple(
                        sample_id,
                        bam_file,    // ← Now using merged BAM
                        bai_file,
                        ref,
                        ref_bai
                    )
                } else {
                    println "WARNING: Cramino - Merged BAM file not found for ${sample_id}. Tried: ${sample_id}.merged.bam, ${sample_id}.merge.bam, ${sample_id}.*.bam"
                    null
                }
            }
            .filter { it != null } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .map { sample_id -> 
                    // Try exact match first, then wildcard pattern (avoid .roi.bam files)
                    def bam_file = file("${params.merge_bam_folder}/${sample_id}.merged.bam")
                    def bai_file = file("${params.merge_bam_folder}/${sample_id}.merged.bam.bai")

                    // If exact match doesn't exist, try .merge.bam specifically (legacy)
                    if (!bam_file.exists()) {
                        bam_file = file("${params.merge_bam_folder}/${sample_id}.merge.bam")
                        bai_file = file("${params.merge_bam_folder}/${sample_id}.merge.bam.bai")
                    }

                    // If still not found, try wildcard but exclude .roi.bam files
                    if (!bam_file.exists()) {
                        def pattern_files = file("${params.merge_bam_folder}/${sample_id}.*.bam")
                        def potential_bams = pattern_files instanceof List ? pattern_files : [pattern_files]
                        // Filter out .roi.bam files
                        def filtered_bams = potential_bams.findAll { !it.name.contains('.roi.') }
                        if (filtered_bams.size() > 0) {
                            bam_file = filtered_bams[0]
                            bai_file = file("${bam_file}.bai")
                        }
                    }

                    // Only process samples that have corresponding BAM files
                    if (bam_file.exists() && bai_file.exists()) {
                        tuple(
                            sample_id,
                            bam_file,
                            bai_file,
                            file(params.reference_genome, checkIfExists: true),
                            file("${params.reference_genome}.fai", checkIfExists: true)
                        )
                    } else {
                        println "WARNING: Skipping sample ${sample_id} - BAM file not found. Tried: ${sample_id}.merged.bam, ${sample_id}.merge.bam, ${sample_id}.*.bam (excluding .roi.bam)"
                        null
                    }
                }
                .filter { it != null }

        // MGMT analysis
        if (params.run_mode in ['mgmt', 'all']) {
            println "Running MGMT Analysis..."
            
            // Create MGMT channel that works for combined modes (order and epianalyse)
            mgmt_ch = (params.run_mode_order || params.run_mode_epianalyse) ?
                input_data.combine(epicsites_ch).combine(mgmt_cpg_island_hg38_ch).map { args ->
                    def sample_id = args[0]
                    def bam = args[1]
                    def bai = args[2]
                    def ref = args[3]
                    def ref_bai = args[4]
                    def tr_bed = args[5]
                    def modkit = args[6]
                    def segs_bed = args[7]
                    def bins_bed = args[8]
                    def segs_vcf = args[9]
                def rds_file = args[10]
                    def sv = args[11]
                    def epicsites = args[12]
                    def mgmt_cpg = args[13]

                    tuple(
                        sample_id,
                        modkit,
                        epicsites,
                        mgmt_cpg
                    )
                } :
                Channel.fromList(sample_thresholds.keySet().collect())
                    .combine(epicsites_ch).combine(mgmt_cpg_island_hg38_ch)
                    .map { sample_id, epicsites, mgmt_cpg ->
                        tuple(
                            sample_id,
                            file("${params.bedmethyl_folder}/${sample_id}/${sample_id}.wf_mods.bedmethyl.gz"),
                            epicsites,
                            mgmt_cpg
                        )
                    }
            
            // Run MGMT related processes
            extract_epic(mgmt_ch)
            
            // Create channels for downstream processes
            MGMT_output = extract_epic.out.MGMTheaderout
            
            MGMT_sturgeon = extract_epic.out.sturgeonbedinput
                 .combine(sturgeon_model_ch)
                 .map { sample_id, sturgeoninput, sturgeon_model ->
                     tuple(sample_id, sturgeoninput, sturgeon_model)
                 }

            mgmt_nanodx = extract_epic.out.epicselectnanodxinput
                .combine(hg19_450model_ch)
                .map { sample_id, epicselectnanodxinput, hg19_model ->
                    tuple(sample_id, epicselectnanodxinput, hg19_model)
                }

            // Run the processes
            sturgeon(MGMT_sturgeon)
            mgmt_promoter(MGMT_output)
            nanodx(mgmt_nanodx)

            nanodx_out = nanodx.out.nanodx450out
                .combine(nanodx_450model_ch).combine(snakefile_nanodx_ch).combine(nn_model_ch)
                .map { sample_id, nanodx450out, nanodx_model, snakefile, nn_model ->
                    tuple(
                        sample_id,
                        nanodx450out,
                        nanodx_model,
                        snakefile,
                        nn_model
                    )
                }

            run_nn_classifier(nanodx_out)

            // Generate t-SNE plot using EPIC bed files
            tsne_plot(
                extract_epic.out.epicselectnanodxinput,
                nanodxcolormap_ch,
                nanodxh5_ch
            )
        }

        // Svanna analysis
        if (params.run_mode in ['svannasv', 'all']) {
            println "Running Svanna Analysis..."
            
            svannasv(boosts_svanna_channel)
            svannasv_out = svannasv.out.occsvannaannotationannotationvcf
                .combine(vcf2circos_json_ch)
                .map{ sample_id, svannavcfoutput, vcf2circos ->
                [sample_id, svannavcfoutput, vcf2circos]
            }
            circosplot(svannasv_out)
            circosplot_out=circosplot.out.circosout
            svannaoutfusion_events= svannasv.out.occsvannaannotationannotationvcf
                .combine(genecode_bed_ch).combine(occ_fusion_genes_list_ch)
                .map{ sample_id, occsvannaannotationannotationvcf, genecode, fusion_genes ->
                [sample_id, occsvannaannotationannotationvcf, genecode, fusion_genes]
            }
            svannasv_fusion_events(svannaoutfusion_events)
            
            // Assign fusion events channel when SV analysis is run
            fusion_events_channel = svannasv_fusion_events.out.filterfusioneventout
        }

        // OCC analysis
        if (params.run_mode in ['occ', 'all']) {
            println "Running OCC Analysis..."
            
            // Run variant callers and get outputs
            clair3(boosts_clair3_channel)
            
            
            // Create properly structured channels for combination
            def clair3_results = clair3.out.clair3output
                .map { args -> 
                    def sample_id = args[0]
                    def pileup_file = args[1]
                    def merge_file = args[2]
                    tuple(sample_id, pileup_file, merge_file)
                }
                .view { "Clair3 mapped: $it" }

            clairs_to(boosts_clairSTo_channel)
            def clairsto_results = clairs_to.out.annotateandfilter_clairstoout
                .view { "ClairSTo output: $it" }

            // Combine results and create input for merge_annotation
            combine_file = clair3_results
                .combine(clairsto_results, by: 0)
                .combine(occ_genes_ch)
                .map { sample_id, pileup_file, merge_file, clairsto_file, occ_genes ->
                    println "Creating merge input for sample: $sample_id"
                    tuple(
                        sample_id,
                        merge_file,
                        pileup_file,
                        clairsto_file,
                        occ_genes
                    )
                }
                .view { "Merge annotation input: $it" }

            // Run merge annotation
            merge_annotation(combine_file)
         }

        // tertp analysis
        if (params.run_mode in ['tertp', 'all']) {
            println "Running tertp Analysis..."
            igv_tools(boosts_igv_channel)
        //    igv_tools.out.tertp_out_igv.view { "tertp output: $it" }
            plot_genomic_regions(boosts_plot_genomic_regions_channel)
        }

        // CNV analysis (now handles both CNV and RMD modes)
        if (params.run_mode in ['cnv', 'all', 'rmd'] || params.run_mode_order) {
            println "Running CNV Analysis..."
            
            // Handle sample_thresholds for different run modes
            def samples_needing_ace = []
            def samples_with_provided_threshold = [:]

            if (params.run_mode_order || params.run_mode_epianalyse) {
                // In run_mode_order or run_mode_epianalyse, we always compute ACE to get thresholds
                println "Using ${params.run_mode_order ? 'run_mode_order' : 'run_mode_epianalyse'} - computing ACE for all samples to get thresholds"

                // For run_mode_order, load from bam_sample_id_file
                // For run_mode_epianalyse, load from epi2me_sample_id_file
                if (params.run_mode_order) {
                    def sample_ids = file(params.bam_sample_id_file).readLines().collect { line ->
                        // Extract only the sample ID part (first column), removing flow cell ID
                        line.trim().split(/\s+/)[0]
                    }
                    samples_needing_ace = sample_ids.toSet()
                } else {
                    // For run_mode_epianalyse, load from epi2me_sample_id_file
                    def sample_ids = file(params.epi2me_sample_id_file).readLines().collect { line ->
                        // Extract only the sample ID part (first column)
                        line.trim().split(/\t/)[0]
                    }
                    samples_needing_ace = sample_ids.toSet()
                }
                println "Samples for ACE calculation: ${samples_needing_ace}"
            } else {
                // Separate samples that need ACE from those that don't
                samples_needing_ace = sample_thresholds.findAll { k, v -> v == null }.keySet()
                samples_with_provided_threshold = sample_thresholds.findAll { k, v -> v != null }
            }

            println "Samples needing ACE calculation: ${samples_needing_ace}"
            println "Samples with provided thresholds: ${samples_with_provided_threshold}"

            // Run ACE only for samples that need calculation (have null threshold)
            if (samples_needing_ace.size() > 0) {
        // For run_mode_epianalyse or run_mode_order, use RDS from input_data channel
        // For standalone mode, scan filesystem
        if (params.run_mode_order || params.run_mode_epianalyse) {
            ace_input = input_data
                .map { args ->
                    def sample_id = args[0]
                    def rds_file = args[10]

                    if (samples_needing_ace.contains(sample_id)) {
                        println "Found matching RDS file for sample ${sample_id} from epi2me output"
                        tuple(sample_id, rds_file)
                    } else {
                        null
                    }
                }
                .filter { it != null }
        } else {
            ace_input = Channel
                .fromPath("${params.cnv_rds}/**/*_copyNumbersCalled.rds")
                .map { rds_file ->
                    // Extract sample ID: everything before "_copyNumbersCalled.rds"
                    def sample_id = rds_file.name.toString().replaceAll(/_copyNumbersCalled\.rds$/, '')
                            if (samples_needing_ace.contains(sample_id)) {
                        println "Found matching RDS file for sample ${sample_id}: ${rds_file}"
                                tuple(sample_id, rds_file)
                    } else {
                        println "Skipping RDS file for sample ${sample_id} (not in samples_needing_ace)"
                        null
                    }
                }
                .filter { it != null }
        }

                // Run ACE analysis
            ace_tmc(ace_input)
                
            ace_thresholds = ace_tmc.out.threshold_value
                .map { args -> 
                    def sample_id = args[0]
                    def threshold = args[1]
                    println "Calculated threshold for ${sample_id}: ${threshold}"
                    tuple(sample_id, threshold.toFloat())
                }
            } else {
                ace_thresholds = Channel.empty()
            }

            // Create final threshold mapping
            def final_thresholds = [:]
            samples_with_provided_threshold.each { sample_id, threshold ->
                final_thresholds[sample_id] = threshold
                println "Using provided threshold for ${sample_id}: ${threshold}"
            }

            println "Final threshold mapping: ${final_thresholds}"

            // Create channel for annotatecnv based on run mode
            if (params.run_mode_order || params.run_mode_epianalyse) {
                // Use epi2me output paths when in run_mode_order or run_mode_epianalyse
                annotatecnv_input = input_data
                    .map { args -> 
                        def sample_id = args[0]
                        def bam = args[1]
                        def bai = args[2]
                        def ref = args[3]
                        def ref_bai = args[4]
                        def tr_bed = args[5]
                        def modkit = args[6]
                        def segs_bed = args[7]
                        def bins_bed = args[8]
                        def segs_vcf = args[9]
                def rds_file = args[10]
                        def sv = args[11]
                        println "Processing epi2me results for sample: ${sample_id} from epi2me output"

                        // Use published epi2me output directory
                        def segs_vcf_path = "${params.path}/routine_epi2me/${sample_id}/${sample_id}_segs.vcf"
                        def bins_bed_path = "${params.path}/routine_epi2me/${sample_id}/${sample_id}_bins.bed"
                        def segs_bed_path = "${params.path}/routine_epi2me/${sample_id}/${sample_id}_segs.bed"

                        println "Checking file existence:"
                        println "  segs_vcf_path: ${segs_vcf_path}"
                        println "  bins_bed_path: ${bins_bed_path}"
                        println "  segs_bed_path: ${segs_bed_path}"

                        tuple(
                            sample_id,
                            file(segs_vcf_path),
                            file(params.occ_protein_coding_bed),
                            file(bins_bed_path),
                            file(segs_bed_path)
                        )
                    }
            } else {
                // Use configured input folders when in standalone mode
                annotatecnv_input = Channel.fromList(sample_thresholds.keySet().collect())
                    .map { sample_id ->
                        println "Processing sample: ${sample_id} from configured folders"
                        tuple(
                            sample_id,
                            file("${params.segsfromepi2me_folder}/${sample_id}/${sample_id}_segs.vcf"),
                            file(params.occ_protein_coding_bed),
                            file("${params.segsfromepi2me_folder}/${sample_id}/${sample_id}_bins.bed"),
                            file("${params.segsfromepi2me_folder}/${sample_id}/${sample_id}_segs.bed")
                        )
                    }
            }

            // Combine with thresholds and prepare final input
            // For run_mode_order and run_mode_epianalyse, we use calculated thresholds from ACE
            def annotatecnv_with_provided = (params.run_mode_order || params.run_mode_epianalyse) ?
                annotatecnv_input.combine(ace_thresholds, by: 0).map { args ->
                    def sample_id = args[0]
                    def segs_vcf = args[1]
                    def occ_protein_coding_bed = args[2]
                    def bins_bed = args[3]
                    def segs_bed = args[4]
                    def threshold = args[5]

                    println "Preparing annotatecnv input for ${sample_id} with ACE threshold: ${threshold}"
                    tuple(
                        sample_id,
                        segs_vcf,
                        occ_protein_coding_bed,
                        bins_bed,
                        segs_bed,
                        threshold.toString()
                    )
                } :
                annotatecnv_input
                    .filter { args ->
                        def sample_id = args[0]
                        def segs_vcf = args[1]
                        def occ_protein_coding_bed = args[2]
                        def bins_bed = args[3]
                        def segs_bed = args[4]

                        // Check if this sample has a provided threshold
                        def has_threshold = final_thresholds.containsKey(sample_id)
                        println "Sample ${sample_id} has provided threshold: ${has_threshold}"
                        has_threshold
                    }
                    .map { args ->
                        def sample_id = args[0]
                        def segs_vcf = args[1]
                        def occ_protein_coding_bed = args[2]
                        def bins_bed = args[3]
                        def segs_bed = args[4]

                        // Add the threshold and cnv_genes_tuned to the tuple
                        tuple(
                            sample_id,
                            segs_vcf,
                            occ_protein_coding_bed,
                            bins_bed,
                            segs_bed,
                            final_thresholds[sample_id],
                            file(params.cnv_genes_tuned)
                        )
                    }

            // For samples with calculated thresholds, combine with ace_thresholds
            def annotatecnv_with_calculated = (params.run_mode_order || params.run_mode_epianalyse) ?
                Channel.empty() :  // Skip this in run_mode_order/run_mode_epianalyse since we handle it above
                annotatecnv_input
                    .filter { args ->
                        def sample_id = args[0]
                        def segs_vcf = args[1]
                        def occ_protein_coding_bed = args[2]
                        def bins_bed = args[3]
                        def segs_bed = args[4]
                        !final_thresholds.containsKey(sample_id)
                    }
                    .combine(ace_thresholds, by: 0)
                    .map { args ->
                        def sample_id = args[0]
                        def segs_vcf = args[1]
                        def occ_protein_coding_bed = args[2]
                        def bins_bed = args[3]
                        def segs_bed = args[4]
                        def threshold = args[5]
                        println "Preparing annotatecnv input for ${sample_id} with calculated tumor content ${threshold}"
                        tuple(
                            sample_id,              // sample_id
                            segs_vcf,               // segs_vcf
                            occ_protein_coding_bed, // occ_protein_coding_bed
                            bins_bed,               // bins_bed
                            segs_bed,               // segs_bed
                            threshold.toString(),   // threshold value as string
                            file(params.cnv_genes_tuned)  // CNV genes annotation file
                        )
                    }

            // Combine both channels
            annotatecnv_input = annotatecnv_with_provided.mix(annotatecnv_with_calculated)
                .view { "Annotatecnv input: $it" }

            // Run annotatecnv
            annotatecnv(annotatecnv_input)
            annotatecnv_results = annotatecnv.out
            //annotatecnv.out.rmdcnvtumornumber.each { println "Annotatecnv results: $it" }
            
            // Run plot_genomic_regions for coverage analysis
            //plot_genomic_regions(boosts_plot_genomic_regions_channel)
        }

        // Statistics mode - run cramino for quality assessment
        if (params.run_mode in ['stat']) {
            println "Running Cramino Statistics..."
            cramino_report(boosts_cramino)
        }

        // RMD report generation
        if (params.run_mode in ['rmd', 'all'] || params.run_mode_order) {
            println "Running RMD Report Generation..."
            
            // Ensure annotatecnv_results is defined for run_mode_order
            if (params.run_mode_order && !annotatecnv_results) {
                println "WARNING: annotatecnv_results not found in run_mode_order. This may indicate an issue with CNV analysis."
                println "Attempting to create fallback annotatecnv_results..."
                
                // Create a minimal fallback for run_mode_order
                annotatecnv_results = Channel.empty()
            }
            
            // Reuse MGMT outputs from earlier analysis if available
            // If MGMT analysis was not run, we need to run it here
            if (!(params.run_mode in ['mgmt', 'all'])) {
                println "MGMT analysis not run earlier, running now for RMD report..."
                
                // Create channel for MGMT analysis
        mgmt_ch = (params.run_mode_order || params.run_mode_epianalyse) ? 
                input_data.map { args -> 
                    def sample_id = args[0]
                    def bam = args[1]
                    def bai = args[2]
                    def ref = args[3]
                    def ref_bai = args[4]
                    def tr_bed = args[5]
                    def modkit = args[6]
                    def segs_bed = args[7]
                    def bins_bed = args[8]
                    def segs_vcf = args[9]
                def rds_file = args[10]
                    def sv = args[11]
                    
                    tuple(
                        sample_id,
                        modkit,
                        epicsites,
                        mgmt_cpg
                    )
                } :
                Channel.fromList(sample_thresholds.keySet().collect())
                    .combine(epicsites_ch).combine(mgmt_cpg_island_hg38_ch)
                    .map { sample_id, epicsites, mgmt_cpg ->
                        tuple(
                            sample_id,
                            file("${params.bedmethyl_folder}/${sample_id}/${sample_id}.wf_mods.bedmethyl.gz"),
                            epicsites,
                            mgmt_cpg
                        )
                    }

            // Run MGMT related processes
            extract_epic(mgmt_ch)

            // Create channels for downstream processes
            MGMT_output = extract_epic.out.MGMTheaderout

            MGMT_sturgeon = extract_epic.out.sturgeonbedinput
                 .combine(sturgeon_model_ch)
                 .map { sample_id, sturgeoninput, sturgeon_model ->
                     tuple(sample_id, sturgeoninput, sturgeon_model)
                 }

            mgmt_nanodx = extract_epic.out.epicselectnanodxinput
                .combine(hg19_450model_ch)
                .map { sample_id, epicselectnanodxinput, hg19_model ->
                    tuple(sample_id, epicselectnanodxinput, hg19_model)
                }

            // Run the processes
            sturgeon(MGMT_sturgeon)
            mgmt_promoter(MGMT_output)
            nanodx(mgmt_nanodx)

            nanodx_out = nanodx.out.nanodx450out
                .combine(nanodx_450model_ch).combine(snakefile_nanodx_ch).combine(nn_model_ch)
                .map { sample_id, nanodx450out, nanodx_model, snakefile, nn_model ->
                    tuple(
                        sample_id,
                        nanodx450out,
                        nanodx_model,
                        snakefile,
                        nn_model
                    )
                }

            run_nn_classifier(nanodx_out)
            rmd_nanodx_out = run_nn_classifier.out.rmdnanodx

            // Generate t-SNE plot using EPIC bed files
            tsne_plot(
                extract_epic.out.epicselectnanodxinput,
                nanodxcolormap_ch,
                nanodxh5_ch
            )
            } else {
                println "Reusing MGMT outputs from earlier analysis"
                // The outputs are already available from the MGMT section
            }

            // Svanna analysis - reuse outputs if already run
            if (!(params.run_mode in ['svannasv', 'all'])) {
                println "Svanna analysis not run earlier, running now for RMD report..."
        svannasv(boosts_svanna_channel)
        rmd_svanna_html = svannasv.out.rmdsvannahtml
            svannasv_out = svannasv.out.occsvannaannotationannotationvcf
                .combine(vcf2circos_json_ch)
                .map { sample_id, occsvannaannotationannotationvcf, vcf2circos ->
                    [sample_id, occsvannaannotationannotationvcf, vcf2circos]
                }
        circosplot(svannasv_out)

        // Also run fusion events analysis for RMD mode
        svannaoutfusion_events = svannasv.out.occsvannaannotationannotationvcf
                .combine(genecode_bed_ch).combine(occ_fusion_genes_list_ch)
                .map { sample_id, occsvannaannotationannotationvcf, genecode, fusion_genes ->
                [sample_id, occsvannaannotationannotationvcf, genecode, fusion_genes]
            }
        svannasv_fusion_events(svannaoutfusion_events)
        
        // Assign fusion events channel
        fusion_events_channel = svannasv_fusion_events.out.filterfusioneventout
            } else {
                println "Reusing Svanna outputs from earlier analysis"
                // Ensure fusion_events_channel is defined when reusing outputs
                fusion_events_channel = svannasv_fusion_events.out.filterfusioneventout
            }

            // OCC analysis - reuse outputs if already run
            if (!(params.run_mode in ['occ', 'all'])) {
                println "OCC analysis not run earlier, running now for RMD report..."
        clair3(boosts_clair3_channel)
        clair3_out = clair3.out.clair3output
        clairs_to(boosts_clairSTo_channel)
        clairs_to_out = clairs_to.out.annotateandfilter_clairstoout
            combine_file = clair3_out.combine(clairs_to_out, by: 0)
                .combine(occ_genes_ch)
                .map { sample_id, pileup_file, merge_file, clairsto_file, occ_genes ->
                    tuple(sample_id, merge_file, pileup_file, clairsto_file, occ_genes)
    }
        merge_annotation(combine_file)
            } else {
                println "Reusing OCC outputs from earlier analysis"
            }

            // Other tools - reuse outputs if already run
            if (!(params.run_mode in ['tertp', 'all'])) {
                println "tertp analysis not run earlier, running now for RMD report..."
        igv_tools(boosts_igv_channel)
        cramino_report(boosts_cramino)
        plot_genomic_regions(boosts_plot_genomic_regions_channel)
            } else {
                println "Reusing tertp outputs from earlier analysis"
            }

            // Add a new run_mode 'stat' for the cramino_report process
            if (params.run_mode in ['stat', 'all']) {
                println "Running Cramino Statistics..."
                cramino_report(boosts_cramino)
            }

            // Combine all results for markdown report
            // Use the stored annotatecnv results from earlier CNV analysis
            if (!annotatecnv_results) {
                error "CNV analysis results not found. Make sure CNV analysis runs before RMD generation."
            }
            
            // Check if all required channels are available
            if (!merge_annotation.out.occmergeout) {
                error "Merge annotation results not found. Make sure OCC analysis runs before RMD generation."
            }
            
            if (!run_nn_classifier.out.rmdnanodx) {
                error "NN classifier results not found. Make sure MGMT analysis runs before RMD generation."
            }
            
            if (!mgmt_promoter.out.mgmtresultsout) {
                error "MGMT promoter results not found. Make sure MGMT analysis runs before RMD generation."
            }
            
            if (!svannasv.out.rmdsvannahtml) {
                error "Svanna HTML results not found. Make sure Svanna analysis runs before RMD generation."
            }
            
            if (!fusion_events_channel) {
                error "Fusion events results not found. Make sure Svanna analysis runs before RMD generation."
            }
            
            if (!igv_tools.out.tertp_out_igv) {
                error "tertp HTML results not found. Make sure tertp analysis runs before RMD generation."
            }
            
            if (!cramino_report.out.craminostatout) {
                error "Cramino statistics not found. Make sure Cramino analysis runs before RMD generation."
            }
            
            if (!plot_genomic_regions.out.plot_genomic_regions_out) {
                error "Genomic regions plot results not found. Make sure tertp analysis runs before RMD generation."
            }
            
            mergecnv_out = annotatecnv_results.rmdcnvtumornumber
            .combine(merge_annotation.out.occmergeout, by:0)
            .combine(run_nn_classifier.out.rmdnanodx, by: 0)
            .combine(mgmt_promoter.out.mgmtresultsout, by:0)
            .combine(svannasv.out.rmdsvannahtml, by:0)
            .combine(fusion_events_channel, by:0)
            .combine(igv_tools.out.tertp_out_igv, by:0)
            .combine(cramino_report.out.craminostatout, by:0)
            .combine(plot_genomic_regions.out.plot_genomic_regions_out, by:0)
            .combine(tsne_plot.out.tsne_out, by:0)
            // Create final map for markdown report
        mergecnv_out_map = mergecnv_out.map { args -> 
                def sample_id = args[0]
                def cnv_plot = args[1]
                def tumor_copy_number = args[2]
                def annotatedcnv_filter_header = args[3]
                def cnv_chr9 = args[4]
                def cnv_chr7 = args[5]
                def merge_annotation_filter_snvs_allcall = args[6]
                def nanodx_classifier = args[7]
                def mgmt_results = args[8]
                def svannahtml = args[9]
                def fusion_events = args[10]
                def tertphtml = args[11]
                def craminoreport = args[12]
                def egfr_coverage = args[13]
                def idh1_coverage = args[14]
                def tertp_coverage = args[15]
                def idh2_coverage = args[16]
                def tsne_plot_file = args[17]

                // Use correct sample ID file based on run mode
                def sample_id_file = params.run_mode_order ? "placeholder" : params.analyse_sample_id_file

                [
                    sample_id,
                    craminoreport,
                    sample_id_file,
                    params.nanodx_dictinaire,
                    params.mardown_logo,
                    cnv_plot,
                    tumor_copy_number,
                    annotatedcnv_filter_header,
                    cnv_chr9,
                    cnv_chr7,
                    mgmt_results,
                    merge_annotation_filter_snvs_allcall,
                    fusion_events,
                    svannahtml,
                    tertphtml,
                    egfr_coverage,
                    idh1_coverage,
                    idh2_coverage,
                    tertp_coverage,
                    tsne_plot_file,
                    nanodx_classifier,
                    file("${params.ref_dir}/snv_target_genes.txt"),
                    file(params.occ_protein_coding_bed),
                    file("${params.nWGS_dir}/bin/nextflow_markdown_pipeline_update_final.Rmd")
                ]
            }.view()

            // Generate markdown report
            markdown_report(mergecnv_out_map)
        }

    emit:
        markdown_out = (params.run_mode_analysis == 'rmd' || params.run_mode_order) ? 
            markdown_report.out : 
            Channel.empty()
}

// Helper function to extract sample_id from BAM filename
//def extractSampleId(file) {
//    def filename = file.getName()
//    return filename.split('\\.')[0]  // Get everything before the first dot
//}
//}