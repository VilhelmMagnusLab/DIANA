#!/usr/bin/env python3
"""
Annotate breakpoints that don't overlap any GFF3 features as "intergenic".
Compares original breakpoints with annotated breakpoints to find missing ones.
"""

import sys
import csv
from collections import defaultdict

def read_original_breakpoints(bed_file):
    """Read original breakpoint BED file and return set of breakpoints."""
    breakpoints = {}
    with open(bed_file, 'r') as f:
        for line in f:
            if line.strip() == "":
                continue
            fields = line.strip().split('\t')
            if len(fields) < 4:
                continue

            chr_col = fields[0]
            start_col = fields[1]
            end_col = fields[2]
            name_col = fields[3]

            # Parse name: ID|svtype|breaking
            if '|' in name_col:
                parts = name_col.split('|')
                if len(parts) >= 3:
                    key = (chr_col, start_col, end_col, name_col)
                    breakpoints[key] = {
                        'chr': chr_col,
                        'start': start_col,
                        'end': end_col,
                        'name': name_col,
                        'id': parts[0],
                        'svtype': parts[1],
                        'breaking': parts[2]
                    }

    return breakpoints

def read_annotated_breakpoints(tsv_file):
    """Read annotated breakpoints TSV and return set of annotated breakpoint keys."""
    annotated = set()
    with open(tsv_file, 'r', newline='') as f:
        reader = csv.DictReader(f, delimiter='\t')
        for row in reader:
            key = (row['chr'], row['star'], row['end'],
                   f"{row['ID']}|{row['svtype']}|{row['breaking']}")
            annotated.add(key)

    return annotated

def find_nearest_gene(unannotated_bp, annotated_rows):
    """
    Find the nearest gene for an unannotated breakpoint by looking at its fusion partner.
    If the breakpoint is part of a fusion pair, look for the gene from the other breakpoint.
    """
    bp_id = unannotated_bp['id']
    bp_breaking = unannotated_bp['breaking']

    # Look for the opposite breakpoint (start <-> end)
    opposite_breaking = 'end' if bp_breaking == 'start' else 'start'

    # Find all genes associated with this fusion ID
    genes_in_fusion = set()
    for row in annotated_rows:
        if row['ID'] == bp_id:
            gene = row['Genes']
            if gene and gene != 'NA':
                genes_in_fusion.add(gene)

    # If we found genes in the fusion, use them
    # Prefer to return a single gene name, or join multiple with "/"
    if genes_in_fusion:
        return "/".join(sorted(genes_in_fusion))

    # Otherwise, return "intergenic"
    return "intergenic"

def add_intergenic_annotations(original_bed, annotated_tsv, output_tsv):
    """
    Add intergenic annotations for breakpoints that weren't annotated.

    Reads:
    - original_bed: Original breakpoint BED file (before intersectBed)
    - annotated_tsv: TSV with annotated breakpoints

    Writes:
    - output_tsv: TSV with all breakpoints, including intergenic ones
    """
    # Read original breakpoints
    original_breakpoints = read_original_breakpoints(original_bed)
    print(f"Found {len(original_breakpoints)} original breakpoints")

    # Read annotated breakpoints
    annotated_keys = read_annotated_breakpoints(annotated_tsv)
    print(f"Found {len(annotated_keys)} annotated breakpoints")

    # Read existing annotations
    with open(annotated_tsv, 'r', newline='') as f:
        reader = csv.DictReader(f, delimiter='\t')
        existing_rows = list(reader)
        header = reader.fieldnames

    # Get list of fusion IDs that are already in the filtered annotations
    # We only want to add intergenic annotations for these IDs, not for all variants
    filtered_fusion_ids = set()
    for row in existing_rows:
        filtered_fusion_ids.add(row['ID'])

    print(f"Found {len(filtered_fusion_ids)} fusion IDs in filtered annotations")

    # Find unannotated breakpoints that belong to filtered fusion IDs
    unannotated = []
    for key, bp in original_breakpoints.items():
        if key not in annotated_keys:
            # Only add if this breakpoint's ID is in the filtered list
            if bp['id'] in filtered_fusion_ids:
                unannotated.append(bp)

    print(f"Found {len(unannotated)} intergenic/unannotated breakpoints for filtered fusions")

    # Add intergenic annotations
    with open(output_tsv, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=header, delimiter='\t')
        writer.writeheader()

        # Write existing annotations
        for row in existing_rows:
            writer.writerow(row)

        # Add intergenic breakpoints (only for filtered fusion IDs)
        for bp in unannotated:
            # Try to find the gene name from the fusion partner
            gene_name = find_nearest_gene(bp, existing_rows)

            writer.writerow({
                'chr': bp['chr'],
                'star': bp['start'],
                'end': bp['end'],
                'ID': bp['id'],
                'svtype': bp['svtype'],
                'breaking': bp['breaking'],
                'Genes': gene_name,
                'feature_type': 'intergenic',
                'exon_number': 'NA',
                'transcript_id': 'NA'
            })

    print(f"Wrote {len(existing_rows) + len(unannotated)} total breakpoints to {output_tsv}")

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Annotate intergenic breakpoints that don't overlap any GFF3 features"
    )
    parser.add_argument(
        '--original-bed', required=True,
        help='Original breakpoint BED file (before intersectBed)'
    )
    parser.add_argument(
        '--annotated', required=True,
        help='Annotated breakpoints TSV file (from remove_duplicate_report_exon.py)'
    )
    parser.add_argument(
        '--out', required=True,
        help='Output TSV with intergenic annotations added'
    )

    args = parser.parse_args()

    add_intergenic_annotations(args.original_bed, args.annotated, args.out)
    print("Processing complete!")
