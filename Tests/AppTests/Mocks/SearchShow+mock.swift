// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import App

import Foundation

extension SearchShow.Model {
    
    private static func mockedWeightedKeywords(results: [Search.Result]) -> [PackageShow.Model.WeightedKeyword] {
        let keywords = results.compactMap { $0.keywordResult?.keyword }
        
        let counts:[Int] = Array(1...keywords.count)
        return zip(keywords, counts).map {
            PackageShow.Model.WeightedKeyword(keyword: $0, weight: $1)
        }
    }
    static func mock(results: [Search.Result] = .mock()) -> Self {
        return .init(page: 3,
                     query: "query",
                     response: .init(hasMoreResults: true, searchTerm: "query", searchFilters: [], results: results), weightedKeywords: mockedWeightedKeywords(results: results))
    }
    
    static func mockWithFilter(results: [Search.Result] = .mock()) -> Self {
        return .init(page: 3,
                     query: "query license:mit",
                     response: .init(hasMoreResults: true,
                                     searchTerm: "query",
                                     searchFilters: [
                                        .init(key: "license", operator: "is", value: "mit")
                                     ],
                                     results: results), weightedKeywords: mockedWeightedKeywords(results: results))
    }
}
