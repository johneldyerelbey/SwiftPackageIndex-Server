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

import Basics
import Dependencies
import PackageCollectionsSigning
import SnapshotTesting
import Vapor


class PackageCollectionTests: AppTestCase {

    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    typealias VersionResult = PackageCollection.VersionResult
    typealias VersionResultGroup = PackageCollection.VersionResultGroup

    func test_query_filter_urls() async throws {
        // Tests PackageResult.query with the url filter option
        // setup
        for index in (0..<3) {
            let pkg = try await savePackage(on: app.db, "url-\(index)".url)
            do {
                let v = try Version(package: pkg,
                                    latest: .release,
                                    packageName: "package \(index)",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.4")
                try await v.save(on: app.db)
                try await Build(version: v,
                                buildCommand: "build \(index)",
                                platform: .iOS,
                                status: .ok,
                                swiftVersion: .v1)
                .save(on: app.db)
                try await Product(version: v,
                                  type: .library(.automatic),
                                  name: "product \(index)")
                .save(on: app.db)
                try await Target(version: v, name: "target \(index)")
                    .save(on: app.db)
            }
            try await Repository(package: pkg,
                                 name: "repo \(index)")
            .save(on: app.db)
        }

        // MUT
        let res = try await VersionResult.query(on: app.db, filterBy: .urls(["url-1"]))

        // validate selection and all relations being loaded
        XCTAssertEqual(res.map(\.version.packageName), ["package 1"])
        XCTAssertEqual(res.flatMap{ $0.builds.map(\.buildCommand) },
                       ["build 1"])
        XCTAssertEqual(res.flatMap{ $0.products.map(\.name) },
                       ["product 1"])
        XCTAssertEqual(res.flatMap{ $0.targets.map(\.name) },
                       ["target 1"])
        XCTAssertEqual(res.map(\.package.url), ["url-1"])
        XCTAssertEqual(res.map(\.repository.name), ["repo 1"])
        // drill into relations of relations
        XCTAssertEqual(res.flatMap { $0.version.products.map(\.name) }, ["product 1"])
    }

    func test_query_filter_urls_no_results() async throws {
        // Tests PackageResult.query without results has safe relationship accessors
        // setup
        for index in (0..<3) {
            let pkg = try await savePackage(on: app.db, "url-\(index)".url)
            do {
                let v = try Version(package: pkg,
                                    latest: .release,
                                    packageName: "package \(index)",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.4")
                try await v.save(on: app.db)
                try await Build(version: v,
                                buildCommand: "build \(index)",
                                platform: .iOS,
                                status: .ok,
                                swiftVersion: .v1)
                .save(on: app.db)
                try await Product(version: v,
                                  type: .library(.automatic),
                                  name: "product \(index)")
                .save(on: app.db)
                try await Target(version: v, name: "target \(index)")
                    .save(on: app.db)
            }
            try await Repository(package: pkg,
                                 name: "repo \(index)")
            .save(on: app.db)
        }

        // MUT
        let res = try await VersionResult.query(
            on: app.db,
            filterBy: .urls(["non-existant"])
        )

        // validate safe access
        XCTAssertEqual(res.map(\.version.packageName), [])
        XCTAssertEqual(res.flatMap{ $0.builds.map(\.buildCommand) }, [])
        XCTAssertEqual(res.flatMap{ $0.products.map(\.name) }, [])
        XCTAssertEqual(res.flatMap{ $0.targets.map(\.name) }, [])
        XCTAssertEqual(res.map(\.package.url), [])
        XCTAssertEqual(res.map(\.repository.name), [])
    }

    func test_query_author() async throws {
        // Tests PackageResult.query with the author filter option
        // setup
        // first package
        let owners = ["foo", "foo", "someone else"]
        for index in (0..<3) {
            let pkg = try await savePackage(on: app.db, "url-\(index)".url)
            do {
                let v = try Version(package: pkg,
                                    latest: .release,
                                    packageName: "package \(index)",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.4")
                try await v.save(on: app.db)
                try await Build(version: v,
                                buildCommand: "build \(index)",
                                platform: .iOS,
                                status: .ok,
                                swiftVersion: .v1)
                .save(on: app.db)
                try await Product(version: v,
                                  type: .library(.automatic),
                                  name: "product \(index)")
                .save(on: app.db)
                try await Target(version: v, name: "target \(index)")
                    .save(on: app.db)
            }
            try await Repository(package: pkg,
                                 name: "repo \(index)",
                                 owner: owners[index])
            .save(on: app.db)
        }

        // MUT
        let res = try await VersionResult.query(on: self.app.db, filterBy: .author("foo"))

        // validate selection (relationship loading is tested in test_query_filter_urls)
        XCTAssertEqual(res.map(\.version.packageName),
                       ["package 0", "package 1"])
    }

    func test_query_custom() async throws {
        // Tests PackageResult.query with the custom collection filter option
        // setup
        let packages = try await (0..<3).mapAsync { index in
            let pkg = try await savePackage(on: app.db, "url-\(index)".url)
            do {
                let v = try Version(package: pkg,
                                    latest: .release,
                                    packageName: "package \(index)",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.4")
                try await v.save(on: app.db)
                try await Build(version: v,
                                buildCommand: "build \(index)",
                                platform: .iOS,
                                status: .ok,
                                swiftVersion: .v1)
                .save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "product \(index)")
                    .save(on: app.db)
                try await Target(version: v, name: "target \(index)")
                    .save(on: app.db)
            }
            try await Repository(package: pkg, name: "repo \(index)", owner: "owner")
                .save(on: app.db)
            return pkg
        }
        let collection = CustomCollection(id: .id2, .init(name: "List", url: "https://github.com/foo/bar/list.json"))
        try await collection.save(on: app.db)
        try await collection.$packages.attach([packages[0], packages[1]], on: app.db)

        // MUT
        let res = try await VersionResult.query(on: self.app.db,
                                                filterBy: .customCollection("List"))

        // validate selection (relationship loading is tested in test_query_filter_urls)
        XCTAssertEqual(res.map(\.version.packageName),
                       ["package 0", "package 1"])
    }

    func test_Version_init() async throws {
        // Tests PackageCollection.Version initialisation from App.Version
        // setup
        let p = Package(url: "1")
        try await p.save(on: app.db)
        do {
            let v = try Version(package: p,
                                latest: .release,
                                packageName: "Foo",
                                publishedAt: Date(timeIntervalSince1970: 0),
                                reference: .tag(1, 2, 3),
                                releaseNotes: "Bar",
                                supportedPlatforms: [.ios("14.0")],
                                toolsVersion: "5.3")
            try await v.save(on: app.db)
            try await Repository(package: p).save(on: app.db)
            do {
                try await Product(version: v,
                            type: .library(.automatic),
                            name: "P1",
                            targets: ["T1"]).save(on: app.db)
                try await Product(version: v,
                            type: .library(.automatic),
                            name: "P2",
                            targets: ["T2"]).save(on: app.db)
            }
            do {
                try await Target(version: v, name: "T1").save(on: app.db)
                try await Target(version: v, name: "T-2").save(on: app.db)
            }
            do {
                try await Build(version: v,
                          platform: .iOS,
                          status: .ok,
                          swiftVersion: .v1).save(on: app.db)
                try await Build(version: v,
                          platform: .macosXcodebuild,
                          status: .ok,
                          swiftVersion: .v2).save(on: app.db)
            }
        }
        let v = try await XCTUnwrapAsync(try await VersionResult.query(on: app.db,filterBy: .urls(["1"])).first?.version)

        // MUT
        let res = try XCTUnwrap(
            PackageCollection.Package.Version(version: v, license: .init(name: "MIT", url: "https://foo/mit"))
        )

        // validate the version
        XCTAssertEqual(res.version, "1.2.3")
        XCTAssertEqual(res.summary, "Bar")
        XCTAssertEqual(res.verifiedCompatibility, [
            .init(platform: .init(name: "ios"), swiftVersion: .init("5.8")),
            .init(platform: .init(name: "macos"), swiftVersion: .init("5.9")),
        ])
        XCTAssertEqual(res.license, .init(name: "MIT", url: URL(string: "https://foo/mit")!))
        XCTAssertEqual(res.createdAt, Date(timeIntervalSince1970: 0))

        // The spec requires there to be a dictionary keyed by the default tools version.
        let manifest = try XCTUnwrap(res.manifests[res.defaultToolsVersion])

        // Validate the manifest.
        XCTAssertEqual(manifest.packageName, "Foo")
        XCTAssertEqual(
            manifest.products,
            [.init(name: "P1", type: .library(.automatic), targets: ["T1"]),
             .init(name: "P2", type: .library(.automatic), targets: ["T2"])])
        XCTAssertEqual(
            manifest.targets,
            [.init(name: "T1", moduleName: "T1"),
             .init(name: "T-2", moduleName: "T_2")])
        XCTAssertEqual(manifest.toolsVersion, "5.3")
        XCTAssertEqual(manifest.minimumPlatformVersions, [.init(name: "ios", version: "14.0")])
    }

    func test_Package_init() async throws {
        // Tests PackageCollection.Package initialisation from App.Package
        // setup
        do {
            let p = Package(url: "1")
            try await p.save(on: app.db)
            try await Repository(package: p,
                                 license: .mit,
                                 licenseUrl: "https://foo/mit",
                                 readmeHtmlUrl: "readmeUrl",
                                 summary: "summary")
            .save(on: app.db)
            let v = try Version(package: p,
                                latest: .release,
                                packageName: "Foo",
                                reference: .tag(1, 2, 3),
                                toolsVersion: "5.3")
            try await v.save(on: app.db)
            try await Product(version: v,
                              type: .library(.automatic),
                              name: "product").save(on: app.db)
        }
        let result = try await XCTUnwrapAsync(
            try await VersionResult.query(on: app.db, filterBy: .urls(["1"])).first
        )
        let group = VersionResultGroup(package: result.package,
                                       repository: result.repository,
                                       versions: [result.version])

        // MUT
        let res = try XCTUnwrap(
            PackageCollection.Package(resultGroup: group,
                                      keywords: ["a", "b"])
        )

        // validate
        XCTAssertEqual(res.keywords, ["a", "b"])
        XCTAssertEqual(res.summary, "summary")
        XCTAssertEqual(res.readmeURL, "readmeUrl")
        XCTAssertEqual(res.license?.name, "MIT")
        // version details tested in test_Version_init
        // simply assert count here
        XCTAssertEqual(res.versions.count, 1)
    }

    func test_groupedByPackage() async throws {
        // setup
        // 2 packages by the same author (which we select) with two versions
        // each.
        do {
            let p = Package(url: "2")
            try await p.save(on: app.db)
            try await Repository(
                package: p,
                owner: "a"
            ).save(on: app.db)
            try await Version(package: p, latest: .release, packageName: "2a")
                .save(on: app.db)
            try await Version(package: p, latest: .release, packageName: "2b")
                .save(on: app.db)
        }
        do {
            let p = Package(url: "1")
            try await p.save(on: app.db)
            try await Repository(
                package: p,
                owner: "a"
            ).save(on: app.db)
            try await Version(package: p, latest: .release, packageName: "1a")
                .save(on: app.db)
            try await Version(package: p, latest: .release, packageName: "1b")
                .save(on: app.db)
        }
        let results = try await VersionResult.query(on: app.db, filterBy: .author("a"))

        // MUT
        let res = results.groupedByPackage(sortBy: .url)

        // validate
        XCTAssertEqual(res.map(\.package.url), ["1", "2"])
        XCTAssertEqual(
            res.first
                .flatMap { $0.versions.compactMap(\.packageName) }?
                .sorted(),
            ["1a", "1b"]
        )
        XCTAssertEqual(
            res.last
                .flatMap { $0.versions.compactMap(\.packageName) }?
                .sorted(),
            ["2a", "2b"]
        )
    }

    func test_groupedByPackage_empty() throws {
        // MUT
        let res = [VersionResult]().groupedByPackage()

        // validate
        XCTAssertTrue(res.isEmpty)
    }

    func test_generate_from_urls() async throws {
        try await withDependencies {
            $0.date.now = .init(timeIntervalSince1970: 1610112345)
        } operation: {
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            do {
                let v = try Version(package: pkg,
                                    latest: .release,
                                    packageName: "package",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.4")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "product")
                    .save(on: app.db)
            }
            try await Repository(package: pkg,
                                 license: .mit,
                                 licenseUrl: "https://foo/mit",
                                 summary: "summary").create(on: app.db)

            // MUT
            let res = try await PackageCollection.generate(db: self.app.db,
                                                           filterBy: .urls(["1"]),
                                                           authorName: "Foo",
                                                           collectionName: "Foo",
                                                           keywords: ["key", "word"],
                                                           overview: "overview")

#if compiler(<6)
            await MainActor.run {  // validate
                assertSnapshot(of: res, as: .json(encoder))
            }
#else
            assertSnapshot(of: res, as: .json(encoder))
#endif
        }
    }

    func test_generate_from_urls_noResults() async throws {
        // MUT
        do {
            _ = try await PackageCollection.generate(db: self.app.db,
                                                     filterBy: .urls(["1"]),
                                                     authorName: "Foo",
                                                     collectionName: "Foo",
                                                     keywords: ["key", "word"],
                                                     overview: "overview")
            XCTFail("Expected error")
        } catch let error as PackageCollection.Error {
            XCTAssertEqual(error, .noResults)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_generate_for_owner() async throws {
        try await withDependencies {
            $0.date.now = .init(timeIntervalSince1970: 1610112345)
        } operation: {
            // setup
            // first package
            let p1 = try await savePackage(on: app.db, "https://github.com/foo/1")
            do {
                let v = try Version(id: UUID(),
                                    package: p1,
                                    packageName: "P1-main",
                                    reference: .branch("main"),
                                    toolsVersion: "5.0")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                    .save(on: app.db)
            }
            do {
                let v = try Version(id: UUID(),
                                    package: p1,
                                    latest: .release,
                                    packageName: "P1-tag",
                                    reference: .tag(2, 0, 0),
                                    toolsVersion: "5.2")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                    .save(on: app.db)
                try await Build(version: v,
                                platform: .iOS,
                                status: .ok,
                                swiftVersion: .init(5, 6, 0)).save(on: app.db)
                try await Target(version: v, name: "t1").save(on: app.db)
            }
            // second package
            let p2 = try await savePackage(on: app.db, "https://github.com/foo/2")
            do {
                let v = try Version(id: UUID(),
                                    package: p2,
                                    packageName: "P2-main",
                                    reference: .branch("main"),
                                    toolsVersion: "5.3")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                    .save(on: app.db)
            }
            do {
                let v = try Version(id: UUID(),
                                    package: p2,
                                    latest: .release,
                                    packageName: "P2-tag",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.3")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t2"])
                    .save(on: app.db)
                try await Target(version: v, name: "t2").save(on: app.db)
            }
            // unrelated package
            _ = try await savePackage(on: app.db, "https://github.com/bar/1")
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 license: .mit,
                                 licenseUrl: "https://foo/mit",
                                 owner: "foo",
                                 summary: "summary 1").create(on: app.db)
            try await Repository(package: p2,
                                 defaultBranch: "main",
                                 license: .mit,
                                 licenseUrl: "https://foo/mit",
                                 owner: "foo",
                                 summary: "summary 2").create(on: app.db)
            
            // MUT
            let res = try await PackageCollection.generate(db: self.app.db,
                                                           filterBy: .author("foo"),
                                                           authorName: "Foo",
                                                           keywords: ["key", "word"])
            
#if compiler(<6)
            await MainActor.run {  // validate
                assertSnapshot(of: res, as: .json(encoder))
            }
#else
            assertSnapshot(of: res, as: .json(encoder))
#endif
        }
    }

    func test_generate_for_owner_noResults() async throws {
        // Ensure we return noResults when no packages are found
        // MUT
        do {
            _ = try await PackageCollection.generate(db: self.app.db,
                                                     filterBy: .author("foo"),
                                                     authorName: "Foo",
                                                     keywords: ["key", "word"])
            XCTFail("Expected error")
        } catch let error as PackageCollection.Error {
            XCTAssertEqual(error, .noResults)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_includes_significant_versions_only() async throws {
        // Ensure we only export significant versions
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1147
        // setup
        let p = try await savePackage(on: app.db, "https://github.com/foo/1")
        try await Repository(package: p,
                             defaultBranch: "main",
                             license: .mit,
                             licenseUrl: "https://foo/mit",
                             owner: "foo",
                             summary: "summary").create(on: app.db)
        do {  // default branch revision
            let v = try Version(id: UUID(),
                                package: p,
                                latest: .defaultBranch,
                                packageName: "P1-main",
                                reference: .branch("main"),
                                toolsVersion: "5.0")
            try await v.save(on: app.db)
            try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                .save(on: app.db)
            try await Target(version: v, name: "t1").save(on: app.db)
        }
        do {  // latest release
            let v = try Version(id: UUID(),
                                package: p,
                                latest: .release,
                                packageName: "P1-main",
                                reference: .tag(1, 2, 3),
                                toolsVersion: "5.0")
            try await v.save(on: app.db)
            try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                .save(on: app.db)
            try await Target(version: v, name: "t1").save(on: app.db)
        }
        do {  // older release
            let v = try Version(id: UUID(),
                                package: p,
                                latest: nil,
                                packageName: "P1-main",
                                reference: .tag(1, 0, 0),
                                toolsVersion: "5.0")
            try await v.save(on: app.db)
            try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                .save(on: app.db)
            try await Target(version: v, name: "t1").save(on: app.db)
        }
        do {  // latest beta release
            let v = try Version(id: UUID(),
                                package: p,
                                latest: .preRelease,
                                packageName: "P1-main",
                                reference: .tag(2, 0, 0, "b1"),
                                toolsVersion: "5.0")
            try await v.save(on: app.db)
            try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                .save(on: app.db)
            try await Target(version: v, name: "t1").save(on: app.db)
        }
        do {  // older beta release
            let v = try Version(id: UUID(),
                                package: p,
                                latest: nil,
                                packageName: "P1-main",
                                reference: .tag(1, 5, 0, "b1"),
                                toolsVersion: "5.0")
            try await v.save(on: app.db)
            try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                .save(on: app.db)
            try await Target(version: v, name: "t1").save(on: app.db)
        }

        try await withDependencies {
            $0.date.now = .now
        } operation: {
            // MUT
            let res = try await PackageCollection.generate(db: self.app.db,
                                                           filterBy: .author("foo"),
                                                           authorName: "Foo",
                                                           collectionName: "Foo",
                                                           keywords: ["key", "word"],
                                                           overview: "overview")

            // validate
            XCTAssertEqual(res.packages.count, 1)
            XCTAssertEqual(res.packages.flatMap { $0.versions.map({$0.version}) },
                           ["2.0.0-b1", "1.2.3"])
        }
    }

    func test_require_products() async throws {
        // Ensure we don't include versions without products (by ensuring
        // init? returns nil, which will be compact mapped away)
        let p = Package(url: "1".asGithubUrl.url)
        try await p.save(on: app.db)
        let v = try Version(package: p,
                            packageName: "pkg",
                            reference: .tag(1,2,3),
                            toolsVersion: "5.3")
        try await v.save(on: app.db)
        try await v.$builds.load(on: app.db)
        try await v.$products.load(on: app.db)
        try await v.$targets.load(on: app.db)
        XCTAssertNil(PackageCollection.Package.Version(version: v,
                                                       license: nil))
    }

    func test_require_versions() async throws {
        // Ensure we don't include packages without versions (by ensuring
        // init? returns nil, which will be compact mapped away)
        do {  // no versions at all
            // setup
            let pkg = Package(url: "1")
            try await pkg.save(on: app.db)
            let repo = try Repository(package: pkg)
            try await repo.save(on: app.db)
            let group = VersionResultGroup(package: pkg,
                                           repository: repo,
                                           versions: [])

            // MUT
            XCTAssertNil(PackageCollection.Package(resultGroup: group,
                                                   keywords: nil))
        }

        do {  // only invalid versions
            // setup
            do {
                let p = Package(url: "2")
                try await p.save(on: app.db)
                try await Version(package: p, latest: .release).save(on: app.db)
                try await Repository(package: p).save(on: app.db)
            }
            let res = try await XCTUnwrapAsync(
                try await VersionResult.query(on: app.db, filterBy: .urls(["2"])).first
            )
            let group = VersionResultGroup(package: res.package,
                                           repository: res.repository,
                                           versions: [res.version])

            // MUT
            XCTAssertNil(PackageCollection.Package(resultGroup: group,
                                                   keywords: nil))
        }
    }

    func test_case_insensitive_owner_matching() async throws {
        // setup
        let pkg = try await savePackage(on: app.db, "https://github.com/foo/1")
        do {
            let v = try Version(id: UUID(),
                                package: pkg,
                                latest: .release,
                                packageName: "P1-tag",
                                reference: .tag(2, 0, 0),
                                toolsVersion: "5.2")
            try await v.save(on: app.db)
            try await Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                .save(on: app.db)
        }
        // Owner "Foo"
        try await Repository(package: pkg,
                             defaultBranch: "main",
                             license: .mit,
                             licenseUrl: "https://foo/mit",
                             owner: "Foo",
                             summary: "summary 1").create(on: app.db)

        try await withDependencies {
            $0.date.now = .now
        } operation: {
            // MUT
            let res = try await PackageCollection.generate(db: self.app.db,
                                                           // looking for owner "foo"
                                                           filterBy: .author("foo"),
                                                           collectionName: "collection")

            // validate
            XCTAssertEqual(res.packages.count, 1)
        }
    }

    func test_generate_ownerName() async throws {
        // Ensure ownerName is used in collectionName and overview
        // setup
        // first package
        let p1 = try await savePackage(on: app.db, "https://github.com/foo/1")
        do {
            let v = try Version(id: UUID(),
                                package: p1,
                                latest: .release,
                                packageName: "P1-tag",
                                reference: .tag(2, 0, 0),
                                toolsVersion: "5.2")
            try await v.save(on: app.db)
            try await Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                .save(on: app.db)
            try await Build(version: v,
                            platform: .iOS,
                            status: .ok,
                            swiftVersion: .v2).save(on: app.db)
            try await Target(version: v, name: "t1").save(on: app.db)
        }
        // unrelated package
        try await Repository(package: p1,
                             defaultBranch: "main",
                             license: .mit,
                             licenseUrl: "https://foo/mit",
                             owner: "foo",
                             ownerName: "Foo Org",
                             summary: "summary 1").create(on: app.db)

        try await withDependencies {
            $0.date.now = .now
        } operation: {
            // MUT
            let res = try await PackageCollection.generate(db: self.app.db,
                                                           filterBy: .author("foo"),
                                                           authorName: "Foo",
                                                           keywords: ["key", "word"])

            // validate
            XCTAssertEqual(res.name, "Packages by Foo Org")
            XCTAssertEqual(res.overview, "A collection of packages authored by Foo Org from the Swift Package Index")
        }
    }

    func test_Compatibility() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1215
        // setup
        var builds = [Build]()
        // set all build to failed as a baseline...
        for p in Build.Platform.allActive {
            for s in SwiftVersion.allActive {
                builds.append(
                    .init(versionId: .id0, platform: p, status: .failed, swiftVersion: s)
                )
            }
        }
        // ...then append three successful ones
        builds.append(contentsOf: [
            .init(versionId: .id0, platform: .iOS, status: .ok, swiftVersion: .v3),
            .init(versionId: .id0, platform: .iOS, status: .ok, swiftVersion: .v2),
            .init(versionId: .id0, platform: .iOS, status: .ok, swiftVersion: .v1),
        ])
        // MUT
        let res = [PackageCollection.Compatibility].init(builds: builds)
        // validate
        XCTAssertEqual(res.count, 3)
        XCTAssertEqual(res.map(\.platform).sorted(),
                       [.init(name: "ios"), .init(name: "ios"), .init(name: "ios")])
        XCTAssertEqual(res.map(\.swiftVersion).sorted(),
                       [SwiftVersion.v1, .v2, .v3].map { $0.description(droppingZeroes: .patch) }.sorted())
    }

    func test_authorLabel() async throws {
        // setup
        let p = Package(url: "1")
        try await p.save(on: app.db)
        let repositories = try (0..<3).map {
            try Repository(package: p, owner: "owner-\($0)")
        }

        // MUT & validate
        XCTAssertEqual(
            PackageCollection.authorLabel(repositories: []),
            nil
        )
        XCTAssertEqual(
            PackageCollection.authorLabel(repositories: Array(repositories.prefix(1))),
            "owner-0"
        )
        XCTAssertEqual(
            PackageCollection.authorLabel(repositories: Array(repositories.prefix(2))),
            "owner-0 and owner-1"
        )
        XCTAssertEqual(
            PackageCollection.authorLabel(repositories: repositories),
            "multiple authors"
        )
    }

    func test_sign_collection() async throws {
        try XCTSkipIf(!isRunningInCI && Current.collectionSigningPrivateKey() == nil, "Skip test for local user due to unset COLLECTION_SIGNING_PRIVATE_KEY env variable")

        // setup
        let collection: PackageCollection = .mock

        // MUT
        let signedCollection = try await SignedCollection.sign(collection: collection)

        // validate signed collection content
        XCTAssertFalse(signedCollection.signature.signature.isEmpty)
#if compiler(<6)
        await MainActor.run {
            assertSnapshot(of: signedCollection, as: .json(encoder))
        }
#else
        assertSnapshot(of: signedCollection, as: .json(encoder))
#endif

        // validate signature
        let validated = try await SignedCollection.validate(signedCollection: signedCollection)
        XCTAssertTrue(validated)
    }

    func test_sign_collection_revoked_key() async throws {
        // Skipping until https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1583#issuecomment-1066592057
        // is resolved
        try XCTSkipIf(true)

        // setup
        let collection: PackageCollection = .mock
        // get cert and key and make sure the inputs are valid (apart from being revoked)
        // so we don't fail for that reason
        let revokedUrl = fixtureUrl(for: "revoked.cer")
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: revokedUrl.path))
        let revokedKey = try XCTUnwrap(fixtureData(for: "revoked.pem"))

        Current.collectionSigningCertificateChain = {
            [
                revokedUrl,
                SignedCollection.certsDir
                    .appendingPathComponent("AppleWWDRCAG3.cer"),
                SignedCollection.certsDir
                    .appendingPathComponent("AppleIncRootCertificate.cer")
            ]
        }
        Current.collectionSigningPrivateKey = { revokedKey }

        // MUT
        do {
            let signedCollection = try await SignedCollection.sign(collection: collection)
            // NB: signing _can_ succeed in case of reachability issues to verify the cert
            // in this case we need to check the signature
            // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1583#issuecomment-1048408400
            let validated = try await SignedCollection.validate(signedCollection: signedCollection)
            XCTAssertFalse(validated)
        } catch PackageCollectionSigningError.invalidCertChain {
            // ok
        } catch {
            XCTFail("unexpected signing error: \(error)")
        }
    }

}


private extension PackageCollection {
    static var mock: Self {
        .init(
            name: "Collection",
            overview: "Some collection",
            keywords: [],
            packages: [
                .init(url: "url",
                      summary: nil,
                      keywords: nil,
                      versions: [
                        .init(version: "1.2.3",
                              summary: nil,
                              manifests: [
                                "5.5": .init(toolsVersion: "5.5",
                                             packageName: "foo",
                                             targets: [.init(name: "t",
                                                             moduleName: nil)],
                                             products: [.init(name: "p",
                                                              type: .executable,
                                                              targets: ["t"])],
                                             minimumPlatformVersions: nil)
                              ],
                              defaultToolsVersion: "5.5",
                              verifiedCompatibility: nil,
                              license: nil,
                              author: nil,
                              signer: .spi,
                              createdAt: .t0)
                      ],
                      readmeURL: nil,
                      license: nil)
            ],
            formatVersion: .v1_0,
            revision: nil,
            generatedAt: .t0,
            generatedBy: nil
        )
    }
}
