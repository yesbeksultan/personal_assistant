import Foundation
import UIKit
import Combine

// MARK: - Clipboard Monitor Service

/// Monitors UIPasteboard for bank notification / SMS text.
/// Uses detectPatterns(for:completionHandler:) (iOS 16+) to check
/// whether clipboard *looks* like it contains money amounts — without
/// triggering the system "app read your pasteboard" banner.
/// Only reads the actual string after the user explicitly taps
/// "Проверить буфер" or when the app moves to foreground.
@Observable
final class ClipboardMonitorService {

    static let shared = ClipboardMonitorService()

    // UserDefaults key
    static let enabledKey = "clipboardMonitor_enabled"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    /// Set to true when we detected a likely bank text in clipboard.
    private(set) var hasPendingClipboardText: Bool = false

    /// Last detected draft from clipboard (before user confirms)
    private(set) var clipboardDraft: ParsedTransactionDraft?

    private var lastChangeCount: Int = -1
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    private init() {
        setupAppLifecycleObservers()
    }

    deinit {
        if let obs = backgroundObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = foregroundObserver  { NotificationCenter.default.removeObserver(obs) }
    }

    // MARK: - Public API

    /// Call on FinanceView appear. Checks if pasteboard changeCount changed
    /// (no banner), and if so — detects patterns to see if it's worth reading.
    func checkClipboardIfNeeded() {
        guard isEnabled else { return }
        let current = UIPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        detectAndPreview()
    }

    /// Explicitly called when user taps "Проверить буфер" button.
    /// Actually reads the string — triggers the iOS 16 banner once.
    func readAndParseClipboard(bankHint: String = "") -> ParsedTransactionDraft? {
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return nil }
        lastChangeCount = UIPasteboard.general.changeCount
        let draft = BankNotificationParser.shared.tryParse(
            title: "",
            body: text,
            bundleID: bankHint.lowercased()
        )
        DispatchQueue.main.async {
            self.clipboardDraft = draft
            self.hasPendingClipboardText = (draft != nil)
        }
        return draft
    }

    /// Clear the pending state
    func clear() {
        hasPendingClipboardText = false
        clipboardDraft = nil
    }

    // MARK: - Private

    /// Uses detectPatterns (iOS 16+) — no banner shown to user.
    /// Falls back to changeCount-only check on older OS.
    private func detectAndPreview() {
        guard #available(iOS 16.0, *) else {
            // On iOS 15 we don't pre-scan — just show the button hint
            hasPendingClipboardText = true
            return
        }

        // Detect whether clipboard text matches our patterns without reading the value
        let patterns: Set<UIPasteboard.DetectionPattern> = [
            .number,          // contains numeric content
            .probableWebURL,  // sometimes bank links
        ]

        UIPasteboard.general.detectPatterns(for: patterns) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let found):
                // If clipboard has number-like content → worth a look
                if found.contains(.number) {
                    DispatchQueue.main.async {
                        self.hasPendingClipboardText = true
                    }
                } else {
                    DispatchQueue.main.async {
                        self.hasPendingClipboardText = false
                        self.clipboardDraft = nil
                    }
                }
            case .failure:
                DispatchQueue.main.async {
                    self.hasPendingClipboardText = false
                }
            }
        }
    }

    private func setupAppLifecycleObservers() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkClipboardIfNeeded()
        }
    }
}

