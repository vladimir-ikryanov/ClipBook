import Foundation
import os

/// Snapshot of the sorted listed items' identifiers and search texts for a
/// single list revision, shared with background search jobs.
nonisolated final class HistorySearchCorpus: Sendable {
    let revision: Int
    let ids: [UUID]
    let texts: [String]
    fileprivate let cachedIndexByID = OSAllocatedUnfairLock<[UUID: Int]?>(initialState: nil)

    init(revision: Int, ids: [UUID], texts: [String]) {
        self.revision = revision
        self.ids = ids
        self.texts = texts
    }
}

/// The outcome of matching a `HistorySearchCorpus` against `HistorySearchTerms`.
nonisolated struct HistorySearchResult: Sendable {
    let terms: HistorySearchTerms
    let revision: Int
    let corpus: HistorySearchCorpus
    let matches: [Bool]
    let indexByID: [UUID: Int]
    let matchCount: Int
    let locale: Locale

    init(
        terms: HistorySearchTerms,
        revision: Int,
        corpus: HistorySearchCorpus,
        matches: [Bool],
        indexByID: [UUID: Int],
        matchCount: Int? = nil,
        locale: Locale = .current
    ) {
        self.terms = terms
        self.revision = revision
        self.corpus = corpus
        self.matches = matches
        self.indexByID = indexByID
        self.matchCount = matchCount ?? matches.reduce(0) { $0 + ($1 ? 1 : 0) }
        self.locale = locale
    }
}

/// Runs a cancellable parallel search over a `HistorySearchCorpus`.
nonisolated final class HistorySearchJob: Sendable {
    private let cancelled = OSAllocatedUnfairLock(initialState: false)

    init() {}

    func cancel() {
        cancelled.withLock { $0 = true }
    }

    var isCancelled: Bool {
        cancelled.withLock { $0 }
    }

    func run(
        corpus: HistorySearchCorpus,
        terms: HistorySearchTerms,
        locale: Locale,
        previous: HistorySearchResult? = nil
    ) -> HistorySearchResult? {
        guard !isCancelled else {
            return nil
        }

        HistorySearchMatcher.warmUp()

        let count = corpus.texts.count
        var matches = [Bool](repeating: false, count: count)

        if count > 0 {
            let chunkCount = min(count, max(1, ProcessInfo.processInfo.activeProcessorCount * 4))
            let chunkSize = (count + chunkCount - 1) / chunkCount
            let texts = corpus.texts
            let checkStride = count <= 512 ? 1 : 64

            matches.withUnsafeMutableBufferPointer { buffer in
                nonisolated(unsafe) let buffer = buffer
                DispatchQueue.concurrentPerform(iterations: chunkCount) { chunk in
                    guard !self.isCancelled else {
                        return
                    }
                    let start = chunk * chunkSize
                    let end = min(start + chunkSize, count)
                    guard start < end else {
                        return
                    }
                    for index in start..<end {
                        if (index - start) % checkStride == 0, self.isCancelled {
                            return
                        }
                        buffer[index] = HistorySearchMatcher.matches(texts[index], terms, locale: locale)
                    }
                }
            }
        }

        guard !isCancelled else {
            return nil
        }

        let indexByID: [UUID: Int]
        if let previous, previous.corpus === corpus {
            indexByID = previous.indexByID
            corpus.cachedIndexByID.withLock {
                if $0 == nil {
                    $0 = indexByID
                }
            }
        } else if let cached = corpus.cachedIndexByID.withLock({ $0 }) {
            indexByID = cached
        } else {
            var built = [UUID: Int](minimumCapacity: corpus.ids.count)
            for (index, id) in corpus.ids.enumerated() {
                if index & 4095 == 0, isCancelled {
                    return nil
                }
                built[id] = index
            }
            indexByID = built
            corpus.cachedIndexByID.withLock { $0 = indexByID }
        }

        guard !isCancelled else {
            return nil
        }

        return HistorySearchResult(
            terms: terms,
            revision: corpus.revision,
            corpus: corpus,
            matches: matches,
            indexByID: indexByID,
            locale: locale
        )
    }
}
