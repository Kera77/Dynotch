@testable import Dynotch
import Testing

struct HUDTests {
    /// Spec A-3: 1/16 steps on a grid, 1/64 with Option-Shift, clamped to 0…1.
    @Test func stepping() {
        #expect(HUDLogic.stepped(0.5, increase: true, fine: false) == 0.5625)
        #expect(HUDLogic.stepped(0.5, increase: false, fine: false) == 0.4375)
        #expect(HUDLogic.stepped(0.51, increase: true, fine: false) == 0.5625)
        #expect(HUDLogic.stepped(0.5, increase: true, fine: true) == 0.515625)
        #expect(HUDLogic.stepped(1, increase: true, fine: false) == 1)
        #expect(HUDLogic.stepped(0.03, increase: false, fine: false) == 0)
    }

    @Test func volumeSymbols() {
        #expect(HUDLogic.volumeSymbol(level: 0.8, muted: true) == "speaker.slash.fill")
        #expect(HUDLogic.volumeSymbol(level: 0, muted: false) == "speaker.slash.fill")
        #expect(HUDLogic.volumeSymbol(level: 0.2, muted: false) == "speaker.wave.1.fill")
        #expect(HUDLogic.volumeSymbol(level: 0.5, muted: false) == "speaker.wave.2.fill")
        #expect(HUDLogic.volumeSymbol(level: 0.9, muted: false) == "speaker.wave.3.fill")
    }

    @Test func mediaKeyCodes() {
        #expect(MediaKey(rawValue: 0) == .soundUp)
        #expect(MediaKey(rawValue: 7) == .mute)
        #expect(MediaKey(rawValue: 3) == .brightnessDown)
        #expect(MediaKey(rawValue: 4) == nil)
        #expect(MediaKey.mute.isVolume)
        #expect(!MediaKey.brightnessUp.isVolume)
    }
}
