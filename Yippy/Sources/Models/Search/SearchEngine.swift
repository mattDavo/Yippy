//
//  SearchEngine.swift
//  Yippy
//
//  Created by Matthew Davidson on 6/9/20.
//  Copyright © 2020 MatthewDavidson. All rights reserved.
//

import Foundation

struct SearchQuery: Hashable, Equatable {
    
    var query: String
    
    // Enfore the data invariant
    private init(query: String) {
        self.query = query
    }
    
    static func fromRawText(_ str: String) -> SearchQuery {
        return SearchQuery(query: str)
    }
}

public class SearchResult {
    
    var query: SearchQuery
    var results: [Int] = []
    var items: Int
    var completed: Int = 0
    
    var isFinished: Bool {
        return completed == items
    }
    
    init(query: SearchQuery, items: Int) {
        self.query = query
        self.items = items
    }
    
    func addResult(_ i: Int) {
        results.append(i)
        results.sort()
        completed += 1
    }
    
    func recordFailure() {
        completed += 1
    }
}

public class SearchEngine {
    
    var results = [SearchQuery: SearchResult]()
    
    var inProgress = [SearchQuery]()
    
    var sem = DispatchSemaphore(value: 1)
    
    var data: [String]
    
    init(data: [String]) {
        self.data = data
    }
    
    public func search(query: String, completion: @escaping (SearchResult) -> Void) {
        let searchQuery = SearchQuery.fromRawText(query)
        
        if let result = findResult(forQuery: searchQuery) {
            return completion(result)
        }
        
        DispatchQueue.global().async {
            self.sem.wait()
            self.inProgress.append(searchQuery)
            self.sem.signal()
            
            // Do something
            let resSem = DispatchSemaphore(value: 1)
            let searchResult = SearchResult(query: searchQuery, items: self.data.count)
            for (i, d) in self.data.enumerated() {
                DispatchQueue.global().async {
                    if performSearch(needle: searchQuery.query, haystack: d) {
                        resSem.wait()
                        searchResult.addResult(i)
                        resSem.signal()
                    }
                    else {
                        resSem.wait()
                        searchResult.recordFailure()
                        resSem.signal()
                    }
                }
            }
            
            self.finishSearch(searchResult: searchResult, update: completion) {
                self.sem.wait()
                self.inProgress.removeAll(where: {$0 == searchQuery})
                self.results[searchQuery] = searchResult
                self.sem.signal()
            }
        }
    }
    
    private func finishSearch(searchResult: SearchResult, update: @escaping (SearchResult) -> (), completion: @escaping () -> ()) {
        if searchResult.isFinished {
            update(searchResult)
            completion()
            return
        }
        
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 0.1, execute: {
            self.finishSearch(searchResult: searchResult, update: update, completion: completion)
        })
    }
    
    private func findResult(forQuery query: SearchQuery) -> SearchResult? {
        return results[query]
    }
}
