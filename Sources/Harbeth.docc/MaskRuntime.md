# Mask Runtime

Build precise, composable coverage while keeping mask processing inside Harbeth's two public routes.

## Public Surface

The public API exposes contracts that a host must create, persist, compose, or inspect:

- ``MaskPlane`` and ``MaskPlaneDescriptor`` carry coordinate space, source transforms, sampling, coverage semantics, storage, resource identity, revision, generation, and modified bounds.
- ``IncrementalMaskCanvas`` owns a persistent GPU coverage texture for pressure-aware paint and erase strokes. It returns ``MaskCanvasUpdate`` diagnostics and rejects stale generations.
- ``MaskExpression`` describes add, intersect, subtract, exclude, invert, and opacity DAGs. ``MaskExpressionPlan`` is a read-only compilation snapshot; execution remains an implementation detail of ``ImageNode``.
- ``MaskDerivedRecipe`` and ``MaskDerivedOperation`` describe thresholding, morphology, distance fields, confidence-weighted guided feathering, edge shift, asymmetric feathering, edge contraction, and cleanup. Their plan and diagnostics types expose stable observations without exposing the compiler or cache implementation. Hosts can select persistent or transient execution through ``ImageCachePolicy`` while the cache objects remain private.
- ``MaskTopologyRecipe`` provides explicit post-render topology inspection and cleanup. ``MaskAuxiliaryPlane`` and ``MaskWarpRecipe`` adapt caller-owned scalar or displacement textures into generic single-frame mask primitives.

Apply a stable mask plane or expression through ``ImageNode``:

```swift
let result = try node.applying(
    mask: .intersect(.source(subjectMask), .invert(.source(backgroundMask))),
    filters: [C7Exposure(exposure: 0.3)]
)
```

Foreground color spill is also exposed through the same route:

```swift
let cleanNode = try node.decontaminating(mask: subjectMask)
```

Use ``HarbethIO`` when the required operation is already a direct filter pipeline. Use ``ImageNode`` for mask descriptions, local effects, diagnostics, and structured delivery. These mask types support those routes; they do not establish a third processing entry.

## Internal Surface

Harbeth intentionally keeps these details internal:

- Metal mask filters, shader kernels, MPS distance-transform and guided-filter adapters;
- expression and derived-graph compiler implementations;
- memoized execution results, shared derived-resource caches, and heap leases;
- intermediate signed-distance, coefficient, normalized-coverage, and color-decontamination textures.

These types can change as scheduling, fusion, heap allocation, MPS behavior, or device capabilities evolve. Public plans and diagnostics report the stable result of those decisions without making the implementation itself a compatibility contract.

## Ownership Boundary

Harbeth owns deterministic single-frame GPU mask primitives. The host owns user interaction, undo/history, document persistence, and product policy. Media capture, playback, timelines, recording, and temporal scheduling remain outside the render core. Model inference, semantic subject selection, saliency policy, and large-image orchestration should provide textures or descriptors to this runtime rather than becoming public Harbeth mask APIs.
