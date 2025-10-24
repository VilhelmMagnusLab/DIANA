#!/usr/bin/env python3
"""
Annotate fusion breakpoints with detailed exon coordinates and coding phase information
using local GFF3 file (offline mode - no internet required).

This script takes fusion events with Ensembl gene IDs and adds:
- Exon number where breakpoint occurs
- Coding phase (0, 1, 2) at the breakpoint
- Position within exon
- Transcript ID
- Distance from exon boundaries

All data is extracted from the local GFF3 annotation file.
"""

import argparse
import sys
import gzip
from collections import defaultdict

def parse_args():
    parser = argparse.ArgumentParser(description='Annotate fusion breakpoints with exon coordinates and phase (offline)')
    parser.add_argument('--input', required=True, help='Input fusion events TSV file')
    parser.add_argument('--output', required=True, help='Output annotated fusion events TSV')
    parser.add_argument('--gff3', required=True, help='GFF3 annotation file (can be gzipped)')
    parser.add_argument('--stats', help='Optional statistics output file')
    return parser.parse_args()

def open_file(filename):
    """Open regular or gzipped file"""
    if filename.endswith('.gz'):
        return gzip.open(filename, 'rt')
    return open(filename, 'r')

def parse_gff3_attributes(attr_string):
    """Parse GFF3 attributes field into dictionary"""
    attrs = {}
    for item in attr_string.strip().split(';'):
        if '=' in item:
            key, value = item.split('=', 1)
            attrs[key] = value
    return attrs

