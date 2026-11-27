import Foundation
import Testing
@testable import Wingmate

/// The music module and its cover beside the notch.
@MainActor
struct MusicTests {
    private let fields = [
        "playing", "Song", "Artist", "Album", "https://i.scdn.co/image/abc", "215000", "61.5", "true", "false", "64",
        "spotify:track:1"
    ]

    @Test func spotifysAnswerIsRead() throws {
        let playing = try #require(NowPlaying.parse(fields))
        #expect(playing.isPlaying)
        #expect(playing.title == "Song")
        #expect(playing.duration == 215)
        #expect(playing.position == 61.5)
        #expect(playing.isShuffling && !playing.isRepeating)
        #expect(playing.volume == 64)
        #expect(playing.artworkURL?.host == "i.scdn.co")
    }

    @Test func stoppedOrBrokenAnswersGiveNothing() {
        #expect(NowPlaying.parse(["stopped"]) == nil)
        var paused = fields
        paused[0] = "paused"
        paused[4] = "http://example.com/x.jpg"
        let parsed = NowPlaying.parse(paused)
        #expect(parsed?.isPlaying == false)
        // Only secure cover addresses are loaded.
        #expect(parsed?.artworkURL == nil)
    }

    @Test func theCoversColourIsItsMostCommonLivelyHue() {
        // 3 red pixels, 1 grey, 1 blue: red wins, made bright enough for the black notch.
        let pixels: [UInt8] = [200, 20, 20, 255, 200, 20, 20, 255, 190, 30, 30, 255, 128, 128, 128, 255, 20, 20, 200, 255]
        let color = ArtworkColor.dominant(rgba: pixels)
        #expect(color.red > 0.7 && color.green < 0.3 && color.blue < 0.3)
        // A grey cover gives the soft white.
        #expect(ArtworkColor.dominant(rgba: [120, 120, 120, 255, 30, 30, 30, 255]) == ArtworkColor.fallback)
    }

    @Test func aPausedCoverHidesAfterTheChosenTime() {
        let now = Date(timeIntervalSince1970: 1000)
        let paused = now.addingTimeInterval(-120)
        #expect(!MusicService.hidesCover(isPlaying: true, pausedSince: nil, after: 0, byHand: true, now: now))
        #expect(MusicService.hidesCover(isPlaying: false, pausedSince: paused, after: 1, byHand: false, now: now))
        #expect(!MusicService.hidesCover(isPlaying: false, pausedSince: paused, after: 5, byHand: false, now: now))
        #expect(!MusicService.hidesCover(isPlaying: false, pausedSince: paused, after: nil, byHand: false, now: now))
        #expect(MusicService.hidesCover(isPlaying: false, pausedSince: paused, after: nil, byHand: true, now: now))
    }

    @Test func aLongTrackNameRunsThroughThenCloses() {
        #expect(MusicMarquee.duration(overflow: 0) == 4)
        // One second before, 80 points at 40 per second, one second after (spec MU-4b).
        #expect(MusicMarquee.duration(overflow: 80) == 4)
        #expect(MusicMarquee.duration(overflow: 200) == 7)
    }

    @Test func theProgressBarMapsClicksToSeconds() {
        #expect(MusicProgressBar.seconds(at: 50, width: 200, duration: 240) == 60)
        #expect(MusicProgressBar.seconds(at: -10, width: 200, duration: 240) == 0)
        #expect(MusicProgressBar.seconds(at: 500, width: 200, duration: 240) == 240)
        #expect(MusicProgressBar.time(125.9) == "2:05")
    }

    @Test @MainActor func theCoverSitsLeftOfTheNotchAndStatsOpenTheirModule() {
        let glance = MusicIndicator.Glance(
            trackID: "1", title: "Song", artist: "A", isPlaying: true, artwork: nil, tint: ArtworkColor.fallback
        )
        let items = IndicatorItem.items(
            meetings: [], usage: nil, tasks: TaskCount(count: 2, isToday: true), music: glance, stats: 2
        )
        #expect(items.map(\.id) == ["music", "stats", "tasks"])
        // The cover is on the left, next to the notch, and drops its player down (spec MU-2).
        #expect(items[0].opensModule == nil)
        #expect(items[0].slotWidth == 0)
        #expect(IndicatorItem.iconSlots(for: items).first == 0)
        let layout = IndicatorLayout(items: items)
        #expect(layout.rightWidth == IndicatorLayout.statsWidth(values: 2) + IndicatorLayout.tasksSlotWidth
            + IndicatorLayout.spacing + 2 * IndicatorLayout.padding)
        #expect(items[1].opensModule == .stats)
        #expect(items[2].opensModule == nil)
    }
}
