# Metal language corpus

`Language/` is a deliberately non-operational Metal reference corpus. It keeps
representative shader language material visible to GitHub's language analysis
without becoming part of Harbeth's library, demo, or test targets.

## Boundary

- Swift Package Manager only processes Metal resources under `Sources/`.
- CocoaPods only bundles `Sources/**/*.metal`.
- The Xcode projects must not add files from this directory to a target.
- Files here are never a runtime fallback, a shader registry, or a supported
  public API.

## Maintenance

- Keep all corpus files self-authored and valid Metal-language reference
  material; do not import third-party shader source without its license.
- Preserve the directory boundary when reorganizing shader examples or adding
  future corpus sections.
- After a default-branch update, use the GitHub Languages card as the source of
  truth for the displayed ratio. Local byte counts are only a planning check.
