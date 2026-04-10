// AudiologistReportService.swift
// LangCI — Generates a printable PDF summary a user can hand to their
// audiologist at a mapping appointment.
//
// The report covers:
//   • Header (name, activation date, report date)
//   • Overall stats (level, points, streak, sessions, accuracy)
//   • Top 10 most-confused word pairs (last 30 days + all-time)
//   • Current CI settings (program, noise profile, SNR, voice prefs)
//   • Recent sessions list with mode + score
//
// Output: a single PDF file in the app's Documents directory, ready to
// be shared via UIActivityViewController or AirDrop. UIGraphicsPDFRenderer
// is used because it ships with UIKit — no external dependencies.

import Foundation
import UIKit

final class AudiologistReportService {

    // MARK: - Singleton

    static let shared = AudiologistReportService()
    private init() {}

    // MARK: - Layout constants (US Letter in points)

    private let pageWidth: CGFloat  = 612
    private let pageHeight: CGFloat = 792
    private let margin: CGFloat     = 48
    private var contentWidth: CGFloat { pageWidth - margin * 2 }

    // MARK: - Public API

    /// Build the PDF from live data and return the file URL. The file is
    /// written to the app's Documents directory with a timestamped name so
    /// earlier reports aren't overwritten.
    func generateReport() async throws -> URL {
        let data = try await gatherReportData()
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )
        let pdfData = renderer.pdfData { context in
            var cursorY: CGFloat = margin
            context.beginPage()

            cursorY = drawHeader(data: data, startY: cursorY)
            cursorY += 16
            cursorY = drawSummaryCard(data: data, startY: cursorY)
            cursorY += 16
            cursorY = drawCISettingsCard(data: data, startY: cursorY)
            cursorY += 16

            // Top confusions — may overflow; start a new page if needed
            cursorY = ensureRoom(
                context: context, cursorY: cursorY, need: 140
            )
            cursorY = drawConfusionsSection(
                title: "Top confusions — last 30 days",
                stats: data.topConfusionsLast30,
                startY: cursorY, context: context
            )
            cursorY += 12
            cursorY = ensureRoom(
                context: context, cursorY: cursorY, need: 140
            )
            cursorY = drawConfusionsSection(
                title: "Top confusions — all time",
                stats: data.topConfusionsAllTime,
                startY: cursorY, context: context
            )
            cursorY += 16

            // Recent sessions
            cursorY = ensureRoom(
                context: context, cursorY: cursorY, need: 120
            )
            cursorY = drawRecentSessionsSection(
                sessions: data.recentSessions,
                startY: cursorY, context: context
            )

            drawFooter()
        }

