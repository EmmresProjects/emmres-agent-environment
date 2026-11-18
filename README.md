# Emmre's Agent Environment

A portable, folder-based environment builder and documentation repository for Emmre's agent tools.

## Add environment material
- Put builder launchers in `Build/`.
- Put dependency lists in `Requirements/`.
- Put component documentation and optional redistributable files in `Components/`.
- Put versions, sources, and checksums in `Manifests/`.
- Put support commands in `Scripts/` and verification in `Tests/`.
- Keep the generated installed environment out of normal Git unless you intentionally package it separately.

## Documentation
The `docs/` folder is the GitHub Pages knowledge site. Update it manually whenever components or profiles change.
