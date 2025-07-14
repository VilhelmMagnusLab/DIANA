rule make_GC_plot:
    input:
        BAM="results/bam/{sample}.bam",
        ref_chopped=Path(workflow.basedir).parent / "static/hg19_1K_subsample.fa"
    output:
        GC_plot="results/figures/{sample}_GC.pdf",
        readlength_plot="results/figures/{sample}_readlength.pdf",
        length_dist="results/stats/{sample}-length_dist.RData"
    conda: "envs/basicR.yaml"
    resources: mem_mb=32768
    script: "scripts/GC_histogram.R"


localrules: PDFreport_WGS, email_report
rule PDFreport_WGS:
    input:
        demux="results/stats/{sample}_demux_stats.txt",
        nanostat="results/stats/{sample}.nanostat.txt",
        CN="results/ichorCNA/{sample}_genomeWide.pdf",
        votes="results/classification/{sample}-votes-NN-{trainingSet}.tsv",
        DICT_FILE=lambda wildcards: Path(workflow.basedir).parent / f"static/{wildcards.trainingSet}_dictionary.txt",
        GC="results/figures/{sample}_GC.pdf",
        RL="results/figures/{sample}_readlength.pdf",
        tSNE="results/plots/{sample}-tSNE-{trainingSet}.pdf" if config["dim_reduction_report"] else [],
        mosdepth="results/stats/{sample}.mosdepth.summary.txt"
    output: "results/reports/{sample}_WGS_report_{trainingSet}.pdf"
    params:
        title="nanopore low-pass whole genome sequencing report"
    resources: pdfReport=1
    conda: "envs/PDFreport.yaml"
    script: "scripts/WGSreport.Rmd"

use rule PDFreport_WGS as CSFreport_WGS with:
    input:
         demux="results/stats/{sample}_demux_stats.txt",
         nanostat="results/stats/{sample}_sizeSelected_50bp_700bp.nanostat.txt",
         CN="results/ichorCNA/{sample}_sizeSelected_50bp_700bp_genomeWide.pdf",
         votes="results/classification/{sample}_sizeSelected_50bp_700bp-votes-NN-{trainingSet}.tsv",
         DICT_FILE=lambda wildcards: Path(workflow.basedir).parent / f"static/{wildcards.trainingSet}_dictionary.txt",
         GC="results/figures/{sample}_sizeSelected_50bp_700bp_GC.pdf",
         RL="results/figures/{sample}_sizeSelected_50bp_700bp_readlength.pdf",
         tSNE="results/plots/{sample}_sizeSelected_50bp_700bp-tSNE-{trainingSet}.pdf" if config["dim_reduction_report"] else [],
         mosdepth="results/stats/{sample}_sizeSelected_50bp_700bp.mosdepth.summary.txt"
    params:
         title="nanopore low-pass cfDNA WGS report (in silico size selection 50-700bp)"
    output: "results/reports/{sample}_cfDNA_report_{trainingSet}.pdf"


rule email_report:
    input: 
        report="results/reports/{sample}_WGS_report_{trainingSet}.pdf",
        cnv="results/igv/{sample}-1000-0.05.seg"
    output: 
        touch("results/tmp/{sample}_WGS_report_{trainingSet}.sent")
    params:
        email=config["email"]
    shell: 
        "echo 'WGS report attached...' | mail -s 'WGS report {wildcards.sample}' -a {input.report} -a {input.cnv} {params.email}"
