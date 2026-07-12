//
//  HealthLoomTodayView.swift
//  HealthLoom — "Today" view (FINAL — Yacht club palette)
//
//  Palette source: Figma "Yacht club" — #F2F0EF / #BBBDBC / #245F73 / #733E24
//  Mapping: deep teal (#245F73) serves as ink — primary text and headings —
//  rather than a neutral gray, which reads sophisticated and still clears
//  ~6.3:1 contrast against the canvas. Rust (#733E24) is the single
//  functional accent: live sync dot, readiness scale fill, steps progress
//  bar, priority marker, and the coach action — nautical brass-on-navy.
//  Design language: Dieter Rams / Braun restraint — one instrument panel,
//  hairline rules, no decorative shape-coding, Helvetica throughout.
//

import SwiftUI

// MARK: - Yacht club tokens

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8)  & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255)
    }
}

enum Theme {
    // canvas / surface
    static let canvas    = Color(hex: 0xF2F0EF)
    static let surface   = Color.white

    // ink (deep teal — doubles as primary text color)
    static let ink       = Color(hex: 0x245F73)
    static let secondary = Color(hex: 0x5C7C87)   // muted teal-gray — secondary text
    static let tertiary  = Color(hex: 0x96AEB5)   // light teal-gray — placeholders

    // structure
    static let border    = Color(hex: 0xE3E0DC)   // soft warm hairline
    static let gray      = Color(hex: 0xBBBDBC)   // exact palette value — dividers/disabled

    // accent (rust — the one functional color)
    static let accent      = Color(hex: 0x733E24)
    static let accentTint   = Color(hex: 0xEDE1DA) // coach panel background
    static let accentDeep   = Color(hex: 0x5A2F1B) // icons/labels on tint
}

extension Font {
    static func helv(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Helvetica Neue", size: size).weight(weight)
    }
}

// MARK: - Braun tick scale

private struct TickScale: View {
    var value: Double          // 0...1
    var count: Int = 28
    var body: some View {
        let cursor = Int((Double(count - 1) * value).rounded())
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<count, id: \.self) { i in
                Rectangle()
                    .fill(i == cursor ? Theme.ink : (i < cursor ? Theme.accent : Theme.gray))
                    .frame(width: i == cursor ? 2 : 1.5,
                           height: i == cursor ? 24 : 13)
            }
        }
        .frame(height: 24, alignment: .bottom)
    }
}

// MARK: - Model

struct Metric: Identifiable {
    let id = UUID()
    let name: String
    let sub: String
    let value: String
    let unit: String?
    var progress: Double? = nil
    var priority: Bool = false
}

extension Metric {
    static let sample: [Metric] = [
        .init(name: "Heart", sub: "Resting · steady", value: "62", unit: "bpm", priority: true),
        .init(name: "Steps", sub: "68% of 12,000 goal", value: "8,240", unit: nil, progress: 0.68),
        .init(name: "Sleep", sub: "Score 89 · deep 1h 24", value: "7h 12m", unit: nil),
        .init(name: "Blood oxygen", sub: "Average overnight", value: "97", unit: "%")
    ]
}

// MARK: - Components

private struct Header: View {
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Rectangle().fill(Theme.accent).frame(width: 6, height: 6)
                Text("healthloom").font(.helv(16, .medium)).foregroundStyle(Theme.ink)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(Theme.accent).frame(width: 6, height: 6)
                Text("Fitbit Air · synced 9m ago")
                    .font(.helv(11.5)).foregroundStyle(Theme.secondary)
            }
        }
    }
}

private struct HeroInstrument: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Readiness").font(.helv(11, .medium)).tracking(0.4)
                .foregroundStyle(Theme.secondary)
            HStack(alignment: .bottom, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("82").font(.helv(60, .light)).foregroundStyle(Theme.ink)
                        .monospacedDigit()
                    Text("/100").font(.helv(18)).foregroundStyle(Theme.tertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    TickScale(value: 0.82)
                    (Text("+6").font(.helv(12, .semibold)).foregroundStyle(Theme.ink)
                     + Text(" vs 30-day average").font(.helv(12)).foregroundStyle(Theme.secondary))
                }
            }
        }
    }
}

