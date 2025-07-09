#!/usr/bin/env nextflow

nextflow.enable.dsl=2
def start_time = new Date()

//---------------------------------------------------------------------
// Helper function definitions must be declared before any workflow blocks
//---------------------------------------------------------------------
def validateParameters() {
    params.run_mode = params.run_mode_analysis ?: 'all'
    println "Analysis run mode: ${params.run_mode}"
    if (!['mgmt', 'annotsv', 'cnv', 'occ', 'terp', 'mgmt', 'rmd', 'all'].contains(params.run_mode)) {
        error "ERROR: Invalid run_mode '${params.run_mode}' for analysis. Valid modes: methylation, annotsv, cnv, occ, terp, mgmt, rmd, all"
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
// (Optional) Parameter definitions and commented documentation
//---------------------------------------------------------------------
// params.mgmt_promoter_r_script = "mnt/scripts/MGMT_Prospective2.R"
// Define the base path as a parameter
// params.path = "/home/chbope/extension"
// params.input_path = "${params.path}"
// params.output_path = "${params.path}/results"
// params.annotate_dir = "/home/chbope/extension/data/annotations"
// params.config_dir = "/home/chbope/Documents/nanopore/packages/knotannotsv/knotAnnotSV"
// params.ref_dir ="/home/chbope/extension/data/reference"
// params.model_path="/home/chbope/extension/Data_for_Bope"
// params.clair3_dir="/home/chbope/Documents/nanopore/Data_for_Bope/results/sample_id1/callvariantclair3/clair3_output"
// params.humandb_dir="/home/chbope/extension/data/annovar/humandb"
// params.clairSTo_dir="/home/chbope/Documents/nanopore/Data_for_Bope/results/sample_id1/callvariantclairsto/clairsto_output"
// params.svanna_dir="/home/chbope/extension/data/svanna-cli-1.0.4/"
// params.bin_dir="/home/chbope/Documents/nanopore/nextflow/bin/"
// params.epi2me_dir="/home/chbope/Documents/nanopore/epi2me/wf-human-variation-master/"
// params.out_dir_epi2me ="/home/chbope/extension/out_dir_epi2me"

// (Additional parameter definitions and file paths are commented out for clarity)
// ...

//---------------------------------------------------------------------
// Process Definitions
//---------------------------------------------------------------------

process extract_epic {
    cpus 4
    memory '2 GB'
    label 'epic'
    tag "${sample_id}"
    publishDir "${params.output_path}/methylation/", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), file(bedmethyl), file(epicsites), file(mgmt_cpg_island_hg38)

    output:
    tuple val(sample_id), path("${sample_id}_EpicSelect_header.bed"), emit: epicselectnanodxinput
    path("${sample_id}_MGMT.bed")
    tuple val(sample_id), path("${sample_id}_MGMT_header.bed"), emit: MGMTheaderout
    tuple val(sample_id), path("${sample_id}_wf_mods.bedmethyl_intersect.bed"), emit: sturgeonbedinput

    script:
    """
    which intersectBed 
    intersectBed -a $bedmethyl -b $epicsites -wb | \
    awk -v OFS="\\t" '\$1=\$1' | awk -F'\\t' 'BEGIN{ OFS="\\t" }{print \$1,\$2,\$3,\$4,\$5,\$11,\$23}' > ${sample_id}_EpicSelect.bed

    intersectBed -a $bedmethyl -b $epicsites -wb | awk -v OFS="\\t" '\$1=\$1' | awk -F'\\t' 'BEGIN{ OFS="\\t" } {print \$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10, \$11, \$12, \$13, \$14, \$15, \$16, \$17, \$18}' > ${sample_id}_wf_mods.bedmethyl_intersect.bed

    awk 'BEGIN {print "Chromosome\\tStart\\tEnd\\tmodBase\\tCoverage\\tMethylation_frequency\\tIllumina_ID"} 1' ${sample_id}_EpicSelect.bed > ${sample_id}_EpicSelect_header.bed

    intersectBed -a $bedmethyl -b $mgmt_cpg_island_hg38 | \
    awk -v OFS="\\t" '\$1=\$1' | awk -F'\\t' 'BEGIN{ OFS="\\t" }{print \$1,\$2,\$3,\$4,\$5,\$11,\$12,\$13,\$14,\$15,\$16}'  > ${sample_id}_MGMT.bed

    awk 'BEGIN {print "Chrom\\tStart\\tEnd\\tmodBase\\tDepth\\tMethylation\\tNmod\\tNcanon\\tNother\\tNdelete\\tNfail"} 1' ${sample_id}_MGMT.bed > ${sample_id}_MGMT_header.bed
    """
}


//Sturgeon classifier
process sturgeon {
    cpus 2
    memory '2 GB'
    label 'epic'
    publishDir "${params.output_path}/classifier/sturgeon", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(sturgeon_bed), path(sturgeon_model)

    output:
    tuple path("${sample_id}_bedmethyl_sturgeon.bed"), path("${sample_id}_bedmethyl_sturgeon")


    """
    /sturgeon/venv/bin/sturgeon inputtobed -i $sturgeon_bed  -o ${sample_id}_bedmethyl_sturgeon.bed  -s modkit_pileup  --reference-genome hg38
   
    /sturgeon/venv/bin/sturgeon predict -i ${sample_id}_bedmethyl_sturgeon.bed   -o  ${sample_id}_bedmethyl_sturgeon --model-files $sturgeon_model  --plot-results

    """
}
process nanodx {
    cpus 4
    memory '16 GB'
    label 'epic'
    publishDir "${params.output_path}/classifier/nanodx", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(nanodx_bed), path(hg19_450model)

    output:
    tuple val(sample_id), path("${sample_id}_nanodx_bedmethyl.bed"), emit: nanodx450out

    script:
    """
    nanodx450intersectdataframe.py $hg19_450model $nanodx_bed ${sample_id}_output_cpg.bed ${sample_id}_nanodx_bedmethyl.bed ${sample_id}_nanodx_bedmethylfilter.bed
    """
}

process run_nn_classifier {
    label 'nanodx'
    publishDir "${params.output_path}/methylation/", mode: "copy", overwrite: true
    
    input:
    tuple val(sample_id), path(bed_file), path(model_file), path(snakefile), path(nn_model)
    
    output:
    tuple val(sample_id), path("${sample_id}_nanodx_classifier.txt")
    tuple val(sample_id), path("${sample_id}_nanodx_classifier.tsv"), emit: rmdnanodx
    
    script:
    """
    #!/bin/bash
    export TMPDIR="/home/chbope/extension/trash/tmp/"
    mkdir -p \$TMPDIR
    
    # Use container's conda environment
    source /opt/conda/etc/profile.d/conda.sh
    conda activate base
    conda activate nanodx_env2feb
    
    # Create Snakefile with correct paths
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
    threads: 4
    resources: 
        mem_mb = 16384
    script: "${params.nanodx_workflow_dir}/scripts/classify_NN_bedMethyl.py"
EOF

    # Run snakemake
    snakemake --cores ${task.cpus} --verbose NN_classifier
    """
}

process mgmt_promoter {
    cpus 4
    memory '2 GB'
    label 'epic'
    publishDir "${params.output_path}/methylation/", mode: "copy", overwrite: true

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

process svannasv {

    label 'svannasv'
   cpus 2
   memory '2 GB'
   publishDir "${params.output_path}/structure_variant/svannasv/", mode: "copy", overwrite: true

   input:
   tuple val(sample_id), path(wf_sv), path(wf_sv_tbi),path(occ_fusions)

   output:
   //file("${sample_id}_OCC_SVs.vcf")
   tuple val(sample_id), path("${sample_id}_OCC_SVs.vcf"), emit: occsvannavcfout
   tuple val(sample_id), path("${sample_id}_occ_svanna_annotation.html"), emit:rmdsvannahtml 
   tuple val(sample_id), path("${sample_id}_occ_svanna_annotation.vcf.gz"), emit: occsvannaannotationannotationvcf

//   export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
//   export PATH=$JAVA_HOME/bin:$PATH
   script:
   """

   intersectBed -a $wf_sv  -b $occ_fusions  -header > ${sample_id}_OCC_SVs.vcf

   # Check if intersection file is empty (excluding header)
   if [ \$(grep -v '^#' ${sample_id}_OCC_SVs.vcf | wc -l) -eq 0 ]; then
      # If empty, use original wf_sv file
      INPUT_FILE=$wf_sv
   else
      # If not empty, use intersection file
      INPUT_FILE=${sample_id}_OCC_SVs.vcf
   fi
 
   /usr/lib/jvm/java-17-openjdk-amd64/bin/java -jar ${params.bin_dir}/svanna-cli-1.0.3.jar prioritize  \
   -d ${params.svanna_dir}/svanna-data  \
   --vcf \$INPUT_FILE \
   --phenotype-term HP:0100836 \
   --output-format html,vcf \
   --prefix ${sample_id}_occ_svanna_annotation

  # cp "${sample_id}_occ_svanna_annotation.html" "${params.output_path}/report/${sample_id}_svanna.html"

   """
}


process svannasv_fusion_events {
    cpus 4
    memory '2 GB'
    label 'svannasv'
    publishDir "${params.output_path}/structure_variant/svannasv/", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(occ_svannavcf), path(genecode_bed), path(occ_fusions_genes)

    output:
    tuple val(sample_id), path("${sample_id}_filter_fusion_event.tsv"), emit: filterfusioneventout

    script:

    """
    breaking_point_bed_translocation.py --vcf $occ_svannavcf --out  ${sample_id}_breaking_bedpoints.bed

    awk 'BEGIN{OFS="\t"} {if (\$1 !~ /^chr/) \$1 = "chr"\$1; print}' ${sample_id}_breaking_bedpoints.bed > ${sample_id}_breaking_bedpoints_sort.bed

    intersectBed -a ${sample_id}_breaking_bedpoints_sort.bed  -b $genecode_bed  -wb  > ${sample_id}_breaking_bedpoints_genecode.bed

    #remove duplicate bed points

    remove_duplicate_report.py --in  ${sample_id}_breaking_bedpoints_genecode.bed  \
            --formatted ${sample_id}_breaking_bedpoints_genecode_format.bed \
             --out ${sample_id}_breaking_bedpoints_genecode_clean.bed    \
             --paired ${sample_id}_breaking_bedpoints_genecode_clean_paired.bed  \
             --gene-list $occ_fusions_genes \
             --filtered ${sample_id}_filter_fusion_event.tsv

    """
}

process circosplot {
    cpus 2
    memory '2 GB'
   label 'circos'
   publishDir "${params.output_path}/structure_variant/svannasv/", mode: "copy", overwrite: true
   
   input:
   tuple val(sample_id), path(annotsv_output), path(vcf2circos_json)

   output:
   tuple val(sample_id), path("${sample_id}_vcf2circo.html"), optional: true, emit: circosout

   script:
   """
   # Check if file is empty (excluding header)
   if [ \$(grep -v '^#' ${annotsv_output} | wc -l) -eq 0 ]; then
      echo "Warning: ${annotsv_output} is empty. Skipping vcf2circos plot generation."
      touch ${sample_id}_vcf2circo.html
      exit 0
   else
      vcf2circos -i $annotsv_output -o ${sample_id}_vcf2circo.html -p $vcf2circos_json -a hg38
   fi
   """
}

process annotatecnv {
    cpus 4
    memory '2 GB'
   label 'annotatecnv'
    publishDir "${params.output_path}/cnv/", mode: "copy", overwrite: true

   input:
    tuple val(sample_id), 
          path(vcf_file), 
          path(occ_fusions), 
          path(calls_bed),
          path(seg_bed),
          val(threshold)  // Now explicitly receiving threshold

   output:
   tuple val(sample_id), path("${sample_id}_calls_fixed.vcf"), emit: callsfixedout
   tuple val(sample_id), path("${sample_id}_annotatedcnv.csv"), emit:annotatedcnvcsvout
   tuple val(sample_id), path("${sample_id}_annotatedcnv_filter.csv"), emit:annotatedcnvfiltercsvout
   tuple val(sample_id), path("${sample_id}_CNV_plot.pdf"), emit:cnvpdfout
   tuple val(sample_id), path("${sample_id}_annotatedcnv_filter_header.csv"), emit:rmdannotatedcnvfilter
   tuple val(sample_id), path("${sample_id}_CNV_plot.html"), emit:rmdcnvhtml
   tuple val(sample_id), path("${sample_id}_tumor_copy.txt"), path("${sample_id}_bins_filter.bed"), emit:tumorcopyandbinsfilterout
   tuple val(sample_id), path("${sample_id}_CNV_plot.pdf"), path("${sample_id}_annotatedcnv_filter.csv"), emit:cnvpdfandcsvout
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
    intersectBed -a ${sample_id}_calls_fixed.vcf -b $occ_fusions -wa -wb | \
        cut -f1,2,5,8,20 | awk '/protein_coding/' | \
        awk -v OFS=";" '\$1=\$1' | \
        awk 'BEGIN { FS=";"; OFS="\\t"} {\$1=\$1; print}' | \
   cut -f1,2,3,5,6,8,9,13 > ${sample_id}_annotatedcnv.csv

    # Generate plots and reports
   cnv_html.R $calls_bed ${sample_id}_annotatedcnv.csv ${sample_id}_CNV_plot.pdf ${sample_id}_CNV_plot.html $sample_id
    
    CNV_function_new_update.R $calls_bed ${sample_id}_annotatedcnv.csv $seg_bed \
        ${sample_id}_cnv_plot_full.pdf ${sample_id}_cnv_chr9.pdf ${sample_id}_cnv_chr7.pdf $sample_id 

    # Process annotation files
    awk 'BEGIN { OFS="," } { gsub(/<[^>]+>/, substr(\$3, 2, length(\$3) - 2), \$3); print \$0 }' \
        ${sample_id}_annotatedcnv.csv > ${sample_id}_annotatedcnv_filter.csv
    
    awk 'BEGIN {print "Chrom,Start,Type,End,SVLEN,Score,LOG2CNT,Gene"} 1' \
        ${sample_id}_annotatedcnv_filter.csv > ${sample_id}_annotatedcnv_filter_header.csv

    # Run CNV mapping with threshold
    cnv_mapping_occfusion_update.py $seg_bed $occ_fusions \
        ${sample_id}_tumor_copy.txt ${sample_id}_bins_filter.bed ${threshold}
    
    cnv_mapping_occfusion_update_nofilter.py $seg_bed \
        ${sample_id}_tumor_copy_number.txt ${threshold}
    """
}

process clair3 {
    cpus 4
    memory '5 GB'
    label 'clair3'
    publishDir "${params.output_path}/OCC/$sample_id", mode: "copy", overwrite: true
   
    input:
    tuple val(sample_id), path(occ_bam), path(occ_bam_bai), path(reference_genome), path(reference_genome_bai),  path(refGene), path(hg38_refGeneMrna), path(clinvar), path(clinvarindex),path(hg38_cosmic100),path(hg38_cosmic100index)

    output:
    tuple val(sample_id), path('output_clair3/')
    tuple val(sample_id), path('occ_pileup_snvs_avinput')
    tuple val(sample_id), path("${sample_id}_occ_pileup_annotateandfilter.csv"), emit:occpileupannotateandfilterout
    path('occ_merge_snv_avinpt')
    path('occ_merge.hg38_multianno.txt')
    tuple val(sample_id), path("${sample_id}_merge_annotateandfilter.csv"), emit:mergeannotateandfilterout
    tuple val(sample_id), path("${sample_id}_occ_pileup_annotateandfilter.csv"), path("${sample_id}_merge_annotateandfilter.csv"), emit:clair3output 


    script:
   
   """ 

   /opt/bin/run_clair3.sh \
    --bam_fn=$occ_bam \
    --ref_fn=$reference_genome  \
    --threads=8 \
    --var_pct_full=1 \
    --ref_pct_full=1 \
    --var_pct_phasing=1 \
    --platform="ont" \
    --no_phasing_for_fa \
    --model_path=${params.ref_dir}/r1041_e82_400bps_sup_v420 \
    --output=output_clair3
 
 convert2annovar.pl output_clair3/pileup.vcf.gz \
    --format vcf4 \
	--withfreq \
	--filter pass \
	--fraction 0.1 \
	--includeinfo \
	--outfile occ_pileup_snvs_avinput

   
   table_annovar.pl occ_pileup_snvs_avinput \
         -outfile occ_pileup \
         -buildver hg38 -protocol refGene,clinvar_20240611,cosmic100coding2024\
         -operation g,f,f \
         ${params.humandb_dir} \
         -otherinfo
      
    awk '/exonic/ && /nonsynonymous/ && !/Benign/ && !/Likely_benign/|| /upstream/ || /Func.refGene/ || /splicing/ && !/Benign/ && !/Likely_benign/' occ_pileup.hg38_multianno.txt \
| awk '/exonic/ || /TERT/ || /Func.refGene/'  \
| awk '!/dist=166/' \
| cut -f1-16,26,28,29 > ${sample_id}_occ_pileup_annotateandfilter.csv

convert2annovar.pl \
    output_clair3/merge_output.vcf.gz \
    --format vcf4 \
    --withfreq \
    --filter pass \
    --fraction 0.1 \
    --includeinfo \
    --outfile occ_merge_snv_avinpt

table_annovar.pl occ_merge_snv_avinpt \
    -outfile occ_merge \
    -buildver hg38 -protocol refGene,clinvar_20240611,cosmic100coding2024\
    -operation g,f,f \
    ${params.humandb_dir} \
    -otherinfo

    awk '/exonic/ && /nonsynonymous/ && !/Benign/ && !/Likely_benign/|| /upstream/ || /Func.refGene/ || /splicing/ && !/Benign/ && !/Likely_benign/ || /    frameshift/ && !/Benign/ && !/Likely_benign/ || /stopgain/ && !/Benign/ && !/Likely_benign/' \
        occ_merge.hg38_multianno.txt \
    | awk '/exonic/ || /TERT/ || /Func.refGene/'  \
    | awk '!/dist=166/' \
    | cut -f1-16,26,28,29 \
    > ${sample_id}_merge_annotateandfilter.csv 

    """
   }


//#################################
//#### ClairS-TO
//#################################
//# ClairS-TO is a recent development to specifically call somatic variants in Tumor-only samples
//# It's run separate from Clair3
// # installed from https://github.com/HKU-BAL/ClairS-TO via micromamba

process clairs_to {
    cpus 4
    memory '2 GB'
    label 'clairsto'
    publishDir "${params.output_path}/OCC/$sample_id", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(occ_bam), path(occ_bam_bai), path(reference_genome), path(reference_genome_bai),  path(refGene), path(hg38_refGeneMrna), path(clinvar), path(clinvarindex),path(hg38_cosmic100),path(hg38_cosmic100index), path(occ_snv_screening)
    
    output:
    tuple val(sample_id), path('clairsto_output/')
    tuple val(sample_id), path('clairS_To_snv_avinput')
    tuple val(sample_id), path('ClairS_TO_snv.hg38_multianno.txt')
    tuple val(sample_id), path("${sample_id}_annotateandfilter_clairsto.csv"), emit:annotateandfilter_clairstoout
    tuple val(sample_id), path("${sample_id}_merge_snv_indel_claisto.vcf.gz")

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
        --bed_fn=${occ_snv_screening} \
        --conda_prefix /opt/micromamba/envs/clairs-to

    bcftools merge --force-samples clairsto_output/snv.vcf.gz clairsto_output/indel.vcf.gz -o ${sample_id}_merge_snv_indel_claisto.vcf.gz

    convert2annovar.pl ${sample_id}_merge_snv_indel_claisto.vcf.gz \
   --format vcf4 \
   --filter pass \
   --includeinfo \
   --outfile  clairS_To_snv_avinput


  table_annovar.pl clairS_To_snv_avinput \
   -outfile ClairS_TO_snv \
   -buildver hg38 -protocol refGene,clinvar_20240611,cosmic100coding2024\
   -operation g,f,f \
    ${params.humandb_dir} \
   -otherinfo  

   awk '/exonic/ && /nonsynonymous/ && !/Benign/ || /upstream/ || /Func.refGene/' \
   ClairS_TO_snv.hg38_multianno.txt \
   | awk '/exonic/ || /TERT/ || /Func.refGene/'  \
  | awk '!/dist=166/' \
  | cut -f1-16,25,26  > ${sample_id}_annotateandfilter_clairsto.csv


    """
   }

process merge_annotation {
    debug true
    cpus 4
    memory '2 GB'
    label 'merge_annotation'
    publishDir "${params.output_path}/merge_annot_clair3andclairsto/", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(merge_file), path(pileup_file), path(clairsto_file), path(occ_genes)
    
    output:
    tuple val(sample_id), path("${sample_id}_merge_annotation_filter_snvs_allcall_filter.csv"), emit: occmergeout
    tuple val(sample_id), path("${sample_id}_merge_annotation_filter_snvs_allcall.csv")
    

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

process igv_tools {
    cpus 4
    memory '2 GB'
    label 'epic'
    publishDir "${params.output_path}/terp", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(occ_bam), path(occ_bam_bai), path(tertp_variants), path(ncbirefseq), path(reference_genome), path(reference_genome_bai)

    output:
    tuple val(sample_id), file("${sample_id}_tertp_id1.html"), emit: tertp_out_igv

    script:
    """
    export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    create_report $tertp_variants --fasta $reference_genome --flanking 1000 --tracks $tertp_variants $occ_bam $ncbirefseq --output ${sample_id}_tertp_id1.html
    ##cp "${sample_id}_tertp_id1.html" "${params.output_path}/report/${sample_id}_tertp_id1.html"
    """
}

    process cramino_report {
        cpus 4
        memory '2 GB'
        label 'epic'
        publishDir "${params.output_path}/cramino", mode: "copy", overwrite: true

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


process plot_genomic_regions {
    publishDir "${params.output_path}/coverage", mode: 'copy'
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
        "${sample_id}_tertp_coverage.pdf" \
        "${cytoband_file}"
    """
}


process markdown_report_old {
    cpus 4
    memory '2 GB'
    publishDir "${params.output_path}/report", mode: "copy", overwrite: true
    label 'markdown'

    input:
    tuple val(sample_id), 
          val(craminoreport),
          val(nanodx), 
          val(dictionaire), 
          val(logo), 
          val(cnv_plot), 
          val(tumor_number), 
          val(annotatecnv),
          val(cnv_chr9),
          val(cnv_chr7), 
          val(mgmt_results),
          val(merge_results),
          val(annotSV_fusion), 
          val(terphtml),
          val(svannahtml), 
          val(annotsvhtml),
          val(egfr_coverage),
          val(idh1_coverage),
          val(tertp_coverage)

    output:
    tuple val(sample_id), path("${sample_id}_markdown_pipeline_report.pdf"), emit: markdown_report

    script:
    """
    # Create header.tex file
    cat << 'EOT' > header.tex
    \\usepackage[utf8]{inputenc}
    \\usepackage{fontspec}
    \\setmainfont{Arial}
    \\usepackage{xcolor}
    \\usepackage{booktabs}
    \\usepackage{longtable}
    \\usepackage{array}
    \\usepackage{multirow}
    \\usepackage{float}
    \\usepackage{makecell}
    \\usepackage{graphicx}
    \\usepackage{caption}
    \\usepackage{placeins}
    EOT

    # Generate report with proper document structure
    Rscript -e '
    rmarkdown::render(
        "${workflow.projectDir}/bin/nextflow_markdown_pipeline3.Rmd",
        output_format = rmarkdown::pdf_document(
            latex_engine = "xelatex",
            includes = list(in_header = "header.tex"),
            keep_tex = TRUE
        ),
        output_file = "${sample_id}_markdown_pipeline_report.pdf",
        params = list(
            sample_id = "${sample_id}",
            cramino_stat = "${craminoreport}",
            nanodx = "${nanodx}",
            dictionary_file = "${dictionaire}",
            logo_file = "${logo}",
            copy_number_plot_file = "${cnv_plot}",
            tumor_copy_number_file = "${tumor_number}",
            cnv_filter_file = "${annotatecnv}",
            cnv_chr9 = "${cnv_chr9}",
            cnv_chr7 = "${cnv_chr7}",
            mgmt_results_file = "${mgmt_results}",
            snv_results_file = "${merge_results}",
            structure_variant_file = "${annotSV_fusion}",
            terp_html = "${terphtml}",
            svanna_html = "${svannahtml}",
            annotsv_html = "${annotsvhtml}",
            egfr_plot_file = "${egfr_coverage}",
            idh1_plot_file = "${idh1_coverage}",
            tertp_plot_file = "${tertp_coverage}"
        )
    )'
    """
}

process markdown_report {
    cpus 4
    memory '2 GB'
    publishDir "${params.output_path}/report", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), 
          path(craminoreport),
          path(nanodx), 
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
          path(terphtml),
          path(egfr_coverage),
          path(idh1_coverage),
          path(tertp_coverage)

    output:
    file("${sample_id}_markdown_pipeline_report.pdf")

    script:
    """
    # Output PDF path
    output_file="${sample_id}_markdown_pipeline_report.pdf"

    # Now call the Rscript with the updated Rmd file
    Rscript -e "rmarkdown::render('${workflow.projectDir}/bin/nextflow_markdown_pipeline_update_final.Rmd', output_file=commandArgs(trailingOnly=TRUE)[20])" \
      "${sample_id}" \
      "${craminoreport}" \
      "${params.analyse_sample_id_file}" \
      "${nanodx}" \
      "${dictionaire}" \
      "${logo}" \
      "${cnv_plot}" \
      "${tumor_number}" \
      "${annotatecnv}" \
      "${cnv_chr9}" \
      "${cnv_chr7}" \
      "${mgmt_results}" \
      "${merge_results}" \
      "${fusion_events}" \
      "${terphtml}" \
      "${svannahtml}" \
      "${egfr_coverage}" \
      "${idh1_coverage}" \
      "${tertp_coverage}" \
      "\${PWD}/\${output_file}"
    """
}


process ace_tmc {
    label 'ace_tmc'
    publishDir "${params.output_path}/cnv/ace/", mode: "copy", overwrite: true
    
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
// Workflow definition
//---------------------------------------------------------------------

workflow analysis {
    take:
        input_data

    main:
        validateParameters()
        
        if (params.run_order_mode) {
            // Verify all required epi2me outputs exist before proceeding
            input_data
                .map { sample_id, bam, bai, ref, ref_bai, tr_bed, modkit, segs_bed, bins_bed, segs_vcf, sv ->
                    def missing_files = []
                    
                    // Check SV file
                    if (!file(sv).exists()) {
                        missing_files << "SV file: ${sv}"
                    }
                    
                    // Check CNV files
                    if (!file(segs_bed).exists()) {
                        missing_files << "CNV segments file: ${segs_bed}"
                    }
                    if (!file(bins_bed).exists()) {
                        missing_files << "CNV bins file: ${bins_bed}"
                    }

                    if (!file(segs_vcf).exists()) {
                        missing_files << "CNV segments file: ${segs_vcf}"
                    }
                    
                    // Check methylation file
                    if (!file(bam).exists()) {
                        missing_files << "Methylation file: ${bam}"
                    }
                    
                    if (missing_files.size() > 0) {
                        error """
                        Missing epi2me output files for sample ${sample_id}:
                        ${missing_files.join('\n')}
                        Pipeline must run in sequential order.
                        """
                    }
                    
                    // Return tuple if all files exist
                    tuple(
                        sample_id, 
                        bam,
                        segs_bed,
                        bins_bed,
                        segs_vcf,
                        bam
                    )
                }
        }
        
        // Initialize channels as empty by default
        def annotatecnv_out = Channel.empty()
        def merge_annotation_out = Channel.empty()
        def run_nn_classifier_out = Channel.empty()
        def mgmt_promoter_out = Channel.empty()
        def annotesv_out = Channel.empty()
        def svannasv_out = Channel.empty()
        def knotannotsv_out = Channel.empty()
        def igv_tools_out = Channel.empty()
        def cramino_report_out = Channel.empty()
        
        // Initialize sample_thresholds based on run mode
        def sample_thresholds = params.run_order_mode ? [:] : loadSampleThresholds()
        println "Sample thresholds: ${sample_thresholds}"

        // Create segsfromepi2me channel based on mode
        boosts_segsfromepi2me_channel = params.run_order_mode ?
            input_data.map { sample_id, bam, bai, ref, ref_bai, tr_bed, modkit, segs_bed, bins_bed, segs_vcf, sv -> 
                tuple(
                    sample_id, 
                    segs_vcf,
                    file(params.occ_fusions),
                    bins_bed,
                    segs_bed,
                    sample_thresholds[sample_id]
                )
            } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .map { sample_id -> 
                    tuple(
                        sample_id, 
                        file("${params.segsfromepi2me_folder}/${sample_id}_segs.vcf"),
                        file(params.occ_fusions),
                        file("${params.segsfromepi2me_folder}/${sample_id}_bins.bed"),
                        file("${params.segsfromepi2me_folder}/${sample_id}_segs.bed"),
                        sample_thresholds[sample_id]
                    )
                }

        boosts_svanna_channel = params.run_order_mode ?
            input_data.map { sample_id, bam, bai, ref, ref_bai, tr_bed, modkit, segs_bed, bins_bed, segs_vcf, sv -> 
                log.info "Creating Svanna input for sample: ${sample_id} (order mode)"
                log.info "SV file path: ${sv}"
                
                tuple(
                    sample_id,
                    sv,                    // SV VCF file from epi2me
                    file("${sv}.tbi"),    // Index file
                    file(params.occ_fusions)
                )
            } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .map { sample_id -> 
                    log.info "Creating Svanna input for sample: ${sample_id} (standalone mode)"
                    def sv_file = file("${params.sv_folder}/${sample_id}.wf_sv.vcf.gz")
                    
                    //if (!sv_file.exists()) {
                    //    error "SV file not found: ${sv_file}"
                    //}
                    
                    tuple(
                        sample_id,
                        sv_file,
                        file("${sv_file}.tbi"),
                        file(params.occ_fusions)
                    )
                }

        boosts_annotsv_channel = params.run_order_mode ?
            input_data.map { sample_id, bam, bai, ref, ref_bai, tr_bed, modkit, segs_bed, bins_bed, segs_vcf, sv -> 
                log.info "Creating AnnotSV input for sample: ${sample_id} (order mode)"
                log.info "SV file path: ${sv}"
                
                tuple(
                    sample_id,
                    sv,                    // SV VCF file from epi2me
                    file("${sv}.tbi"),    // Index file
                    file(params.occ_fusions),
                    file(params.occ_fusion_genes_list)
                )
            } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .map { sample_id -> 
                    log.info "Creating AnnotSV input for sample: ${sample_id} (standalone mode)"
                    def sv_file = file("${params.sv_folder}/${sample_id}.wf_sv.vcf.gz")
                    
                    //if (!sv_file.exists()) {
                    //    error "SV file not found: ${sv_file}"
                    //}
                    
                    tuple(
                        sample_id,
                        sv_file,
                        file("${sv_file}.tbi"),
                        file(params.occ_fusions),
                        file(params.occ_fusion_genes_list)
                    )
                }

        boosts_clair3_channel = params.run_order_mode ?
            input_data.map { sample_id, bam, bai, ref, ref_bai, tr_bed, modkit, segs_bed, bins_bed, segs_vcf, sv -> 
                tuple(
                    sample_id, 
                    bam, 
                    bai, 
                    ref, 
                    ref_bai,
                    file(params.refgene),
                    file(params.hg38_refgenemrna),
                    file(params.clinvar), 
                    file(params.clinvarindex),
                    file(params.hg38_cosmic100), 
                    file(params.hg38_cosmic100index)
                )
            } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .map { sample_id -> 
                    tuple(
                        sample_id, 
                        file("${params.occ_bam_folder}/${sample_id}.occ.bam"),
                        file("${params.occ_bam_folder}/${sample_id}.occ.bam.bai"),
                        file(params.reference_genome), 
                        file(params.reference_genome_bai),
                        file(params.refgene),
                        file(params.hg38_refgenemrna),
                        file(params.clinvar), 
                        file(params.clinvarindex),
                        file(params.hg38_cosmic100), 
                        file(params.hg38_cosmic100index)
                    )
                }

        boosts_clairSTo_channel = params.run_order_mode ?
            input_data.map { sample_id, bam, bai, ref, ref_bai, tr_bed, modkit, segs_bed, bins_bed, segs_vcf, sv -> 
                tuple(
                    sample_id, 
                    bam, 
                    bai, 
                    ref, 
                    ref_bai,
                    file(params.refgene),
                    file(params.hg38_refgenemrna),
                    file(params.clinvar), 
                    file(params.clinvarindex),
                    file(params.hg38_cosmic100), 
                    file(params.hg38_cosmic100index),
                    file(params.occ_snv_screening)
                )
            } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .map { sample_id -> 
                    tuple(
                        sample_id, 
                        file("${params.occ_bam_folder}/${sample_id}.occ.bam"),
                        file("${params.occ_bam_folder}/${sample_id}.occ.bam.bai"),
                        file(params.reference_genome),
                        file(params.reference_genome_bai),
                        file(params.refgene),
                        file(params.hg38_refgenemrna),
                        file(params.clinvar), 
                        file(params.clinvarindex),
                        file(params.hg38_cosmic100), 
                        file(params.hg38_cosmic100index),
                        file(params.occ_snv_screening)
                    
                    )
                }

        boosts_igv_channel = params.run_order_mode ?
            input_data.map { sample_id, bam, bai, ref, ref_bai, tr_bed, modkit, segs_bed, bins_bed, segs_vcf, sv -> 
                tuple(sample_id, bam, bai, file(params.tertp_variants), file(params.ncbirefseq), ref, ref_bai)
            } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .map { sample_id -> 
                    tuple(sample_id, file("${params.occ_bam_folder}/${sample_id}.occ.bam"),
                          file("${params.occ_bam_folder}/${sample_id}.occ.bam.bai"),
                          file(params.tertp_variants),
                          file(params.ncbirefseq),
                          file(params.reference_genome),
                          file("${params.reference_genome}.fai"))
                }

        boosts_plot_genomic_regions_channel = params.run_order_mode ?
            input_data.map { sample_id, bam, bai, ref, ref_bai, tr_bed, modkit, segs_bed, bins_bed, segs_vcf, sv -> 
                tuple(
                    sample_id, 
                    file(params.gviz_data),
                    bam,
                    bai,
                    file(params.cytoband_file)
                )
            } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .map { sample_id -> 
                    tuple(
                        sample_id, 
                        file(params.gviz_data),
                        file("${params.occ_bam_folder}/${sample_id}.occ.bam"),
                        file("${params.occ_bam_folder}/${sample_id}.occ.bam.bai"),
                        file(params.cytoband_file)
                    )
                }

        boosts_cramino = params.run_order_mode ?
            input_data.map { sample_id, bam, bai, ref, ref_bai, tr_bed, modkit, segs_bed, bins_bed, segs_vcf, sv -> 
                tuple(
                    sample_id, 
                    bam, 
                    bai,
                    ref,
                    ref_bai
                )
            } :
            Channel.fromList(sample_thresholds.keySet().collect())
                .map { sample_id -> 
                    tuple(
                        sample_id, 
                        file("${params.merge_bam_folder}/${sample_id}.bam", checkIfExists: true),
                        file("${params.merge_bam_folder}/${sample_id}.bam.bai", checkIfExists: true),
                        file(params.reference_genome, checkIfExists: true),
                        file("${params.reference_genome}.fai", checkIfExists: true)
                    )
                }

        // MGMT analysis
        if (params.run_mode in ['mgmt', 'all']) {
            println "Running MGMT Analysis..."
            
            // Create MGMT channel that works for both modes
            mgmt_ch = params.run_order_mode ? 
                input_data.map { sample_id, bam, bai, ref, ref_bai, tr_bed, modkit, segs_bed, bins_bed, segs_vcf, sv -> 
                    tuple(
                        sample_id, 
                        modkit,
                        file(params.epicsites),
                        file(params.mgmt_cpg_island_hg38)
                    )
                } :
                Channel.fromList(sample_thresholds.keySet().collect())
                    .map { sample_id -> 
                        tuple(
                            sample_id,
                            file("${params.bedmethyl_folder}/*.wf_mods.bedmethyl.gz"),
                            file(params.epicsites),
                            file(params.mgmt_cpg_island_hg38)
                        )
                    }
            
            // Run MGMT related processes
            extract_epic(mgmt_ch)
            
            // Create channels for downstream processes
            MGMT_output = extract_epic.out.MGMTheaderout
            
            MGMT_sturgeon = extract_epic.out.sturgeonbedinput
                .map { sample_id, sturgeoninput -> 
                    tuple(sample_id, sturgeoninput, file(params.sturgeon_model)) 
                }
            
            mgmt_nanodx = extract_epic.out.epicselectnanodxinput
                .map { sample_id, epicselectnanodxinput -> 
                    tuple(sample_id, epicselectnanodxinput, file(params.hg19_450model)) 
                }

            // Run the processes
            //sturgeon(MGMT_sturgeon)
            mgmt_promoter(MGMT_output)
            nanodx(mgmt_nanodx)
            
            nanodx_out = nanodx.out.nanodx450out
                .map { sample_id, nanodx450out -> 
                    tuple(
                        sample_id, 
                        nanodx450out, 
                        file(params.nanodx_450model),
                        file(params.snakefile_nanodx),
                        file(params.nn_model)
                    ) 
                }
            
            run_nn_classifier(nanodx_out)
        }

        // AnnotSV analysis
        if (params.run_mode in ['annotsv', 'all']) {
            println "Running AnnotSV Analysis..."
            
            svannasv(boosts_svanna_channel)
            svannasv_out = svannasv.out.occsvannaannotationannotationvcf.map{sample_id,svannavcfoutput -> [sample_id, svannavcfoutput, params.vcf2circos_json]}
            circosplot(svannasv_out)
            circosplot_out=circosplot.out.circosout
            svannaoutfusion_events= svannasv.out.occsvannavcfout.map{sample_id, occsvannavcfout -> [sample_id, occsvannavcfout, params.genecode_bed, params.occ_fusion_genes_list]}
            svannasv_fusion_events(svannaoutfusion_events)
        }

        // OCC analysis
        if (params.run_mode in ['occ', 'all']) {
            println "Running OCC Analysis..."
            
            // Run variant callers and get outputs
            clair3(boosts_clair3_channel)
            
            
            // Create properly structured channels for combination
            def clair3_results = clair3.out.clair3output
                .map { sample_id, pileup_file, merge_file -> 
                    tuple(sample_id, pileup_file, merge_file)
                }
                .view { "Clair3 mapped: $it" }

            clairs_to(boosts_clairSTo_channel)
            def clairsto_results = clairs_to.out.annotateandfilter_clairstoout
                .view { "ClairSTo output: $it" }

            // Combine results and create input for merge_annotation
            combine_file = clair3_results
                .combine(clairsto_results, by: 0)
                .map { sample_id, pileup_file, merge_file, clairsto_file -> 
                    println "Creating merge input for sample: $sample_id"
                    tuple(
                        sample_id,
                        merge_file,
                        pileup_file,
                        clairsto_file,
                        file(params.occ_genes)
                    )
                }
                .view { "Merge annotation input: $it" }

            // Run merge annotation
            merge_annotation(combine_file)
         }

        // TERP analysis
        if (params.run_mode in ['terp', 'all']) {
            println "Running TERP Analysis..."
            igv_tools(boosts_igv_channel)
        //    igv_tools.out.tertp_out_igv.view { "TERP output: $it" }
            plot_genomic_regions(boosts_plot_genomic_regions_channel)
        }

        // CNV analysis (now handles both CNV and RMD modes)
        if (params.run_mode in ['cnv', 'all', 'rmd'] || params.run_order_mode) {
            println "Running CNV Analysis..."
            
            // Separate samples that need ACE from those that don't
            def samples_needing_ace = sample_thresholds.findAll { k, v -> v == null }.keySet()
            def samples_with_provided_threshold = sample_thresholds.findAll { k, v -> v != null }

            println "Samples needing ACE calculation: ${samples_needing_ace}"
            println "Samples with provided thresholds: ${samples_with_provided_threshold}"

            // Run ACE only for samples that need calculation (have null threshold)
            if (samples_needing_ace.size() > 0) {
        ace_input = Channel
            .fromPath("${params.cnv_rds}/*_*.rds")
            .map { rds_file -> 
                def sample_id = rds_file.name.toString().split("_")[0]
                        if (samples_needing_ace.contains(sample_id)) {
                    println "Found matching RDS file for sample ${sample_id}: ${rds_file}"
                            tuple(sample_id, rds_file)
                } else {
                    null
                }
            }
            .filter { it != null }

                // Run ACE analysis
            ace_tmc(ace_input)
                
            ace_thresholds = ace_tmc.out.threshold_value
                .map { sample_id, threshold -> 
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
            if (params.run_order_mode) {
                // Use epi2me output paths when in run_order_mode
                annotatecnv_input = input_data
                    .map { sample_id, bam, bai, ref, ref_bai, tr_bed, modkit, segs_bed, bins_bed, segs_vcf, sv -> 
                        println "Processing epi2me results for sample: ${sample_id} from epi2me output"
                        tuple(
                            sample_id,
                            file("${params.path}/results/epi2me/epicnv/${sample_id}_segs.vcf"),
                            file(params.occ_fusions),
                            file("${params.path}/results/epi2me/epicnv/${sample_id}_bins.bed"),
                            file("${params.path}/results/epi2me/epicnv/${sample_id}_segs.bed")
                        )
                    }
            } else {
                // Use configured input folders when in standalone mode
                annotatecnv_input = Channel.fromList(sample_thresholds.keySet().collect())
                    .map { sample_id -> 
                        println "Processing sample: ${sample_id} from configured folders"
                        tuple(
                            sample_id,
                            file("${params.segsfromepi2me_folder}/${sample_id}_segs.vcf"),
                            file(params.occ_fusions),
                            file("${params.segsfromepi2me_folder}/${sample_id}_bins.bed"),
                            file("${params.segsfromepi2me_folder}/${sample_id}_segs.bed")
                        )
                    }
            }

            // Combine with thresholds and prepare final input
            // For samples with provided thresholds, use them directly
            def annotatecnv_with_provided = annotatecnv_input
                .filter { sample_id, segs_vcf, occ_fusions, bins_bed, segs_bed -> 
                    final_thresholds.containsKey(sample_id)
                }
                .map { sample_id, segs_vcf, occ_fusions, bins_bed, segs_bed -> 
                    def threshold = final_thresholds[sample_id]
                    println "Preparing annotatecnv input for ${sample_id} with provided tumor content ${threshold}"
                    tuple(
                        sample_id,              // sample_id
                        segs_vcf,               // segs_vcf
                        occ_fusions,            // occ_fusions
                        bins_bed,               // bins_bed
                        segs_bed,               // segs_bed
                        threshold.toString()    // threshold value as string
                    )
                }

            // For samples with calculated thresholds, combine with ace_thresholds
            def annotatecnv_with_calculated = annotatecnv_input
                .filter { sample_id, segs_vcf, occ_fusions, bins_bed, segs_bed -> 
                    !final_thresholds.containsKey(sample_id)
                }
                .combine(ace_thresholds, by: 0)
                .map { sample_id, segs_vcf, occ_fusions, bins_bed, segs_bed, threshold -> 
                    println "Preparing annotatecnv input for ${sample_id} with calculated tumor content ${threshold}"
                    tuple(
                        sample_id,              // sample_id
                        segs_vcf,               // segs_vcf
                        occ_fusions,            // occ_fusions
                        bins_bed,               // bins_bed
                        segs_bed,               // segs_bed
                        threshold.toString()    // threshold value as string
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

        // RMD report generation
        if (params.run_mode in ['rmd', 'all']) {
            println "Running RMD Report Generation..."
            
            // Reuse MGMT outputs from earlier analysis if available
            // If MGMT analysis was not run, we need to run it here
            if (!(params.run_mode in ['mgmt', 'all'])) {
                println "MGMT analysis not run earlier, running now for RMD report..."
                
                // Create channel for MGMT analysis
        mgmt_ch = params.run_order_mode ? 
                input_data.map { sample_id, bam, bai, ref, ref_bai, tr_bed, modkit, segs_bed, bins_bed, segs_vcf, sv -> 
                    tuple(
                        sample_id, 
                        modkit,
                        file(params.epicsites),
                        file(params.mgmt_cpg_island_hg38)
                    )
                } :
                Channel.fromList(sample_thresholds.keySet().collect())
                    .map { sample_id -> 
                        tuple(
                            sample_id,
                            file("${params.bedmethyl_folder}/*.wf_mods.bedmethyl.gz"),
                            file(params.epicsites),
                            file(params.mgmt_cpg_island_hg38)
                        )
                    }
            
            // Run MGMT related processes
            extract_epic(mgmt_ch)
            
            // Create channels for downstream processes
            MGMT_output = extract_epic.out.MGMTheaderout
            
            MGMT_sturgeon = extract_epic.out.sturgeonbedinput
                .map { sample_id, sturgeoninput -> 
                    tuple(sample_id, sturgeoninput, file(params.sturgeon_model)) 
                }
            
            mgmt_nanodx = extract_epic.out.epicselectnanodxinput
                .map { sample_id, epicselectnanodxinput -> 
                    tuple(sample_id, epicselectnanodxinput, file(params.hg19_450model)) 
                }

            // Run the processes
            //sturgeon(MGMT_sturgeon)
            mgmt_promoter(MGMT_output)
            nanodx(mgmt_nanodx)
            
            nanodx_out = nanodx.out.nanodx450out
                .map { sample_id, nanodx450out -> 
                    tuple(
                        sample_id, 
                        nanodx450out, 
                        file(params.nanodx_450model),
                        file(params.snakefile_nanodx),
                        file(params.nn_model)
                    ) 
                }
            
            run_nn_classifier(nanodx_out)
            rmd_nanodx_out = run_nn_classifier.out.rmdnanodx
            } else {
                println "Reusing MGMT outputs from earlier analysis"
                // The outputs are already available from the MGMT section
            }

            // SV analysis - reuse outputs if already run
            if (!(params.run_mode in ['annotsv', 'all'])) {
                println "SV analysis not run earlier, running now for RMD report..."
        svannasv(boosts_svanna_channel)
        rmd_svanna_html = svannasv.out.rmdsvannahtml
            svannasv_out = svannasv.out.occsvannaannotationannotationvcf
                .map { sample_id, svannavcfoutput -> tuple(sample_id, svannavcfoutput, params.vcf2circos_json) }
        circosplot(svannasv_out)
            } else {
                println "Reusing SV outputs from earlier analysis"
            }

            // AnnotSV analysis
            //annotesv(boosts_annotsv_channel)
            //annotsv_output = annotesv.out.annotatedvariantsout
            //.map { sample_id, annotated_variants -> tuple(sample_id, annotated_variants, file(params.knotannotsv_conf)) }
            //knotannotsv(annotsv_output)
            //rmd_knotannotsv_html = knotannotsv.out.rmdannotsvhtml

            // OCC analysis - reuse outputs if already run
            if (!(params.run_mode in ['occ', 'all'])) {
                println "OCC analysis not run earlier, running now for RMD report..."
        clair3(boosts_clair3_channel)
        clair3_out = clair3.out.clair3output
        clairs_to(boosts_clairSTo_channel)
        clairs_to_out = clairs_to.out.annotateandfilter_clairstoout
            combine_file = clair3_out.combine(clairs_to_out)
                .map { occ_pileup_annotateandfilter, merge_annotateandfilter, sample_id, annotateandfilter_clairsto ->
                    tuple(sample_id, merge_annotateandfilter, occ_pileup_annotateandfilter, annotateandfilter_clairsto, file(params.occ_genes))
    }
        merge_annotation(combine_file)
            } else {
                println "Reusing OCC outputs from earlier analysis"
            }

            // Other tools - reuse outputs if already run
            if (!(params.run_mode in ['terp', 'all'])) {
                println "TERP analysis not run earlier, running now for RMD report..."
        igv_tools(boosts_igv_channel)
        cramino_report(boosts_cramino)
        plot_genomic_regions(boosts_plot_genomic_regions_channel)
            } else {
                println "Reusing TERP outputs from earlier analysis"
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
 
        mergecnv_out = annotatecnv_results.rmdcnvtumornumber
            .combine(merge_annotation.out.occmergeout, by:0)
            .combine(run_nn_classifier.out.rmdnanodx, by: 0)
            .combine(mgmt_promoter.out.mgmtresultsout, by:0)
            .combine(svannasv.out.rmdsvannahtml, by:0)
            .combine(svannasv_fusion_events.out.filterfusioneventout, by:0)
            .combine(igv_tools.out.tertp_out_igv, by:0)
            .combine(cramino_report.out.craminostatout, by:0)
            .combine(plot_genomic_regions.out.plot_genomic_regions_out, by:0)
            // Create final map for markdown report
        mergecnv_out_map = mergecnv_out.map { sample_id, cnv_plot, tumor_copy_number, annotatedcnv_filter_header, cnv_chr9, cnv_chr7, merge_annotation_filter_snvs_allcall, nanodx_classifier, mgmt_results, svannahtml, fusion_events, terphtml, craminoreport, egfr_coverage, idh_coverage, tertp_coverage -> [
                    sample_id,
                    craminoreport,
                    nanodx_classifier,
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
                    terphtml,
                    egfr_coverage,
                    idh_coverage,
                    tertp_coverage
                ]
            }.view()

            // Generate markdown report
            markdown_report(mergecnv_out_map)
        }

    // emit:
    //     markdown_out = params.run_mode_analysis == 'rmd' ? 
    //         markdown_report.out.markdown_report : 
    //         Channel.empty()
}

// Helper function to extract sample_id from BAM filename
//def extractSampleId(file) {
//    def filename = file.getName()
//    return filename.split('\\.')[0]  // Get everything before the first dot
//}
//}