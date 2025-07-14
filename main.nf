#!/usr/bin/env nextflow
nextflow.enable.dsl=2


// Include pipeline modules conditionally
if (params.run_mode_mergebam || params.run_mode_order) {
    include { mergebam } from './modules/mergebam.nf'
}
if (params.run_mode_epi2me || params.run_mode_order) {
    include { epi2me }   from './modules/epi2me.nf'
}
if (params.run_mode_analysis || params.run_mode_order) {
    include { analysis } from './modules/analysis.nf'
}

workflow {
    if (params.run_mode_order) {
        // Set run_mode_analysis to 'all' when using run_mode_order to ensure all analyses run
        params.run_mode_analysis = 'all'
        
        log.info """
        Running pipelines sequentially in strict order:
        1. Mergebam Pipeline
        2. Epi2me Pipeline
        3. Analysis Pipeline
        """

        // Step 1: Run mergebam
        log.info "=== Starting Mergebam Pipeline ==="
        def mergebam_results = mergebam()

        // Step 2: Run epi2me
        log.info "=== Starting Epi2me Pipeline ==="
        def epi2me_results = epi2me(mergebam_results.merged_bams)

        // Step 3: Prepare analysis input using epi2me outputs and mergebam outputs
        def analysis_input = epi2me_results.results
            .join(mergebam_results.occ_bams, by: 0)
            .map { joined ->
                println "DEBUG: joined: ${joined}"
                def sample_id = joined[0]
                def modkit = joined[1]
                def segs_bed = joined[2]
                def bins_bed = joined[3]
                def segs_vcf = joined[4]
                def sv = joined[5]
                def occ_bam = joined[6]
                def occ_bai = joined[7]

                def ref = file(params.reference_genome)
                def ref_bai = file(params.reference_genome_bai)
                def tr_bed = file(params.tr_bed_file)

                tuple(
                    sample_id, 
                    occ_bam, 
                    occ_bai, 
                    ref, 
                    ref_bai, 
                    tr_bed, 
                    modkit, 
                    segs_bed, 
                    bins_bed, 
                    segs_vcf, 
                    sv
                )
            }

        // Step 4: Run analysis
        log.info "=== Starting Analysis Pipeline ==="
        def analysis_results = analysis(analysis_input)
        
    } else {
        if (params.run_mode_mergebam) mergebam()
        if (params.run_mode_epi2me) epi2me(Channel.empty())
        if (params.run_mode_analysis) analysis(Channel.empty())
    }
}

// Single workflow completion handler
workflow.onComplete {
    def msg = """
        Pipeline execution summary
        ---------------------------
        Completed at : ${workflow.complete}
        Duration    : ${workflow.duration}
        Success     : ${workflow.success}
        workDir     : ${workflow.workDir}
        exit status : ${workflow.exitStatus}
        """
    if (workflow.success) {
        log.info msg
        if (params.run_mode_analysis == 'rmd' || params.run_mode_order) {
            log.info "RMD report generated successfully"
        }
    } else {
        log.error msg
    }
}

workflow.onError {
    log.error """
        Pipeline execution failed
        ---------------------------
        Error message: ${workflow.errorMessage}
        """
}
