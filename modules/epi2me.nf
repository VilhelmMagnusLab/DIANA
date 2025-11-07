#!/usr/bin/env nextflow
nextflow.enable.dsl=2

//---------------------------------------------------------------------
// Epi2me Pipeline: Modified base calling, structural variant calling, and copy number variation analysis
//---------------------------------------------------------------------

//---------------------------------------------------------------------
// Process Definitions
//---------------------------------------------------------------------

process run_epi2me_modkit {
    label 'modkit'
    publishDir "${params.path}/routine_epi2me/${sample_id}", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(bam), path(bai), path(reference_genome), path(reference_genome_bai)

    output:
    tuple val(sample_id), path("${sample_id}.wf_mods.bedmethyl.gz")

    script:
    """
    export PATH=/opt/custflow/epi2meuser/conda/bin:\$PATH
    
    # Check if modkit is available
    which modkit || echo "modkit not found in PATH"
    
    # Check if input files exist
    if [ ! -f "${bam}" ]; then
        echo "ERROR: BAM file not found: ${bam}"
        exit 1
    fi
    
    if [ ! -f "${reference_genome}" ]; then
        echo "ERROR: Reference genome not found: ${reference_genome}"
        exit 1
    fi
    
    modkit pileup \
      ${bam} \
      ${sample_id}.wf_mods.bedmethyl \
      --ref ${reference_genome} \
      --interval-size ${params.interval_size} \
      --log-filepath ${sample_id}_modkit.log \
      --cpg \
      --combine-strands

    gzip ${sample_id}.wf_mods.bedmethyl
    
    # Check if output was created
    ls -la ${sample_id}.wf_mods.bedmethyl.gz
    """
}

process run_epi2me_sv {
    label 'pipeline1'
    publishDir "${params.path}/routine_epi2me/${sample_id}", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(bam), path(bai)

    output:
    tuple val(sample_id), path("${sample_id}.vcf.gz"), path("${sample_id}.vcf.gz.tbi"), emit: svvcf

    script:
    """
    # Check if sniffles is available
    which sniffles || echo "sniffles not found in PATH"
    
    # Check if input file exists
    if [ ! -f "${bam}" ]; then
        echo "ERROR: BAM file not found: ${bam}"
        exit 1
    fi
    
    # Run Sniffles2
    sniffles --input ${bam} --vcf ${sample_id}.vcf.gz
    
    # Check if output was created
    ls -la ${sample_id}.vcf.gz
    """
}

process run_epi2me_cnv {
    label 'epi2me'
    publishDir "${params.path}/routine_epi2me/${sample_id}", mode: "copy", overwrite: true

    input:
    tuple val(sample_id), path(bam), path(bai), path(reference_genome), path(reference_genome_bai)

    output:
    tuple val(sample_id), path("${sample_id}_segs.bed"), path("${sample_id}_bins.bed"), path("${sample_id}_segs.vcf"), path("${sample_id}_copyNumbersCalled.rds"), path("${sample_id}_calls.bed"), path("${sample_id}_calls.vcf")
    
    script:
    """
    # Create a .Renviron file to forcefully override R library paths
    # This prevents R from using host libraries even if they're accessible
    cat > .Renviron <<'RENVEOF'
R_LIBS_USER=
R_LIBS_SITE=
R_USER_CACHE_DIR=
R_PROFILE_USER=
R_ENVIRON_USER=
R_HOME=
RENVEOF

    # Clear all R environment variables to prevent host library conflicts
    # Use unset to completely remove the variables
    unset R_HOME R_LIBS R_LIBS_USER R_LIBS_SITE R_USER_CACHE_DIR R_PROFILE_USER R_ENVIRON_USER

    echo "R environment cleared for container isolation"

    # Run QDNAseq R script with explicit --vanilla flag to ignore R environment
    Rscript --no-site-file --no-init-file --no-environ $baseDir/bin/run_qdnaseq_rds.r \
        --bam ${bam} \
        --binsize ${params.binsize} \
        --out_prefix ${sample_id}

    # Check if output files were created
    ls -la ${sample_id}_*
    """
}

//---------------------------------------------------------------------
// Workflow Definition
//---------------------------------------------------------------------

