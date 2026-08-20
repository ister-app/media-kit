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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.0/libmpv-xcframeworks_v0.8.0_ios-universal-audio-default"
let libmpvChecksums = [
    "Ass": "e97cc0db9628cc49682e5cadb0e564e93eec14475fd72fedb7bc1d4d8049cb99",
    "Avcodec": "8a06a6d4e83b7bf43c6c6ba6ad12d014defa3f6a70c936eca16da30fb788032f",
    "Avfilter": "504fad8399d273b67b55ecbdaf7d053a62fa6943b66c836649740e25a78754f1",
    "Avformat": "46c8339b0e35c529a3e202617d061dc41dc1213bd31bc6e880fa80adc1ac81c4",
    "Avutil": "6d246530988e1257a4a9341f6b0bc3c8c7cbba096a8cc7722fa9423c0b563cef",
    "Freetype": "6c9d55ce78623af1faed323e3fb77d32895c598769f25d0622d304ae249089d7",
    "Fribidi": "ab7531c5d41c426211285fcd2cfde910ebc0f14e28ca3178b1ca8044271a65b5",
    "Harfbuzz": "ec81d3aae0dd62c224bfbc2931563e840e7da4aa36fe21ecbfb3fdddb8cc84af",
    "Mbedcrypto": "c7681e556392b80f89b9959021a821c38b230e52ff3544e59f0c4d2d7b883b79",
    "Mbedtls": "1428fd50bb3110444d1a6cd24a8150d69b9d8b47024ab105d188e3e092a67965",
    "Mbedx509": "6b15e9ad32c490f0ac910b9558f02835fccb9dda2f1e656d5aef0ed3c5e5cccd",
    "Mpv": "dcea64d8e7d573e4fe99957a8a243d1e084e4180ed4f60688f2fec48d8d43fbd",
    "Placebo": "f40e9ae2bad8c87dabf950e940c7ddd1cf2a3aaabd9562da92db4a71ecea115b",
    "Png16": "7e695dea1eb44f12f8d793525c16e5486a3439e1619b6f29d551f541251328d9",
    "Swresample": "b14e8e6fb4e613cbd839bb03484c9a8eb625bfefe224a6577b40a3adc912b157",
    "Swscale": "2a9e626a79dfe86a3c0abe7d21d3f469a872ae48e0d2827b743ca691226a0e2d"
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
