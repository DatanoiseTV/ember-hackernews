import Foundation

enum HNError: LocalizedError {
    case invalidURL
    case badStatus(Int)
    case decoding(Error)
    case transport(Error)
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The request URL was invalid."
        case .badStatus(let code): "The server responded with status \(code)."
        case .decoding: "The response could not be read."
        case .transport(let e): (e as NSError).localizedDescription
        case .notFound: "This item could not be found."
        }
    }
}

/// Abstraction over the Hacker News data sources so views can be driven by a
/// live network service or an in-memory mock (previews / tests).
protocol HNServicing {
    func storyIDs(for feed: Feed) async throws -> [Int]
    func item(_ id: Int) async throws -> HNItem
    func items(_ ids: [Int]) async throws -> [HNItem]
    func user(_ id: String) async throws -> HNUser
    func commentTree(for id: Int) async throws -> AlgoliaItem
    func search(_ query: String, mode: SearchMode, page: Int) async throws -> [SearchHit]
    func favoriteIDs(username: String) async throws -> [Int]
}

/// Live implementation. Feeds and items come from the official Firebase API;
/// full comment trees and search come from Algolia (one request per thread
/// instead of hundreds).
final class LiveHNService: HNServicing {
    static let shared = LiveHNService()

    private let firebaseBase = "https://hacker-news.firebaseio.com/v0"
    private let algoliaBase = "https://hn.algolia.com/api/v1"
    private let session: URLSession
    private let cache = DiskCache.shared

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.urlCache = URLCache(memoryCapacity: 16 << 20, diskCapacity: 64 << 20)
        config.requestCachePolicy = .reloadRevalidatingCacheData
        // Fail fast when offline so we can fall back to the disk cache promptly.
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    private var firebaseDecoder: JSONDecoder { JSONDecoder() }
    private var algoliaDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private func get<T: Decodable>(_ urlString: String, decoder: JSONDecoder) async throws -> T {
        #if DEBUG
        if LaunchArgs.forceOffline { throw HNError.transport(URLError(.notConnectedToInternet)) }
        #endif
        guard let url = URL(string: urlString) else { throw HNError.invalidURL }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw HNError.transport(error)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw HNError.badStatus(http.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HNError.decoding(error)
        }
    }

    func storyIDs(for feed: Feed) async throws -> [Int] {
        let key = "ids.\(feed.rawValue)"
        do {
            let ids: [Int] = try await get("\(firebaseBase)/\(feed.endpoint).json", decoder: firebaseDecoder)
            await cache.store(ids, for: key)
            return ids
        } catch {
            if let cached = await cache.load([Int].self, for: key) { return cached }
            throw error
        }
    }

    func item(_ id: Int) async throws -> HNItem {
        let key = "item.\(id)"
        do {
            let item: HNItem = try await get("\(firebaseBase)/item/\(id).json", decoder: firebaseDecoder)
            await cache.store(item, for: key)
            return item
        } catch {
            if let cached = await cache.load(HNItem.self, for: key) { return cached }
            throw error
        }
    }

    /// Fetch many items concurrently, preserving the requested order and
    /// silently dropping items the API returns as null (deleted / missing).
    func items(_ ids: [Int]) async throws -> [HNItem] {
        try await withThrowingTaskGroup(of: (Int, HNItem?).self) { group in
            for (index, id) in ids.enumerated() {
                group.addTask { [self] in
                    // Tolerate per-item failures: a null payload or a decode
                    // error for one id must not fail the whole batch.
                    let item = try? await item(id)
                    return (index, item)
                }
            }
            var collected: [(Int, HNItem)] = []
            for try await (index, item) in group {
                if let item { collected.append((index, item)) }
            }
            return collected.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    func user(_ id: String) async throws -> HNUser {
        try await get("\(firebaseBase)/user/\(id).json", decoder: firebaseDecoder)
    }

    func commentTree(for id: Int) async throws -> AlgoliaItem {
        let key = "tree.\(id)"
        do {
            let tree: AlgoliaItem = try await get("\(algoliaBase)/items/\(id)", decoder: algoliaDecoder)
            await cache.store(tree, for: key)
            return tree
        } catch {
            if let cached = await cache.load(AlgoliaItem.self, for: key) { return cached }
            throw error
        }
    }

    func search(_ query: String, mode: SearchMode, page: Int) async throws -> [SearchHit] {
        var components = URLComponents(string: "\(algoliaBase)/\(mode.path)")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "tags", value: "story"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "hitsPerPage", value: "30"),
        ]
        guard let url = components.url else { throw HNError.invalidURL }
        let response: SearchResponse = try await get(url.absoluteString, decoder: algoliaDecoder)
        return response.hits
    }

    /// HN favorites live only on the website (no API). Fetch the public favorites
    /// page and extract the favorited story ids from its `item?id=` links — a
    /// minimal, stable parse; the items themselves are then loaded via the API.
    func favoriteIDs(username: String) async throws -> [Int] {
        guard let url = URL(string: "https://news.ycombinator.com/favorites?id=\(username)") else {
            throw HNError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw HNError.badStatus(http.statusCode)
        }
        let html = String(decoding: data, as: UTF8.self)
        let regex = try NSRegularExpression(pattern: "item\\?id=(\\d+)")
        let ns = html as NSString
        var ids: [Int] = []
        var seen = Set<Int>()
        for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            if let id = Int(ns.substring(with: match.range(at: 1))), seen.insert(id).inserted {
                ids.append(id)
            }
        }
        return ids
    }
}
