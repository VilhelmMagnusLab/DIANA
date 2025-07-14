import glob
import os

def list_raw(wildcards):
  fast5 = glob.glob(config["FAST5_basedir"] + "/" + wildcards.sample + "/**/*.fast5", recursive=True)
  pod5 = glob.glob(config["FAST5_basedir"] + "/" + wildcards.sample +  "/**/*.pod5", recursive=True)
  bam = glob.glob(config["FAST5_basedir"] + "/" + wildcards.sample +  "/**/*.bam", recursive=True)
  fq = glob.glob(config["FAST5_basedir"] + "/" + wildcards.sample +  "/**/*.fq", recursive=True)
  if len(fast5 + pod5 + bam + fq) == 0:
    logger.warning("WARNING: No raw data files (POD5, FAST5, FASTQ or BAM) found for sample " + wildcards.sample)
  else:
    logger.info("Sample " + wildcards.sample + ": " + str(len(pod5)) + " POD5, " + str(len(fast5)) + " FAST5, " + str(len(fq)) + " FASTQ, " + str(len(bam)) + " BAM files detected.")
  return fast5, pod5, bam, fq

def list_fast5_pod5(wildcards):
  fast5, pod5, bam, fq = list_raw(wildcards)
  return fast5 + pod5

def list_bam(wildcards):
  fast5, pod5, bam, fq = list_raw(wildcards)
  return bam

def list_fq(wildcards):
  fast5, pod5, bam, fq = list_raw(wildcards)
  return fq

def list_basecall_targets(wildcards):
  files = list_fast5_pod5(wildcards)
  files.sort(key=os.path.getmtime)
  files = [i.replace(config["FAST5_basedir"], 'results/basecalling_parallel', 1) for i in files]
  return files[:config["max_fast5"]] if 'max_fast5' in config.keys() else files

rule setup_dorado:
  output: "resources/tools/dorado-0.3.4-linux-x64/bin/dorado"
  shell: "mkdir -p resources/tools && wget https://cdn.oxfordnanoportal.com/software/analysis/dorado-0.3.4-linux-x64.tar.gz -O - | tar -xz -C resources/tools"

rule setup_guppy_cpu:
  output: directory("resources/tools/ont-guppy-cpu")
  shell: "mkdir -p resources/tools && wget https://cdn.oxfordnanoportal.com/software/analysis/ont-guppy-cpu_6.4.6_linux64.tar.gz -O - | tar -xz -C resources/tools"

rule setup_guppy_gpu:
  output: directory("resources/tools/ont-guppy")
  shell: "mkdir -p resources/tools && wget https://cdn.oxfordnanoportal.com/software/analysis/ont-guppy_6.4.6_linux64.tar.gz -O - | tar -xz -C resources/tools"

rule download_model:
  input: "resources/tools/dorado-0.3.4-linux-x64/bin/dorado"
  output: directory("resources/dorado_models/{model}")
  shell: "resources/tools/dorado-0.3.4-linux-x64/bin/dorado download --model {wildcards.model} --directory resources/dorado_models"

### map system proxy settings to dorado-specific environment variables
import urllib.request
from urllib.parse import urlparse
proxies = urllib.request.getproxies()
http_proxy = None
if 'https' in proxies.keys():
  http_proxy = urlparse(proxies['https'])
elif 'http' in proxies.keys():
  http_proxy = urlparse(proxies['http'])
if http_proxy != None:
  logger.debug(f"Setting dorado environment variables: dorado_proxy={http_proxy.hostname} dorado_proxy_port={http_proxy.port}")
  if "dorado_proxy" in os.environ or "dorado_proxy_port" in os.environ:
    logger.warning("WARNING: overwriting dorado_proxy/dorado_proxy_port environment variables.")
  os.environ["dorado_proxy"] = http_proxy.hostname
  os.environ["dorado_proxy_port"] = str(http_proxy.port)
  envvars:
    "dorado_proxy",
    "dorado_proxy_port"

if config["basecalling_mode"]=="dorado":
  rule basecall_dorado:
    input:
      fast5 = config["FAST5_basedir"] + "/{sample}/{file}",
      model = "resources/dorado_models/" + config["dorado_model"]
    output:
      out = temporary(directory("results/basecalling_parallel/{sample}/{file}")),
      tmp = temporary(directory("results/tmp/bc/{sample}/{file}"))
    threads: 4
    params: options = config["dorado_options"] if 'dorado_options' in config.keys() else "--modified-bases 5mCG_5hmCG" # by default, call 5mC + 5hmC because currently only combined models are available for R10.4.1 chemistry
    conda: "envs/minimap.yaml"
    resources: gpu=1
    shell:
      "mkdir {output.tmp} ; cp {input.fast5} {output.tmp} ; mkdir -p {output.out} ; "
      "resources/tools/dorado-0.3.4-linux-x64/bin/dorado basecaller {input.model} {output.tmp}/ {params.options} | samtools view -bS - > {output.out}/{wildcards.file}.bam"

