//
//  CurvesView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2026/3/10.
//

import SwiftUI
import Harbeth

struct CurvesView: View {
    @State private var inputImage: UIImage = R.image("Bear")!
    @State private var selectedChannel: Channel = .rgb
    @State private var controlPoints: [C7Point2D] = [
        C7Point2D(x: 0.0, y: 0.0),
        C7Point2D(x: 0.4, y: 0.1),
        C7Point2D(x: 0.6, y: 0.6),
        C7Point2D(x: 0.8, y: 0.8),
        C7Point2D(x: 1.0, y: 1.0)
    ]
    
    @State private var selectedPointIndex: Int? = nil
    @State private var isDragging: Bool = false
    
    enum Channel: String, CaseIterable {
        case rgb = "RGB"
        case red = "Red"
        case green = "Green"
        case blue = "Blue"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 图像预览
                HarbethView(image: inputImage, filters: [createFilter()]) {
                    $0.resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 400)
                }
                .animation(nil, value: controlPoints)
                .padding()
                
                // 通道选择器
                Picker("Channel", selection: $selectedChannel) {
                    ForEach(Channel.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // 曲线编辑器
                GeometryReader { geometry in
                    let editorSize = CGSize(width: geometry.size.width - 32, height: 200)
                    ZStack {
                        // 网格背景
                        GridView(size: editorSize)
                        
                        // 曲线
                        CurvePath(controlPoints: controlPoints, size: editorSize)
                            .animation(nil, value: controlPoints)
                        
                        // 控制点
                        ForEach(0..<controlPoints.count, id: \.self) { index in
                            ControlPointView(
                                point: controlPoints[index],
                                size: editorSize,
                                isSelected: selectedPointIndex == index,
                                onDragStart: {
                                    selectedPointIndex = index
                                    isDragging = true
                                },
                                onDrag: { newPoint in
                                    handlePointDrag(index: index, newPoint: newPoint)
                                },
                                onDragEnd: {
                                    isDragging = false
                                    selectedPointIndex = nil
                                },
                                onDoubleTap: {
                                    handleDoubleTap(index: index)
                                }
                            )
                        }
                    }
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding()
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                if selectedPointIndex == nil && !isDragging {
                                    // 点击空白处添加新点
                                    handleSingleTap(location: value.location, size: editorSize)
                                    isDragging = true
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                selectedPointIndex = nil
                            }
                    )
                }
                
                // 预设曲线
                VStack {
                    Text("Presets")
                        .font(.headline)
                        .padding(.top)
                    
                    HStack(spacing: 16) {
                        PresetButton(title: "Brighten") {
                            applyPreset(.brighten)
                        }
                        
                        PresetButton(title: "Contrast") {
                            applyPreset(.contrast)
                        }
                        
                        PresetButton(title: "S-curve") {
                            applyPreset(.sCurve)
                        }
                        
                        PresetButton(title: "Reset") {
                            resetToDefault()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }
    
    func createFilter() -> C7Curves {
        var rgbPoints = controlPoints
        var redPoints = controlPoints
        var greenPoints = controlPoints
        var bluePoints = controlPoints
        
        switch selectedChannel {
        case .red:
            redPoints = controlPoints
        case .green:
            greenPoints = controlPoints
        case .blue:
            bluePoints = controlPoints
        default:
            rgbPoints = controlPoints
        }
        
        return C7Curves(
            rgbPoints: rgbPoints,
            redPoints: redPoints,
            greenPoints: greenPoints,
            bluePoints: bluePoints
        )
    }
    
    func applyPreset(_ preset: CurvePreset) {
        switch preset {
        case .brighten:
            controlPoints = [
                C7Point2D(x: 0.0, y: 0.1),
                C7Point2D(x: 0.5, y: 0.6),
                C7Point2D(x: 1.0, y: 1.0)
            ]
        case .contrast:
            controlPoints = [
                C7Point2D(x: 0.0, y: 0.0),
                C7Point2D(x: 0.5, y: 0.5),
                C7Point2D(x: 1.0, y: 1.0)
            ]
        case .sCurve:
            controlPoints = [
                C7Point2D(x: 0.0, y: 0.0),
                C7Point2D(x: 0.3, y: 0.2),
                C7Point2D(x: 0.7, y: 0.8),
                C7Point2D(x: 1.0, y: 1.0)
            ]
        }
    }
    
    func resetToDefault() {
        controlPoints = [
            C7Point2D(x: 0.0, y: 0.0),
            C7Point2D(x: 0.4, y: 0.1),
            C7Point2D(x: 0.6, y: 0.6),
            C7Point2D(x: 0.8, y: 0.8),
            C7Point2D(x: 1.0, y: 1.0)
        ]
    }
    
    func handlePointDrag(index: Int, newPoint: C7Point2D) {
        selectedPointIndex = index
        var updatedPoints = controlPoints
        updatedPoints[index] = newPoint
        updatedPoints.sort { $0.x < $1.x }
        controlPoints = updatedPoints
        selectedPointIndex = controlPoints.firstIndex { $0.x == newPoint.x && $0.y == newPoint.y }
    }
    
    func handleSingleTap(location: CGPoint, size: CGSize) {
        // 计算点击位置对应的归一化坐标
        let x = max(0.0, min(1.0, Float(location.x / size.width)))
        let y = max(0.0, min(1.0, Float(1.0 - location.y / size.height)))
        
        // 检查是否点击了现有控制点
        for (i, point) in controlPoints.enumerated() {
            let pointX = CGFloat(point.x) * size.width
            let pointY = CGFloat(1.0 - point.y) * size.height
            let distance = sqrt(pow(location.x - pointX, 2) + pow(location.y - pointY, 2))
            if distance < 15 {
                selectedPointIndex = i
                return
            }
        }
        
        // 创建新的控制点
        let newPoint = C7Point2D(x: x, y: y)
        
        // 添加到点列表并排序
        var updatedPoints = controlPoints
        updatedPoints.append(newPoint)
        updatedPoints.sort { $0.x < $1.x }
        controlPoints = updatedPoints
    }
    
    func handleDoubleTap(index: Int) {
        if controlPoints.count > 2 {
            controlPoints.remove(at: index)
        }
    }
    
    enum CurvePreset {
        case brighten
        case contrast
        case sCurve
    }
}

// 曲线路径视图 - 使用Catmull-Rom样条曲线实现平滑曲线
private struct CurvePath: View {
    let controlPoints: [C7Point2D]
    let size: CGSize
    
    var body: some View {
        Path {
            path in
            if controlPoints.count < 2 {
                return
            }
            
            // 转换控制点为屏幕坐标
            let points = controlPoints.map {
                CGPoint(x: CGFloat($0.x) * size.width, y: CGFloat((1.0 - $0.y)) * size.height)
            }
            
            // 移动到第一个点
            path.move(to: points[0])
            
            // 使用Catmull-Rom样条曲线绘制平滑曲线
            if points.count == 2 {
                // 只有两个点，使用直线
                path.addLine(to: points[1])
            } else {
                // 对于多个点，使用Catmull-Rom样条曲线
                for i in 1..<points.count {
                    let p0 = i > 1 ? points[i-2] : points[0]
                    let p1 = points[i-1]
                    let p2 = points[i]
                    let p3 = i < points.count - 1 ? points[i+1] : points[points.count-1]
                    
                    // 计算控制点
                    let c1 = CGPoint(
                        x: p1.x + (p2.x - p0.x) / 6.0,
                        y: p1.y + (p2.y - p0.y) / 6.0
                    )
                    
                    let c2 = CGPoint(
                        x: p2.x - (p3.x - p1.x) / 6.0,
                        y: p2.y - (p3.y - p1.y) / 6.0
                    )
                    
                    // 使用三次贝塞尔曲线
                    path.addCurve(to: p2, control1: c1, control2: c2)
                }
            }
        }
        .stroke(Color.purple, lineWidth: 2)
        .shadow(color: Color.purple.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// 控制点视图
private struct ControlPointView: View {
    let point: C7Point2D
    let size: CGSize
    let isSelected: Bool
    let onDragStart: () -> Void
    let onDrag: (C7Point2D) -> Void
    let onDragEnd: () -> Void
    let onDoubleTap: () -> Void
    
    var body: some View {
        let position = CGPoint(x: CGFloat(point.x) * size.width, y: CGFloat((1.0 - point.y)) * size.height)
        Circle()
            .fill(isSelected ? Color.red : Color.white)
            .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)
            .position(position)
            .shadow(radius: 3)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onDragStart()
                        let newX = max(0.0, min(1.0, Float(value.location.x / size.width)))
                        let newY = max(0.0, min(1.0, Float(1.0 - value.location.y / size.height)))
                        onDrag(C7Point2D(x: newX, y: newY))
                    }
                    .onEnded { _ in
                        onDragEnd()
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        onDoubleTap()
                    }
            )
    }
}

private struct GridView: View {
    let size: CGSize
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<5) { _ in
                HStack(spacing: 0) {
                    ForEach(0..<5) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: size.width / 5, height: size.height / 5)
                            .border(Color.gray.opacity(0.3), width: 0.5)
                    }
                }
            }
        }
    }
}

struct CurvesView_Previews: PreviewProvider {
    static var previews: some View {
        CurvesView()
    }
}
