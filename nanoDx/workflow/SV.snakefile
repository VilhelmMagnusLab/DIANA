rule callSVs:
    input:
        bam="results/bam/{sample}.bam",
        bai="results/bam/{sample}.bam.bai",
    output:
        "results/sv/{sample}.{format}"
    wildcard_constraints:
        format="vcf|bedpe"
    conda: "envs/SV.yaml"
    shell:
        "sniffles -m {input.bam} --{wildcards.format} {output} --min_support 5"

rule circosPlot:
    input: "results/sv/{sample}.bedpe"
    output: "results/plots/{sample}.SV.circos.pdf"
    conda: "envs/SV.yaml"
    script: "scripts/plotSV.R"
