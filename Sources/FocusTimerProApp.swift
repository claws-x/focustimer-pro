//
//  FocusTimerProApp.swift
//  Focus Timer Pro
//
//  专注计时器 - Pomodoro 工作法
//

import SwiftUI

@main
struct FocusTimerProApp: App {
    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerManager)
                .environmentObject(settingsManager)
        }
    }
}

// MARK: - Timer Manager

class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    @Published var timeRemaining: Int = 25 * 60 // 25 分钟
    @Published var isRunning: Bool = false
    @Published var currentMode: TimerMode = .focus
    @Published var completedSessions: Int = 0
    
    private var timer: Timer?
    
    enum TimerMode: String, CaseIterable {
        case focus = "专注"
        case shortBreak = "短休息"
        case longBreak = "长休息"
        
        var duration: Int {
            switch self {
            case .focus: return 25 * 60
            case .shortBreak: return 5 * 60
            case .longBreak: return 15 * 60
            }
        }
    }
    
    func start() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        stop()
        timeRemaining = currentMode.duration
    }
    
    func switchMode(_ mode: TimerMode) {
        stop()
        currentMode = mode
        timeRemaining = mode.duration
    }
    
    private func tick() {
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            // 计时结束
            stop()
            if currentMode == .focus {
                completedSessions += 1
                // 每 4 个专注会话后长休息
                if completedSessions % 4 == 0 {
                    switchMode(.longBreak)
                } else {
                    switchMode(.shortBreak)
                }
            }
            // TODO: 播放提示音
        }
    }
}

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @AppStorage("focusDuration") var focusDuration: Int = 25
    @AppStorage("shortBreakDuration") var shortBreakDuration: Int = 5
    @AppStorage("longBreakDuration") var longBreakDuration: Int = 15
    @AppStorage("sessionsBeforeLongBreak") var sessionsBeforeLongBreak: Int = 4
    @AppStorage("autoStartBreaks") var autoStartBreaks: Bool = false
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
}

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedMode: TimerManager.TimerMode = .focus
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // 模式选择
                Picker("模式", selection: $selectedMode) {
                    ForEach(TimerManager.TimerMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: selectedMode) { newMode in
                    timerManager.switchMode(newMode)
                }
                
                // 计时器显示
                VStack(spacing: 20) {
                    Text(formatTime(timerManager.timeRemaining))
                        .font(.system(size: 80, weight: .light, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Text(timerManager.currentMode.rawValue)
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 40)
                
                // 控制按钮
                HStack(spacing: 40) {
                    Button(action: {
                        if timerManager.isRunning {
                            timerManager.stop()
                        } else {
                            timerManager.start()
                        }
                    }) {
                        Image(systemName: timerManager.isRunning ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)
                    }
                    
                    Button(action: {
                        timerManager.reset()
                    }) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                    }
                }
                
                // 统计
                VStack(spacing: 10) {
                    Text("已完成专注：\(timerManager.completedSessions) 次")
                        .font(.headline)
                    
                    HStack {
                        ForEach(0..<4, id: \.self) { index in
                            Image(systemName: index < timerManager.completedSessions % 4 ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(index < timerManager.completedSessions % 4 ? .green : .gray)
                        }
                    }
                    .font(.title2)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Focus Timer Pro")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }
    
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            Section(header: Text("时长设置")) {
                Stepper("专注时长：\(settingsManager.focusDuration) 分钟", value: $settingsManager.focusDuration, in: 1...60)
                Stepper("短休息：\(settingsManager.shortBreakDuration) 分钟", value: $settingsManager.shortBreakDuration, in: 1...15)
                Stepper("长休息：\(settingsManager.longBreakDuration) 分钟", value: $settingsManager.longBreakDuration, in: 1...30)
                Stepper("长休息前会话数：\(settingsManager.sessionsBeforeLongBreak)", value: $settingsManager.sessionsBeforeLongBreak, in: 2...8)
            }
            
            Section(header: Text("选项")) {
                Toggle("自动开始休息", isOn: $settingsManager.autoStartBreaks)
                Toggle("提示音", isOn: $settingsManager.soundEnabled)
            }
            
            Section(header: Text("关于")) {
                Text("版本 1.0.0")
                Text("Focus Timer Pro")
                Text("基于 Pomodoro 工作法")
            }
        }
        .navigationTitle("设置")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("完成") {
                    dismiss()
                }
            }
        }
    }
}
