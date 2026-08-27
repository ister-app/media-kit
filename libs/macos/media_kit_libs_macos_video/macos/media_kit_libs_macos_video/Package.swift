// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let libmpvTargets = [
    "Ass",
    "Avcodec",
    "Avfilter",
    "Avformat",
    "Avutil",
    "Dav1d",
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
    "Swscale",
    "Uchardet",
    "Xml2"
]

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.3/libmpv-xcframeworks_v0.8.3_macos-universal-video-default"
let libmpvChecksums = [
    "Ass": "f56f29d291796aeb1598af2b9b71846268c3d2f5f943dacfcfcd640e0dc7c123",
    "Avcodec": "2e45256b4b012a66319e04bf654b8c880a6762e1f44dca4ab121f4fa23d194d8",
    "Avfilter": "2d202c86b35d4c9f441e4510eff9facd49af4da4c0f00dfd922a3a84a30fae07",
    "Avformat": "24baff4e7cab4322a9eb88ed164996a791652dd399798e865ec668ca46226d18",
    "Avutil": "8639c196bd423864c9fb5c0e9fc954e5117060dd27427737bc80b4bea39a5e49",
    "Dav1d": "9eb6a0dc388e93b95341640e65b0d159287c564be617b3a48cba14a7ae08e345",
    "Freetype": "bda279bb5fda11e52685cdc84fbd32661a36c110b953d2b52753e3bcf0435b31",
    "Fribidi": "e1efdea593ebc779efeba1cfa9dfba126ce857d8a68f70754963fc6b30159eeb",
    "Harfbuzz": "f9fc66aeb7a9f9405852fc0225b93f56d9fde1c1d05c3cb5fa2f79cce3206773",
    "Mbedcrypto": "67eb15618cfb8aab685feb64c1a53a75d29d97668aed9c6d4436cca734507e40",
    "Mbedtls": "fa7c3e1f9eb98065242a4af7a794758548cb37e394a4203ee79dc37f46a403a7",
    "Mbedx509": "d027c8575bb2da6055480e02e0feb01390ac3039550c43534b8116088224f594",
    "Mpv": "94cb96e7421c4a6b6806940f5663f0d3b7eaa18bfc0f75d3f2d82880bf35a9bd",
    "Placebo": "5111f16e861ef396876040ee43d7c7387de58ca30fdb4cdce50f6c469f3779dc",
    "Png16": "edeba5e18852bb0e6108e7d1276563b104adfe7c6a1a137da7578911bf29c186",
    "Swresample": "b02ca2c8a3311e94f03d546bbbc0a3cd12978b690a69a243320bac533b8ef4a0",
    "Swscale": "9a5ccfb427655cd7393f7fd0c647e9247225fcbdbaf5c89de4e7774dde77cd49",
    "Uchardet": "924249bfd5b1bf6e39d7ed281f1f1839a13fb969a214dadffb62121562de07c9",
    "Xml2": "44a54465b1a828a7d695f396f47e33a1119064fe86bbe6d5cfa1675539ad905d"
]
let libmpvProductTargets: [String] = ["media_kit_libs_macos_video"] + libmpvTargets

let package = Package(
    name: "media_kit_libs_macos_video",
    platforms: [
        .macOS("10.9")
    ],
    products: [
        .library(name: "media-kit-libs-macos-video", targets: libmpvProductTargets),
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
            name: "media_kit_libs_macos_video",
            dependencies: libmpvTargets.map { framework in .target(name: framework) },
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
