#!/usr/bin/env python3
import csv
import sys
from collections import defaultdict
import re

def parse_gff3_attributes(attributes):
    """Parse GFF3 attributes string and extract relevant information."""
    attr_dict = {}
    if attributes:
        fields = attributes.split(';')
        for field in fields:
            if '=' in field:
                key, value = field.split('=', 1)
                attr_dict[key] = value
    return attr_dict

def extract_gene_name(attributes):
    """Extract gene_name from the attributes string (equivalent to the first awk command)."""
    gene = "NA"
    if attributes:
        attr_dict = parse_gff3_attributes(attributes)
        # Try gene_name first, then fall back to gene_id
        gene = attr_dict.get('gene_name', attr_dict.get('gene_id', 'NA'))
    return gene

def extract_exon_intron_info(gff3_feature_type, attributes):
    """
    Extract exon/intron information from GFF3 annotation.
    Returns a tuple: (feature_type, exon_number, transcript_id)

    GFF3 feature types include: gene, transcript, exon, CDS, UTR, etc.
    For exons, we extract the exon number if available.
    For introns (regions between exons), we infer from context.
    """
    attr_dict = parse_gff3_attributes(attributes)

    # Determine feature type
    feature_type = gff3_feature_type
    exon_number = "NA"
    transcript_id = attr_dict.get('transcript_id', 'NA')

    # Extract exon number if available
    if feature_type == 'exon':
        # Try to get exon_number attribute
        exon_number = attr_dict.get('exon_number', attr_dict.get('exon_id', 'NA'))
    elif feature_type == 'CDS':
        # CDS is coding sequence, often within exons
        exon_number = attr_dict.get('exon_number', 'NA')
        feature_type = 'CDS/exon'
    elif feature_type in ['five_prime_UTR', 'three_prime_UTR', 'UTR']:
        feature_type = 'UTR'
        exon_number = attr_dict.get('exon_number', 'NA')
    elif feature_type == 'transcript':
        feature_type = 'transcript'
    elif feature_type == 'gene':
        feature_type = 'gene'
    else:
        # For other features or intergenic regions
        feature_type = feature_type if feature_type else 'intergenic'

    return feature_type, exon_number, transcript_id

def process_intersectbed_output(input_file, output_file):
    """Process intersectBed output to extract gene names, exon/intron info and format for filter_breakpoints."""
    with open(input_file, 'r') as fin, open(output_file, 'w', newline='') as fout:
        writer = csv.writer(fout, delimiter='\t')
        # Extended header with exon/intron information
        writer.writerow(['chr', 'star', 'end', 'ID', 'svtype', 'breaking', 'Genes', 'feature_type', 'exon_number', 'transcript_id'])

        for line in fin:
            if line.strip() == "":
                continue
            fields = line.strip().split('\t')
            if len(fields) < 10:
                continue

            # Extract fields from intersectBed output
            # First 6 columns are from the breakpoint BED file
            chr_col = fields[0]
            start_col = fields[1]
            end_col = fields[2]
            name_col = fields[3]

            # Remaining columns are from the GFF3 file
            # GFF3 format: chr, source, feature_type, start, end, score, strand, phase, attributes
            gff3_chr = fields[6]
            gff3_feature_type = fields[8] if len(fields) > 8 else "unknown"
            attributes = fields[-1]  # Last column contains attributes

            # Extract gene name from attributes (equivalent to first awk)
            gene = extract_gene_name(attributes)

            # Extract exon/intron information
            feature_type, exon_number, transcript_id = extract_exon_intron_info(gff3_feature_type, attributes)

            # Parse the name field to extract ID, svtype, breaking (equivalent to second awk)
            if '|' in name_col:
                parts = name_col.split('|')
                if len(parts) >= 3:
                    id_part = parts[0]
                    svtype_part = parts[1]
                    breaking_part = parts[2]

                    # Write formatted output with exon/intron info
                    writer.writerow([chr_col, start_col, end_col, id_part, svtype_part, breaking_part,
                                   gene, feature_type, exon_number, transcript_id])

def read_gene_list(gene_file):
    """Read gene list from a one-column file."""
    genes = set()
    with open(gene_file, 'r') as f:
        for line in f:
            gene = line.strip()
            if gene:  # Skip empty lines
                genes.add(gene)
    return genes

