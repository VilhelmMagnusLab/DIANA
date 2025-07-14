library(ACE)

runACE(inputdir = snakemake@input[["bamDir"]], 
	snakemake@output[["dir"]], 
	filetype = 'bam', 
	genome = 'hg19', 
	c(500,1000), 
	ploidies = 2, 
	imagetype = 'pdf', 
	method = 'RMSE', 
	penalty = 0, 
	cap = 12, 
	bottom = 0, 
	trncname = FALSE, 
	printsummaries = TRUE,
	autopick = TRUE)