        let fileURL = try writeToDocuments(pdfData)
        return fileURL
    }

    // MARK: - Data gathering

    private struct ReportData {
        var reportDate: Date
        var stats: HomeStats
        var topConfusionsLast30: [ConfusionStatDto]
        var topConfusionsAllTime: [ConfusionStatDto]
        var recentSessions: [TrainingSession]
        var processorProgram: String
        var noiseProfile: String
        var noiseLevel: String
        var voicePreference: String
    }

    private func gatherReportData() async throws -> ReportData {
        let loc = ServiceLocator.shared

        async let stats   = loc.progressService.getHomeStats()
        async let top30   = loc.confusionPairService.getTopConfusions(limit: 10, days: 30)
        async let topAll  = loc.confusionPairService.getTopConfusions(limit: 10, days: nil)
        async let recent  = loc.trainingService.getRecentSessions(count: 10)

        let processor: String = {
            let raw = UserDefaults.standard.string(forKey: "processorProgram") ?? "everyday"
            return raw.capitalized
        }()

        return ReportData(
            reportDate:           Date(),
            stats:                try await stats,
            topConfusionsLast30:  (try? await top30) ?? [],
            topConfusionsAllTime: (try? await topAll) ?? [],
            recentSessions:       (try? await recent) ?? [],
            processorProgram:     processor,
            noiseProfile:         AVTAudioPlayer.noiseProfile.displayName,
            noiseLevel:           AVTAudioPlayer.noiseLevel.displayName,
            voicePreference:      AVTAudioPlayer.voicePreference.displayName
        )
    }

    // MARK: - Drawing helpers

    private func drawHeader(data: ReportData, startY: CGFloat) -> CGFloat {
        var y = startY

        let title = "LangCI — Practice Report"
        draw(text: title,
             at: CGPoint(x: margin, y: y),
             font: .systemFont(ofSize: 24, weight: .bold))
        y += 32

        let fmt = DateFormatter()
        fmt.dateStyle = .long
        let dateLine = "Generated \(fmt.string(from: data.reportDate))"
        draw(text: dateLine,
             at: CGPoint(x: margin, y: y),
             font: .systemFont(ofSize: 11, weight: .regular),
             color: .darkGray)
        y += 16

        // Horizontal separator
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: y))
        line.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        UIColor(white: 0.85, alpha: 1).setStroke()
        line.lineWidth = 0.5
        line.stroke()

        return y + 4
    }

    private func drawSummaryCard(data: ReportData, startY: CGFloat) -> CGFloat {
        var y = startY
        draw(text: "At a glance",
             at: CGPoint(x: margin, y: y),
             font: .systemFont(ofSize: 14, weight: .semibold))
        y += 22

        let stats = data.stats
        let accuracy = stats.totalAttempts > 0
            ? Int(Double(stats.totalCorrect) / Double(stats.totalAttempts) * 100)
            : 0

        let rows: [(String, String)] = [
            ("Level",           "\(stats.currentLevel)"),
            ("Total points",    "\(stats.totalPoints)"),
            ("Current streak",  "\(stats.currentStreak) days"),
            ("Longest streak",  "\(stats.longestStreak) days"),
            ("Sessions",        "\(stats.totalSessions)"),
            ("Accuracy",        "\(accuracy)%"),
            ("Badges earned",   "\(stats.badgesEarned)"),
        ]

        y = drawKeyValueGrid(rows: rows, startY: y, columns: 2)
        return y
    }

    private func drawCISettingsCard(data: ReportData, startY: CGFloat) -> CGFloat {
        var y = startY
        draw(text: "CI settings",
             at: CGPoint(x: margin, y: y),
             font: .systemFont(ofSize: 14, weight: .semibold))
        y += 22

        let rows: [(String, String)] = [
            ("Processor program", data.processorProgram),
            ("Voice preference",  data.voicePreference),
            ("Background noise",  data.noiseProfile),
            ("Noise level (SNR)", data.noiseLevel),
        ]
        return drawKeyValueGrid(rows: rows, startY: y, columns: 2)
    }

    private func drawConfusionsSection(
        title: String,
        stats: [ConfusionStatDto],
        startY: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var y = startY
        draw(text: title,
             at: CGPoint(x: margin, y: y),
             font: .systemFont(ofSize: 14, weight: .semibold))
        y += 22

        if stats.isEmpty {
            draw(text: "No confusion data yet.",
                 at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 11, weight: .regular),
                 color: .darkGray)
            return y + 16
        }

        // Table header
        draw(text: "Said → Heard",
             at: CGPoint(x: margin, y: y),
             font: .systemFont(ofSize: 10, weight: .semibold),
             color: .darkGray)
        draw(text: "Count",
             at: CGPoint(x: margin + contentWidth - 120, y: y),
             font: .systemFont(ofSize: 10, weight: .semibold),
             color: .darkGray)
        draw(text: "Last seen",
             at: CGPoint(x: margin + contentWidth - 70, y: y),
             font: .systemFont(ofSize: 10, weight: .semibold),
             color: .darkGray)
        y += 16

        let fmt = DateFormatter()
        fmt.dateStyle = .short
        for stat in stats {
            if y > pageHeight - margin - 20 {
                drawFooter()
                context.beginPage()
                y = margin
            }
            draw(text: "\(stat.saidWord) → \(stat.heardWord)",
                 at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 11, weight: .regular))
            draw(text: "\(stat.count)",
                 at: CGPoint(x: margin + contentWidth - 120, y: y),
                 font: .systemFont(ofSize: 11, weight: .regular))
            draw(text: fmt.string(from: stat.mostRecent),
                 at: CGPoint(x: margin + contentWidth - 70, y: y),
                 font: .systemFont(ofSize: 11, weight: .regular))
            y += 16
        }
        return y
    }

    private func drawRecentSessionsSection(
        sessions: [TrainingSession],
        startY: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var y = startY
        draw(text: "Recent sessions",
             at: CGPoint(x: margin, y: y),
             font: .systemFont(ofSize: 14, weight: .semibold))
        y += 22

        if sessions.isEmpty {
            draw(text: "No sessions yet.",
                 at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 11, weight: .regular),
                 color: .darkGray)
            return y + 16
        }

        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short

        for session in sessions {
            if y > pageHeight - margin - 20 {
                drawFooter()
                context.beginPage()
                y = margin
            }
            let mode = String(describing: session.trainingMode).capitalized
            let progress = "\(session.completedWords)/\(session.totalWords)"
            let line = "\(fmt.string(from: session.startedAt))  —  \(mode)  —  \(progress)"
            draw(text: line,
                 at: CGPoint(x: margin, y: y),
                 font: .systemFont(ofSize: 11, weight: .regular))
            y += 16
        }
        return y
    }

    private func drawKeyValueGrid(
        rows: [(String, String)],
        startY: CGFloat,
        columns: Int
    ) -> CGFloat {
        let colW = contentWidth / CGFloat(columns)
        let rowH: CGFloat = 22
        var y = startY
        for (idx, row) in rows.enumerated() {
            let col = idx % columns
            let x = margin + CGFloat(col) * colW
            draw(text: row.0,
                 at: CGPoint(x: x, y: y),
                 font: .systemFont(ofSize: 10, weight: .regular),
                 color: .darkGray)
            draw(text: row.1,
                 at: CGPoint(x: x, y: y + 11),
                 font: .systemFont(ofSize: 13, weight: .semibold))
            if col == columns - 1 || idx == rows.count - 1 {
                y += rowH + 8
            }
        }
        return y
    }

    private func drawFooter() {
        let footer = "LangCI practice report — share with your audiologist"
        draw(text: footer,
             at: CGPoint(x: margin, y: pageHeight - margin + 12),
             font: .systemFont(ofSize: 9, weight: .regular),
             color: .gray)
    }

    private func ensureRoom(
        context: UIGraphicsPDFRendererContext,
        cursorY: CGFloat,
        need: CGFloat
    ) -> CGFloat {
        if cursorY + need > pageHeight - margin {
            drawFooter()
            context.beginPage()
            return margin
        }
        return cursorY
    }

    private func draw(
        text: String,
        at point: CGPoint,
        font: UIFont,
        color: UIColor = .black
    ) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    // MARK: - Persistence

    private func writeToDocuments(_ data: Data) throws -> URL {
        let fm = FileManager.default
        let docs = try fm.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let stamp: String = {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd-HHmm"
            return fmt.string(from: Date())
        }()
        let url = docs.appendingPathComponent("LangCI-Report-\(stamp).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }
}
