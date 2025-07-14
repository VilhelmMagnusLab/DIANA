#!/usr/bin/env python3
import sys
import pandas as pd
import pickle
import numpy as np
from pathlib import Path

def load_model(model_path):
    try:
        with open(model_path, 'rb') as f:
            return pickle.load(f)
    except Exception as e:
        print(f"Error loading model: {e}", file=sys.stderr)
        sys.exit(1)

def load_bed_file(bed_path):
    try:
        return pd.read_csv(bed_path, delimiter="\t")
    except Exception as e:
        print(f"Error loading bed file: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    try:
        # Get paths from snakemake
        model_file_path = snakemake.input.model
        bed_file_path = snakemake.input.bed
        output_summary_path = snakemake.output.txt
        output_votes_path = snakemake.output.votes

        # Load data
        print(f"Loading model from {model_file_path}")
        model = load_model(model_file_path)
        
        print(f"Loading bed file from {bed_file_path}")
        bed_data = load_bed_file(bed_file_path)
        
        # Make predictions
        print("Making predictions...")
        predictions = model.predict(bed_data)
        probabilities = model.predict_proba(bed_data)
        
        # Create results DataFrame
        results_df = pd.DataFrame({
            'Prediction': predictions,
            'Confidence': np.max(probabilities, axis=1)
        })
        
        # Save results
        print(f"Saving results to {output_votes_path}")
        results_df.to_csv(output_votes_path, sep='\t', index=False)
        
        # Write summary
        print(f"Writing summary to {output_summary_path}")
        with open(output_summary_path, 'w') as f:
            f.write(f"Number of samples: {len(predictions)}\n")
            f.write(f"Unique predictions: {', '.join(map(str, np.unique(predictions)))}\n")
            f.write(f"Average confidence: {np.mean(np.max(probabilities, axis=1)):.3f}\n")
        
        print("Processing completed successfully")
        
    except Exception as e:
        print(f"Error in script execution: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
