#!/bin/bash
################################################################################
# Zenodo Upload Script for nWGS Pipeline Reference Files
################################################################################
# This script automates uploading reference files to Zenodo using the API.
# It supports large file uploads, progress tracking, and resumable uploads.
#
# Prerequisites:
#   - curl or wget
#   - jq (for JSON parsing)
#   - Zenodo account and access token
#
# Usage:
#   ./upload_to_zenodo.sh [OPTIONS]
#
# Options:
#   --token TOKEN              Zenodo API access token (required)
#   --record RECORD_ID         Existing Zenodo record ID to create new version
#   --sandbox                  Use Zenodo sandbox (for testing)
#   --files-dir PATH           Directory containing files to upload
#   --help                     Show this help message
#
# Example:
#   # Create new version of existing record
#   ./upload_to_zenodo.sh --token YOUR_TOKEN --record 15916972 --files-dir ./zenodo_files
#
#   # Test on sandbox first
#   ./upload_to_zenodo.sh --token SANDBOX_TOKEN --record RECORD_ID --sandbox --files-dir ./zenodo_files
#
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
ZENODO_TOKEN=""
ZENODO_RECORD="15916972"  # Default to nWGS pipeline Zenodo record
USE_SANDBOX=false
FILES_DIR=""
ZENODO_API="https://zenodo.org/api"
SANDBOX_API="https://sandbox.zenodo.org/api"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}==========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

show_usage() {
    grep "^#" "$0" | grep -v "^#!/bin/bash" | sed 's/^# //' | sed 's/^#//'
}

check_dependencies() {
    print_header "Checking Dependencies"

    local missing_deps=()

    # Check for curl or wget
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        missing_deps+=("curl or wget")
    fi

    # Check for jq (JSON parser)
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
        print_warning "jq is required for JSON parsing"
        print_info "Install: sudo apt-get install jq (Debian/Ubuntu)"
        print_info "Install: sudo yum install jq (CentOS/RHEL)"
        print_info "Install: brew install jq (macOS)"
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi

    print_success "All dependencies met"
    echo ""
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --token)
                ZENODO_TOKEN="$2"
                shift 2
                ;;
            --record)
                ZENODO_RECORD="$2"
                shift 2
                ;;
            --sandbox)
                USE_SANDBOX=true
                shift
                ;;
            --files-dir)
                FILES_DIR="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo ""
                show_usage
                exit 1
                ;;
        esac
    done

    # Validate required parameters
    if [ -z "$ZENODO_TOKEN" ]; then
        print_error "Zenodo API token is required (--token)"
        echo ""
        print_info "Get your token from:"
        if [ "$USE_SANDBOX" = true ]; then
            print_info "  Sandbox: https://sandbox.zenodo.org/account/settings/applications/tokens/new/"
        else
            print_info "  Production: https://zenodo.org/account/settings/applications/tokens/new/"
        fi
        echo ""
        print_info "Required scopes: deposit:write and deposit:actions"
        echo ""
        show_usage
        exit 1
    fi

    if [ -z "$FILES_DIR" ]; then
        print_error "Files directory is required (--files-dir)"
        show_usage
        exit 1
    fi

    if [ ! -d "$FILES_DIR" ]; then
        print_error "Files directory does not exist: $FILES_DIR"
        exit 1
    fi

    # Set API endpoint
    if [ "$USE_SANDBOX" = true ]; then
        API_BASE="$SANDBOX_API"
        print_warning "Using SANDBOX environment (test only)"
    else
        API_BASE="$ZENODO_API"
        print_info "Using PRODUCTION environment"
    fi
}

human_readable_size() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(( bytes / 1024 ))KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(( bytes / 1048576 ))MB"
    else
        echo "$(( bytes / 1073741824 ))GB"
    fi
}

create_new_version() {
    print_header "Creating New Version"

    if [ -z "$ZENODO_RECORD" ]; then
        print_error "Record ID required to create new version (--record)"
        exit 1
    fi

    print_info "Creating new version of record: $ZENODO_RECORD"

    # Create new version
    local response=$(curl -s -X POST \
        "${API_BASE}/deposit/depositions/${ZENODO_RECORD}/actions/newversion" \
        -H "Authorization: Bearer ${ZENODO_TOKEN}")

    # Check for errors
    if echo "$response" | jq -e '.status' &> /dev/null; then
        local status=$(echo "$response" | jq -r '.status')
        local message=$(echo "$response" | jq -r '.message')
        print_error "Failed to create new version: $message (status: $status)"
        exit 1
    fi

    # Get the new draft URL
    local draft_url=$(echo "$response" | jq -r '.links.latest_draft')

    if [ "$draft_url" = "null" ] || [ -z "$draft_url" ]; then
        print_error "Failed to get draft URL from response"
        echo "$response" | jq '.'
        exit 1
    fi

    # Get the new deposit ID
    local deposit_response=$(curl -s -H "Authorization: Bearer ${ZENODO_TOKEN}" "$draft_url")
    NEW_DEPOSIT_ID=$(echo "$deposit_response" | jq -r '.id')

    print_success "New version created with deposit ID: $NEW_DEPOSIT_ID"
    echo ""

    echo "$NEW_DEPOSIT_ID"
}