private struct MetricRow: View {
    let metric: Metric
    let editing: Bool
    var body: some View {
        ZStack(alignment: .leading) {
            if metric.priority {
                Rectangle().fill(Theme.accent).frame(width: 2).frame(maxHeight: .infinity)
            }
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.name).font(.helv(14, .medium)).foregroundStyle(Theme.ink)
                    Text(metric.sub).font(.helv(11)).foregroundStyle(Theme.tertiary)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(metric.value).font(.helv(21)).foregroundStyle(Theme.ink)
                        .monospacedDigit().opacity(editing ? 0.35 : 1)
                    if let u = metric.unit {
                        Text(u).font(.helv(12)).foregroundStyle(Theme.tertiary)
                            .opacity(editing ? 0.35 : 1)
                    }
                }
                if editing {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 15)).foregroundStyle(Theme.tertiary)
                        .padding(.leading, 12)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .overlay(alignment: .bottom) {
            if let p = metric.progress {
                GeometryReader { g in
                    Rectangle().fill(Theme.accent)
                        .frame(width: g.size.width * p, height: 2)
                }.frame(height: 2)
            }
        }
    }
}

private struct InstrumentPanel: View {
    let metrics: [Metric]
    let editing: Bool
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { idx, m in
                if idx > 0 { Rectangle().fill(Theme.border).frame(height: 1) }
                MetricRow(metric: m, editing: editing)
            }
        }
        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(editing ? Theme.accent : Theme.border))
    }
}

private struct CoachPanel: View {
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("COACH").font(.helv(11, .semibold)).tracking(0.6)
                    .foregroundStyle(Theme.accentDeep)
                Text("Resting heart rate is down 4 bpm this week — recovery is trending up. Want an easy aerobic day?")
                    .font(.helv(13.5)).foregroundStyle(Theme.ink).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.right").font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.accentDeep)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.accentTint))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.border))
    }
}

private struct TabBar: View {
    @Binding var selection: Int
    private let items = ["today", "coach", "you", "settings"]
    private let icons = ["square.split.1x2", "smallcircle.filled.circle", "person", "slider.horizontal.3"]
    var body: some View {
        HStack {
            ForEach(items.indices, id: \.self) { i in
                Button { selection = i } label: {
                    VStack(spacing: 7) {
                        Image(systemName: icons[i]).font(.system(size: 18, weight: .light))
                        Text(items[i].capitalized).font(.helv(10, .medium))
                    }
                    .foregroundStyle(selection == i ? Theme.ink : Theme.tertiary)
                    .frame(maxWidth: .infinity)
                }.buttonStyle(.plain)
            }
        }
        .padding(.top, 14).padding(.bottom, 28)
        .background(Theme.surface.overlay(Rectangle().fill(Theme.gray).frame(height: 1), alignment: .top))
    }
}

// MARK: - Main

struct HealthLoomTodayView: View {
    @State private var editing = false
    @State private var tab = 0
    private let metrics = Metric.sample

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Header().padding(.top, 12).padding(.bottom, 16)

                    Text("Good morning, Sam").font(.helv(19, .medium)).foregroundStyle(Theme.ink)
                    Text("Tuesday 27 June").font(.helv(12)).foregroundStyle(Theme.tertiary)
                        .padding(.top, 3)

                    Rectangle().fill(Theme.gray).frame(height: 1).padding(.top, 16)

                    HeroInstrument().padding(.top, 20)

                    Rectangle().fill(Theme.border).frame(height: 1).padding(.top, 22)

                    HStack(alignment: .firstTextBaseline) {
                        Text("TODAY").font(.helv(11, .medium)).tracking(0.8)
                            .foregroundStyle(Theme.secondary)
                        Spacer()
                        Button { editing.toggle() } label: {
                            Text(editing ? "Done" : "Edit").font(.helv(12))
                                .foregroundStyle(editing ? Theme.accent : Theme.accentDeep)
                                .overlay(Rectangle().fill(editing ? Theme.accent : .clear)
                                    .frame(height: 1), alignment: .bottom)
                        }.buttonStyle(.plain)
                    }
                    .padding(.top, 22).padding(.bottom, 12)

                    InstrumentPanel(metrics: metrics, editing: editing)

                    CoachPanel().padding(.top, 14)
                }
                .padding(.horizontal, 22).padding(.bottom, 24)
            }
            TabBar(selection: $tab)
        }
        .background(Theme.canvas.ignoresSafeArea())
    }
}

#Preview {
    HealthLoomTodayView()
}
