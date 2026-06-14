import SwiftUI

extension ContentBlockView {
    /// Pure helper — extracts the `href` for the first link mark in a list of runs,
    /// if any. Used by tests + accessibility surfacing.
    static func firstLinkHref(in runs: [InlineRun]) -> String? {
        for run in runs {
            if let marks = run.marks, marks.contains(.link), let href = run.href {
                return href
            }
        }
        return nil
    }

    /// Pure helper — resolves an image asset path against `bookId`'s images dir.
    /// Used by tests; production rendering uses bundle lookup.
    static func resolveImagePath(asset: String, bookId: String) -> String {
        "books/\(bookId)/images/\(asset)"
    }
}
