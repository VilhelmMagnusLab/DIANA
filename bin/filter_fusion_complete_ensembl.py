#!/usr/bin/env python3
"""
Filter fusion events to only include those where both partner genes have official Ensembl gene IDs.
Cross-references gene names with GFF3 file to verify they have ENSG... gene IDs.
"""

import argparse
import sys
import re
from collections import defaultdict

def load_ensembl_genes_from_gff3(gff3_file):
    """
    Load genes with official Ensembl gene IDs (ENSG...) from GFF3 file.
    Returns: dict[gene_name] -> ensembl_gene_id
    """
    ensembl_genes = {}

    print(f"Loading Ensembl gene references from {gff3_file}...", file=sys.stderr)

    with open(gff3_file, 'r') as f:
        for line in f:
            if line.startswith('#'):
                continue

            fields = line.strip().split('\t')
            if len(fields) < 9:
                continue

            # Only process gene features
            if fields[2] != 'gene':
                continue

            attributes = fields[8]

            # Extract gene_name and gene_id
            gene_name_match = re.search(r'gene_name=([^;]+)', attributes)
            gene_id_match = re.search(r'gene_id=(ENSG[^;\.]+)', attributes)

            if gene_name_match and gene_id_match:
                gene_name = gene_name_match.group(1)
                gene_id = gene_id_match.group(1)
                ensembl_genes[gene_name] = gene_id

    print(f"Loaded {len(ensembl_genes)} genes with Ensembl IDs", file=sys.stderr)
    return ensembl_genes

