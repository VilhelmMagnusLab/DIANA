#!/bin/bash

# Quick debug script to test sample loading
SAMPLE_IDS_FILE="/home/chbope/extension/nWGS_manuscript_data/data/testdata/sample_ids_bam.txt"

echo "=== Debug Sample Loading ==="
echo "File: $SAMPLE_IDS_FILE"
echo "File size: $(wc -c < "$SAMPLE_IDS_FILE") bytes"
echo "Line count: $(wc -l < "$SAMPLE_IDS_FILE")"
echo "Content:"
cat -A "$SAMPLE_IDS_FILE"
echo

samples=()
line_count=0
valid_count=0

echo "=== Parsing Logic ==="
while IFS=$'\t' read -r sample_id flow_cell_id || [[ -n "$sample_id" ]]; do
    ((line_count++))
    sample_id=$(echo "$sample_id" | xargs)
    
    echo "Line $line_count: raw='$sample_id' flow_cell='${flow_cell_id:-}'"
    
    # Skip empty lines and comments
    if [[ -n "$sample_id" && ! "$sample_id" =~ ^# ]]; then
        samples+=("$sample_id")
        ((valid_count++))
        echo "  -> Added valid sample #$valid_count: $sample_id"
    else
        echo "  -> Skipped: empty or comment"
    fi
done < "$SAMPLE_IDS_FILE"

echo
echo "=== Results ==="
echo "Total lines processed: $line_count"
echo "Valid samples found: $valid_count"
echo "Samples array: ${samples[*]}"
echo "Array length: ${#samples[@]}"
