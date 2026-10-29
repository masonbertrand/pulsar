// 29/10: the audio outputs (speakers, headphones, AirPods, displays) and the one in use, for the Now Playing tab's picker.
// CoreAudio, no permission needed. The dial (ghiera.swift) already follows a change of output by itself.
import CoreAudio
import Foundation

enum UsciteAudio {
    struct Uscita: Identifiable, Equatable { let id: AudioObjectID; let nome: String }

    private static let sistema = AudioObjectID(kAudioObjectSystemObject)
    private static func indirizzo(_ s: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: s, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    /// Devices that can play sound, without aggregate ones (the mixer makes its own, and they aren't real outputs).
    static func elenco() -> [Uscita] {
        var a = indirizzo(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(sistema, &a, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(sistema, &a, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            var flussi = indirizzo(kAudioDevicePropertyStreams, kAudioDevicePropertyScopeOutput)
            var fs: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &flussi, 0, nil, &fs) == noErr, fs > 0 else { return nil }
            var tipo = indirizzo(kAudioDevicePropertyTransportType)
            var t: UInt32 = 0
            var ts = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(id, &tipo, 0, nil, &ts, &t) == noErr, t == kAudioDeviceTransportTypeAggregate { return nil }
            var n = indirizzo(kAudioObjectPropertyName)
            var nome: CFString? = nil
            var ns = UInt32(MemoryLayout<CFString?>.size)
            let ok = withUnsafeMutablePointer(to: &nome) { AudioObjectGetPropertyData(id, &n, 0, nil, &ns, $0) }
            guard ok == noErr, let nome else { return nil }
            return Uscita(id: id, nome: nome as String)
        }
    }

    /// The output in use.
    static var attuale: AudioObjectID {
        var a = indirizzo(kAudioHardwarePropertyDefaultOutputDevice)
        var v = AudioObjectID(0)
        var s = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(sistema, &a, 0, nil, &s, &v)
        return v
    }

    static func scegli(_ id: AudioObjectID) {
        var a = indirizzo(kAudioHardwarePropertyDefaultOutputDevice)
        var v = id
        AudioObjectSetPropertyData(sistema, &a, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &v)
    }
}
