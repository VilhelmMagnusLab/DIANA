#!/usr/bin/env python3
"""
Summarize fusion event features from detailed exon/intron annotations.
Consolidates multiple transcript annotations into a single row per breakpoint.
"""

import csv
import sys
from collections import defaultdict

def summarize_features(rows):
    """
    Summarize feature types and exon numbers from multiple transcript annotations.

    Args:
        rows: List of dictionaries with feature_type, exon_number, transcript_id

    Returns:
        String representation of consolidated features (e.g., "exon 8/UTR 8")
    """
    # Collect all exon/intron numbers and feature types
    all_numbers = set()
    has_cds = False
    has_utr = False
    has_exon = False
    has_intron = False
    has_intergenic = False
    has_gene_only = False
    gene_name = None

    for row in rows:
        feature_type = row.get('feature_type', 'NA')
        exon_number = row.get('exon_number', 'NA')
        row_gene = row.get('Genes', 'NA')

        # Store gene name
        if gene_name is None and row_gene not in ['NA', 'intergenic']:
            gene_name = row_gene

        # Check for intergenic regions
        if feature_type == 'intergenic' or row_gene == 'intergenic':
            has_intergenic = True
            continue

        # Track if we only have gene-level annotation (no specific features)
        if feature_type == 'gene':
            has_gene_only = True
            continue

        # Skip transcript level annotations
        if feature_type in ['transcript', 'NA', 'unknown']:
            continue

        # Check for introns
        if 'intron' in feature_type.lower():
            has_intron = True
            # Collect intron numbers if available
            if exon_number != 'NA':
                all_numbers.add(exon_number)
            continue

        # Simplify CDS/exon to just track components
        if 'CDS' in feature_type or 'cds' in feature_type.lower():
            has_cds = True
        if 'UTR' in feature_type or 'utr' in feature_type.lower():
            has_utr = True
        if 'exon' in feature_type.lower():
            has_exon = True

        # Collect exon/intron numbers
        if exon_number != 'NA':
            all_numbers.add(exon_number)

    # If only intergenic, return that
    if has_intergenic and not (has_exon or has_intron or has_cds or has_utr):
        return "intergenic"

    # Build feature type string
    feature_parts = []
    if has_exon:
        feature_parts.append("exon")
    if has_intron:
        feature_parts.append("intron")
    if has_cds:
        feature_parts.append("CDS")
    if has_utr:
        feature_parts.append("UTR")

    # If we have no specific features but have gene annotation, mark as intergenic
    # This happens when a breakpoint overlaps a gene region but not any exon/intron/CDS/UTR
    if not feature_parts:
        if has_gene_only or gene_name:
            return "intergenic"
        elif has_intergenic:
            return "intergenic"
        else:
            return "NA"

    # Sort numbers
    number_list = sorted([e for e in all_numbers if e != 'NA'])

    if number_list:
        # Format: "exon/intron/CDS/UTR number_range"
        feature_str = "/".join(feature_parts)
        number_str = format_exon_range(number_list)
        return f"{feature_str} {number_str}"
    else:
        # No numbers, just list features
        return "/".join(feature_parts)

def format_exon_range(exon_list):
    """
    Format list of exon numbers into compact representation.
    Examples: [1, 2, 3] -> "1-3", [1, 3, 5] -> "1,3,5", [17, 18, 19] -> "17-19"
    """
    if len(exon_list) <= 1:
        return ",".join(map(str, exon_list))

    # Check if it's a continuous range
    try:
        exon_nums = [int(e) for e in exon_list]
        if max(exon_nums) - min(exon_nums) == len(exon_nums) - 1:
            return f"{min(exon_nums)}-{max(exon_nums)}"
    except (ValueError, TypeError):
        pass

    # Otherwise, just list them
    return ",".join(map(str, exon_list))

def summarize_fusion_events(input_file, output_file):
    """
    Read detailed fusion event file and create summarized version.

    Input format (from remove_duplicate_report_exon.py):
        chr, star, end, ID, svtype, breaking, Genes, feature_type, exon_number, transcript_id

    Output format:
        chr, star, end, ID, svtype, breaking, Genes, Features
    """
    # Read input file
    with open(input_file, 'r', newline='') as fin:
        reader = csv.DictReader(fin, delimiter='\t')
        rows = list(reader)

    # Group by breakpoint (chr, star, end, ID, svtype, breaking, Genes)
    breakpoint_groups = defaultdict(list)
    for row in rows:
        key = (row['chr'], row['star'], row['end'], row['ID'],
               row['svtype'], row['breaking'], row['Genes'])
        breakpoint_groups[key].append(row)

    # First, group by ID to check which have both start and end
    id_breakings = defaultdict(set)
    for key in breakpoint_groups.keys():
        chr_val, star, end, id_val, svtype, breaking, genes = key
        id_breakings[id_val].add(breaking)

    # Only keep IDs that have both start and end
    complete_ids = {id_val for id_val, breakings in id_breakings.items()
                    if 'start' in breakings and 'end' in breakings}

    print(f"Found {len(complete_ids)} complete fusion events (with both start and end)")
    print(f"Filtered out {len(id_breakings) - len(complete_ids)} incomplete events")

    # Summarize each breakpoint, but only for complete fusion events
    summarized = []
    for key, group_rows in breakpoint_groups.items():
        chr_val, star, end, id_val, svtype, breaking, genes = key

        # Skip if this ID doesn't have both start and end
        if id_val not in complete_ids:
            continue

        features = summarize_features(group_rows)

        summarized.append({
            'chr': chr_val,
            'star': star,
            'end': end,
            'ID': id_val,
            'svtype': svtype,
            'breaking': breaking,
            'Genes': genes,
            'Features': features
        })

    # Sort by chromosome, position, ID, and breaking point
    def sort_key(row):
        # Extract numeric part of chromosome for sorting
        chr_str = row['chr'].replace('chr', '')
        try:
            chr_num = int(chr_str) if chr_str.isdigit() else 999
        except:
            chr_num = 999

        try:
            pos = int(row['star'])
        except:
            pos = 0

        breaking_order = {'start': 0, 'end': 1}
        breaking_val = breaking_order.get(row['breaking'], 2)

        return (chr_num, pos, row['ID'], breaking_val)

    summarized.sort(key=sort_key)

    # Write output
    output_header = ['chr', 'star', 'end', 'ID', 'svtype', 'breaking', 'Genes', 'Features']
    with open(output_file, 'w', newline='') as fout:
        writer = csv.DictWriter(fout, fieldnames=output_header, delimiter='\t')
        writer.writeheader()
        for row in summarized:
            writer.writerow(row)

    print(f"Summarized {len(breakpoint_groups)} breakpoints into {output_file}")
    return len(summarized)

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Summarize fusion event features from detailed exon/intron annotations"
    )
    parser.add_argument(
        '--in', dest='input_file', required=True,
        help='Input file with detailed feature annotations (TSV)'
    )
    parser.add_argument(
        '--out', dest='output_file', required=True,
        help='Output file with summarized features (TSV)'
    )

    args = parser.parse_args()

    try:
        summarize_fusion_events(args.input_file, args.output_file)
        print("Processing complete!")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
