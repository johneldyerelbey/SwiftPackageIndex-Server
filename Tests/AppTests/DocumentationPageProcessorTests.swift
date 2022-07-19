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

import XCTVapor

class DocumentationPageProcessorTests: AppTestCase {

    func test_availableDocumentationVersionArray_latestStableVersion() throws {
        let versions: [DocumentationPageProcessor.AvailableDocumentationVersion] = [
            .init(kind: .defaultBranch, reference: "main", docArchives: ["docs"], isLatestStable: false),
            .init(kind: .release, reference: "1.0.0", docArchives: ["docs"], isLatestStable: false),
            .init(kind: .release, reference: "2.0.0", docArchives: ["docs"], isLatestStable: false),
            .init(kind: .release, reference: "2.1.0", docArchives: ["docs"], isLatestStable: true),
            .init(kind: .preRelease, reference: "3.0.0-beta1", docArchives: ["docs"], isLatestStable: false)
        ]

        // MUT
        let latestStableVersion = try XCTUnwrap(versions.latestStableVersion)

        XCTAssertEqual(latestStableVersion.reference, "2.1.0")
    }

}
