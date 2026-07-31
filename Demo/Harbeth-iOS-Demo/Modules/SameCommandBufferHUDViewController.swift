//
//  SameCommandBufferHUDViewController.swift
//  Harbeth-iOS-Demo
//
//  Created by Condy on 2026/7/31.
//

import UIKit
import Metal
import Harbeth

/// 展示 Harbeth 编码完成后，宿主继续在同一个 command buffer 上编码并自行提交。
final class SameCommandBufferHUDViewController: UIViewController {

    private struct RenderResult {
        let texture: MTLTexture
        let report: String
    }

    private enum DemoError: LocalizedError {
        case missingAsset
        case commandQueue
        case commandBuffer
        case destinationTexture
        case hostEncoder
        case missingAttachment(RenderOutputAttachmentSemantic)
        case unexpectedStatus(MTLCommandBufferStatus)

        var errorDescription: String? {
            switch self {
            case .missingAsset:
                return "找不到 Demo 图片资源 yuan001。"
            case .commandQueue:
                return "宿主无法创建 Metal command queue。"
            case .commandBuffer:
                return "宿主无法创建 Metal command buffer。"
            case .destinationTexture:
                return "宿主无法创建 HUD 输出纹理。"
            case .hostEncoder:
                return "宿主无法创建 HUD compute encoder。"
            case .missingAttachment(let semantic):
                return "Harbeth 没有返回所需 attachment：\(semantic.rawValue)。"
            case .unexpectedStatus(let status):
                return "command buffer 结束状态异常：\(status.rawValue)。"
            }
        }
    }

    private let renderQueue = DispatchQueue(label: "com.condy.harbeth.same-command-buffer-hud", qos: .userInitiated)

    private lazy var renderView: RenderView = {
        let view = RenderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.resizingMode = .aspectFit
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = "等待宿主编码。"
        return label
    }()

    private lazy var runButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = "运行同一 Command Buffer 示例"
        configuration.baseBackgroundColor = UIColor(hex: "#5C48FA")
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 16, bottom: 13, trailing: 16)
        button.configuration = configuration
        button.addTarget(self, action: #selector(runExample), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Command Buffer HUD"
        view.backgroundColor = .systemBackground
        setupUI()
        runExample()
    }
}

private extension SameCommandBufferHUDViewController {

    func setupUI() {
        let summaryLabel = UILabel()
        summaryLabel.font = UIFont.systemFont(ofSize: 15)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.numberOfLines = 0
        summaryLabel.text = "Harbeth 只负责把主色和亮度 attachment 编码进去；紫色 HUD 是 Demo 宿主随后追加的 Metal pass，最后仍由宿主提交。"

        let stepsLabel = UILabel()
        stepsLabel.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        stepsLabel.textColor = .label
        stepsLabel.numberOfLines = 0
        stepsLabel.text = "1  Harbeth.encodeAttachmentSet\n2  Host.hostHUDOverlay\n3  Host.commandBuffer.commit()"

        let stack = UIStackView(arrangedSubviews: [summaryLabel, renderView, stepsLabel, statusLabel, runButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            renderView.heightAnchor.constraint(equalTo: renderView.widthAnchor, multiplier: 0.72)
        ])
    }

    @objc func runExample() {
        guard let image = UIImage(named: "yuan001") else {
            show(error: DemoError.missingAsset)
            return
        }

        runButton.isEnabled = false
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = "正在编码 Harbeth attachments…"
        renderQueue.async { [weak self] in
            do {
                let result = try Self.render(image: image)
                DispatchQueue.main.async {
                    self?.renderView.texture = result.texture
                    self?.statusLabel.text = result.report
                    self?.runButton.isEnabled = true
                }
            } catch {
                DispatchQueue.main.async {
                    self?.show(error: error)
                }
            }
        }
    }

    func show(error: Error) {
        statusLabel.text = "失败：\(error.localizedDescription)"
        statusLabel.textColor = .systemRed
        runButton.isEnabled = true
    }

    private static func render(image: UIImage) throws -> RenderResult {
        let sourceTexture = try TextureLoader(with: image).texture
        let device = sourceTexture.device
        guard let commandQueue = device.makeCommandQueue() else {
            throw DemoError.commandQueue
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw DemoError.commandBuffer
        }
        commandBuffer.label = "Host.SameCommandBufferHUD"

        let attachments = try RenderAuxiliaryLuminance().encodeAttachmentSet(
            from: sourceTexture,
            commandBuffer: commandBuffer,
            identifier: "Demo.SameCommandBufferHUD"
        )
        let statusAfterHarbeth = commandBuffer.status
        guard let colorTexture = attachments.texture(for: .primaryColor) else {
            throw DemoError.missingAttachment(.primaryColor)
        }
        guard let luminanceTexture = attachments.texture(for: .luminance) else {
            throw DemoError.missingAttachment(.luminance)
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: colorTexture.pixelFormat,
            width: colorTexture.width,
            height: colorTexture.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let outputTexture = device.makeTexture(descriptor: descriptor) else {
            throw DemoError.destinationTexture
        }
        outputTexture.label = "Host.HUDOutput"

        guard let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "harbethDemoHostHUDOverlay") else {
            throw DemoError.hostEncoder
        }
        let pipeline = try device.makeComputePipelineState(function: function)
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw DemoError.hostEncoder
        }
        encoder.label = "Host.HUDOverlay"
        encoder.setTexture(colorTexture, index: 0)
        encoder.setTexture(luminanceTexture, index: 1)
        encoder.setTexture(outputTexture, index: 2)
        let threadWidth = pipeline.threadExecutionWidth
        let threadHeight = max(1, pipeline.maxTotalThreadsPerThreadgroup / threadWidth)
        encoder.setComputePipelineState(pipeline)
        encoder.dispatchThreads(
            MTLSize(width: outputTexture.width, height: outputTexture.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        )
        encoder.endEncoding()
        let statusAfterHostEncoding = commandBuffer.status

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else {
            if let error = commandBuffer.error { throw error }
            throw DemoError.unexpectedStatus(commandBuffer.status)
        }

        let report = """
        Harbeth 后：\(statusAfterHarbeth == .notEnqueued ? "notEnqueued" : "status=\(statusAfterHarbeth.rawValue)")
        Host encoder 后：\(statusAfterHostEncoding == .notEnqueued ? "notEnqueued" : "status=\(statusAfterHostEncoding.rawValue)")
        Host 提交后：completed
        Attachments：primaryColor + luminance
        提交次数：1（由 Demo 宿主执行）
        """
        return RenderResult(texture: outputTexture, report: report)
    }
}
