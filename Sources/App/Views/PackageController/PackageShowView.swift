import Foundation
import Plot


class PackageShowView: PublicPage {

    let model: Model

    init(_ model: Model) {
        self.model = model
    }

    override func pageTitle() -> String? {
        model.title
    }

    override func content() -> Node<HTML.BodyContext> {
        .group(
            .div(
                .class("split"),
                .div(
                    .h2(.text(model.title)),
                    .element(named: "small", nodes: [ // TODO: Fix after Plot update
                        .a(
                            .href(model.url),
                            .text(model.url)
                        )
                    ])
                ),
                .div(
                    .class("license"),
                    .attribute(named: "title", value: model.license.fullName), // TODO: Fix after Plot update
                    .i(.class("icon osi")),
                    .text(model.license.shortName)
                )
            ),
            .hr(),
            .p(
                .class("description"),
                .text(model.summary)
            ),
            .section(
                .class("metadata"),
                .ul(
                    .li(
                        .class("icon author"),
                        .group(model.authorsClause())
                    )
                    ,
                    .li(
                        .class("icon history"),
                        .group(model.historyClause())
                    ),
                    .li(
                        .class("icon activity"),
                        .group(model.activityClause())
                    ),
                    .li(
                        .class("icon products"),
                        .group(model.productsClause())
                    )
                )
            ),
            .element(named: "hr", nodes:[ // TODO: Fix after Plot update
                .attribute(named: "class", value: "short")
            ]),
            .section(
                .class("releases"),
                .ul(
                    .li(.group(model.stableReleaseClause())),
                    .li(.group(model.betaReleaseClause())),
                    .li(.group(model.latestReleaseClause()))
                )
            ),
            .section(
                .class("language_platforms"),
                .h3("Language and Platforms"),
                .ul(
                    .li(
                        .p(
                            "Version ",
                            .a(
                                .href("https://github.com/Alamofire/Alamofire/releases/tag/5.2.0"),
                                .span(
                                    .class("stable"),
                                    .i(.class("icon stable")),
                                    "5.2.0"
                                )
                            ),
                            " supports:"
                        ),
                        .ul(
                            .li(
                                "Swift ",
                                .strong("5"),
                                " and ",
                                .strong("5.2")
                            ),
                            .li(
                                .strong("iOS 10.0+"),
                                ", ",
                                .strong("macOS 10.12+"),
                                ", ",
                                .strong("watchOS 3.0+"),
                                ", and ",
                                .strong("tvOS 10.0+"),
                                "."
                            )
                        )
                    ),
                    .li(
                        .p(
                            "Version ",
                            .a(
                                .href("https://github.com/Alamofire/Alamofire/releases/tag/5.3.1-beta1"),
                                .span(
                                    .class("beta"),
                                    .i(.class("icon beta")),
                                    "5.3.1-beta.1"
                                )
                            ),
                            " and ",
                            .a(
                                .href("https://github.com/Alamofire/Alamofire"),
                                .span(
                                    .class("branch"),
                                    .i(.class("icon branch")),
                                    "master"
                                )
                            ),
                            " support:"
                        ),
                        .ul(
                            .li(
                                "Swift ",
                                .strong("5.2")
                            ),
                            .li(
                                .strong("iOS 13.0+"),
                                ", ",
                                .strong("macOS 10.15+"),
                                ", ",
                                .strong("watchOS 6.0+"),
                                ", and ",
                                .strong("tvOS 13.0+"),
                                "."
                            )
                        )
                    )
                )
            )
        )
    }

}


extension PackageShowView {
    struct Model: Equatable {
        let title: String
        let url: String
        let license: License
        let summary: String
        let authors: [Link]
        let history: History?
        let activity: Activity?
        let products: ProductCounts?
        let releases: ReleaseInfo

        struct Link: Equatable {
            let name: String
            let url: String
        }

        struct DatedLink: Equatable {
            let date: Date
            let link: Link
        }

        struct History: Equatable {
            let since: String  // TODO: use Date and derive on the fly
            let commits: Link
            let releases: Link
        }

