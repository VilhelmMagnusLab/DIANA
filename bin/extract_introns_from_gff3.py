#!/usr/bin/env python3
"""
Extract intron regions from GFF3 file by calculating regions between exons.
Introns are not directly annotated in GFF3, so we derive them from exon coordinates.
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

def read_gff3_exons(gff3_file):
    """
    Read GFF3 file and extract exon coordinates grouped by transcript.

    Returns:
        dict: transcript_id -> list of (chr, start, end, strand, gene_name, gene_id)
    """
    transcript_exons = defaultdict(list)

    with open(gff3_file, 'r') as f:
        for line in f:
            if line.startswith('#'):
                continue

            fields = line.strip().split('\t')
            if len(fields) < 9:
                continue

            chrom = fields[0]
            feature_type = fields[2]
            start = int(fields[3])
            end = int(fields[4])
            strand = fields[6]
            attributes = parse_gff3_attributes(fields[8])

            # Only process exon features
            if feature_type != 'exon':
                continue

            transcript_id = attributes.get('transcript_id', '')
            gene_name = attributes.get('gene_name', attributes.get('gene_id', 'NA'))
            gene_id = attributes.get('gene_id', 'NA')

            if transcript_id:
                transcript_exons[transcript_id].append({
                    'chr': chrom,
                    'start': start,
                    'end': end,
                    'strand': strand,
                    'gene_name': gene_name,
                    'gene_id': gene_id
                })

    return transcript_exons

def calculate_introns(transcript_exons):
    """
    Calculate intron coordinates from exon coordinates.

    For each transcript, introns are regions between consecutive exons.

    Returns:
        list: List of intron dictionaries with chr, start, end, transcript_id, etc.
    """
    introns = []

    for transcript_id, exons in transcript_exons.items():
        if len(exons) < 2:
            # No introns if only one exon
            continue

        # Sort exons by start position
        sorted_exons = sorted(exons, key=lambda x: x['start'])

        # Get common attributes
        chrom = sorted_exons[0]['chr']
        strand = sorted_exons[0]['strand']
        gene_name = sorted_exons[0]['gene_name']
        gene_id = sorted_exons[0]['gene_id']

        # Calculate introns between consecutive exons
        for i in range(len(sorted_exons) - 1):
            intron_start = sorted_exons[i]['end'] + 1
            intron_end = sorted_exons[i + 1]['start'] - 1

            # Only add if there's actually space for an intron
            if intron_start <= intron_end:
                introns.append({
                    'chr': chrom,
                    'start': intron_start,
                    'end': intron_end,
                    'strand': strand,
                    'transcript_id': transcript_id,
                    'gene_name': gene_name,
                    'gene_id': gene_id,
                    'intron_number': i + 1  # First intron is between exon 1 and 2
                })

    return introns

def write_introns_bed(introns, output_file):
    """
    Write introns to BED format file.

    BED format: chr, start, end, name, score, strand
    """
    with open(output_file, 'w') as f:
        for intron in introns:
            name = f"{intron['gene_name']}|{intron['transcript_id']}|intron{intron['intron_number']}"
            f.write(f"{intron['chr']}\t{intron['start']}\t{intron['end']}\t{name}\t.\t{intron['strand']}\n")

    print(f"Wrote {len(introns)} introns to {output_file}")

def write_introns_gff3(introns, output_file):
    """
    Write introns to GFF3 format file (compatible with original GFF3).
    """
    with open(output_file, 'w') as f:
        f.write("##gff-version 3\n")

        for intron in introns:
            attrs = (
                f"ID={intron['transcript_id']}_intron_{intron['intron_number']};"
                f"Parent={intron['transcript_id']};"
                f"gene_id={intron['gene_id']};"
                f"gene_name={intron['gene_name']};"
                f"transcript_id={intron['transcript_id']};"
                f"intron_number={intron['intron_number']}"
            )

            f.write(
                f"{intron['chr']}\tderived\tintron\t{intron['start']}\t{intron['end']}\t.\t"
                f"{intron['strand']}\t.\t{attrs}\n"
            )

    print(f"Wrote {len(introns)} introns to {output_file}")

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Extract intron regions from GFF3 by calculating regions between exons"
    )
    parser.add_argument(
        '--gff3', required=True,
        help='Input GFF3 annotation file'
    )
    parser.add_argument(
        '--out-bed', dest='out_bed',
        help='Output BED file with intron coordinates'
    )
    parser.add_argument(
        '--out-gff3', dest='out_gff3',
        help='Output GFF3 file with intron annotations'
    )

    args = parser.parse_args()

    if not args.out_bed and not args.out_gff3:
        print("Error: Must specify at least one output file (--out-bed or --out-gff3)", file=sys.stderr)
        sys.exit(1)

    print(f"Reading exons from {args.gff3}...")
    transcript_exons = read_gff3_exons(args.gff3)
    print(f"Found {len(transcript_exons)} transcripts with exons")

    print("Calculating intron coordinates...")
    introns = calculate_introns(transcript_exons)
    print(f"Calculated {len(introns)} introns")

    if args.out_bed:
        write_introns_bed(introns, args.out_bed)

    if args.out_gff3:
        write_introns_gff3(introns, args.out_gff3)

    print("Processing complete!")
