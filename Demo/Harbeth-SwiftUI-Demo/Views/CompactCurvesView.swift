//
//  CompactCurvesView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2026/3/10.
//

import SwiftUI
import Harbeth

struct CompactCurvesView: View {
    @Binding var controlPoints: [C7Point2D]
    @Binding var selectedChannel: Channel
    var onCurvesChange: (C7Curves) -> Void
    
    enum Channel: String, CaseIterable {
        case rgb = "RGB"
        case red = "Red"
        case green = "Green"
        case blue = "Blue"
    }
    
    @State private var selectedPointIndex: Int? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            // 通道选择器
            HStack {
                ForEach(Channel.allCases, id: \.self) {
                    channel in
                    Button(action: {
                        selectedChannel = channel
                        updateFilter()
                    }) {
                        Text(channel.rawValue)
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedChannel == channel ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedChannel == channel ? .white : .black)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.horizontal, 12)
            
            // 曲线编辑器
            GeometryReader { geometry in
                ZStack {
                    // 网格背景
                    CompactGridView(size: geometry.size)
                    
                    // 曲线
                    CompactCurvePath(controlPoints: controlPoints, size: geometry.size)
                    
                    // 控制点
                    ForEach(0..<controlPoints.count, id: \.self) {
                        index in
                        CompactControlPointView(
                            point: controlPoints[index],
                            size: geometry.size,
                            isSelected: selectedPointIndex == index,
                            onDrag: { newPoint in
                                handlePointDrag(index: index, newPoint: newPoint)
                            },
                            onDragEnd: { 
                                selectedPointIndex = nil
                            },
                            onDoubleTap: { 
                                handleDoubleTap(index: index)
                            }
                        )
                    }
                    
                    // 单击添加点的覆盖层
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onEnded { value in
                                            handleSingleTap(location: value.location, size: geometry.size)
                                        }
                                )
                }
                .frame(height: 120)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .padding(.horizontal, 12)
            }
            
            // 控制按钮
            HStack(spacing: 8) {
                Button(action: {
                    resetToDefault()
                }) {
                    Text("Reset")
                        .font(.system(size: 12))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // 预设按钮
                HStack(spacing: 6) {
                    CompactPresetButton(title: "S", preset: .sCurve) { preset in
                        applyPreset(preset)
                    }
                    CompactPresetButton(title: "B", preset: .brighten) { preset in
                        applyPreset(preset)
                    }
                    CompactPresetButton(title: "C", preset: .contrast) { preset in
                        applyPreset(preset)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(height: 200)
    }
    
    func updateFilter() {
        let filter = createFilter()
        onCurvesChange(filter)
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
        updateFilter()
    }
    
    func resetToDefault() {
        controlPoints = [
            C7Point2D(x: 0.0, y: 0.0),
            C7Point2D(x: 0.5, y: 0.5),
            C7Point2D(x: 1.0, y: 1.0)
        ]
        updateFilter()
    }
    
    func handlePointDrag(index: Int, newPoint: C7Point2D) {
        selectedPointIndex = index
        var updatedPoints = controlPoints
        updatedPoints[index] = newPoint
        // 重新排序点以保持x坐标递增
        updatedPoints.sort { $0.x < $1.x }
        controlPoints = updatedPoints
        // 找到新的索引
        selectedPointIndex = controlPoints.firstIndex { $0.x == newPoint.x && $0.y == newPoint.y }
        updateFilter()
    }
    
    func handleSingleTap(location: CGPoint, size: CGSize) {
        // 计算点击位置对应的归一化坐标
        let x = max(0.0, min(1.0, Float(location.x / size.width)))
        let y = max(0.0, min(1.0, Float(1.0 - location.y / size.height)))
        
        // 创建新的控制点
        let newPoint = C7Point2D(x: x, y: y)
        
        // 添加到点列表并排序
        var updatedPoints = controlPoints
        updatedPoints.append(newPoint)
        updatedPoints.sort { $0.x < $1.x }
        controlPoints = updatedPoints
        
        // 更新滤镜
        updateFilter()
    }
    
    func handleDoubleTap(index: Int) {
        // 确保至少保留两个点（起点和终点）
        if controlPoints.count > 2 {
            controlPoints.remove(at: index)
            updateFilter()
        }
    }
    
    enum CurvePreset {
        case brighten
        case contrast
        case sCurve
    }
}

// 曲线路径视图
struct CompactCurvePath: View {
    let controlPoints: [C7Point2D]
    let size: CGSize
    
    var body: some View {
        Path {
            path in
            if !controlPoints.isEmpty {
                path.move(to: CGPoint(x: CGFloat(controlPoints[0].x) * size.width, y: CGFloat((1.0 - controlPoints[0].y)) * size.height))
                for i in 1..<controlPoints.count {
                    let point = controlPoints[i]
                    path.addLine(to: CGPoint(x: CGFloat(point.x) * size.width, y: CGFloat((1.0 - point.y)) * size.height))
                }
            }
        }
        .stroke(Color.blue, lineWidth: 2)
    }
}

// 控制点视图
struct CompactControlPointView: View {
    let point: C7Point2D
    let size: CGSize
    let isSelected: Bool
    let onDrag: (C7Point2D) -> Void
    let onDragEnd: () -> Void
    let onDoubleTap: () -> Void
    
    var body: some View {
        let position = CGPoint(x: CGFloat(point.x) * size.width, y: CGFloat((1.0 - point.y)) * size.height)
        Circle()
            .stroke(Color.blue, lineWidth: 2)
            .frame(width: 10, height: 10)
            .position(position)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newX = max(0.0, min(1.0, Float(value.location.x / size.width)))
                        let newY = max(0.0, min(1.0, Float(1.0 - value.location.y / size.height)))
                        onDrag(C7Point2D(x: newX, y: newY))
                    }
                    .onEnded { _ in
                        onDragEnd()
                    }
            )
            .gesture(
                TapGesture(count: 2)
                    .onEnded { 
                        onDoubleTap()
                    }
            )
    }
}

struct CompactGridView: View {
    let size: CGSize
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<4) { _ in
                HStack(spacing: 0) {
                    ForEach(0..<4) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.05))
                            .frame(width: size.width / 4, height: size.height / 4)
                            .border(Color.gray.opacity(0.2), width: 0.5)
                    }
                }
            }
        }
    }
}

struct CompactPresetButton: View {
    let title: String
    let preset: CompactCurvesView.CurvePreset
    let action: (CompactCurvesView.CurvePreset) -> Void
    
    var body: some View {
        Button(action: {
            action(preset)
        }) {
            Text(title)
                .font(.system(size: 10))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.black)
                .cornerRadius(3)
        }
    }
}

struct CompactCurvesView_Previews: PreviewProvider {
    static var previews: some View {
        CompactCurvesView(
            controlPoints: .constant([
                C7Point2D(x: 0.0, y: 0.0),
                C7Point2D(x: 0.5, y: 0.5),
                C7Point2D(x: 1.0, y: 1.0)
            ]),
            selectedChannel: .constant(.rgb),
            onCurvesChange: { _ in }
        )
        .frame(height: 200)
        .background(Color.white)
    }
}
