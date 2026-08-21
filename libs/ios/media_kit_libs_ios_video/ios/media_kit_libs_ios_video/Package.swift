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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.2/libmpv-xcframeworks_v0.8.2_ios-universal-video-default"
let libmpvChecksums = [
    "Ass": "cb0e098cc876fb8251bac36fbb3fdf59156691edca98ce6b780c91c5c798062e",
    "Avcodec": "ed819481408e52200a0325a71ac64dac296c8a006d62b491bbbe8e609e976059",
    "Avfilter": "d98450fb7dff78be7937e7e8314eb8c0e1e00d56f53d774dc029bc85c82aceba",
    "Avformat": "8c4c15820cca0153555f0c4e5ffd9828c197d934f55d593e4a78ba8967278e11",
    "Avutil": "971f2f8356c3a0fe24705ae759798e843d19d37e6593989d5055360d6e9eea92",
    "Dav1d": "592d39258e85b70309fbef9c2361f0cfd7be8001f4edb46b387c769a3a3956b0",
    "Freetype": "d3b732c5f5ee653b26efea40a614b7d59e1524489a08883fa0979bcf767e8d66",
    "Fribidi": "07eb75c0ba303581d4f10cb570be5ed85a61861e7467b1917d08774fe7116721",
    "Harfbuzz": "b03f056d710d034b08ac5c5673282cc7c939aa55654772b1ffc0f7319201b4db",
    "Mbedcrypto": "fe51abccece16571f95c9533b1d87940d539e8f85503a29401e592a245f83e42",
    "Mbedtls": "ce6e9f8021a52d098e87728eb983e090897dbb61b3fc32fe01507918e383b9f7",
    "Mbedx509": "81d824258ba708c4d9282dd2cb275b65a310bccd5ce67ab45a1633e1e7285742",
    "Mpv": "44661a2cb73102e114dac4409de1b927c3c08d60da8a3405aa0145be9433f3ef",
    "Placebo": "cce8fdf892068f4ca9551534936393ace6f6225832f0e1f08fadc50c9e1b6c89",
    "Png16": "f7f96301ad4e9152a8a0e948dc39f8426736ed6e63d49e4aefe0cdbb7e5e1495",
    "Swresample": "8195451fe2febd4e8cf4d680578d6882ec6ec7957be10420834db3216422eab6",
    "Swscale": "657a8d3c9ab7c08bf5690bbcb374012db8e914992b0c722801564c87f9696828",
    "Uchardet": "766374fd6f7274fc020eb9491f99731adf52fa65d2cdeeb754b5542c2ff905a1",
    "Xml2": "a77ae278700ea9e930dca6f9de60bd0f3f4c4c1bc9d75ea2bec27a7070c4cf5e"
]
let libmpvProductTargets: [String] = ["media_kit_libs_ios_video"] + libmpvTargets

let package = Package(
    name: "media_kit_libs_ios_video",
    platforms: [
        .iOS("9.0")
    ],
    products: [
        .library(name: "media-kit-libs-ios-video", targets: libmpvProductTargets),
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
            name: "media_kit_libs_ios_video",
            dependencies: libmpvTargets.map { framework in .target(name: framework) },
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