        struct Activity: Equatable {
            let openIssues: Link
            let pullRequests: Link
            let lastPullRequestClosedMerged: String
        }

        struct ProductCounts: Equatable {
            let libraries: Int
            let executables: Int
        }

        struct ReleaseInfo: Equatable {
            let stable: DatedLink?
            let beta: DatedLink?
            let latest: DatedLink?
        }
    }
}


extension PackageShowView.Model {
    func authorsClause() -> [Node<HTML.BodyContext>] {
        switch authors.count {
            case 0:
                return ["–"]
            case 1:
                let author = authors.first!
                return ["By ", .a(.href(author.url), .text(author.name)), "."]
            case 2:
                let author1 = authors[0]
                let author2 = authors[1]
                return ["By ", .a(.href(author1.url), .text(author1.name)),
                        " and ", .a(.href(author2.url), .text(author2.name)), "."]
            default:
                let start: [Node<HTML.BodyContext>]
                    = ["By ", .a(.href(authors.first!.url), .text(authors.first!.name))]
                let middle: [[Node<HTML.BodyContext>]] = authors[1..<(authors.count - 1)].map {
                        [", ", .a(.href($0.url), .text($0.name))]
                }
                let end: [Node<HTML.BodyContext>] =
                    [", and ", .a(.href(authors.last!.url), .text(authors.last!.name)), "."]
                return middle.reduce(start) { $0 + $1 } + end
        }
    }

    func historyClause() -> [Node<HTML.BodyContext>] {
        guard let history = history else { return [] }
        return [
            "In development for \(history.since), with ",
            .a(
                .href(history.commits.url),
                .text(history.commits.name)
            ),
            " and ",
            .a(
                .href(history.releases.url),
                .text(history.releases.name)
            ),
            "."
        ]
    }

    func activityClause() -> [Node<HTML.BodyContext>] {
        guard let activity = activity else { return [] }
        return [
            "There are ",
            .a(
                .href(activity.openIssues.url),
                .text(activity.openIssues.name)
            ),
            ", and ",
            .a(
                .href(activity.pullRequests.url),
                .text(activity.pullRequests.name)
            ),
            ". The last pull request was closed/merged \(activity.lastPullRequestClosedMerged)."
        ]
    }

    func productsClause() -> [Node<HTML.BodyContext>] {
        guard let products = products else { return [] }
        return [
            "\(title) contains ",
            .strong(
                .text(pluralize(count: products.libraries, singular: "library", plural: "libraries"))
            ),
            " and ",
            .strong(
                .text(pluralize(count: products.executables, singular: "executable"))
            ),
            "."
        ]
    }

    func stableReleaseClause() -> [Node<HTML.BodyContext>] {
        releases.stable.map { datedLink -> [Node<HTML.BodyContext>] in
            [
                "The latest stable release is ",
                .a(
                    .href(datedLink.link.url),
                    .span(
                        .class("stable"),
                        .i(.class("icon stable")),
                        .text(datedLink.link.name)
                    )
                ),
                ". Released \(datedLink.date) ago."  // FIXME: turn into relative date
            ]
        } ?? []
    }

    func betaReleaseClause() -> [Node<HTML.BodyContext>] {
        releases.beta.map { datedLink -> [Node<HTML.BodyContext>] in
            [
                "The latest beta release is ",
                .a(
                    .href(datedLink.link.url),
                    .span(
                        .class("beta"),
                        .i(.class("icon beta")),
                        .text(datedLink.link.name)
                    )
                ),
                ". Released \(datedLink.date) ago."  // FIXME: turn into relative date
            ]
        } ?? []
    }

    func latestReleaseClause() -> [Node<HTML.BodyContext>] {
        releases.latest.map { datedLink -> [Node<HTML.BodyContext>] in
            [
                "The last commit to ",
                .a(
                    .href(datedLink.link.url),
                    .span(
                        .class("branch"),
                        .i(.class("icon branch")),
                        .text(datedLink.link.name)
                    )
                ),
                ". was \(datedLink.date) ago."  // FIXME: turn into relative date
            ]
        } ?? []
    }
}
