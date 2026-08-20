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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.1/libmpv-xcframeworks_v0.8.1_macos-universal-audio-full"
let libmpvChecksums = [
    "Ass": "33398704884f0c48ba2c720c6abe6ddaa1e2e95f760c2037418f10ab5d52dfae",
    "Avcodec": "f3539180d3d2cb7f1fc5d1252e0afc2d726492d3249d116af42869d2e98fd078",
    "Avfilter": "734048a28d6bbda6a3d5d39926fcf23aa68017f28fd528bfd6cec9e6a89d7cc5",
    "Avformat": "4cabdd1733bc974d189299293d8ff08c6d61f80b517e57d6348a828ffb4d935b",
    "Avutil": "9c55616c01dfc747f90d87167ea9a2cd3b0b3a5c951510e3400ec7f778e10992",
    "Freetype": "9c60ef1fa8770be9e4925ded8a15cb067ae70c71356a8d387b81b6e6737fa74e",
    "Fribidi": "96d950ff8b47df2f40703e91a9b51755e244698ab3a10d08a0fcb6fc8565f5a8",
    "Harfbuzz": "0c43d2ce5c4e8a906370ff39ac0d8b3b7edd2478ef9448ae3c3769189959a607",
    "Mbedcrypto": "f8f2a66042be027af2bfd70bf4ed4e422f05b7bd0ec03a7965fb3f361536ec0a",
    "Mbedtls": "5310976c2e8bce6c9d397755a064cbb3d5b37832dfe654e67bda06e1d18b050d",
    "Mbedx509": "b7ef05ffbfcee48f01372680407e9eecb75a6c21eb18eed41893f5989c948199",
    "Mpv": "926e9339e017c7a3512a0b185eaaa17b26fb181b44c408b018cda863f72846cd",
    "Placebo": "d734e3ece93b4a6b6c392bbb0e72760537f4954f437d255bfa06179d1bea69a1",
    "Png16": "42376466dea7607c21b7a66b229e2fd53ee5188a2c6f6a227a412ad1fb901f07",
    "Swresample": "eef7feb87b7970cc1ea382fb3e0e588bdab823792ebf2c29a49d6f85e5cc4f31",
    "Swscale": "9a2812e8aea05e3b4ecc8fa183dfe5de3137a626e4101b9e847630cefb912cc0"
]

let package = Package(
    name: "media_kit_libs_macos_audio",
    platforms: [
        .macOS("10.9")
    ],
    products: [
        .library(name: "media-kit-libs-macos-audio", targets: ["media_kit_libs_macos_audio"] + libmpvTargets),
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
            name: "media_kit_libs_macos_audio",
            dependencies: libmpvTargets.map { framework in .target(name: framework) },
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
