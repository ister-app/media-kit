// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let libmpvTargets = [
    "Ass",
    "Avcodec",
    "Avfilter",
    "Avformat",
    "Avutil",
    "Freetype",
    "Fribidi",
    "Harfbuzz",
    "Mbedcrypto",
    "Mbedtls",
    "Mbedx509",
    "Mpv",
    "Placebo",
    "Png16",
    "Swresample",
    "Swscale"
]

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.1/libmpv-xcframeworks_v0.8.1_ios-universal-audio-default"
let libmpvChecksums = [
    "Ass": "9e3edcdc7c87fd3437a7b20dfac3bf0b6e845cb00de69c76ae3d3edba71cf582",
    "Avcodec": "463ac5c6c5d8884c2d3262b5808d7914941df3265af78b61504c19b17215d9af",
    "Avfilter": "4a3bc56a5389582a43b6ac73250159254a1f254cbaa7c1d1d338fdc4a5c5fe15",
    "Avformat": "a8aefc9771a0491a1576abfc3e8a2607d4460ce95e9b1d64f2c2b2b163c968a6",
    "Avutil": "bc72bd3d5befe91305ff1421031a5e91b4f423cdd28b24b7ed8772686ead632c",
    "Freetype": "21f470bbd58f8f909941cf701759f263eb367280579a5e02eca522d4ff05e251",
    "Fribidi": "bd96836051a5c73513df07ccb4f6c820e14f196268ec8d24f3961d4fd3c75ee0",
    "Harfbuzz": "391ba56e1c9a1e0fc772b7a26812a6b247f486b34336c83af54af19286310f24",
    "Mbedcrypto": "9c7a836107141708048b662934aeab05e67919fcbb67838d3b2714383fe2f156",
    "Mbedtls": "8e9358975abfc205eb9135f1d5dc34301647adf2f97ec16bb826360397d0a33c",
    "Mbedx509": "a85d1eb855089f1ce01cd23f97976014054b6e3d58ed85a83ec3020a935f2dfe",
    "Mpv": "2f8af46410a5dd491d0f2b54f37dc6c9c76ae61ef542d9b3b193bed8bafbf846",
    "Placebo": "3c3b597aa6138feee3509bd2de5b84a3c53a375a460fee28437b1e9b70ba6b34",
    "Png16": "92239c6e9add454f9660020beb8478f9e105a8c24681c8a4b5e1cd3597c59d45",
    "Swresample": "dfd07e416b62e9652f991aaa8524392e6173f1bb280acae5d74af2de34061eea",
    "Swscale": "4acea640302c8133014daeab826efd4ca30390ae855572aeedf6f707ca18c1c2"
]

let package = Package(
    name: "media_kit_libs_ios_audio",
    platforms: [
        .iOS("9.0")
    ],
    products: [
        .library(name: "media-kit-libs-ios-audio", targets: ["media_kit_libs_ios_audio"] + libmpvTargets),
        .library(name: "Mpv", targets: ["Mpv"])
    ],
    dependencies: [],
    targets: libmpvTargets.map { framework in
        .binaryTarget(
            name: framework,
            url: "\(libmpvArtifactBase)_\(framework).zip",
            checksum: libmpvChecksums[framework]!
        )
    } + [
        .target(
            name: "media_kit_libs_ios_audio",
            dependencies: libmpvTargets.map { framework in .target(name: framework) },
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
