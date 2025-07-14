rule demux_qcat:
    input: "results/fastq/{run}.fq"
    output: directory("results/tmpDemux/{run}")
    conda: "envs/demux.yaml"
    threads: 12
    shell: "qcat -f {input} -b results/tmpDemux/{wildcards.run} --min-score 40 -t {threads} --trim"

rule extract_fast5:
    input: 
      fast5 = config["FAST5_basedir"] + "/{run}/",
      fqDemux = "results/tmpDemux/{run}"
    output: 
      fast5dir = directory("results/demux/{run}_{barcode}"),
      ids = "results/tmpDemux/{run}_{barcode}.ids"
    conda: "envs/demux.yaml"
    shell: "awk '{{if(NR%4==1) print $1}}' {input.fqDemux}/{wildcards.barcode}.fastq | sed -e \"s/^@//\" > {output.ids} ; fast5_subset -i {input.fast5} -s {output.fast5dir} -l {output.ids} -r"
