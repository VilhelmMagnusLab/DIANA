#!/usr/bin/env python3
import sys
import re

def parse_info(info_str):
    info = {}
    for entry in info_str.split(';'):
        if '=' in entry:
            key, value = entry.split('=', 1)
            info[key] = value
        else:
            info[entry] = True
    return info

def extract_bnd_coordinates(alt_field):
    """Extract breakpoint coordinates from BND ALT field."""
    # BND format: N[chr2:pos[, N]chr2:pos[, [chr2:pos]N, or ]chr2:pos]N
    # For the example: ]chr22:41178950]N
    bnd_pattern = r'[\[\]]([^:]+):(\d+)[\[\]]'
    match = re.search(bnd_pattern, alt_field)
    
    if match:
        chr_second = re.sub(r'(?i)^chr', '', match.group(1))  # Remove 'chr' or 'CHR' prefix case-insensitive
        pos2 = int(match.group(2))
        return chr_second, pos2
    
    return None, None

def process_bnd_vcf(input_vcf, output_txt):
    """Process BND variants specifically."""
    with open(input_vcf, 'r') as fin, open(output_txt, 'w') as fout:
        for line in fin:
            if line.startswith('#'):
                continue
            fields = line.strip().split('\t')
            if len(fields) < 8:
                continue
            
            # Only process lines with SVTYPE=BND
            if 'SVTYPE=BND' not in fields[7]:
                continue
                
            #chrom = fields[0].replace('chr', '')  # Remove 'chr' prefix if present
            chrom = re.sub(r'(?i)^chr', '', fields[0])
            #chrom = fields[0]
            start = int(fields[1])
            var_id = fields[2]
            alt = fields[4]
            info = parse_info(fields[7])
            svtype = info.get('SVTYPE', '')
            
            chr_second, pos2 = extract_bnd_coordinates(alt)
            if chr_second and pos2:
                # Write start breakpoint (current chromosome/position) - BED format
                bed_start = start #- 1
                bed_end = start
                name_start = f"{var_id}|{svtype}|start"
                fout.write(f"{chrom}\t{bed_start}\t{bed_end}\t{name_start}\t.\t.\n")
                # Write end breakpoint (from ALT field) - BED format
                bed_end_start = pos2 #- 1
                bed_end_end = pos2
                name_end = f"{var_id}|{svtype}|end"
                fout.write(f"{chr_second}\t{bed_end_start}\t{bed_end_end}\t{name_end}\t.\t.\n")

def process_vcf(input_vcf, output_txt):
    """Process non-BND variants."""
    with open(input_vcf, 'r') as fin, open(output_txt, 'w') as fout:
        for line in fin:
            if line.startswith('#'):
                continue
            fields = line.strip().split('\t')
            if len(fields) < 8:
                continue
            
            # Skip BND variants - they are handled separately
            if 'SVTYPE=BND' in fields[7]:
                continue
                
            #chrom = fields[0].replace('chr', '')  # Remove 'chr' prefix if present
            chrom = re.sub(r'(?i)^chr', '', fields[0])
            #chrom = fields[0]
            start = int(fields[1])
            var_id = fields[2]
            info = parse_info(fields[7])
            svtype = info.get('SVTYPE', '')
            
            # Handle other SV types (existing logic)
            end = int(info.get('END', start))
            svlen = info.get('SVLEN', None)
            # Write start breakpoint - BED format
            bed_start = start #- 1
            bed_end = start
            name = f"{var_id}|{svtype}|start"
            fout.write(f"{chrom}\t{bed_start}\t{bed_end}\t{name}\t.\t.\n")
            # Write end breakpoint if SVLEN is present and numeric
            if svlen is not None:
                try:
                    svlen_int = int(svlen)
                    svlen_abs = abs(svlen_int)
                    end_pos = start + svlen_abs
                    bed_end_start = end_pos #- 1
                    bed_end_end = end_pos
                    name_end = f"{var_id}|{svtype}|end"
                    fout.write(f"{chrom}\t{bed_end_start}\t{bed_end_end}\t{name_end}\t.\t.\n")
                except ValueError:
                    pass

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description="Extract breakpoints from VCF to BED format")
    parser.add_argument('--vcf', required=True, help='Input VCF file')
    parser.add_argument('--out', required=True, help='Output BED file')
    args = parser.parse_args()
    
    # Process all variants by combining both functions
    import tempfile
    import os
    
    # Create temporary files
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.tmp') as tmp_bnd:
        tmp_bnd_file = tmp_bnd.name
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.tmp') as tmp_non_bnd:
        tmp_non_bnd_file = tmp_non_bnd.name
    
    # Process BND and non-BND separately
    process_bnd_vcf(args.vcf, tmp_bnd_file)
    process_vcf(args.vcf, tmp_non_bnd_file)
    
    # Combine results
    with open(args.out, 'w') as outfile:
        # Write BND results
        with open(tmp_bnd_file, 'r') as bnd_file:
            outfile.write(bnd_file.read())
        
        # Write non-BND results
        with open(tmp_non_bnd_file, 'r') as non_bnd_file:
            outfile.write(non_bnd_file.read())
    
    # Clean up temporary files
    os.unlink(tmp_bnd_file)
    os.unlink(tmp_non_bnd_file)
