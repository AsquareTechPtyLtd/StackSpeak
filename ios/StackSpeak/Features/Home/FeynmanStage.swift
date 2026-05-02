import Foundation

/// Stages of the Feynman flow for one word.
///
/// The standalone `word` stage ("say it out loud") was removed once Today
/// became a list — the user already sees + says the word from the list before
/// drilling in. Flow is now: simple → technical → explain → connector → done.
enum FeynmanStage: Int, CaseIterable {
    case simple
    case technical
    case explain
    case connector
    case done

    /// Forward transition. Coming-soon words skip the connector stage because
    /// the simple-explanation copy isn't authored yet, so there's nothing
    /// meaningful for the connector to anchor.
    func next(isComingSoon: Bool) -> FeynmanStage? {
        switch self {
        case .simple:    return .technical
        case .technical: return .explain
        case .explain:   return isComingSoon ? .done : .connector
        case .connector: return .done
        case .done:      return nil
        }
    }

    /// Inverse of `next(isComingSoon:)`. Used by the header back button so
    /// users can revisit a prior stage. The done -> previous traversal
    /// honors the same coming-soon skip.
    func previous(isComingSoon: Bool) -> FeynmanStage? {
        switch self {
        case .simple:    return nil
        case .technical: return .simple
        case .explain:   return .technical
        case .connector: return .explain
        case .done:      return isComingSoon ? .explain : .connector
        }
    }
}
