import Foundation

enum CatalogStatus: Equatable {
    case loading
    case loaded(count: Int)
}
