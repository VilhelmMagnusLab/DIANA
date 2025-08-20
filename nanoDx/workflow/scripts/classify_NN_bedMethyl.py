#!/usr/bin env python
import pandas as pd
from NN_model import NN_classifier

# Retrieve paths from Snakemake's provided input and output variables
model_file_path = snakemake.input.model
bed_file_path = snakemake.input.bed
output_summary_path = snakemake.output.txt
output_votes_path = snakemake.output.votes

# Initialize the model
NN = NN_classifier(model_file_path)
bed_sample = pd.read_csv(bed_file_path, delimiter="\t", index_col=0)  # Load the bed file
predictions, class_labels, n_features = NN.predict(bed_sample)

# Write predictions to a table
#df = pd.DataFrame({'class': class_labels, 'score': predictions, 'num_features': [n_features]})
df = pd.DataFrame({
    'class': class_labels,
    'score': predictions,
    'num_features': [n_features] * len(class_labels)  # repeat `n_features` if needed
})
df.to_csv(output_votes_path, sep='\t', index=False)

# Write summary to a txt file
summary = [
    f'Number of features: {n_features}',
    f'Predicted Class: {class_labels[0]}',
    f'Score: {predictions[0]}'
]

with open(output_summary_path, 'w') as f:
    f.write("\n".join(summary))
