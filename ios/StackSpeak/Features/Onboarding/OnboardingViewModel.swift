import Foundation

@Observable
final class OnboardingViewModel {
    var currentPage = 0
    var isComplete = false

    func nextPage() {
        currentPage += 1
    }

    func complete() {
        isComplete = true
    }

    func skip() {
        isComplete = true
    }
}
