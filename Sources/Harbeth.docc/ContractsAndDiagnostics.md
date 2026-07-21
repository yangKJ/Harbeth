# Contracts and Diagnostics

Make output semantics and failures explicit before optimizing a pipeline.

- Use ``RenderProfile`` to select latency, preview, inspection, export, or readback behavior.
- Use ``RenderedFrame`` to keep texture ownership and frame metadata together.
- Set ``HarbethLogger/handler`` to route structured events into the host application's logger. Harbeth is silent by default.
- Attach `try HarbethSupportSnapshot.capture().json()` to bug reports for a privacy-safe environment summary.
- Consume analysis after rendering; analysis is an inspection layer shared by `HarbethIO` and `ImageNode`, not a processing route.

Performance monitoring must not change output timing. Real-time command buffers are delivered after scheduling whether monitoring is enabled or disabled; GPU timing is recorded asynchronously after completion.
