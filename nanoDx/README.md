# nanoDx pipeline 

nanoDx is an open-source, end-to-end bioinformatics pipeline for DNA methylation-based classification of tumours using nanopore low-pass whole genome sequencing data. 

# News and updates

## Major release (v1.0rc3)

**IMPORTANT NOTE:** Starting with version 1.0, nanoDx uses **crossNN**, a pre-trained neural network model, for classification. Please see the preprint for a benchmarking: [Yuan et al. 2024 ](https://doi.org/10.1101/2024.01.22.24301523). This goes along with a major remodeling of the folder architecture (to comply with best practice for snakemake, the workflow management system used). If you migrate from version 0.6.2 or earlier, you will have to update you commands/launch scripts for generating reports.

Please find the complete release history and changelog here: [https://gitlab.com/pesk/nanoDx/-/releases](https://gitlab.com/pesk/nanoDx/-/releases).

To stay informed about releases and news related to the nanoDx pipeline, you can self-subscribe to the nanodx-users mailing list (no regular postings): [https://mailman.charite.de/mailman/listinfo/nanodx-users](https://mailman.charite.de/mailman/listinfo/nanodx-users)

# Installation and configuration

First, we assume that you have installed the following dependencies:

 - conda (e.g. [miniforge](https://github.com/conda-forge/miniforge))
 - snakemake (v7.32.4 is currently recommended, make sure to run under python 3.11 to work around [this](https://github.com/snakemake/snakemake/issues/2480) incompatibility with python 3.12)
 - LaTeX (e.g. `sudo apt-get install texlive texlive-latex-extra` on Ubuntu)

Then, you can install the pipeline using:

`git clone https://gitlab.com/pesk/nanoDx.git`

To use a specific version, e.g. v1.0rc3, check it out as follows:

`git checkout v1.0rc3`

To update to the latest version, run:

`git checkout master && git pull`

### Static data 

crossNN models and reference sets for dimensionality reduction can be downloaded from [**Zenodo**](https://zenodo.org/records/14006255).

crossNN models are also available in the [**crossNN gitlab repository**](https://gitlab.com/euskirchen-lab/crossNN/-/tree/master/models).

### Configuration

Some paths need to be set in the `config.yaml` file (see template `config.EXAMPLE.yaml`) in the pipeline directory to the raw data basedir (see Input data below) and the reference genome to be used:

```
ref_genome: /path/to/hg19.fa
FAST5_basedir: /path/to/FAST5_or_POD5
trainingset_dir: /path/to/models/and/referencesets

basecalling_mode: dorado_posthoc

# dorado parameters
dorado_model: dna_r10.4.1_e8.2_400bps_hac@v4.1.0
dorado_options: "--modified-bases 5mCG_5hmCG"
```

## (Modified) base calling

Until version v0.5.1, modified bases (5mC) were called using [nanopolish](https://github.com/jts/nanopolish). However, nanopolish is no longer compatible to recent FAST5/POD5 file formats and sequencing chemistry.
We have therefore implemented base and 5mC calling using ONT's proprietary software (guppy or dorado) which needs to be configured using the `basecalling_mode` option:

 - `guppy_cpu`: basecalling will be performed using a recent guppy version (which will be automatically installed in the `resources/tools` subfolder) in a parallelized fashion (one job per FAST5 file) using CPU computation only.
This option is recommended for high-performance compute cluster with high CPU capacity but no or little GPU resources.
 - `guppy_gpu`: basecalling will be performed using a recent guppy version supporting GPU. Recommended for GPU-equipped workstations. Basecalling is performed for each FAST5 file individually.
 - `dorado`: basecalling using the experimental [dorado](https://github.com/nanoporetech/dorado) basecaller. Basecalling is performed for each POD5/FAST5 file individually. This allows incremental basecalling while sequencing without having to re-basecall the entire run. This option is recommended for GPU equipped workstations and near-realtime analysis.
 - `dorado_posthoc`: basecalling using dorado, but all POD5/FAST5 are basecalled as bulk. This greatly increases performance when basecalling is performed after a sequencing run has completed (post-hoc). Not recommended during runs, as all raw data will be re-basecalled.
 - `none_bam`: No base or modified base calling is performed. (Unaligned) modified BAM files output by MinKNOW or other pipelines are expected in the input folder (see `FAST5_basedir` config directive). This option requires that modified bases (5mC in CpG context) have been called with the correct model.
 - `none_fastq`: No base or modified base calling is performed. FASTQ containing methylation calls (via MM/ML tags) are expected in the input folder (see `FAST5_basedir` config directive). This option requires that modified bases (5mC in CpG context) have been called with the correct model.

The `perform_basecalling` flag is no longer supported.
Command line options (e.g. to configure CUDA devices) can be passed to basecallers using the `guppy_options` and `dorado_options` options, respectively, in the config file.


## Cluster vs. local workstation execution

The nanoDx pipeline can be run both on a single workstation or in a compute cluster environment. 
 - **HPC**: You will need to configure snakemake to work with your cluster. Example launch scripts (`run_slurm.sh`) for use with SLURM are provided in the repo. If basecalling is to be performed at part of the pipeline, CPU-only basecalling can be parallelized using the `guppy_cpu` basecalling mode.
 - **Workstation/PC/Laptop**: When running nanoDx on a single workstation, you will need either a) CUDA-enabled GPU acceleration for basecalling or b) use already basecalled raw data (usually unaligned BAM files via the `none_bam` basecalling mode).


# Input data

The pipeline takes one top level folder per sample as input. The base directory is set in the `config.yaml` file using the `FAST5_basedir` option.

So for each sample, `<BASEDIR>/<samplename>/` should contain all FAST5 or POD5 files. All subfolders are processed recursively. 
The pipeline can handle multi-read FAST5 or POD5 files. If you have older single-read FAST5 data, you can convert them using [single_to_multi_fast5](https://github.com/nanoporetech/ont_fast5_api) script provided by ONT.

# Output

# Quick start

Typically, the pipeline should generate a PDF report with CNV plot and DNA methylation-based classification using the Heidelberg brain tumor classifier v11b4 reference set (Capper et al.) together with quality control metrics. On a local workstation, a typical report can be generated using:

`snakemake --use-conda -c all results/reports/<SAMPLE>_WGS_report_Capper_et_al.pdf`

A dry run can be invoked by appending snakemake's `-n` option. This is useful before starting analysis of large datasets and for debugging:

`snakemake --use-conda -c all results/reports/<SAMPLE>_WGS_report_Capper_et_al.pdf -n`

Using a SLURM-managed compute cluster, a typical report could be generated using:

`./run_slurm.sh results/reports/<SAMPLE>_WGS_report_Capper_et_al.pdf`

This works for other training sets, too:

`./run_slurm.sh results/reports/<SAMPLE>_WGS_report_<TRAININGSET>.pdf`

Currently, we provide two neural network models and reference sets:

- `Capper_et_al` for primary brain tumour classification. It has been trained using the public Heidelberg brain tumor classifier v11b4 reference set (see [Capper et al., Nature 2018](https://doi.org/10.1038/nature26000) and [GSE90496](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE90496))

- `pancan_devel_v5i`, an experimental pan-cancer classifier trained from curated publicly available data. This training set is currently unpublished and not yet described in detail.

#    Batch mode

Sometimes you might want to classify several samples at once. You can use generate a zipped archive of reports for a given training set using the batch_samples option in your main config file (or an additional one). The following command would use an additional config file to define your batch and generate PDF reports for all samples plus a ZIP archive of these reports:

`./run_slurm.sh --configfile my_batch.yaml results/reports/batch_reports_<TRAININGSET>.zip`

my_batch.yaml should then hold the sample IDs of your batch to be processed:
```
batch_samples:
- sample1
- sample2
```

# Current issues

- Rendering several reports in parallel (by specifying two or more target PDFs) fails due ambigious intermediate/temp file naming. You can work around this by specifing the (imaginary) pdfReport ressource when invoking snakemake: `--ressources pdfReport=1`. This option is automatically passed when using the `run_slurm.sh` wrapper, but you have to explicitly pass this when invoking snakemake directly. 
- ONT's dorado basecaller currently does not respect system-wide proxy settings (like the `HTTPS_PROXY` environment variable). nanoDx now sets dorado-specific environment variables `dorado_proxy` and `dorado_proxy_port` depending on the system's https/http proxy settings (possibly overwriting them).


# Citation

If you use the nanoDx pipeline in your research, *please consider citing the following papers* in your work:

[Yuan, D., Jugas, R., Pokorna, P., Sterba, J., Slaby, O., Schmid, S., Siewert, C., Osberg, B., Capper, D., Zeiner, P., Weber, K., Harter, P., Jabareen, N., Mackowiak, S., Ishaque, N., Eils, R., Lukassen, S., & Euskirchen, P. (2024). An explainable framework for cross-platform DNA methylation-based classification of cancer (S. 2024.01.22.24301523). medRxiv.](https://doi.org/10.1101/2024.01.22.24301523)


[Kuschel LP, Hench J, Frank S, Hench IB, Girard E, Blanluet M, Masliah-Planchon J, Misch M, Onken J, Czabanka M, Yuan D, Lukassen S, Karau P, Ishaque N, Hain EG, Heppner F, Idbaih A, Behr N, Harms C, Capper D, Euskirchen P. Robust methylation-based classification of brain tumours using nanopore sequencing. Neuropathol Appl Neurobiol. 2023 Feb;49(1):e12856. doi: 10.1111/nan.12856.](https://doi.org/10.1111/nan.12856)

[Euskirchen P, Bielle F, Labreche K, Kloosterman WP, Rosenberg S, Daniau M, Schmitt C, Masliah-Planchon J, Bourdeaut F, Dehais C, Marie Y, Delattre JY, Idbaih A. Same-day genomic and epigenomic diagnosis of brain tumors using real-time nanopore sequencing. Acta Neuropathol. 2017 Nov;134(5):691-703. doi: 10.1007/s00401-017-1743-5.](https://doi.org/10.1007/s00401-017-1743-5)

# Disclaimer

Methylation-based classification using nanopore whole genome sequening is a research tool currently under development.
Interpretation and implementation of the results in a clinical setting is in the sole responsibility of the treating physician.
