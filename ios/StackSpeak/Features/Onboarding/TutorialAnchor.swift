import SwiftUI

/// Identifiers for the two tutorial spotlight anchors per §1 of
/// `ui-ux-tutorial-design-2026-05-01.md`.
///
/// - `simpleAdvance` — S1 anchor on the `simple` stage. Cutout includes the
///   SwipeNudge component + card body so either tap-Next or left-swipe
///   resolves S1.
/// - `explainComposite` — S2 single static cutout encompassing TextEditor +
///   mic button + Submit ("Lock it in"). No within-S2 reposition.
enum TutorialTargetID: Hashable {
    case simpleAdvance
    case explainComposite
}

/// Preference key for hoisting target rects from `FeynmanCardView` up to
/// the screen-level overlay.
///
/// Multiple anchors can publish under the same `TutorialTargetID` — the
/// host (`WordFeynmanScreen`) unions their resolved rects into a single
/// bounding rect for the lens. This lets §1's compound `explainComposite`
/// cutout (TextEditor + mic + Submit) be three independent
/// `.tutorialTarget(.explainComposite)` call sites without restructuring
/// `FeynmanCardView`'s view tree.
struct TutorialAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [TutorialTargetID: [Anchor<CGRect>]] { [:] }

    static func reduce(
        value: inout [TutorialTargetID: [Anchor<CGRect>]],
        nextValue: () -> [TutorialTargetID: [Anchor<CGRect>]]
    ) {
        value.merge(nextValue(), uniquingKeysWith: +)
    }
}

extension View {
    /// Marks this view as a tutorial spotlight anchor. The view's `.bounds`
    /// anchor is published via `TutorialAnchorPreferenceKey` and combined
    /// with any other anchors using the same `id` (the host unions them).
    ///
    /// Usage in `FeynmanCardView` (Task #7):
    /// ```
    /// TextEditor(text: $explanation).tutorialTarget(.explainComposite)
    /// micButton(...).tutorialTarget(.explainComposite)
    /// PrimaryCTAButton(...).tutorialTarget(.explainComposite)
    /// ```
    func tutorialTarget(_ id: TutorialTargetID) -> some View {
        anchorPreference(
            key: TutorialAnchorPreferenceKey.self,
            value: .bounds
        ) { anchor in
            [id: [anchor]]
        }
    }
}