def parse_fusion_events(input_file):
    """
    Parse fusion events file and group by SV ID.
    Returns: dict[sv_id] -> dict[breaking] -> list of events, and header
    """
    fusion_events = defaultdict(lambda: defaultdict(list))
    header = None

    with open(input_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            fields = line.split('\t')

            # Save header
            if not header:
                header = fields
                continue

            # Parse event
            event = dict(zip(header, fields))
            sv_id = event['ID']
            breaking = event['breaking']

            fusion_events[sv_id][breaking].append(event)

    return fusion_events, header

def get_genes_from_breakpoint(events):
    """Extract unique gene names from a breakpoint's events"""
    return set(e['Genes'] for e in events if e['Genes'] != 'NA')

def filter_complete_fusions(fusion_events, ensembl_genes):
    """
    Filter fusion events to only include those where both genes have Ensembl gene IDs.
    """
    complete_fusions = {}
    stats = {
        'total': 0,
        'complete': 0,
        'missing_start': 0,
        'missing_end': 0,
        'missing_both': 0,
        'no_pair': 0
    }

    for sv_id, breakpoints in fusion_events.items():
        stats['total'] += 1

        # Check if we have both start and end breakpoints
        if 'start' not in breakpoints or 'end' not in breakpoints:
            stats['no_pair'] += 1
            print(f"✗ {sv_id}: Missing start or end breakpoint", file=sys.stderr)
            continue

        # Get gene names from both breakpoints
        start_genes = get_genes_from_breakpoint(breakpoints['start'])
        end_genes = get_genes_from_breakpoint(breakpoints['end'])

        if not start_genes or not end_genes:
            stats['no_pair'] += 1
            print(f"✗ {sv_id}: No gene annotations found", file=sys.stderr)
            continue

        # Check if all genes have Ensembl IDs
        start_has_ensembl = all(gene in ensembl_genes for gene in start_genes)
        end_has_ensembl = all(gene in ensembl_genes for gene in end_genes)

        if start_has_ensembl and end_has_ensembl:
            complete_fusions[sv_id] = breakpoints
            stats['complete'] += 1

            # Get Ensembl IDs for reporting
            start_ensembl = [f"{gene}({ensembl_genes[gene]})" for gene in sorted(start_genes)]
            end_ensembl = [f"{gene}({ensembl_genes[gene]})" for gene in sorted(end_genes)]

            print(f"✓ {sv_id}: {', '.join(start_ensembl)} -- {', '.join(end_ensembl)}",
                  file=sys.stderr)
        else:
            # Report what's missing
            missing = []
            if not start_has_ensembl:
                missing_genes = [g for g in start_genes if g not in ensembl_genes]
                missing.append(f"start genes: {', '.join(missing_genes)}")
                if not end_has_ensembl:
                    stats['missing_both'] += 1
                else:
                    stats['missing_start'] += 1
            if not end_has_ensembl and start_has_ensembl:
                missing_genes = [g for g in end_genes if g not in ensembl_genes]
                missing.append(f"end genes: {', '.join(missing_genes)}")
                stats['missing_end'] += 1

            print(f"✗ {sv_id}: {', '.join(sorted(start_genes))} -- {', '.join(sorted(end_genes))} "
                  f"(missing Ensembl ID for: {'; '.join(missing)})",
                  file=sys.stderr)

    return complete_fusions, stats

def write_filtered_output(complete_fusions, header, output_file):
    """
    Write filtered fusion events to output file.
    """
    with open(output_file, 'w') as f:
        # Write header
        f.write('\t'.join(header) + '\n')

        # Write events for complete fusions
        for sv_id in sorted(complete_fusions.keys()):
            for breaking in ['start', 'end']:
                if breaking in complete_fusions[sv_id]:
                    for event in complete_fusions[sv_id][breaking]:
                        row = [event.get(col, '') for col in header]
                        f.write('\t'.join(row) + '\n')

def main():
    parser = argparse.ArgumentParser(
        description='Filter fusion events to keep only those with official Ensembl gene IDs (ENSG...)'
    )
    parser.add_argument('--input', '-i', required=True,
                       help='Input fusion events TSV file')
    parser.add_argument('--output', '-o', required=True,
                       help='Output filtered TSV file')
    parser.add_argument('--gff3', '-g', required=True,
                       help='GFF3 annotation file (e.g., gencode.v48.annotation.gff3)')
    parser.add_argument('--stats', '-s',
                       help='Optional statistics output file')

    args = parser.parse_args()

    # Load Ensembl gene IDs from GFF3
    ensembl_genes = load_ensembl_genes_from_gff3(args.gff3)
    print("", file=sys.stderr)

    # Parse fusion events
    print(f"Parsing fusion events from {args.input}...", file=sys.stderr)
    fusion_events, header = parse_fusion_events(args.input)
    print(f"Found {len(fusion_events)} fusion events", file=sys.stderr)
    print("", file=sys.stderr)

    # Filter for complete fusions
    print("Filtering for fusions with complete Ensembl gene IDs...", file=sys.stderr)
    complete_fusions, stats = filter_complete_fusions(fusion_events, ensembl_genes)

    print("", file=sys.stderr)
    print(f"=== Summary ===", file=sys.stderr)
    print(f"Total fusion events: {stats['total']}", file=sys.stderr)
    print(f"Complete (both genes have ENSG IDs): {stats['complete']}", file=sys.stderr)
    print(f"Missing start gene Ensembl ID: {stats['missing_start']}", file=sys.stderr)
    print(f"Missing end gene Ensembl ID: {stats['missing_end']}", file=sys.stderr)
    print(f"Missing both: {stats['missing_both']}", file=sys.stderr)
    print(f"No valid pair: {stats['no_pair']}", file=sys.stderr)
    if stats['total'] > 0:
        print(f"Percentage complete: {100*stats['complete']/stats['total']:.1f}%", file=sys.stderr)

    # Write output
    write_filtered_output(complete_fusions, header, args.output)
    print("", file=sys.stderr)
    print(f"✓ Filtered fusion events written to {args.output}", file=sys.stderr)

    # Write statistics if requested
    if args.stats:
        with open(args.stats, 'w') as f:
            for key, value in stats.items():
                f.write(f"{key}: {value}\n")
            if stats['total'] > 0:
                f.write(f"percentage_complete: {100*stats['complete']/stats['total']:.1f}%\n")

if __name__ == '__main__':
    main()
