import CommonCrypto
import Foundation

/// オーム電機 LT-Y33T6D1 が使う LampSmart Pro V2 プロトコルのパケット生成。
/// アルゴリズムは ha-ble-adv (NicoIIT) の FanLampEncoderV2 と同じ。
enum LampProtocol {
    /// 付属リモコンから復号した固有ID。このIDで送ればペアリング不要のはず。
    static let remoteID: UInt32 = 0x052C_9239
    static let deviceType: UInt16 = 0x0100  // LampSmart Pro 系
    static let appPrefix: [UInt8] = [0x30, 0x80, 0x00]  // アプリ形式
    static let remotePrefix: [UInt8] = [0x11, 0x00, 0x56]  // 付属リモコン形式
    static let header: [UInt8] = [0xF0, 0x08]

    struct Command {
        var cmd: UInt8
        var arg0: UInt8 = 0
        var arg1: UInt8 = 0
        var arg2: UInt8 = 0

        static let on = Command(cmd: 0x10)
        static let off = Command(cmd: 0x11)
        /// 2つ目の灯り。間接照明がこれに当たるかは未確認。
        static let secondaryOn = Command(cmd: 0x12)
        static let secondaryOff = Command(cmd: 0x13)
        static let nightMode = Command(cmd: 0x23)
        static let pair = Command(cmd: 0x28)
        static let brightnessUp = Command(cmd: 0x21, arg0: 0x14)  // リモコンで実測
        static let brightnessDown = Command(cmd: 0x21, arg0: 0x28)
        static let warmer = Command(cmd: 0x21, arg0: 0x24)
        static let cooler = Command(cmd: 0x21, arg0: 0x18)

        /// 昼光色LEDと電球色LEDの出力を 0...255 で直接指定する。
        static func white(cold: UInt8, warm: UInt8) -> Command {
            Command(cmd: 0x21, arg0: 0, arg1: cold, arg2: warm)
        }

        /// 明るさ・色温度 (どちらも 0...1、色温度は 0=電球色 1=昼光色) から指定する。
        static func white(brightness: Double, coolness: Double) -> Command {
            let b = min(max(brightness, 0), 1), c = min(max(coolness, 0), 1)
            return white(cold: UInt8((b * c * 255).rounded()), warm: UInt8((b * (1 - c) * 255).rounded()))
        }
    }

    /// 24バイトのペイロード (ヘッダ F0 08 の後ろに続く部分) を作る。
    static func payload(
        _ command: Command,
        txCount: UInt8,
        seed: UInt16,
        id: UInt32 = remoteID,
        index: UInt8 = 0,
        prefix: [UInt8] = appPrefix
    ) -> [UInt8] {
        var buf: [UInt8] = prefix + [txCount] + le(deviceType) + le(id)
        buf += [index, command.cmd, 0, 0, command.arg0, command.arg1, command.arg2]
        buf += le(sign(Array(buf[1..<17]), txCount: txCount, seed: seed))
        buf += [0x00] + le(seed)

        let s = Int(seed & 0xFF)
        let salt = Int(buf[1] & 0x3) << 5
        for i in 2..<(buf.count - 2) {
            buf[i] ^= xboxes[((s + (i - 2) + 9) & 0x1F) + salt] ^ UInt8(s)
        }
        return buf + le(crc16(buf, initial: seed ^ 0xFFFF))
    }

    // MARK: - Internals

    private static func le<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        withUnsafeBytes(of: value.littleEndian) { Array($0) }
    }

    private static func sign(_ block: [UInt8], txCount: UInt8, seed: UInt16) -> UInt16 {
        let key: [UInt8] =
            [UInt8(seed & 0xFF), UInt8(seed >> 8), txCount]
            + [0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16]
        var out = [UInt8](repeating: 0, count: 32)
        var outLen = 0
        let status = CCCrypt(
            CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionECBMode),
            key, key.count, nil, block, block.count, &out, out.count, &outLen)
        precondition(status == kCCSuccess && outLen >= 2)
        let value = UInt16(out[0]) | UInt16(out[1]) << 8
        return value == 0 ? 0xFFFF : value
    }

    /// CRC16-CCITT (poly 0x1021, MSB first)。
    private static func crc16(_ data: [UInt8], initial: UInt16) -> UInt16 {
        var crc = initial
        for byte in data {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1
            }
        }
        return crc
    }

    private static let xboxes: [UInt8] = [
        0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31, 0x15,
        0x04, 0xC7, 0x23, 0xC3, 0x18, 0x96, 0x05, 0x9A, 0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75,
        0xD0, 0xEF, 0xAA, 0xFB, 0x43, 0x4D, 0x33, 0x85, 0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8,
        0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5, 0xBC, 0xB6, 0xDA, 0x21, 0x10, 0xFF, 0xF3, 0xD2,
        0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C, 0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79,
        0xE7, 0xC8, 0x37, 0x6D, 0x8D, 0xD5, 0x4E, 0xA9, 0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08,
        0xE1, 0xF8, 0x98, 0x11, 0x69, 0xD9, 0x8E, 0x94, 0x9B, 0x1E, 0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF,
        0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16,
    ]
}

extension LampProtocol {
    /// 既知のパケットと突き合わせる自己診断。1つ目は付属リモコンの実キャプチャ。
    static func selfTest() -> Bool {
        func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02X", $0) }.joined() }
        let captured = payload(.brightnessUp, txCount: 17, seed: 0x36A1, prefix: remotePrefix)
        let on = payload(.on, txCount: 1, seed: 0x1234)
        let white = payload(.white(cold: 255, warm: 64), txCount: 200, seed: 0xBEEF)
        return hex(captured) == "11001241D078A92689638243B937B03BA6438E43A136D025"
            && hex(on) == "308013874182F0353E070BD3F80091D1C565810534126D40"
            && hex(white) == "3080E8356F0C3D5A719F58337CC9D92F58BD804AEFBE7789"
    }
}