class ExonDatabase:
    """Build and query exon coordinate database from GFF3"""

    def __init__(self):
        self.transcripts = defaultdict(lambda: {
            'gene_id': None,
            'gene_name': None,
            'exons': [],
            'strand': None,
            'biotype': None
        })
        self.gene_to_transcripts = defaultdict(list)

    def load_from_gff3(self, gff3_file):
        """Load exon information from GFF3 file"""
        print(f"Loading exon data from {gff3_file}...", file=sys.stderr)

        exon_count = 0
        transcript_count = 0

        with open_file(gff3_file) as f:
            for line in f:
                if line.startswith('#'):
                    continue

                fields = line.strip().split('\t')
                if len(fields) < 9:
                    continue

                chrom, source, feature, start, end, score, strand, phase, attributes = fields
                start, end = int(start), int(end)

                attrs = parse_gff3_attributes(attributes)

                # Process transcripts
                if feature == 'transcript' or feature == 'mRNA':
                    transcript_id = attrs.get('transcript_id') or attrs.get('ID')
                    if transcript_id:
                        gene_id = attrs.get('gene_id') or attrs.get('Parent')
                        gene_name = attrs.get('gene_name', '')
                        biotype = attrs.get('transcript_type') or attrs.get('biotype', 'unknown')

                        self.transcripts[transcript_id]['gene_id'] = gene_id
                        self.transcripts[transcript_id]['gene_name'] = gene_name
                        self.transcripts[transcript_id]['strand'] = strand
                        self.transcripts[transcript_id]['biotype'] = biotype

                        if gene_id:
                            self.gene_to_transcripts[gene_id].append(transcript_id)
                        transcript_count += 1

                # Process exons
                elif feature == 'exon':
                    transcript_id = attrs.get('transcript_id') or attrs.get('Parent')
                    if not transcript_id:
                        continue

                    exon_id = attrs.get('exon_id') or attrs.get('ID', '')
                    exon_number = attrs.get('exon_number', '0')

                    # Normalize chromosome format
                    chrom = chrom.replace('chr', '')

                    exon_data = {
                        'chrom': chrom,
                        'start': start,
                        'end': end,
                        'strand': strand,
                        'phase': int(phase) if phase != '.' else -1,
                        'exon_id': exon_id,
                        'exon_number': int(exon_number) if exon_number.isdigit() else 0
                    }

                    self.transcripts[transcript_id]['exons'].append(exon_data)
                    exon_count += 1

        # Sort exons by position for each transcript
        for transcript_id in self.transcripts:
            exons = self.transcripts[transcript_id]['exons']
            strand = self.transcripts[transcript_id]['strand']

            # Sort by start position
            exons.sort(key=lambda x: x['start'])

            # Assign exon numbers if not present (1-based)
            for idx, exon in enumerate(exons, 1):
                if exon['exon_number'] == 0:
                    exon['exon_number'] = idx

            # For negative strand, reverse exon numbering
            if strand == '-':
                total = len(exons)
                for exon in exons:
                    exon['exon_number_reverse'] = total - exon['exon_number'] + 1

        print(f"  Loaded {transcript_count} transcripts with {exon_count} exons", file=sys.stderr)

    def find_exon_for_position(self, gene_id, chrom, position):
        """
        Find which exon contains the breakpoint position

        Returns: dict with exon_number, phase, transcript_id, position_in_exon, etc.
        """
        # Normalize chromosome
        chrom = chrom.replace('chr', '')

        # Get all transcripts for this gene
        transcript_ids = self.gene_to_transcripts.get(gene_id, [])
        if not transcript_ids:
            return None

        results = []

        for transcript_id in transcript_ids:
            transcript = self.transcripts[transcript_id]
            exons = transcript['exons']
            strand = transcript['strand']

            for exon in exons:
                # Check if position is in this exon
                if exon['chrom'] == chrom and exon['start'] <= position <= exon['end']:
                    # Calculate position within exon
                    if strand == '+':
                        pos_in_exon = position - exon['start'] + 1
                        dist_from_start = pos_in_exon
                        dist_from_end = exon['end'] - position + 1
                        exon_num = exon['exon_number']
                    else:
                        pos_in_exon = exon['end'] - position + 1
                        dist_from_start = pos_in_exon
                        dist_from_end = position - exon['start'] + 1
                        exon_num = exon.get('exon_number_reverse', exon['exon_number'])

                    exon_length = exon['end'] - exon['start'] + 1
                    total_exons = len(exons)

                    result = {
                        'transcript_id': transcript_id,
                        'exon_number': exon_num,
                        'total_exons': total_exons,
                        'exon_id': exon['exon_id'],
                        'exon_start': exon['start'],
                        'exon_end': exon['end'],
                        'exon_length': exon_length,
                        'phase': exon['phase'],
                        'position_in_exon': pos_in_exon,
                        'dist_from_exon_start': dist_from_start,
                        'dist_from_exon_end': dist_from_end,
                        'strand': strand,
                        'biotype': transcript['biotype'],
                        'gene_name': transcript['gene_name']
                    }

                    results.append(result)

        # Prioritize protein_coding transcripts
        if results:
            protein_coding = [r for r in results if r['biotype'] == 'protein_coding']
            if protein_coding:
                return protein_coding[0]
            return results[0]

        return None

def parse_fusion_line(line):
    """Parse a fusion event line and extract relevant fields"""
    fields = line.strip().split('\t')
    if len(fields) < 10:
        return None

    return {
        'fields': fields,
        'sv_id': fields[0],
        'gene1': fields[1],
        'chr1': fields[2],
        'pos1': int(fields[3]) if fields[3].replace('-', '').isdigit() else 0,
        'feature1': fields[4],
        'gene2': fields[5],
        'chr2': fields[6],
        'pos2': int(fields[7]) if fields[7].replace('-', '').isdigit() else 0,
        'feature2': fields[8],
        'sv_type': fields[9]
    }

def extract_ensembl_id(gene_name):
    """Extract Ensembl gene ID from gene name if present"""
    # Format: "GENE_NAME (ENSG00000123456)" or just "ENSG00000123456"
    if '(' in gene_name and ')' in gene_name:
        parts = gene_name.split('(')
        if len(parts) > 1:
            ensembl_id = parts[1].split(')')[0].strip()
            if ensembl_id.startswith('ENSG'):
                return ensembl_id

    if gene_name.startswith('ENSG'):
        return gene_name.strip()

    return None

