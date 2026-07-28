# Contracts and Diagnostics

Make output semantics and failures explicit before optimizing a pipeline.

- Use ``RenderProfile`` to select latency, preview, inspection, export, or readback behavior.
- Use ``RenderedFrame`` to keep texture ownership and frame metadata together.
- Set ``HarbethLogger/handler`` to route structured events into the host application's logger. Harbeth is silent by default. Events expose their library origin, stable diagnostic code, outcome, correlation identifier, and metadata without introducing a host logging dependency.
- Use ``HarbethDiagnosticError`` and `Error.harbethDiagnosticCode` when a host needs a stable aggregation key instead of localized error text.
- Attach `try HarbethSupportSnapshot.capture().json()` to bug reports for a privacy-safe environment summary.
- Consume analysis after rendering; analysis is an inspection layer shared by `HarbethIO` and `ImageNode`, not a processing route.
- Use ``RenderRequest/resourceAdmission`` to reject work against a request budget before texture allocation, and `renderFrameWithResourceReport(metadata:)` when allocator-observed allocation and reuse evidence is required.
- Compare `RenderRequest.parityReport(comparedTo:)` before treating preview and export requests as visually equivalent.
- Configure pipeline binary archives and derived texture lifetime through ``HarbethContext``; both remain runtime support under `HarbethIO` and `ImageNode`.

Performance monitoring must not change output timing. Real-time command buffers are delivered after scheduling whether monitoring is enabled or disabled; GPU timing is recorded asynchronously after completion.

Hosts own persistence, redaction, retention, presentation, and upload policy. Treat dynamic metadata as private unless its export safety is explicitly known; do not attach image content, absolute paths, or user identifiers to a Harbeth event.
