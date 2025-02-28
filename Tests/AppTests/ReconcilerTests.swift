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

import XCTest

@testable import App

import Dependencies
import Vapor


class ReconcilerTests: AppTestCase {

    func test_fetchCurrentPackageList() async throws {
        // setup
        for url in ["1", "2", "3"].asURLs {
            try await Package(url: url).save(on: app.db)
        }

        // MUT
        let urls = try await fetchCurrentPackageList(app.db)

        // validate
        XCTAssertEqual(urls.map(\.absoluteString).sorted(), ["1", "2", "3"])
    }

    func test_reconcileMainPackageList() async throws {
        let urls = ["1", "2", "3"]
        try await withDependencies {
            $0.packageListRepository.fetchPackageList = { @Sendable _ in urls.asURLs }
            $0.packageListRepository.fetchPackageDenyList = { @Sendable _ in [] }
        } operation: {
            // MUT
            _ = try await reconcileMainPackageList(client: app.client, database: app.db)
        }

        // validate
        let packages = try await Package.query(on: app.db).all()
        XCTAssertEqual(packages.map(\.url).sorted(), urls.sorted())
        packages.forEach {
            XCTAssertNotNil($0.id)
            XCTAssertNotNil($0.createdAt)
            XCTAssertNotNil($0.updatedAt)
            XCTAssertEqual($0.status, .new)
            XCTAssertEqual($0.processingStage, .reconciliation)
        }
    }

    func test_reconcileMainPackageList_adds_and_deletes() async throws {
        // save intial set of packages 1, 2, 3
        for url in ["1", "2", "3"].asURLs {
            try await Package(url: url).save(on: app.db)
        }

        // new package list drops 2, 3, adds 4, 5
        let urls = ["1", "4", "5"]

        try await withDependencies {
            $0.packageListRepository.fetchPackageList = { @Sendable _ in urls.asURLs }
            $0.packageListRepository.fetchPackageDenyList = { @Sendable _ in [] }
        } operation: {
            // MUT
            _ = try await reconcileMainPackageList(client: app.client, database: app.db)
        }

        // validate
        let packages = try await Package.query(on: app.db).all()
        XCTAssertEqual(packages.map(\.url).sorted(), urls.sorted())
    }

    func test_reconcileMainPackageList_packageDenyList() async throws {
        // Save the intial set of packages
        for url in ["1", "2", "3"].asURLs {
            try await Package(url: url).save(on: app.db)
        }

        // New list adds two new packages 4, 5
        let packageList = ["1", "2", "3", "4", "5"]

        // Deny list denies 2 and 4 (one existing and one new)
        let packageDenyList = ["2", "4"]

        try await withDependencies {
            $0.packageListRepository.fetchPackageList = { @Sendable _ in packageList.asURLs }
            $0.packageListRepository.fetchPackageDenyList = { @Sendable _ in packageDenyList.asURLs }
        } operation: {
            // MUT
            _ = try await reconcileMainPackageList(client: app.client, database: app.db)
        }

        // validate
        let packages = try await Package.query(on: app.db).all()
        XCTAssertEqual(packages.map(\.url).sorted(), ["1", "3", "5"])
    }

    func test_reconcileMainPackageList_packageDenyList_caseSensitivity() async throws {
        // Save the intial set of packages
        for url in ["https://example.com/one/one", "https://example.com/two/two"].asURLs {
            try await Package(url: url).save(on: app.db)
        }

        // New list adds no new packages
        let packageList = ["https://example.com/one/one", "https://example.com/two/two"]

        // Deny list denies one/one, but with incorrect casing.
        let packageDenyList = ["https://example.com/OnE/oNe"]

        try await withDependencies {
            $0.packageListRepository.fetchPackageList = { @Sendable _ in packageList.asURLs }
            $0.packageListRepository.fetchPackageDenyList = { @Sendable _ in packageDenyList.asURLs }
        } operation: {
            // MUT
            _ = try await reconcileMainPackageList(client: app.client, database: app.db)
        }

        // validate
        let packages = try await Package.query(on: app.db).all()
        XCTAssertEqual(packages.map(\.url).sorted(), ["https://example.com/two/two"])
    }

