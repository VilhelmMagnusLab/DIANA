rule ichorCNA:
  input: "/home/chbope/Documents/trash/epi2me/qdna_seq/T21-058_raw_bins.bin.wig",
  output:
    pdf="/home/chbope/Documents/trash/epi2me/qdna_seq/T21_genomeWide.pdf",
    seg="/home/chbope/Documents/trash/epi2me/qdna_seq/T21.seg",
    txt="/home/chbope/Documents/trash/epi2me/qdna_seq/T21.params.txt",
    dir=directory("/home/chbope/Documents/trash/epi2me/qdna_seq/")
  conda: "envs/ichorCNA.yaml"
  shell: """mkdir -p {output.dir} && \
            R -e "if (file.exists('static/ichorCNA')==FALSE) system(paste0('ln -s ', find.package('ichorCNA'), '/extdata static/ichorCNA'))" && \
            runIchorCNA.R \
              --id {wildcards.sample} \
              --WIG {input} \
              --gcWig static/ichorCNA/gc_hg19_1000kb.wig \
              --mapWig static/ichorCNA/map_hg19_1000kb.wig \
              --normalPanel static/ichorCNA/HD_ULP_PoN_1Mb_median_normAutosome_mapScoreFiltered_median.rds \
              --genomeStyle UCSC \
              --estimateNormal TRUE \
              --estimatePloidy TRUE \
              --estimateScPrevalence FALSE \
              --minMapScore 0.75 \
              --normal  "c(0.5,0.6,0.7,0.8,0.9,0.95,0.99)" \
              --ploidy "c(2,3)" \
              --txnStrength 10000 \
              --txnE 0.9999 \
              --plotYLim "c(-2,4)" \
              --outDir {output.dir} && \
            cp {output.dir}/{wildcards.sample}/{wildcards.sample}_genomeWide.pdf {output.pdf} && \
            cp {output.dir}/{wildcards.sample}.seg {output.seg} && \
            cp {output.dir}/{wildcards.sample}.params.txt {output.txt}
         """
