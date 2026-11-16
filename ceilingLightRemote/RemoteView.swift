import SwiftUI

/// 動作確認用の最小リモコン画面。Info.plist に NSBluetoothAlwaysUsageDescription が必要。
struct RemoteView: View {
    @StateObject private var remote = LightRemote()
    @State private var brightness = 1.0
    @State private var coolness = 0.5

    var body: some View {
        Form {
            Section {
                Text(LampProtocol.selfTest() ? "プロトコル自己診断: OK" : "プロトコル自己診断: NG")
                Text(remote.isReady ? "Bluetooth: 準備完了" : "Bluetooth: 利用不可")
            }
            Section("電源") {
                Button("点灯") { remote.send(.on) }
                Button("消灯") { remote.send(.off) }
                Button("常夜灯") { remote.send(.nightMode) }
            }
            Section("明るさ・色") {
                Slider(value: $brightness, in: 0.05...1) { Text("明るさ") }
                Slider(value: $coolness, in: 0...1) { Text("色温度") }
                Button("反映") { remote.send(.white(brightness: brightness, coolness: coolness)) }
            }
            Section("未確認のコマンド") {
                Button("2灯目 ON (間接照明?)") { remote.send(.secondaryOn) }
                Button("2灯目 OFF") { remote.send(.secondaryOff) }
                Button("ペアリング (通電後5秒以内)") { remote.send(.pair) }
            }
        }
        .disabled(!remote.isReady)
    }
}