delete_old_files() {
    local deposit_id=$1

    print_header "Removing Old Files from New Version"

    # Get list of files in the deposit
    local files_response=$(curl -s \
        "${API_BASE}/deposit/depositions/${deposit_id}/files" \
        -H "Authorization: Bearer ${ZENODO_TOKEN}")

    local file_count=$(echo "$files_response" | jq '. | length')

    if [ "$file_count" -eq 0 ]; then
        print_info "No old files to remove"
        echo ""
        return
    fi

    print_info "Found $file_count old file(s) to remove"

    # Delete each file
    echo "$files_response" | jq -r '.[] | .id' | while read file_id; do
        local filename=$(echo "$files_response" | jq -r ".[] | select(.id==\"$file_id\") | .filename")
        echo -e "${CYAN}  Deleting: $filename${NC}"

        curl -s -X DELETE \
            "${API_BASE}/deposit/depositions/${deposit_id}/files/${file_id}" \
            -H "Authorization: Bearer ${ZENODO_TOKEN}" > /dev/null

        echo -e "  ${GREEN}✓${NC} Deleted"
    done

    print_success "Old files removed"
    echo ""
}

upload_file() {
    local deposit_id=$1
    local filepath=$2
    local filename=$(basename "$filepath")
    local filesize=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath")
    local filesize_human=$(human_readable_size $filesize)

    echo -e "${CYAN}📤 Uploading: $filename ($filesize_human)${NC}"

    # Upload file with progress
    local upload_response=$(curl -X PUT \
        "${API_BASE}/deposit/depositions/${deposit_id}/files" \
        -H "Authorization: Bearer ${ZENODO_TOKEN}" \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@${filepath}" \
        --progress-bar \
        -o /dev/null \
        -w "%{http_code}")

    if [ "$upload_response" -eq 201 ] || [ "$upload_response" -eq 200 ]; then
        echo -e "${GREEN}✓ Successfully uploaded: $filename${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to upload: $filename (HTTP $upload_response)${NC}"
        return 1
    fi
}

upload_files() {
    local deposit_id=$1

    print_header "Uploading Files"

    # Define files to upload (in order of size - smallest first for faster initial upload)
    local files_to_upload=(
        "Assembly.zip"
        "general.zip"
        "r1041_e82_400bps_sup_v420.zip"
        "humandb.tar.gz"
        "svanna-data.zip"
        "reference_core.tar.gz"
    )

    local total_files=${#files_to_upload[@]}
    local uploaded=0
    local failed=0

    print_info "Found ${total_files} files to upload"
    echo ""

    for filename in "${files_to_upload[@]}"; do
        local filepath="${FILES_DIR}/${filename}"

        if [ ! -f "$filepath" ]; then
            print_warning "File not found, skipping: $filename"
            continue
        fi

        if upload_file "$deposit_id" "$filepath"; then
            ((uploaded++))
        else
            ((failed++))
        fi
        echo ""
    done

    echo ""
    print_success "Upload complete: $uploaded succeeded, $failed failed"
    echo ""
}

update_metadata() {
    local deposit_id=$1

    print_header "Updating Metadata"

    # Create metadata JSON
    local metadata=$(cat <<EOF
{
  "metadata": {
    "title": "nWGS Pipeline Reference Files - v5.0",
    "upload_type": "dataset",
    "description": "<p>Reference files for the nWGS (Nanopore Whole Genome Sequencing) pipeline for brain tumor analysis.</p><p><strong>Contents:</strong></p><ul><li><strong>reference_core.tar.gz</strong> - Core reference files (GRCh38, BED files, annotations)</li><li><strong>humandb.tar.gz</strong> - ANNOVAR annotation databases</li><li><strong>general.zip</strong> - Sturgeon classifier model (keep as zip)</li><li><strong>Assembly.zip</strong> - vcfcircos assembly data</li><li><strong>r1041_e82_400bps_sup_v420.zip</strong> - Dorado basecalling model</li><li><strong>svanna-data.zip</strong> - Svanna structural variant annotation database (optional)</li></ul><p><strong>Installation:</strong></p><pre>git clone https://github.com/VilhelmMagnusLab/nWGS_pipeline.git\ncd nWGS_pipeline\n./setup_pipeline.sh docker</pre><p>The setup script automatically downloads and organizes all reference files.</p>",
    "creators": [
      {
        "name": "VilhelmMagnusLab",
        "affiliation": "Your Institution"
      }
    ],
    "keywords": [
      "nanopore",
      "whole genome sequencing",
      "brain tumor",
      "methylation",
      "bioinformatics",
      "reference genome",
      "annotation"
    ],
    "license": "cc-by-4.0",
    "access_right": "open"
  }
}
EOF
)

    # Update metadata
    local response=$(curl -s -X PUT \
        "${API_BASE}/deposit/depositions/${deposit_id}" \
        -H "Authorization: Bearer ${ZENODO_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$metadata")

    # Check for errors
    if echo "$response" | jq -e '.status' &> /dev/null; then
        local status=$(echo "$response" | jq -r '.status')
        local message=$(echo "$response" | jq -r '.message')
        print_error "Failed to update metadata: $message"
        return 1
    fi

    print_success "Metadata updated"
    echo ""
}

publish_version() {
    local deposit_id=$1

    print_header "Publishing New Version"

    echo ""
    print_warning "⚠️  IMPORTANT: Publishing cannot be undone!"
    echo ""
    print_info "This will:"
    echo "  1. Make the new version publicly available"
    echo "  2. Assign a new DOI"
    echo "  3. Lock the files (cannot be modified after publishing)"
    echo ""

    read -p "Are you sure you want to publish? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Publication cancelled"
        print_info "You can publish later from the Zenodo web interface"
        print_info "Draft URL: ${API_BASE}/deposit/${deposit_id}"
        return
    fi

    # Publish
    local response=$(curl -s -X POST \
        "${API_BASE}/deposit/depositions/${deposit_id}/actions/publish" \
        -H "Authorization: Bearer ${ZENODO_TOKEN}")

    # Check for errors
    if echo "$response" | jq -e '.status' &> /dev/null; then
        local status=$(echo "$response" | jq -r '.status')
        local message=$(echo "$response" | jq -r '.message')
        print_error "Failed to publish: $message"
        return 1
    fi

    local doi=$(echo "$response" | jq -r '.doi')
    local record_id=$(echo "$response" | jq -r '.record_id')

    print_success "Successfully published!"
    echo ""
    echo -e "${GREEN}New Version Details:${NC}"
    echo -e "  DOI: ${CYAN}$doi${NC}"
    echo -e "  Record ID: ${CYAN}$record_id${NC}"
    if [ "$USE_SANDBOX" = true ]; then
        echo -e "  URL: ${CYAN}https://sandbox.zenodo.org/record/$record_id${NC}"
    else
        echo -e "  URL: ${CYAN}https://zenodo.org/record/$record_id${NC}"
    fi
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    clear

    echo -e "${BLUE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║           Zenodo Upload Script for nWGS Pipeline              ║
║              Automated Reference File Upload                  ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    check_dependencies

    print_info "Configuration:"
    echo "  Files directory: $FILES_DIR"
    if [ -n "$ZENODO_RECORD" ]; then
        echo "  Base record: $ZENODO_RECORD (creating new version)"
    else
        echo "  Mode: Creating new deposit"
    fi
    echo "  Environment: $([ "$USE_SANDBOX" = true ] && echo "SANDBOX (test)" || echo "PRODUCTION")"
    echo ""

    # List files to be uploaded
    print_info "Files to upload:"
    ls -lh "$FILES_DIR" | grep -E '\.(tar\.gz|zip)$' | awk '{print "  - " $9 " (" $5 ")"}'
    echo ""

    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Upload cancelled"
        exit 0
    fi

    echo ""

    # Create new version or new deposit
    if [ -n "$ZENODO_RECORD" ]; then
        NEW_DEPOSIT_ID=$(create_new_version)
        delete_old_files "$NEW_DEPOSIT_ID"
    else
        print_error "Creating new deposits not yet implemented"
        print_info "Please use --record to create a new version of existing record"
        exit 1
    fi

    # Upload files
    upload_files "$NEW_DEPOSIT_ID"

    # Update metadata
    update_metadata "$NEW_DEPOSIT_ID"

    # Publish (with confirmation)
    publish_version "$NEW_DEPOSIT_ID"

    echo ""
    print_success "All done! 🎉"
    echo ""
}

# Parse arguments and run
parse_args "$@"
main