elif config["basecalling_mode"]=="dorado_posthoc":
  rule basecall_dorado_posthoc:
    input:
      dir = config["FAST5_basedir"] + "/{sample}",
      raw = list_fast5_pod5, # list individual raw files to trigger re-run upon change
      model = "resources/dorado_models/" + config["dorado_model"]
    output:
      "results/fastq/{sample}.fq"
    threads: 4
    params:
      options = config["dorado_options"] if 'dorado_options' in config.keys() else "--modified-bases 5mCG_5hmCG" # by default, call 5mC + 5hmC because currently only combined models are available for R10.4.1 chemistry
    conda: "envs/minimap.yaml"
    resources: gpu=1
    shell: "resources/tools/dorado-0.3.4-linux-x64/bin/dorado basecaller {input.model} {input.dir} --recursive {params.options} | samtools fastq -T '*' > {output}"

elif config["basecalling_mode"]=="guppy_cpu":
  rule basecall_guppy:
    input:
      "resources/tools/ont-guppy-cpu",
      fast5 = config["FAST5_basedir"] + "/{sample}/{file}"
    output:
      out = temporary(directory("results/basecalling_parallel/{sample}/{file}")),
      tmp = temporary(directory("results/tmp/bc/{sample}/{file}"))
    params:
      model = config["guppy_model"],
      options = config["guppy_options"] if 'guppy_options' in config.keys() else ""
    threads: 4
    shell:
      "mkdir {output.tmp} ; cp {input.fast5} {output.tmp} ; mkdir -p {output.out} ; "
      "resources/tools/ont-guppy-cpu/bin/guppy_basecaller -i {output.tmp} -s {output.out} -c {params.model} --bam_out --disable_pings {params.options}"

elif config["basecalling_mode"]=="guppy_gpu":
  rule basecall_guppy_gpu:
    input:
      "resources/tools/ont-guppy",
      fast5 = config["FAST5_basedir"] + "/{sample}/{file}"
    output:
      out = temporary(directory("results/basecalling_parallel/{sample}/{file}")),
      tmp = temporary(directory("results/tmp/bc/{sample}/{file}"))
    params:
      model = config["guppy_model"],
      options = config["guppy_options"] if 'guppy_options' in config.keys() else "--device cuda:0"
    threads: 1
    resources: gpu=1
    shell:
      "mkdir {output.tmp} ; cp {input.fast5} {output.tmp} ; mkdir -p {output.out} ; "
      "resources/tools/ont-guppy/bin/guppy_basecaller -i {output.tmp} -s {output.out} -c {params.model} --bam_out --disable_pings {params.options}"


if config["basecalling_mode"]=="none_fastq":
  rule mirror_fastq:
    input:
      dir = config["FAST5_basedir"] + "/{sample}",
      fq = list_fq
    output: "results/fastq/{sample}.fq"
    conda: "envs/minimap.yaml"
    shell: "find -L {input.dir} -name '*.fq' | xargs -n 1 cat > {output}"

elif config["basecalling_mode"]=="none_bam":
  rule mirror_modbam:
    input:
      dir = config["FAST5_basedir"] + "/{sample}",
      bam = list_bam
    output: "results/fastq/{sample}.fq"
    conda: "envs/minimap.yaml"
    shell: "find -L {input.dir} -name '*.bam' | xargs -n 1 samtools fastq -T '*' > {output}"

elif config["basecalling_mode"]!="dorado_posthoc":
  rule merge_fastq:
    input: list_basecall_targets
    output: "results/fastq/{sample}.fq"
    conda: "envs/minimap.yaml"
    shell: "find results/basecalling_parallel/{wildcards.sample}/ -name '*.bam' | xargs -n 1 samtools fastq -T '*' > {output}"


rule demux_QC:
    input: "results/fastq/{sample}.fq"
    output:
        txt="results/stats/{sample}_demux_stats.txt",
        fq100k=temp("results/fastq/{sample}.100k.fq"),
        tmp=temp(directory("results/tmp/{sample}_qcat"))
    conda: "envs/demux.yaml"
    shell: "seqtk sample {input} 100000 > {output.fq100k} && qcat -f {output.fq100k} -b {output.tmp} 2> {output.txt}"
