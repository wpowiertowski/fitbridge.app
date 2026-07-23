// TickScale.swift
//
// WP-33 (implementation-plan.md) / architecture.md D12: the Braun-style
// tick-scale instrument from the Yacht club mockup
// (`Design/HealthLoomTodayView-YachtClub.swift`), ported verbatim in its
// geometry (28 ticks, 3 pt gaps, 13 pt ticks with a 24 pt / 2 pt-wide
// cursor; rust fill below the cursor, palette gray above) with the two
// production requirements the mockup lacks:
//   - **VoiceOver** (test-plan.md §6: "tick scale announces 'Readiness 82
//     of 100'"): the whole scale is one accessibility element whose
//     label/value the *caller* supplies -- the scale itself is a generic
//     0...1 instrument and shouldn't hardcode "Readiness".
//   - **Value clamping**: renders sensibly at exactly 0, 0.5 and 1.0
//     (test-plan.md §4's explicit render points) and clamps out-of-range
//     input rather than crashing the ForEach index math.

import SwiftUI

struct TickScale: View {
    /// 0...1 (clamped). `nil` renders the empty/pending instrument -- all
    /// ticks palette-gray, no cursor (the hero's insufficient-signals /
    /// pre-readiness state, WP-33 step 4).
    var value: Double?
    var count: Int = 28
    /// VoiceOver label for the whole instrument, e.g. "Readiness".
    var accessibilityLabel: String
    /// VoiceOver value, e.g. "82 of 100" -- supplied by the caller so it
    /// can match the on-screen number exactly.
    var accessibilityValue: String

    var body: some View {
        let cursor: Int? = value.map { unclamped in
            let clamped = min(max(unclamped, 0), 1)
            return Int((Double(count - 1) * clamped).rounded())
        }
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<count, id: \.self) { i in
                Rectangle()
                    .fill(tickColor(index: i, cursor: cursor))
                    .frame(
                        width: i == cursor ? 2 : 1.5,
                        height: i == cursor ? 24 : 13
                    )
            }
        }
        .frame(height: 24, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private func tickColor(index: Int, cursor: Int?) -> Color {
        guard let cursor else { return Theme.gray }
        if index == cursor { return Theme.ink }
        return index < cursor ? Theme.accent : Theme.gray
    }
}

#Preview {
    VStack(spacing: 24) {
        TickScale(value: 0, accessibilityLabel: "Readiness", accessibilityValue: "0 of 100")
        TickScale(value: 0.5, accessibilityLabel: "Readiness", accessibilityValue: "50 of 100")
        TickScale(value: 0.82, accessibilityLabel: "Readiness", accessibilityValue: "82 of 100")
        TickScale(value: 1, accessibilityLabel: "Readiness", accessibilityValue: "100 of 100")
        TickScale(value: nil, accessibilityLabel: "Readiness", accessibilityValue: "not yet available")
    }
    .padding()
    .background(Theme.canvas)
}
