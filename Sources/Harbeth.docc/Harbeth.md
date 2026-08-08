# Harbeth

Build texture-first GPU image and frame pipelines on Apple platforms.

## Overview

Harbeth is a Metal render engine for iOS, iPadOS, macOS, and tvOS. It owns deterministic GPU image and frame rendering; the host retains interaction, persistence, and product policy. Its public usage model has two routes:

- ``HarbethIO`` for direct source-to-output processing.
- ``ImageNode`` for structured editing, geometry, optics, recipes, and render contracts.

``RenderView`` and ``HarbethRenderView`` host texture-first output without turning preview into a third processing route. Runtime, diagnostics, and analysis support both routes.

## Topics

### Start Here

- <doc:HarbethIO>
- <doc:ImageNode>

### Sources and Results

- <doc:InputOutputInterop>
- <doc:OutputContracts>

### Preview

- <doc:PreviewHost>
- <doc:RealTimeDelivery>

### Filter Development

- <doc:FilterAuthoring>

### Runtime Contracts

- <doc:RuntimeResources>
- <doc:ContractsAndDiagnostics>
- <doc:AttachmentInterop>
- <doc:MaskRuntime>