def format_fusion_string(row1, row2):
    """
    Format fusion event string with exon/intron information.
    Example output: GENE1(exon 5) -> GENE2(exon 3)
    """
    gene1 = row1['Genes']
    feature1 = row1['feature_type']
    exon1 = row1['exon_number']

    gene2 = row2['Genes']
    feature2 = row2['feature_type']
    exon2 = row2['exon_number']

    # Format gene1 info
    if exon1 != 'NA' and feature1 == 'exon':
        gene1_str = f"{gene1}({feature1} {exon1})"
    elif feature1 not in ['NA', 'unknown', 'intergenic']:
        gene1_str = f"{gene1}({feature1})"
    else:
        gene1_str = gene1

    # Format gene2 info
    if exon2 != 'NA' and feature2 == 'exon':
        gene2_str = f"{gene2}({feature2} {exon2})"
    elif feature2 not in ['NA', 'unknown', 'intergenic']:
        gene2_str = f"{gene2}({feature2})"
    else:
        gene2_str = gene2

    return f"{gene1_str} -> {gene2_str}"

def filter_breakpoints(input_file, output_file, paired_output_file=None, gene_file=None, filtered_output_file=None, gene_filtered_output_file=None):
    """Filter breakpoints function with exon/intron information support."""
    with open(input_file, newline='') as fin:
        reader = csv.DictReader(fin, delimiter='\t')
        rows = list(reader)
        header = reader.fieldnames

    # Group by (ID, Genes)
    groups = defaultdict(list)
    for row in rows:
        key = (row['ID'], row['Genes'])
        groups[key].append(row)

    # Find keys with both start and end
    to_remove = set()
    for key, group in groups.items():
        breakings = set(row['breaking'] for row in group)
        if 'start' in breakings and 'end' in breakings:
            to_remove.add(key)

    # Write output (rows for (ID, Genes) without both start and end)
    with open(output_file, 'w', newline='') as fout:
        writer = csv.DictWriter(fout, fieldnames=header, delimiter='\t')
        writer.writeheader()
        for row in rows:
            key = (row['ID'], row['Genes'])
            if key not in to_remove:
                writer.writerow(row)

    # If paired_output_file is provided, filter the output file further
    if paired_output_file:
        with open(output_file, newline='') as fin:
            reader = csv.DictReader(fin, delimiter='\t')
            out_rows = list(reader)
            out_header = reader.fieldnames
        # Group by ID and breaking
        id_breaking_groups = defaultdict(lambda: {'start': [], 'end': []})
        for row in out_rows:
            id_breaking_groups[row['ID']][row['breaking']].append(row)
        # For each ID, pair as many start and end as possible
        paired_rows = []
        for id_, breaks in id_breaking_groups.items():
            n_start = len(breaks['start'])
            n_end = len(breaks['end'])
            n_pair = min(n_start, n_end)
            # Keep only up to n_pair of each
            paired_rows.extend(breaks['start'][:n_pair])
            paired_rows.extend(breaks['end'][:n_pair])
        # Remove duplicates
        seen = set()
        with open(paired_output_file, 'w', newline='') as fout2:
            writer2 = csv.DictWriter(fout2, fieldnames=out_header, delimiter='\t')
            writer2.writeheader()
            for row in paired_rows:
                row_key = (row['chr'], row['star'], row['end'], row['ID'], row['svtype'], row['breaking'],
                          row['Genes'], row.get('feature_type', 'NA'), row.get('exon_number', 'NA'),
                          row.get('transcript_id', 'NA'))
                if row_key not in seen:
                    writer2.writerow(row)
                    seen.add(row_key)

        # If gene_file is provided, filter paired output by genes
        if gene_file:
            # Read gene list
            gene_list = read_gene_list(gene_file)
            print(f"Loaded {len(gene_list)} genes from {gene_file}")

            # Filter paired output to keep only rows with genes in the gene list
            with open(paired_output_file, newline='') as fin:
                reader = csv.DictReader(fin, delimiter='\t')
                paired_rows = list(reader)
                paired_header = reader.fieldnames

            # Filter rows where Genes column contains a gene from the gene list AND SVTYPE is not "INV"
            filtered_rows = []
            # New filter: rows where at least one gene is in the gene list (regardless of SVTYPE)
            gene_filtered_rows = []

            for row in paired_rows:
                gene = row['Genes']
                svtype = row['svtype']

                # Original filter: gene in list AND not INV
                if gene in gene_list and svtype != "INV":
                    filtered_rows.append(row)

                # New filter: at least one gene in the gene list (regardless of SVTYPE)
                if gene in gene_list:
                    gene_filtered_rows.append(row)

            # Apply pairing logic to both filtered outputs (same as original paired output logic)
            def apply_pairing_logic(rows):
                # Group by ID and breaking
                id_breaking_groups = defaultdict(lambda: {'start': [], 'end': []})
                for row in rows:
                    id_breaking_groups[row['ID']][row['breaking']].append(row)

                # For each ID, pair as many start and end as possible
                paired_result = []
                for id_, breaks in id_breaking_groups.items():
                    n_start = len(breaks['start'])
                    n_end = len(breaks['end'])
                    n_pair = min(n_start, n_end)
                    # Keep only up to n_pair of each
                    paired_result.extend(breaks['start'][:n_pair])
                    paired_result.extend(breaks['end'][:n_pair])

                # Remove duplicates
                seen = set()
                final_result = []
                for row in paired_result:
                    row_key = (row['chr'], row['star'], row['end'], row['ID'], row['svtype'], row['breaking'],
                              row['Genes'], row.get('feature_type', 'NA'), row.get('exon_number', 'NA'),
                              row.get('transcript_id', 'NA'))
                    if row_key not in seen:
                        final_result.append(row)
                        seen.add(row_key)

                return final_result

            # Write filtered results (original filter) with pairing
            # Keep the same format as the original script, just with additional exon/intron columns
            if filtered_output_file:
                paired_filtered_rows = apply_pairing_logic(filtered_rows)

                with open(filtered_output_file, 'w', newline='') as fout3:
                    writer3 = csv.DictWriter(fout3, fieldnames=paired_header, delimiter='\t')
                    writer3.writeheader()
                    for row in paired_filtered_rows:
                        writer3.writerow(row)

                print(f"Kept {len(paired_filtered_rows)} rows with genes from the gene list (excluding INV variants) after pairing")

            # Write new gene-filtered results with pairing
            # Keep the same format as the original script, just with additional exon/intron columns
            if gene_filtered_output_file:
                paired_gene_filtered_rows = apply_pairing_logic(gene_filtered_rows)

                with open(gene_filtered_output_file, 'w', newline='') as fout4:
                    writer4 = csv.DictWriter(fout4, fieldnames=paired_header, delimiter='\t')
                    writer4.writeheader()
                    for row in paired_gene_filtered_rows:
                        writer4.writerow(row)

                print(f"Kept {len(paired_gene_filtered_rows)} rows with at least one gene from the gene list (all SV types) after pairing")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Process intersectBed output and filter breakpoints with exon/intron information: extract gene names, exon/intron info, format data, and apply filtering.")
    parser.add_argument('--in', dest='intersectbed_file', required=True, help='Input intersectBed output file')
    parser.add_argument('--formatted', dest='formatted_file', required=True, help='Formatted output file (ready for filtering)')
    parser.add_argument('--out', dest='output_file', required=True, help='Filtered output file')
    parser.add_argument('--paired', dest='paired_output_file', required=False, help='Paired output file (optional)')
    parser.add_argument('--gene-list', dest='gene_file', required=False, help='Gene list file (one gene per line)')
    parser.add_argument('--filtered', dest='filtered_output_file', required=False, help='Filtered fusion output file with exon/intron annotations (genes from gene list only, excluding INV)')
    parser.add_argument('--gene-filtered', dest='gene_filtered_output_file', required=False, help='Gene-filtered fusion output file with exon/intron annotations (at least one gene from gene list, all SV types)')
    args = parser.parse_args()

    # Step 1: Process intersectBed output to extract gene names, exon/intron info and format data
    print("Processing intersectBed output with exon/intron information...")
    process_intersectbed_output(args.intersectbed_file, args.formatted_file)
    print(f"Formatted data with exon/intron info saved to {args.formatted_file}")

    # Step 2: Apply filtering
    print("Applying breakpoint filtering with exon/intron tracking...")
    filter_breakpoints(args.formatted_file, args.output_file, args.paired_output_file, args.gene_file, args.filtered_output_file, args.gene_filtered_output_file)
    print("Processing complete!")
