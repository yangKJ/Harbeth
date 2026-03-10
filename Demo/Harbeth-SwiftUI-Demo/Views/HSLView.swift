//
//  HSLView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2026/3/10.
//

import SwiftUI
import Harbeth

struct HSLView: View {
    @State private var inputImage: UIImage = R.image("yuan002") ?? UIImage()
    @State private var hue: Float = 0.0
    @State private var saturation: Float = 0.0
    @State private var lightness: Float = 0.0
    @State private var selectedParameter: Parameter = .saturation
    @State private var currentValue: Float = 0.0
    
    init() {
        // 初始化时设置 currentValue 为默认参数的值
        _currentValue = State(initialValue: 0.0)
    }
    
    enum Parameter: String, CaseIterable {
        case hue = "Hue"
        case saturation = "Saturation"
        case lightness = "Lightness"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 图像预览
                HarbethView(image: inputImage, filters: [createFilter()]) {
                    $0.resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 400)
                }
                .onAppear {
                    // 视图出现时设置 currentValue 为当前选择的参数的值
                    switch selectedParameter {
                    case .hue:
                        currentValue = hue
                    case .saturation:
                        currentValue = saturation
                    case .lightness:
                        currentValue = lightness
                    }
                }
                
                // 参数选择器
                Picker("Parameter", selection: $selectedParameter) {
                    ForEach(Parameter.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedParameter) {
                    newValue in
                    switch newValue {
                    case .hue:
                        currentValue = hue
                    case .saturation:
                        currentValue = saturation
                    case .lightness:
                        currentValue = lightness
                    }
                }
                
                // 参数调整滑块
                VStack {
                    Slider(
                        value: $currentValue,
                        in: rangeForSelectedParameter(),
                        step: 0.01
                    )
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding()
                    .onChange(of: currentValue) {
                        newValue in
                        switch selectedParameter {
                        case .hue:
                            hue = newValue
                        case .saturation:
                            saturation = newValue
                        case .lightness:
                            lightness = newValue
                        }
                    }
                    
                    // 参数范围提示
                    HStack {
                        Text(minValueForSelectedParameter())
                        Spacer()
                        Text(maxValueForSelectedParameter())
                    }
                    .padding(.horizontal, 30)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                }
                
                // 预设效果
                HStack(spacing: 10) {
                    PresetButton(title: "Warm") {
                        applyPreset(.warm)
                    }
                    PresetButton(title: "Cool") {
                        applyPreset(.cool)
                    }
                    PresetButton(title: "Vibrant") {
                        applyPreset(.vibrant)
                    }
                    PresetButton(title: "Muted") {
                        applyPreset(.muted)
                    }
                    PresetButton(title: "Reset") {
                        resetToDefault()
                    }
                }
                
                // 实时参数值显示
                VStack {
                    Text("Current Values")
                        .font(.headline)
                        .padding(.top)
                    
                    HStack(spacing: 20) {
                        ParameterValueView(label: "Hue", value: hue, range: (-180, 180))
                        ParameterValueView(label: "Saturation", value: saturation, range: (-1, 1))
                        ParameterValueView(label: "Lightness", value: lightness, range: (-1, 1))
                    }
                    .padding()
                }
            }
        }
    }
    
    func createFilter() -> C7HSL {
        return C7HSL(hue: hue, saturation: saturation, lightness: lightness)
    }
    
    func bindingForSelectedParameter() -> Binding<Float> {
        return Binding<Float>(
            get: {
                switch self.selectedParameter {
                case .hue:
                    return self.hue
                case .saturation:
                    return self.saturation
                case .lightness:
                    return self.lightness
                }
            },
            set: {
                switch self.selectedParameter {
                case .hue:
                    self.hue = $0
                case .saturation:
                    self.saturation = $0
                case .lightness:
                    self.lightness = $0
                }
            }
        )
    }
    
    func rangeForSelectedParameter() -> ClosedRange<Float> {
        switch selectedParameter {
        case .hue:
            return -180.0...180.0
        case .saturation:
            return -1.0...1.0
        case .lightness:
            return -1.0...1.0
        }
    }
    
    func minValueForSelectedParameter() -> String {
        switch selectedParameter {
        case .hue:
            return "-180"
        case .saturation:
            return "-1"
        case .lightness:
            return "-1"
        }
    }
    
    func maxValueForSelectedParameter() -> String {
        switch selectedParameter {
        case .hue:
            return "180"
        case .saturation:
            return "1"
        case .lightness:
            return "1"
        }
    }
    
    func getCurrentValue() -> Float {
        switch selectedParameter {
        case .hue:
            return hue
        case .saturation:
            return saturation
        case .lightness:
            return lightness
        }
    }
    
    func applyPreset(_ preset: HLSPreset) {
        switch preset {
        case .warm:
            hue = 30.0
            saturation = 0.3
            lightness = 0.1
        case .cool:
            hue = -30.0
            saturation = 0.2
            lightness = 0.0
        case .vibrant:
            hue = 0.0
            saturation = 1.0
            lightness = 0.0
        case .muted:
            hue = 0.0
            saturation = -0.5
            lightness = 0.0
        }
        
        // 更新 currentValue 为当前选择的参数的值
        switch selectedParameter {
        case .hue:
            currentValue = hue
        case .saturation:
            currentValue = saturation
        case .lightness:
            currentValue = lightness
        }
    }
    
    func resetToDefault() {
        hue = 0.0
        saturation = 0.0
        lightness = 0.0
        
        // 更新 currentValue 为当前选择的参数的值
        switch selectedParameter {
        case .hue:
            currentValue = hue
        case .saturation:
            currentValue = saturation
        case .lightness:
            currentValue = lightness
        }
    }
    
    enum HLSPreset {
        case warm
        case cool
        case vibrant
        case muted
    }
}

struct ParameterValueView: View {
    let label: String
    let value: Float
    let range: (Float, Float)
    
    var body: some View {
        VStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Text(String(format: "%.2f", value))
                .font(.system(size: 14, weight: .bold))
            Text("\(range.0) to \(range.1)")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .frame(minWidth: 80)
    }
}

struct PresetButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(title) {
            action()
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .font(.system(size: 12))
    }
}

struct HSLView_Previews: PreviewProvider {
    static var previews: some View {
        HSLView()
    }
}
