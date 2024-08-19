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

import XCTVapor


class HomeIndexModelTests: AppTestCase {

    func test_query() async throws {
        // setup
        let pkgId = UUID()
        let pkg = Package(id: pkgId, url: "1".url)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg,
                             name: "1",
                             owner: "foo").save(on: app.db)
        try await App.Version(package: pkg,
                              commitDate: Date(timeIntervalSince1970: 0),
                              packageName: "Package",
                              reference: .tag(.init(1, 2, 3))).save(on: app.db)
        try await RecentPackage.refresh(on: app.db)
        try await RecentRelease.refresh(on: app.db)
        // Sleep for 1ms to ensure we can detect a difference between update times.
        try await Task.sleep(nanoseconds: UInt64(1e6))

        // MUT
        let m = try await HomeIndex.Model.query(database: app.db)

        // validate
        let createdAt = try XCTUnwrap(pkg.createdAt)
#if os(Linux)
        if m.recentPackages == [
            .init(
                date: createdAt,
                link: .init(label: "Package", url: "/foo/1")
            )
        ] {
            XCTFail("Direct comparison of recentPackages is working again, replace by-property comparison with the Task.sleep delay.")
            // When this triggers, remove Task.sleep above and the validtion below until // TEMPORARY - END
            // and replace with original assert:
            //     XCTAssertEqual(m.recentPackages, [
            //         .init(
            //             date: createdAt,
            //             link: .init(label: "Package", url: "/foo/1")
            //         )
            //     ])
        }
#endif
        XCTAssertEqual(m.recentPackages.count, 1)
        let recent = try XCTUnwrap(m.recentPackages.first)
        // Comaring the dates directly fails due to tiny rounding differences with the new swift-foundation types on Linux
        // E.g.
        // 1724071056.5824609
        // 1724071056.5824614
        // By testing only to accuracy 10e-5 and delaying by 10e-3 we ensure we properly detect if the value was changed.
        XCTAssertEqual(recent.date.timeIntervalSince1970, createdAt.timeIntervalSince1970, accuracy: 10e-5)
        XCTAssertEqual(recent.link, .init(label: "Package", url: "/foo/1"))
        XCTAssertEqual(m.recentReleases, [
            .init(packageName: "Package",
                  version: "1.2.3",
                  date: "\(date: Date(timeIntervalSince1970: 0), relativeTo: Current.date())",
                  url: "/foo/1"),
        ])
        // TEMPORARY - END
    }

}
