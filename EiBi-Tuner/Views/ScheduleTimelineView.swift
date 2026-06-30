//
//  ScheduleTimelineView.swift
//  EiBi-Tuner
//
//  The pop-up shown by the GUIDE button: a 24-hour "TV guide" of the channel
//  nearest the dial. Each station that shares the frequency gets a row with its
//  broadcast window(s) drawn along a UTC time axis. A scrubber sweeps a cursor
//  across the day so you can ask "what's on here at 18:00 UTC?" — stations on
//  the air at the cursor time light up.
//

import SwiftUI

struct ScheduleTimelineView: View {
    @Bindable var vm: RadioViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var scrubMinute: Double = ScheduleTimelineView.nowMinute()

    private let labelWidth: CGFloat = 124
    private let trackWidth: CGFloat = 392
    private let rowHeight: CGFloat = 18
    private let rowGap: CGFloat = 4
    private let maxRows = 16

    var body: some View {
        let channel = vm.channelStations()
        VStack(alignment: .leading, spacing: 12) {
            header(freq: channel.freq)
            if channel.stations.isEmpty {
                empty
            } else {
                let shown = Array(channel.stations.prefix(maxRows))
                axis
                timeline(shown)
                if channel.stations.count > maxRows {
                    Text("+\(channel.stations.count - maxRows) " + AppLanguage.t("weitere", "more"))
                        .font(.system(size: 9, design: .serif)).foregroundStyle(Theme.amberDim)
                }
                scrubber
            }
        }
        .padding(18)
        .frame(width: labelWidth + trackWidth + 8 + 36)
        .background(Theme.cabinet)
    }

    // MARK: Header

    private func header(freq: Double) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.day.timeline.left")
                .font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.amberBright)
            VStack(alignment: .leading, spacing: -1) {
                Text(AppLanguage.t("PROGRAMM", "SCHEDULE")).font(Theme.label(15)).tracking(2)
                    .foregroundStyle(Theme.ivory)
                Text("\(freqText(freq)) kHz · UTC").font(Theme.label(9)).tracking(1)
                    .foregroundStyle(Theme.amberDim)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 16))
                    .foregroundStyle(Theme.ivory.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Hour axis

    private var axis: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: labelWidth)
            ZStack(alignment: .leading) {
                ForEach([0, 6, 12, 18, 24], id: \.self) { h in
                    Text(String(format: "%02d", h))
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.amberDim)
                        .offset(x: xFor(hour: h, labelW: 16))
                }
            }
            .frame(width: trackWidth, height: 9, alignment: .leading)
        }
    }

    /// Positions an axis label centred on its hour tick, clamped at the edges.
    private func xFor(hour h: Int, labelW: CGFloat) -> CGFloat {
        let x = CGFloat(h) / 24 * trackWidth
        return min(max(x - labelW / 2, 0), trackWidth - labelW)
    }

    // MARK: Timeline

    private func timeline(_ stations: [Station]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: rowGap) {
                ForEach(stations) { st in
                    Text(st.station.isEmpty ? "—" : st.station)
                        .font(.system(size: 10, design: .serif)).lineLimit(1)
                        .foregroundStyle(active(st) ? Theme.amberBright : Theme.ivory.opacity(0.7))
                        .frame(height: rowHeight, alignment: .leading)
                }
            }
            .frame(width: labelWidth, alignment: .leading)

            ZStack(alignment: .topLeading) {
                gridlines
                VStack(spacing: rowGap) {
                    ForEach(stations) { st in trackRow(st) }
                }
                Rectangle().fill(Theme.pointer).frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .offset(x: CGFloat(scrubMinute) / 1440 * trackWidth - 1)
                    .shadow(color: Theme.pointer.opacity(0.8), radius: 3)
                    .allowsHitTesting(false)
            }
            .frame(width: trackWidth)
        }
    }

    private var gridlines: some View {
        ForEach([0, 6, 12, 18, 24], id: \.self) { h in
            Rectangle().fill(Theme.brassDark.opacity(0.6))
                .frame(width: (h == 0 || h == 24) ? 1 : 0.5)
                .frame(maxHeight: .infinity)
                .offset(x: CGFloat(h) / 24 * trackWidth)
        }
    }

    private func trackRow(_ st: Station) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.3))
            ForEach(Array(segments(st).enumerated()), id: \.offset) { _, seg in
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(
                        colors: active(st) ? [Theme.amberBright, Theme.amber]
                                           : [Theme.amber.opacity(0.7), Theme.amberDeep.opacity(0.8)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: max(2, seg.width * trackWidth))
                    .offset(x: seg.x * trackWidth)
                    .shadow(color: active(st) ? Theme.amber.opacity(0.7) : .clear, radius: 4)
            }
        }
        .frame(height: rowHeight)
    }

    // MARK: Scrubber

    private var scrubber: some View {
        HStack(spacing: 12) {
            Text("UTC \(timeString(Int(scrubMinute)))")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.amberBright)
                .frame(width: 92, alignment: .leading)
            Slider(value: $scrubMinute, in: 0...1439).tint(Theme.amberDeep)
            Button { scrubMinute = Self.nowMinute() } label: {
                Text(AppLanguage.t("Jetzt", "Now")).font(Theme.label(10)).tracking(1)
                    .foregroundStyle(Theme.amber)
            }
            .buttonStyle(.plain)
        }
    }

    private var empty: some View {
        Text(AppLanguage.t("Keine Stationen auf diesem Kanal.", "No stations on this channel."))
            .font(.system(size: 12, design: .serif)).foregroundStyle(Theme.amberDim)
            .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 28)
    }

    // MARK: Helpers

    /// Window fraction segments (x, width) across the day, splitting overnight.
    private func segments(_ st: Station) -> [(x: Double, width: Double)] {
        guard let r = st.minuteRange else { return [(0, 1)] }
        let s = Double(r.start) / 1440, e = Double(r.end) / 1440
        if r.end <= r.start && !(r.start == 0 && r.end == 1440) {
            return [(s, 1 - s), (0, e)]   // runs past midnight
        }
        return [(s, e - s)]
    }

    private func active(_ st: Station) -> Bool {
        Station.isTimeValid(st.time, hour: Int(scrubMinute) / 60, minute: Int(scrubMinute) % 60)
    }

    private static func nowMinute() -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.hour, .minute], from: Date())
        return Double((c.hour ?? 0) * 60 + (c.minute ?? 0))
    }
    private func timeString(_ m: Int) -> String { String(format: "%02d:%02d", m / 60, m % 60) }
    private func freqText(_ f: Double) -> String {
        f.formatted(.number.precision(.fractionLength(2)).grouping(.automatic))
    }
}
