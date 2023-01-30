// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import SQLKit
import XCTest


class SQLKitExtensionTests: AppTestCase {

    func test_OrderByGroup() throws {
        let b = SQLOrderBy(SQLIdentifier("id"), .ascending)
            .then(SQLIdentifier("foo"), .descending)
        XCTAssertEqual(renderSQL(b), #""id" ASC, "foo" DESC"#)
    }

    func test_OrderByGroup_complex() throws {
        let packageName = SQLIdentifier("package_name")
        let mergedTerms = SQLBind("a b")
        let score = SQLIdentifier("score")

        let orderBy = SQLOrderBy(eq(lower(packageName), mergedTerms), .descending)
            .then(score, .descending)
            .then(packageName, .ascending)
        XCTAssertEqual(renderSQL(orderBy),
                       #"LOWER("package_name") = $1 DESC, "score" DESC, "package_name" ASC"#)
    }

}
