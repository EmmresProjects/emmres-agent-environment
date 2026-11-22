# Emmre's Environment Repository

Put only `Emmres_Environment` in the GitHub repository. `Local Environment` stays beside it and is reused by the builder.

1. `1. Build Environment.cmd` updates the local runtime, publishes accepted readable and binary resources, and rebuilds docs.
2. `2. Push to GitHub LFS.cmd` commits and pushes all repository content with configured LFS patterns.

`.onnx` and other selected binaries are accepted as downloadable resources. They are not text-searchable knowledge. Files over 100 MiB are skipped because GitHub rejects them as ordinary repository files; use GitHub Releases for those.

## V8 publication repair
V8 fixes the Windows PowerShell 5.1 `TrimStart` binding failure. The publisher now uses an explicit character array and normal `foreach` loops. ONNX, FFmpeg executables, and other selected binary files are accepted up to 2 GiB and stored through Git LFS.

## V9 virtual-environment reuse
The builder no longer calls `uv venv` when `../Local Environment/venv/Scripts/python.exe` already exists. It reuses the environment and installs or updates only the required packages, so unattended builds do not stop at the replacement prompt.

## V10 documentation-launch repair
The build now runs `Scripts/build_documentation.py` directly with `../Local Environment/venv/Scripts/python.exe`. It does not use `py.exe`, a PATH launcher, or a stale Python association. This fixes failures caused by old interpreter paths and apostrophes in parent folder names.
