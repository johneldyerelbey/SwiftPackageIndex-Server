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

import Fluent
import Vapor


protocol Referencable {}

extension Build: Referencable {}
extension Product: Referencable {}
extension Version: Referencable {}
extension Joined: Referencable {}

struct Ref<M: Referencable, R: Referencable>: Referencable {
    private(set) var model: M
}
struct Ref2<M: Referencable, R1: Referencable, R2: Referencable>: Referencable {
    private(set) var model: M
}


// TODO: move
extension Ref where M == Joined<Package, Repository>, R == Version {
    static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<M> {
        M.query(on: database)
            .with(\.$versions)
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
            .first()
            .unwrap(or: Abort(.notFound))
    }
}


extension Ref where M == Joined<Package, Repository>, R == Ref2<Version, Build, Product> {
    static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<Self> {
        M.query(on: database)
            .with(\.$versions) {
                $0.with(\.$products)
                $0.with(\.$builds)
            }
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
            .first()
            .unwrap(or: Abort(.notFound))
            .map(Self.init(model:))
    }
}


extension Ref where M == Joined<Package, Repository>, R == Ref2<Version, Build, Product> {
    var package: Package { model.package }
    var repository: Repository? { model.repository }
    var versions: [Version] { package.versions }
}


extension PackageController {
    typealias PackageResult = Ref<Joined<Package, Repository>, Ref2<Version, Build, Product>>
}
