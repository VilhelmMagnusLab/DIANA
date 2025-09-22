rule NN_classifier:
    input:
        bed = "/home/chbope/Documents/trash/methyl_call.bed",
        model = "/home/chbope/extension/data/reference/nanoDx/static/Capper_et_al_NN.pkl"
    output:
        txt="/home/chbope/Documents/trash/T001_nanodx5.txt",
        votes="/home/chbope/Documents/trash/T001_nanodx5.tsv"
    conda: "envs/NN_model.yaml"
    threads: 4
    resources: mem_mb=16384
    script: "scripts/classify_NN_bedMethyl.py"
