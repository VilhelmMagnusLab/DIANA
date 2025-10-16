#!/usr/bin/env python3
"""
Create an enhanced GFF3 file that includes both exons and calculated introns.
This allows intersectBed to properly identify both exon and intron features.
"""

import sys
from collections import defaultdict

def parse_gff3_attributes(attr_string):
    """Parse GFF3 attribute column into dictionary."""
    attrs = {}
    for item in attr_string.strip().split(';'):
        if '=' in item:
            key, value = item.split('=', 1)
            attrs[key] = value
    return attrs

def read_gff3_and_extract_introns(gff3_file, output_file):
    """
    Read GFF3, calculate introns, and write enhanced GFF3 with both exons and introns.
    """
    # First pass: collect all exons by transcript
    transcript_exons = defaultdict(list)
    lines_to_write = []

    print(f"Reading {gff3_file}...")
    with open(gff3_file, 'r') as f:
        for line in f:
            # Keep header lines and comments
            if line.startswith('#'):
                lines_to_write.append(line)
                continue

            fields = line.strip().split('\t')
            if len(fields) < 9:
                continue

            chrom = fields[0]
            source = fields[1]
            feature_type = fields[2]
            start = int(fields[3])
            end = int(fields[4])
            score = fields[5]
            strand = fields[6]
            phase = fields[7]
            attributes = parse_gff3_attributes(fields[8])

            # Keep all original lines
            lines_to_write.append(line)

            # Collect exon information for intron calculation
            if feature_type == 'exon':
                transcript_id = attributes.get('transcript_id', '')
                gene_name = attributes.get('gene_name', attributes.get('gene_id', 'NA'))
                gene_id = attributes.get('gene_id', 'NA')

                if transcript_id:
                    transcript_exons[transcript_id].append({
                        'chr': chrom,
                        'source': source,
                        'start': start,
                        'end': end,
                        'score': score,
                        'strand': strand,
                        'phase': phase,
                        'gene_name': gene_name,
                        'gene_id': gene_id,
                        'gene_type': attributes.get('gene_type', 'unknown'),
                        'transcript_type': attributes.get('transcript_type', 'unknown')
                    })

    print(f"Found {len(transcript_exons)} transcripts")

    # Calculate introns
    print("Calculating introns...")
    intron_lines = []
    intron_count = 0

    for transcript_id, exons in transcript_exons.items():
        if len(exons) < 2:
            continue

        # Sort exons by start position
        sorted_exons = sorted(exons, key=lambda x: x['start'])

        # Get common attributes
        exon0 = sorted_exons[0]

        # Calculate introns between consecutive exons
        for i in range(len(sorted_exons) - 1):
            intron_start = sorted_exons[i]['end'] + 1
            intron_end = sorted_exons[i + 1]['start'] - 1

            # Only add if there's actually space for an intron (at least 1 bp)
            if intron_start <= intron_end:
                intron_number = i + 1

                # Build attributes string
                attrs = (
                    f"ID={transcript_id}_intron_{intron_number};"
                    f"Parent={transcript_id};"
                    f"gene_id={exon0['gene_id']};"
                    f"gene_name={exon0['gene_name']};"
                    f"transcript_id={transcript_id};"
                    f"gene_type={exon0['gene_type']};"
                    f"transcript_type={exon0['transcript_type']};"
                    f"intron_number={intron_number}"
                )

                # Create GFF3 line for intron
                intron_line = (
                    f"{exon0['chr']}\t{exon0['source']}\tintron\t{intron_start}\t{intron_end}\t"
                    f"{exon0['score']}\t{exon0['strand']}\t{exon0['phase']}\t{attrs}\n"
                )
                intron_lines.append(intron_line)
                intron_count += 1

    print(f"Calculated {intron_count} introns")

    # Write output: original lines + intron lines
    print(f"Writing enhanced GFF3 to {output_file}...")
    with open(output_file, 'w') as f:
        # Write all original content
        for line in lines_to_write:
            f.write(line)

        # Append all calculated introns
        for line in intron_lines:
            f.write(line)

    print(f"Wrote {len(lines_to_write)} original lines + {intron_count} intron annotations")
    print("Processing complete!")

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Create enhanced GFF3 file with both exons and calculated introns"
    )
    parser.add_argument(
        '--gff3', required=True,
        help='Input GFF3 annotation file'
    )
    parser.add_argument(
        '--out', required=True,
        help='Output enhanced GFF3 file with introns'
    )

    args = parser.parse_args()

    read_gff3_and_extract_introns(args.gff3, args.out)
