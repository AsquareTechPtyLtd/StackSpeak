import Foundation
import SwiftData

// Writes a merged snapshot back into SwiftData. Additive by construction: the
// merge guarantees the snapshot is a superset of local, so sub-records are
// update-or-insert only — nothing is deleted here.
extension SyncCoordinator {
    func applySnapshot(_ s: ProgressSnapshot, to p: UserProgress) {
        p.level = s.level
        p.currentStreak = s.currentStreak
        p.longestStreak = s.longestStreak
        p.lastCompletedDate = s.lastCompletedDate
        p.didCompleteOnboarding = s.didCompleteOnboarding
        p.wordQueueCursor = s.wordQueueCursor
        if let seed = UUID(uuidString: s.shuffleSeed) { p.shuffleSeed = seed }

        p.wordsPracticedIds = Self.uuids(s.practicedWordIds)
        p.masteredWordIds = Self.uuids(s.masteredWordIds)
        p.bookmarkedWordIds = Self.uuids(s.bookmarkedWordIds)
        p.wordsWithTwoCorrectIds = Self.uuids(s.wordsWithTwoCorrectIds)
        p.wordsCreditedForLevelIds = Self.uuids(s.wordsCreditedForLevelIds)
        p.selectedStacks = Set(s.selectedStacks)

        applyReviewStates(s.reviewStates, to: p)
        applyAssessmentResults(s.assessmentResults, to: p)
        applyPracticedSentences(s.practicedSentences, to: p)
        applyBookProgress(s.bookProgress)
    }

    private static func uuids(_ strings: [String]) -> Set<UUID> {
        Set(strings.compactMap(UUID.init(uuidString:)))
    }

    private func applyReviewStates(_ dtos: [ProgressSnapshot.ReviewStateDTO], to p: UserProgress) {
        let existing = Dictionary(p.reviewStates.map { ($0.wordId, $0) }, uniquingKeysWith: { a, _ in a })
        for dto in dtos {
            guard let wid = UUID(uuidString: dto.wordId) else { continue }
            let rs = existing[wid] ?? {
                let new = ReviewState(wordId: wid)
                p.reviewStates.append(new)
                return new
            }()
            rs.easinessFactor = dto.easinessFactor
            rs.interval = dto.interval
            rs.repetitions = dto.repetitions
            rs.dueDate = dto.dueDate
            rs.lastReviewedAt = dto.lastReviewedAt
        }
    }

    private func applyAssessmentResults(_ dtos: [ProgressSnapshot.AssessmentResultDTO], to p: UserProgress) {
        let existingIds = Set(p.assessmentResults.map(\.id))
        for dto in dtos {
            guard let id = UUID(uuidString: dto.id),
                  let wid = UUID(uuidString: dto.wordId),
                  !existingIds.contains(id) else { continue }
            let result = AssessmentResult(wordId: wid, attemptedAt: dto.attemptedAt,
                                          isCorrect: dto.isCorrect,
                                          selectedAnswer: dto.selectedAnswer,
                                          correctAnswer: dto.correctAnswer)
            result.id = id  // preserve the originating device's id for cross-device dedup
            p.assessmentResults.append(result)
        }
    }

    private func applyPracticedSentences(_ dtos: [ProgressSnapshot.PracticedSentenceDTO], to p: UserProgress) {
        func key(_ wid: UUID, _ created: Date, _ text: String) -> String {
            "\(wid)|\(created.timeIntervalSince1970)|\(text)"
        }
        var seen = Set(p.practicedSentences.map { key($0.wordId, $0.createdAt, $0.sentence) })
        for dto in dtos {
            guard let wid = UUID(uuidString: dto.wordId),
                  let method = InputMethod(rawValue: dto.inputMethod) else { continue }
            let k = key(wid, dto.createdAt, dto.sentence)
            guard seen.insert(k).inserted else { continue }
            p.practicedSentences.append(PracticedSentence(wordId: wid, sentence: dto.sentence,
                                                          createdAt: dto.createdAt, inputMethod: method))
        }
    }

    private func applyBookProgress(_ dtos: [ProgressSnapshot.BookProgressDTO]) {
        let existing = Dictionary(fetchBookProgress().map { ($0.bookId, $0) }, uniquingKeysWith: { a, _ in a })
        for dto in dtos {
            let bp = existing[dto.bookId] ?? {
                let new = BookProgress(bookId: dto.bookId)
                modelContext.insert(new)
                return new
            }()
            bp.lastOpenedAt = dto.lastOpenedAt
            bp.currentChapterId = dto.currentChapterId
            bp.currentCardId = dto.currentCardId
            bp.completedCardIds = Set(dto.completedCardIds)
            bp.lastReadingDayString = dto.lastReadingDayString
            bp.currentStreakDays = dto.currentStreakDays
            bp.longestStreakDays = dto.longestStreakDays
        }
    }
}