def format_exon_annotation(exon_info):
    """Format exon information into a compact annotation string"""
    if not exon_info:
        return "NA"

    phase_str = f"phase{exon_info['phase']}" if exon_info['phase'] >= 0 else "non-coding"

    annotation = (
        f"Exon{exon_info['exon_number']}/{exon_info['total_exons']}"
        f"|{phase_str}"
        f"|pos{exon_info['position_in_exon']}/{exon_info['exon_length']}"
        f"|{exon_info['transcript_id']}"
    )

    return annotation

def main():
    args = parse_args()

    # Build exon database from GFF3
    exon_db = ExonDatabase()
    exon_db.load_from_gff3(args.gff3)

    # Process input file
    print(f"\nReading fusion events from {args.input}...", file=sys.stderr)

    stats = {
        'total_fusions': 0,
        'annotated_gene1': 0,
        'annotated_gene2': 0,
        'both_annotated': 0,
        'no_ensembl_id': 0
    }

    with open(args.input, 'r') as infile, open(args.output, 'w') as outfile:
        header = infile.readline().strip()

        # Add new columns to header
        new_header = header + '\tGene1_Exon_Info\tGene2_Exon_Info\tGene1_Phase\tGene2_Phase'
        outfile.write(new_header + '\n')

        for line in infile:
            if not line.strip():
                continue

            stats['total_fusions'] += 1
            fusion = parse_fusion_line(line)

            if not fusion:
                outfile.write(line)
                continue

            # Extract Ensembl IDs from gene names
            ensembl_id1 = extract_ensembl_id(fusion['gene1'])
            ensembl_id2 = extract_ensembl_id(fusion['gene2'])

            if not ensembl_id1 and not ensembl_id2:
                stats['no_ensembl_id'] += 1

            # Annotate breakpoints with exon information
            exon_info1 = None
            exon_info2 = None

            if ensembl_id1 and fusion['pos1'] > 0:
                exon_info1 = exon_db.find_exon_for_position(
                    ensembl_id1,
                    fusion['chr1'],
                    fusion['pos1']
                )
                if exon_info1:
                    stats['annotated_gene1'] += 1

            if ensembl_id2 and fusion['pos2'] > 0:
                exon_info2 = exon_db.find_exon_for_position(
                    ensembl_id2,
                    fusion['chr2'],
                    fusion['pos2']
                )
                if exon_info2:
                    stats['annotated_gene2'] += 1

            if exon_info1 and exon_info2:
                stats['both_annotated'] += 1

            # Format output
            exon_annotation1 = format_exon_annotation(exon_info1)
            exon_annotation2 = format_exon_annotation(exon_info2)
            phase1 = str(exon_info1['phase']) if exon_info1 else 'NA'
            phase2 = str(exon_info2['phase']) if exon_info2 else 'NA'

            # Write annotated line
            outfile.write(f"{line.rstrip()}\t{exon_annotation1}\t{exon_annotation2}\t{phase1}\t{phase2}\n")

    # Write statistics
    print(f"\n=== Annotation Statistics ===", file=sys.stderr)
    print(f"Total fusion events: {stats['total_fusions']}", file=sys.stderr)
    print(f"Gene1 breakpoints annotated: {stats['annotated_gene1']}", file=sys.stderr)
    print(f"Gene2 breakpoints annotated: {stats['annotated_gene2']}", file=sys.stderr)
    print(f"Both breakpoints annotated: {stats['both_annotated']}", file=sys.stderr)
    print(f"Fusions without Ensembl IDs: {stats['no_ensembl_id']}", file=sys.stderr)
    print(f"\nOutput written to {args.output}", file=sys.stderr)

    if args.stats:
        with open(args.stats, 'w') as f:
            f.write("Metric\tCount\n")
            for key, value in stats.items():
                f.write(f"{key}\t{value}\n")

if __name__ == '__main__':
    main()