workflow epi2me {
    take:
        merged_data
        
    main:
        params.run_mode = params.run_mode_epi2me ?: 'all'
        println "epi2me run mode: ${params.run_mode}"

        // Validate required parameters
        if (!params.reference_genome) {
            error "ERROR: Reference genome path not specified (params.reference_genome)"
        }
        if (!params.reference_genome_bai) {
            error "ERROR: Reference genome index path not specified (params.reference_genome_bai)"
        }

        // Create file objects for reference files
        reference_genome = file(params.reference_genome)
        reference_genome_bai = file(params.reference_genome_bai)
        episv = file(params.episv)
        epimodkit = file(params.epimodkit)
        epicnv = file(params.epicnv)    

        // Validate reference files exist
        if (!reference_genome.exists()) {
            error "ERROR: Reference genome file not found: ${params.reference_genome}"
        }
        if (!reference_genome_bai.exists()) {
            error "ERROR: Reference genome index file not found: ${params.reference_genome_bai}"
        }

        // Validate run_mode parameter
        if (!['modkit', 'cnv', 'sv', 'all'].contains(params.run_mode)) {
            error "ERROR: Invalid run_mode '${params.run_mode}' for epi2me. Valid modes: modkit, cnv, sv, all."
        }

        // Create input channel based on run mode
        // Use merged_data input for both run_mode_order and run_mode_epianalyse
        input_channel = (params.run_mode_order || params.run_mode_epianalyse) ?
            merged_data.map { sid, bam, bai, ref, ref_bai ->
                tuple(
                    sid,
                    bam,
                    bai,
                    ref,
                    ref_bai
                )
            } : Channel
            .from(file(params.epi2me_sample_id_file).readLines())
            .map { line ->
                def fields = line.tokenize("\t")
                def sample_id = fields[0].trim()
                // Try exact match first, then wildcard pattern
                def bam = file("${params.merge_bam_folder}/${sample_id}.merged.bam")
                def bai = file("${params.merge_bam_folder}/${sample_id}.merged.bam.bai")

                // If exact match doesn't exist, try wildcard pattern
                if (!bam.exists()) {
                    bam = file("${params.merge_bam_folder}/${sample_id}.*.bam")
                    bam = bam.find()
                }
                if (!bai.exists()) {
                    bai = file("${params.merge_bam_folder}/${sample_id}.*.bam.bai")
                    bai = bai.find()
                }

                if (!bam || !bai || !bam.exists() || !bai.exists()) {
                    error "BAM file or index file not found for sample ID: ${sample_id}. Tried both exact match (${sample_id}.merged.bam) and wildcard pattern (${sample_id}.*.bam)"
                }

                return tuple(
                    sample_id, 
                    bam, 
                    bai,
                    reference_genome,
                    reference_genome_bai
                )
            }

        // Run processes based on mode
        modkit_ch = Channel.empty()
        cnv_ch = Channel.empty()
        sv_ch = Channel.empty()

        if (params.run_mode in ['modkit', 'all']) {
            println "Running modkit..."
            modkit_ch = run_epi2me_modkit(input_channel)
        }

        if (params.run_mode in ['cnv', 'all']) {
            println "Running cnv..."
            cnv_ch = run_epi2me_cnv(input_channel)
        }

        if (params.run_mode in ['sv', 'all']) {
            println "Running sv..."
            sv_ch = input_channel.map { sid, bam, bai, ref, ref_bai ->
                tuple(
                    sid, 
                    bam, 
                    bai
                )
            } | run_epi2me_sv
        }

        // Create default channels for empty processes
        default_modkit = input_channel.map { sid, bam, bai, ref, ref_bai -> 
            tuple(sid, file("${params.epimodkit}/${sid}.wf_mods.bedmethyl.gz")) 
        }
        
        default_cnv = input_channel.map { sid, bam, bai, ref, ref_bai -> 
            tuple(
                sid, 
                file("${params.epicnv}/${sid}_segs.bed"),
                file("${params.epicnv}/${sid}_bins.bed"),
                file("${params.epicnv}/${sid}_segs.vcf")
            )
        }
        
        default_sv = input_channel.map { sid, bam, bai, ref, ref_bai -> 
            tuple(sid, file("${params.episv}/${sid}.vcf.gz"))
        }

        // Mix actual results with defaults (but only for standalone mode, not for run_mode_order/epianalyse)
        // In run_mode_order and run_mode_epianalyse, we want to wait for actual process outputs
        modkit_results = (params.run_mode_order || params.run_mode_epianalyse) ?
            modkit_ch : modkit_ch.mix(default_modkit)
        cnv_results = (params.run_mode_order || params.run_mode_epianalyse) ?
            cnv_ch : cnv_ch.mix(default_cnv)
        sv_results = (params.run_mode_order || params.run_mode_epianalyse) ?
            sv_ch : sv_ch.mix(default_sv)

        // Combine all results
        results_ch = input_channel
            .join(modkit_results, by: 0)
            .join(cnv_results, by: 0)
            .join(sv_results, by: 0)
            .map { args ->
                def sample_id = args[0]
                def bam = args[1]
                def bai = args[2]
                def ref = args[3]
                def ref_bai = args[4]
                def modkit = args[5]

                // CNV outputs (10 files): segs_bed, bins_bed, segs_vcf, copyNumbersCalled.rds, calls.bed, calls.vcf, raw_bins.bed, plots.pdf, isobar_plot.png, cov.png
                def segs_bed = args[6]
                def bins_bed = args[7]
                def segs_vcf = args[8]
                def rds_file = args[9]  // copyNumbersCalled.rds - needed for ACE
                // Skip the other CNV outputs (args[10] through args[15])

                // SV outputs: sv.vcf.gz and sv.vcf.gz.tbi
                def sv = args[16]
                def sv_index = args[17]

                log.info "Processing completed for sample: ${sample_id}"
                tuple(
                    sample_id,
                    modkit,
                    segs_bed,
                    bins_bed,
                    segs_vcf,
                    rds_file,
                    sv
                )
            }

    emit:
        results = results_ch
            .map { results ->
                log.info "Epi2me processing completed for sample: ${results[0]}"
                results
            }
}