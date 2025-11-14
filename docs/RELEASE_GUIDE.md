# nWGS Pipeline Release Guide

This guide explains how to create and publish new releases of the nWGS pipeline.

## Version Numbering (Semantic Versioning)

We follow [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`

- **MAJOR** (x.0.0): Breaking changes, incompatible API changes
  - Example: Changing config file structure, removing features, major workflow changes

- **MINOR** (0.x.0): New features, backward-compatible additions
  - Example: Adding new analysis module, new command-line options, new classifiers

- **PATCH** (0.0.x): Bug fixes, backward-compatible fixes
  - Example: Fixing cramino BAM bug, fixing R Markdown syntax errors

## Release Checklist

### 1. Update Version Number

Edit [nextflow.config](../nextflow.config) and update the version:

```groovy
manifest {
    version = '1.0.1'  // Update this line
}
```

### 2. Update CHANGELOG.md

Move changes from `[Unreleased]` section to a new version section:

```markdown
## [Unreleased]

### `Added`

### `Changed`

### `Fixed`

## [1.0.1] - 2024-11-14

### `Added`
- List new features added in this release

### `Changed`
- List changes to existing features

### `Fixed`
- List bug fixes
```

Add release link at the bottom:

```markdown
[Unreleased]: https://github.com/VilhelmMagnusLab/nWGS_pipeline/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/VilhelmMagnusLab/nWGS_pipeline/compare/v1.0.0...v1.0.1
```

### 3. Commit Version Changes

```bash
git add nextflow.config CHANGELOG.md
git commit -m "Release version 1.0.1

- Updated version in nextflow.config
- Updated CHANGELOG with release notes
"
```

### 4. Create Git Tag

Create an annotated tag with release notes:

```bash
git tag -a v1.0.1 -m "nWGS Pipeline v1.0.1

## Summary
Brief description of this release

## New Features
- Feature 1
- Feature 2

## Bug Fixes
- Fix 1
- Fix 2

## Changes
- Change 1
- Change 2
"
```

### 5. Push to GitHub

Push both the commit and the tag:

```bash
# Push the commit
git push origin main

# Push the tag
git push origin v1.0.1
```

### 6. Create GitHub Release

**Option A: Using GitHub CLI (Recommended)**

```bash
gh release create v1.0.1 \
  --title "nWGS Pipeline v1.0.1" \
  --notes-file docs/RELEASE_NOTES_v1.0.1.md
```

**Option B: Manual via GitHub Website**

1. Go to: https://github.com/VilhelmMagnusLab/nWGS_pipeline/releases/new
2. Select tag: `v1.0.1`
3. Release title: `nWGS Pipeline v1.0.1`
4. Copy release notes from CHANGELOG.md
5. Click "Publish release"

## Release Notes Template

Create a file `docs/RELEASE_NOTES_v1.0.1.md` for each release:

```markdown
# nWGS Pipeline v1.0.1

**Release Date:** 2024-11-14

## Summary

Brief overview of what this release contains.

## What's New

### New Features
- Feature 1 description
- Feature 2 description

### Improvements
- Improvement 1
- Improvement 2

### Bug Fixes
- Fixed issue with cramino analyzing wrong BAM file
- Fixed R Markdown syntax error in report generation

## Breaking Changes

None in this release.

## Installation

```bash
git clone https://github.com/VilhelmMagnusLab/nWGS_pipeline.git
cd nWGS_pipeline
git checkout v1.0.1
```

## Upgrade Instructions

For users upgrading from v1.0.0:

1. Pull the latest changes:
   ```bash
   git pull origin main
   git checkout v1.0.1
   ```

2. No configuration changes required for this release.

## Requirements

- Nextflow >= 23.10.1
- Singularity/Apptainer
- GRCh38 reference genome
- See [README.md](../README.md) for complete requirements

## Known Issues

None.

## Contributors

- Christian Domilongo Bope
- Skarphéðinn Halldórsson
- Richard Nagymihaly

## Full Changelog

See [CHANGELOG.md](../CHANGELOG.md) for complete details.
```

## Quick Release Commands

```bash
# Example: Creating release v1.0.1

# 1. Update files
vim nextflow.config  # Update version = '1.0.1'
vim CHANGELOG.md     # Move unreleased to v1.0.1

# 2. Commit and tag
git add nextflow.config CHANGELOG.md
git commit -m "Release version 1.0.1"
git tag -a v1.0.1 -m "Release v1.0.1 - Bug fixes and improvements"

# 3. Push
git push origin main
git push origin v1.0.1

# 4. Create GitHub release
gh release create v1.0.1 --title "nWGS Pipeline v1.0.1" --generate-notes
```

## Hotfix Release Process

For urgent bug fixes that need immediate release:

```bash
# 1. Create hotfix branch from tag
git checkout -b hotfix/v1.0.2 v1.0.1

# 2. Make fixes and commit
git add fixed_files
git commit -m "Fix critical bug in..."

# 3. Update version and CHANGELOG
vim nextflow.config  # version = '1.0.2'
vim CHANGELOG.md
git add nextflow.config CHANGELOG.md
git commit -m "Release version 1.0.2 (hotfix)"

# 4. Tag and merge back
git tag -a v1.0.2 -m "Hotfix release v1.0.2"
git checkout main
git merge hotfix/v1.0.2

# 5. Push
git push origin main
git push origin v1.0.2
git branch -d hotfix/v1.0.2

# 6. Create GitHub release
gh release create v1.0.2 --title "nWGS Pipeline v1.0.2 (Hotfix)"
```

## Version History

| Version | Release Date | Type | Highlights |
|---------|--------------|------|------------|
| v1.0.1 | 2024-11-14 | Patch | Bug fixes, improved documentation |
| v1.0dev | 2025-01-16 | Dev | Development release with fusion annotation |

## Best Practices

1. **Always test before releasing**: Run full pipeline on test data
2. **Update documentation**: Ensure README and docs are current
3. **Write clear release notes**: Explain what changed and why
4. **Use descriptive commit messages**: Follow conventional commits format
5. **Tag releases properly**: Use annotated tags with release notes
6. **Maintain CHANGELOG**: Keep it updated throughout development
7. **Communicate breaking changes**: Clearly document any breaking changes

## Checking Current Version

```bash
# From nextflow.config
grep "version" nextflow.config | head -1

# From git tags
git describe --tags --abbrev=0

# List all tags
git tag -l
```

## Rolling Back a Release

If you need to remove a release:

```bash
# Delete local tag
git tag -d v1.0.1

# Delete remote tag
git push --delete origin v1.0.1

# Delete GitHub release (manual or via gh CLI)
gh release delete v1.0.1
```

---

**For questions or issues with the release process, contact the development team.**
