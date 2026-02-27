# Zenodo Upload Guide - Automated Upload Script

## Overview

This guide explains how to use the `upload_to_zenodo.sh` script to automatically upload new versions of reference files to Zenodo without using the web interface.

---

## Prerequisites

### 1. Install Required Tools

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install curl jq

# CentOS/RHEL
sudo yum install curl jq

# macOS
brew install curl jq
```

### 2. Get Zenodo API Token

#### For Testing (Sandbox):
1. Go to: https://sandbox.zenodo.org/account/settings/applications/tokens/new/
2. Name: "nWGS Pipeline Upload"
3. Scopes: Select `deposit:write` and `deposit:actions`
4. Click "Create"
5. **Copy the token** (you won't see it again!)

#### For Production:
1. Go to: https://zenodo.org/account/settings/applications/tokens/new/
2. Name: "nWGS Pipeline Upload"
3. Scopes: Select `deposit:write` and `deposit:actions`
4. Click "Create"
5. **Copy the token** (you won't see it again!)

**⚠️ Keep your token secret! Don't commit it to git!**

---

## Preparing Files for Upload

### Step 1: Create a Directory for Upload Files

```bash
cd /home/godzilla/nWGS_pipeline
mkdir -p zenodo_upload
```

### Step 2: Package Your Files

Run the packaging script I'll create, or manually package:

```bash
# Package reference core files
tar -czf zenodo_upload/reference_core.tar.gz \
    data/reference/GRCh38.fa \
    data/reference/GRCh38.fa.fai \
    data/reference/*.bed \
    data/reference/CNV_genes_tuned.csv \
    data/reference/gencode.v48.annotation.gff3

# Package ANNOVAR databases
tar -czf zenodo_upload/humandb.tar.gz data/humandb/

# Copy existing zip files
cp data/reference/general.zip zenodo_upload/
cp data/reference/r1041_e82_400bps_sup_v420.zip zenodo_upload/

# Create Assembly.zip (if not already exists)
cd data/reference/
zip -r ../../zenodo_upload/Assembly.zip Assembly/
cd ../..

# Create svanna-data.zip (if not already exists)
cd data/reference/
zip -r ../../zenodo_upload/svanna-data.zip svanna-data/
cd ../..
```

### Step 3: Verify Files

```bash
ls -lh zenodo_upload/

# Should show:
# Assembly.zip
# general.zip
# humandb.tar.gz
# r1041_e82_400bps_sup_v420.zip
# reference_core.tar.gz
# svanna-data.zip
```

---

## Using the Upload Script

### Test on Sandbox First (Recommended)

```bash
./upload_to_zenodo.sh \
  --token YOUR_SANDBOX_TOKEN \
  --record SANDBOX_RECORD_ID \
  --sandbox \
  --files-dir ./zenodo_upload
```

**What happens:**
1. Creates a new version of the sandbox record
2. Removes old files from the draft
3. Uploads all new files with progress bars
4. Updates metadata
5. Asks for confirmation before publishing

### Upload to Production

```bash
./upload_to_zenodo.sh \
  --token YOUR_PRODUCTION_TOKEN \
  --record 15916972 \
  --files-dir ./zenodo_upload
```

**⚠️ This uploads to the REAL Zenodo!**

---

## Full Example Workflow

### Example 1: Test Upload to Sandbox

```bash
# 1. Set your token as environment variable (more secure)
export ZENODO_SANDBOX_TOKEN="your_sandbox_token_here"

# 2. Prepare files
mkdir -p zenodo_upload
# ... copy/create files as shown above ...

# 3. Upload to sandbox
./upload_to_zenodo.sh \
  --token "$ZENODO_SANDBOX_TOKEN" \
  --record 1234567 \
  --sandbox \
  --files-dir ./zenodo_upload

# 4. Check sandbox: https://sandbox.zenodo.org/record/NEW_RECORD_ID
```

### Example 2: Production Upload

```bash
# 1. Set your production token
export ZENODO_TOKEN="your_production_token_here"

# 2. Prepare files (make sure they're correct!)
mkdir -p zenodo_upload
# ... package all files ...

# 3. Verify files one more time
ls -lh zenodo_upload/
du -sh zenodo_upload/*

# 4. Upload to production
./upload_to_zenodo.sh \
  --token "$ZENODO_TOKEN" \
  --record 15916972 \
  --files-dir ./zenodo_upload

# 5. Script will ask for confirmation before publishing
```

---

## Script Output Example

```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║           Zenodo Upload Script for nWGS Pipeline              ║
║              Automated Reference File Upload                  ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

==========================================
Checking Dependencies
==========================================
✅ All dependencies met

ℹ️  Configuration:
  Files directory: ./zenodo_upload
  Base record: 15916972 (creating new version)
  Environment: PRODUCTION

ℹ️  Files to upload:
  - Assembly.zip (2.1G)
  - general.zip (2.8G)
  - humandb.tar.gz (9.2G)
  - r1041_e82_400bps_sup_v420.zip (1.8G)
  - reference_core.tar.gz (24G)
  - svanna-data.zip (14G)

Continue? (y/n) y

==========================================
Creating New Version
==========================================
ℹ️  Creating new version of record: 15916972
✅ New version created with deposit ID: 7654321

==========================================
Removing Old Files from New Version
==========================================
ℹ️  Found 6 old file(s) to remove
  Deleting: Assembly.zip
  ✓ Deleted
  ... (more files)
✅ Old files removed

==========================================
Uploading Files
==========================================
ℹ️  Found 6 files to upload

📤 Uploading: Assembly.zip (2.1G)
######################################################################## 100%
✓ Successfully uploaded: Assembly.zip

📤 Uploading: general.zip (2.8G)
######################################################################## 100%
✓ Successfully uploaded: general.zip

... (more uploads)

✅ Upload complete: 6 succeeded, 0 failed

==========================================
Updating Metadata
==========================================
✅ Metadata updated

==========================================
Publishing New Version
==========================================

⚠️  IMPORTANT: Publishing cannot be undone!

ℹ️  This will:
  1. Make the new version publicly available
  2. Assign a new DOI
  3. Lock the files (cannot be modified after publishing)

Are you sure you want to publish? (yes/no): yes
✅ Successfully published!

New Version Details:
  DOI: 10.5281/zenodo.7654321
  Record ID: 7654321
  URL: https://zenodo.org/record/7654321

✅ All done! 🎉
```

---

## Command Reference

### Basic Usage

```bash
./upload_to_zenodo.sh \
  --token TOKEN \
  --record RECORD_ID \
  --files-dir PATH
```

### All Options

| Option | Required | Description |
|--------|----------|-------------|
| `--token TOKEN` | Yes | Zenodo API access token |
| `--record ID` | Yes | Existing record ID to create new version |
| `--files-dir PATH` | Yes | Directory containing files to upload |
| `--sandbox` | No | Use Zenodo sandbox (for testing) |
| `--help` | No | Show help message |

---

## Troubleshooting

### "jq: command not found"

Install jq:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq

# macOS
brew install jq
```

### "Failed to create new version: Unauthorized"

Your API token is invalid or missing required scopes.

**Fix:**
1. Create a new token with `deposit:write` and `deposit:actions` scopes
2. Make sure you're using the correct token (sandbox vs production)

### "Failed to upload: filename (HTTP 413)"

File is too large for Zenodo's limits (50 GB per file).

**Fix:**
1. Split large files: `split -b 40G largefile.tar.gz largefile.tar.gz.part_`
2. Or contact Zenodo to request higher limits

### Upload Failed Halfway

The script doesn't support resume yet. You'll need to:

1. Delete the draft version from Zenodo web interface
2. Re-run the script

### "File not found, skipping: filename"

The file doesn't exist in your `--files-dir`.

**Fix:**
1. Check that all files are in the directory
2. Verify filenames match exactly (case-sensitive)

---

## Security Best Practices

### 1. Never Commit Tokens to Git

```bash
# Add to .gitignore
echo "zenodo_token.txt" >> .gitignore
echo "*.token" >> .gitignore
```

### 2. Use Environment Variables

```bash
# Set token in environment
export ZENODO_TOKEN="your_token_here"

# Use in script
./upload_to_zenodo.sh \
  --token "$ZENODO_TOKEN" \
  --record 15916972 \
  --files-dir ./zenodo_upload
```

### 3. Store Token Securely

```bash
# Save to file with restricted permissions
echo "your_token_here" > ~/.zenodo_token
chmod 600 ~/.zenodo_token

# Use in script
./upload_to_zenodo.sh \
  --token "$(cat ~/.zenodo_token)" \
  --record 15916972 \
  --files-dir ./zenodo_upload
```

---

## Advanced Usage

### Upload Only Specific Files

Edit the script and modify the `files_to_upload` array:

```bash
# In upload_to_zenodo.sh, around line 300
local files_to_upload=(
    "reference_core.tar.gz"  # Only upload this
    # "Assembly.zip"         # Comment out to skip
)
```

### Update Metadata Only

The script doesn't support this yet, but you can:

1. Create new version (script will pause before publishing)
2. Manually edit metadata on Zenodo web interface
3. Publish from web interface

### Batch Upload to Multiple Records

```bash
# Upload to record 1
./upload_to_zenodo.sh --token "$TOKEN" --record RECORD1 --files-dir ./files1

# Upload to record 2
./upload_to_zenodo.sh --token "$TOKEN" --record RECORD2 --files-dir ./files2
```

---

## Limits and Quotas

### Zenodo Limits (as of 2025)

- **File size**: 50 GB per file (can request increase)
- **Dataset size**: Unlimited (multiple files)
- **Upload speed**: Depends on your connection
- **API rate limit**: ~100 requests per hour

### Estimated Upload Times

| File | Size | Time (100 Mbps) | Time (1 Gbps) |
|------|------|-----------------|---------------|
| Assembly.zip | ~2 GB | ~3 min | ~20 sec |
| general.zip | ~3 GB | ~4 min | ~30 sec |
| humandb.tar.gz | ~10 GB | ~13 min | ~1.5 min |
| reference_core.tar.gz | ~25 GB | ~33 min | ~3.5 min |
| svanna-data.zip | ~15 GB | ~20 min | ~2 min |
| **Total** | **~55 GB** | **~73 min** | **~8 min** |

---

## FAQ

### Q: Can I update an already published version?

**A:** No, published versions are immutable. You must create a new version (which the script does automatically).

### Q: What happens to the old version?

**A:** It remains available with its original DOI. The new version gets a new DOI, but both are linked.

### Q: Can I delete a published version?

**A:** No, but you can hide it from public view by contacting Zenodo support.

### Q: Do I need to re-upload files if only metadata changed?

**A:** Yes, currently the script creates a new version and re-uploads all files. Manual editing via web interface is faster for metadata-only changes.

### Q: Can I automate this completely (no confirmation)?

**A:** Yes, modify the script to remove the `read -p` confirmation prompts, but be very careful!

---

## Alternative: Manual Web Upload

If the script doesn't work, use Zenodo's web interface:

1. Go to: https://zenodo.org/record/15916972
2. Click "New version"
3. Delete old files
4. Upload new files (drag & drop or click to browse)
5. Update metadata
6. Click "Publish"

**Note:** Web interface may timeout for very large files (>10 GB).

---

## Getting Help

If you encounter issues:

1. **Check logs**: The script prints detailed error messages
2. **Test on sandbox first**: Use `--sandbox` flag
3. **Zenodo documentation**: https://developers.zenodo.org/
4. **GitHub issues**: Report bugs at the nWGS pipeline repository

---

## Next Steps After Upload

1. **Update setup_pipeline.sh**: Change `ZENODO_RECORD` variable to new record ID
2. **Test download**: Run `./setup_pipeline.sh docker --skip-containers` to test download
3. **Update documentation**: Update README with new DOI
4. **Tag git release**: Create git tag for the version

---

## Example: Complete Version 5 Upload

```bash
# 1. Prepare workspace
cd /home/godzilla/nWGS_pipeline
mkdir -p zenodo_upload_v5

# 2. Package all files
tar -czf zenodo_upload_v5/reference_core.tar.gz data/reference/[files]
tar -czf zenodo_upload_v5/humandb.tar.gz data/humandb/
cp data/reference/general.zip zenodo_upload_v5/
# ... package other files ...

# 3. Test on sandbox
export ZENODO_SANDBOX_TOKEN="sandbox_token"
./upload_to_zenodo.sh \
  --token "$ZENODO_SANDBOX_TOKEN" \
  --record SANDBOX_ID \
  --sandbox \
  --files-dir ./zenodo_upload_v5

# 4. Verify sandbox upload works
# Check: https://sandbox.zenodo.org/record/NEW_ID

# 5. Upload to production
export ZENODO_TOKEN="production_token"
./upload_to_zenodo.sh \
  --token "$ZENODO_TOKEN" \
  --record 15916972 \
  --files-dir ./zenodo_upload_v5

# 6. Get new DOI and update pipeline
# Update setup_pipeline.sh with new record ID
# Commit and push changes
```

Done! Your new version is published on Zenodo! 🎉
