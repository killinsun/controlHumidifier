import CoreBluetooth
import Foundation

/// コマンドを BLE アドバタイズとして送信する。
/// iOS は Service Data を広告できないため、LampSmart Pro アプリと同じく
/// 26バイトを 13個の 16bit サービスUUID に見せかけて送る。フォアグラウンド専用。
final class LightRemote: NSObject, ObservableObject, CBPeripheralManagerDelegate {
    @Published private(set) var isReady = false

    private var manager: CBPeripheralManager!
    private var stopWork: DispatchWorkItem?
    private let txKey = "LightRemote.txCount"

    override init() {
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: .main)
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        isReady = peripheral.state == .poweredOn
    }

    func send(_ command: LampProtocol.Command, duration: TimeInterval = 0.8) {
        guard isReady else { return }

        // ライトは同じカウンタのパケットを無視するので、送信ごとに進めて保存する。
        let tx = UInt8(truncatingIfNeeded: UserDefaults.standard.integer(forKey: txKey) + 1)
        UserDefaults.standard.set(Int(tx), forKey: txKey)

        // UUID が重複すると iOS にまとめられる恐れがあるので、重複しない乱数を引く。
        var uuids: [CBUUID] = []
        repeat {
            let seed = UInt16.random(in: 1...0xFFF5)
            let bytes = LampProtocol.header + LampProtocol.payload(command, txCount: tx, seed: seed)
            uuids = stride(from: 0, to: bytes.count, by: 2).map {
                CBUUID(data: Data([bytes[$0 + 1], bytes[$0]]))  // 電波上はリトルエンディアン
            }
        } while Set(uuids).count != uuids.count

        stopWork?.cancel()
        manager.stopAdvertising()
        manager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: uuids])

        let work = DispatchWorkItem { [weak self] in self?.manager.stopAdvertising() }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }
}
