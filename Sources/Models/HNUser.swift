import Foundation

/// A Hacker News user profile from the Firebase API.
struct HNUser: Codable, Identifiable, Hashable {
    let id: String
    var created: Int?
    var karma: Int?
    var about: String?
    var submitted: [Int]?
}

extension HNUser {
    var createdDate: Date? {
        created.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }
    var karmaValue: Int { karma ?? 0 }
    var submissionCount: Int { submitted?.count ?? 0 }
    var profileURL: URL {
        URL(string: "https://news.ycombinator.com/user?id=\(id)")!
    }
}