    func test_reconcileCustomCollections() async throws {
        // Test single custom collection reconciliation
        // setup
        var fullPackageList = [URL("https://github.com/a.git"), URL("https://github.com/b.git"), URL("https://github.com/c.git")]
        for url in fullPackageList { try await Package(url: url).save(on: app.db) }

        // Initial run
        try await withDependencies {
            $0.packageListRepository.fetchCustomCollection = { @Sendable _, _ in [URL("https://github.com/b.git")] }
        } operation: {
            // MUT
            try await reconcileCustomCollection(client: app.client,
                                                database: app.db,
                                                fullPackageList: fullPackageList,
                                                .init(name: "List", url: "url"))

            // validate
            let count = try await CustomCollection.query(on: app.db).count()
            XCTAssertEqual(count, 1)
            let collection = try await CustomCollection.query(on: app.db).first().unwrap()
            try await collection.$packages.load(on: app.db)
            XCTAssertEqual(collection.packages.map(\.url), ["https://github.com/b.git"])
        }

        // Reconcile again with an updated list of packages in the collection
        try await withDependencies {
            $0.packageListRepository.fetchCustomCollection = { @Sendable _, _ in [URL("https://github.com/c.git")] }
        } operation: {
            // MUT
            try await reconcileCustomCollection(client: app.client,
                                                database: app.db,
                                                fullPackageList: fullPackageList,
                                                .init(name: "List", url: "url"))

            // validate
            let count = try await CustomCollection.query(on: app.db).count()
            XCTAssertEqual(count, 1)
            let collection = try await CustomCollection.query(on: app.db).first().unwrap()
            try await collection.$packages.load(on: app.db)
            XCTAssertEqual(collection.packages.map(\.url), ["https://github.com/c.git"])
        }

        // Re-run after the single package in the list has been deleted in the full package list
        fullPackageList = [URL("https://github.com/a.git"), URL("https://github.com/b.git")]
        try await Package.query(on: app.db).filter(by: URL("https://github.com/c.git")).first()?.delete(on: app.db)
        try await withDependencies {
            $0.packageListRepository.fetchCustomCollection = { @Sendable _, _ in [URL("https://github.com/c.git")] }
        } operation: {
            // MUT
            try await reconcileCustomCollection(client: app.client,
                                                database: app.db,
                                                fullPackageList: fullPackageList,
                                                .init(name: "List", url: "url"))

            // validate
            let count = try await CustomCollection.query(on: app.db).count()
            XCTAssertEqual(count, 1)
            let collection = try await CustomCollection.query(on: app.db).first().unwrap()
            try await collection.$packages.load(on: app.db)
            XCTAssertEqual(collection.packages.map(\.url), [])
        }
    }

    func test_reconcileCustomCollections_limit() async throws {
        // Test custom collection reconciliation size limit
        // setup
        let fullPackageList = (1...60).map { URL(string: "https://github.com/\($0).git")! }
        for url in fullPackageList { try await Package(url: url).save(on: app.db) }

        try await withDependencies {
            $0.packageListRepository.fetchCustomCollection = { @Sendable _, _ in
                fullPackageList
            }
        } operation: {
            // MUT
            try await reconcileCustomCollection(client: app.client,
                                                database: app.db,
                                                fullPackageList: fullPackageList,
                                                .init(name: "List", url: "url"))

            // validate
            let collection = try await CustomCollection.query(on: app.db).first().unwrap()
            try await collection.$packages.load(on: app.db)
            XCTAssertEqual(collection.packages.count, 50)
            XCTAssertEqual(collection.packages.first?.url, "https://github.com/1.git")
            XCTAssertEqual(collection.packages.last?.url, "https://github.com/50.git")
        }
    }

    func test_reconcile() async throws {
        let fullPackageList = (1...3).map { URL(string: "https://github.com/\($0).git")! }
        struct TestError: Error { var message: String }

        try await withDependencies {
            $0.packageListRepository.fetchPackageList = { @Sendable _ in fullPackageList }
            $0.packageListRepository.fetchPackageDenyList = { @Sendable _ in [] }
            $0.packageListRepository.fetchCustomCollection = { @Sendable _, url in
                if url == "collectionURL" {
                    return [URL("https://github.com/2.git")]
                } else {
                    throw TestError(message: "collection not found: \(url)")
                }
            }
            $0.packageListRepository.fetchCustomCollections = { @Sendable _ in
                [.init(name: "List", url: "collectionURL")]
            }
        } operation: {
            // MUT
            _ = try await reconcile(client: app.client, database: app.db)

            // validate
            let packages = try await Package.query(on: app.db).all()
            XCTAssertEqual(packages.map(\.url).sorted(),
                           fullPackageList.map(\.absoluteString).sorted())
            let count = try await CustomCollection.query(on: app.db).count()
            XCTAssertEqual(count, 1)
            let collection = try await CustomCollection.query(on: app.db).first().unwrap()
            XCTAssertEqual(collection.name, "List")
            XCTAssertEqual(collection.url, "collectionURL")
            try await collection.$packages.load(on: app.db)
            XCTAssertEqual(collection.packages.map(\.url), ["https://github.com/2.git"])
        }
    }

}
