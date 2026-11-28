import Foundation

extension WhatsNew {
    /// The test builds after 1.10.0, newest first; merged into one entry at the next public release (spec WN-4).
    static let testBuilds110: [WhatsNewRelease] = [
        WhatsNewRelease(version: "1.10.8", items: [
            WhatsNewItem(symbol: "rectangle.3.group", title: "Spencer layouts for these displays",
                         text: "Only the layouts made for the displays connected now can be chosen; the others are greyed out.")
        ]),
        WhatsNewRelease(version: "1.10.7", items: [
            WhatsNewItem(symbol: "hand.point.up.left", title: "Hover beside the notch again",
                         text: "Tasks, badges and the AI ring open on hover; only new notifications wait for a swipe down."),
            WhatsNewItem(symbol: "hand.draw", title: "Flick pop-ups away",
                         text: "Swipe up on a small notification, Beeper message or screenshot under the notch to put it away."),
            WhatsNewItem(symbol: "square.grid.2x2", title: "A scrolling module row",
                         text: "Swipe over the module icons to scroll them, like the buttons on the right; click to switch."),
            WhatsNewItem(symbol: "moon.fill", title: "Focus as on the Mac",
                         text: "The Focus that is on shows its icon in colour, and the highlight keeps up with a quick pointer."),
            WhatsNewItem(symbol: "trash.fill", title: "Empty Trash works",
                         text: "Empty Trash in the quick toggles really empties the Trash now."),
            WhatsNewItem(symbol: "rectangle.3.group", title: "Spencer layouts",
                         text: "Layouts you can restore are no longer greyed out, the current one included.")
        ]),
        WhatsNewRelease(version: "1.10.6", items: [
            WhatsNewItem(symbol: "moon.fill", title: "A smoother Focus list",
                         text: "Rows light up as soon as you point at them, and a Focus's lengths slide down and back up.")
        ]),
        WhatsNewRelease(version: "1.10.5", items: [
            WhatsNewItem(symbol: "moon.fill", title: "A calmer Focus list",
                         text: "The Focus list highlights at once with a faint grey, and the arrows stay arrows.")
        ]),
        WhatsNewRelease(version: "1.10.4", items: [
            WhatsNewItem(symbol: "moon.fill", title: "Focus that switches",
                         text: "Pick a Focus and its lengths open right under it; close the list and it stays on until you turn it off."),
            WhatsNewItem(symbol: "arrow.left.arrow.right", title: "Move the Focus button",
                         text: "The Focus button moves like the other buttons beside the notch (⌘-drag or in the settings)."),
            WhatsNewItem(symbol: "cursorarrow.rays", title: "Pop-ups wait for you",
                         text: "A notification stays while the pointer is on it and goes 3 seconds after you move away."),
            WhatsNewItem(symbol: "text.below.photo", title: "What Claude finished",
                         text: "Swipe down on Claude finished to see the task it did and the start of its answer.")
        ]),
        WhatsNewRelease(version: "1.10.3", items: [
            WhatsNewItem(symbol: "moon.fill", title: "Focus, quietly",
                         text: "Control Center no longer flashes open; click the Focus icon beside the notch to turn it off.")
        ]),
        WhatsNewRelease(version: "1.10.2", items: [
            WhatsNewItem(symbol: "moon.fill", title: "Focus without Shortcuts",
                         text: "Your Mac's own Focuses with their icons; pick one, then how long, and Control Center does the rest."),
            WhatsNewItem(symbol: "hand.draw", title: "Notifications on a swipe",
                         text: "With swipe drop-downs on, new notifications and screenshots open with a swipe down, not on hover.")
        ]),
        WhatsNewRelease(version: "1.10.1", items: [
            WhatsNewItem(symbol: "moon.fill", title: "Focus in the top row",
                         text: "Pick a Focus for an hour, two or until morning; its icon waits beside the notch with Turn off."),
            WhatsNewItem(symbol: "hand.draw", title: "Drop-downs on a swipe",
                         text: "Optional: tasks and badges open with a swipe down instead of on hover (Settings › General)."),
            WhatsNewItem(symbol: "rectangle.and.hand.point.up.left", title: "Trackpad edge sliders",
                         text: "Slide along the edges for volume, brightness and keyboard light, in macOS or 1% steps."),
            WhatsNewItem(symbol: "arrow.left.and.right", title: "More buttons fit",
                         text: "When the buttons right of the notch don't fit, swipe them; Focus and Settings stay put.")
        ])
    ]
}
