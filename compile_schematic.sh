#!/bin/bash

# nWGS Pipeline Schematic Compilation Script
# This script compiles the LaTeX TikZ schematic into high-quality formats

echo "Compiling nWGS Pipeline Schematic..."

# Check if xelatex is available (preferred) or pdflatex
if command -v xelatex &> /dev/null; then
    LATEX_ENGINE="xelatex"
    echo "Using XeLaTeX for better font support"
elif command -v pdflatex &> /dev/null; then
    LATEX_ENGINE="pdflatex"
    echo "Using pdfLaTeX (XeLaTeX recommended for better fonts)"
else
    echo "ERROR: No LaTeX engine found. Please install a LaTeX distribution."
    echo "For Ubuntu/Debian: sudo apt-get install texlive-full"
    echo "For CentOS/RHEL: sudo yum install texlive-scheme-full"
    exit 1
fi

# Check if ImageMagick is available for PNG conversion
if ! command -v convert &> /dev/null; then
    echo "WARNING: ImageMagick not found. PNG conversion will be skipped."
    echo "Install with: sudo apt-get install imagemagick"
    PNG_CONVERSION=false
else
    PNG_CONVERSION=true
fi

# Compile LaTeX to PDF
echo "Step 1: Compiling LaTeX to PDF..."
$LATEX_ENGINE -interaction=nonstopmode nWGS_pipeline_schematic.tex

if [ $? -eq 0 ]; then
    echo "✓ PDF compilation successful!"
    
    # Clean up auxiliary files
    rm -f *.aux *.log *.nav *.out *.snm *.toc *.fdb_latexmk *.fls *.synctex.gz
    
    # Convert to high-quality PNG if ImageMagick is available
    if [ "$PNG_CONVERSION" = true ]; then
        echo "Step 2: Converting PDF to high-quality PNG..."
        convert -density 300 nWGS_pipeline_schematic.pdf -quality 100 nWGS_pipeline_schematic.png
        
        if [ $? -eq 0 ]; then
            echo "✓ PNG conversion successful!"
            echo "Generated files:"
            echo "  - nWGS_pipeline_schematic.pdf (vector format, scalable)"
            echo "  - nWGS_pipeline_schematic.png (300 DPI, high quality)"
        else
            echo "✗ PNG conversion failed"
        fi
    else
        echo "Generated file:"
        echo "  - nWGS_pipeline_schematic.pdf (vector format, scalable)"
    fi
    
    echo ""
    echo "Schematic compilation completed successfully!"
    echo "The PDF file is vector-based and can be scaled to any size without quality loss."
    
else
    echo "✗ PDF compilation failed"
    echo "Check the error messages above for details."
    exit 1
fi 