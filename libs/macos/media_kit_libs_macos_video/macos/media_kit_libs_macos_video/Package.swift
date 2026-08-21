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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.2/libmpv-xcframeworks_v0.8.2_macos-universal-video-default"
let libmpvChecksums = [
    "Ass": "8b982d9a0ad44b1d6200464a03aa453bf6534ad5a9a10f5b5e7733236d992e9a",
    "Avcodec": "00251f2965b0e31265c560a076893e940937851471c352263979e0ee11736a1b",
    "Avfilter": "6d2d9967970262d3b23e4f7a9c5ee058e3694b8b99fdba64344a80afd78c4e0f",
    "Avformat": "69d522f12c259e1993b2880bca2af7a27c8489331ae19a52620de888e02cf926",
    "Avutil": "5a4321ab2d3bad1ae089c0dfeb77c49425a851d88d03b126c05d8772b846613e",
    "Dav1d": "e7a54f71dc83de834ef6828fc0d0f355875f7440181bacfecdfd68ac7c1a1dac",
    "Freetype": "16f7b547ceffe9d46c6355969fd103630c9aca2baa473a106688778036f21116",
    "Fribidi": "aa779cd3fa9f7c8c95115caf8cbcd80170ad32c77b51998106a2ef9ca20c1c10",
    "Harfbuzz": "dcc21b8b0b1bf6c345200ab9d0695861b5aeff5cfadf5c1a513132cf2e17c3c4",
    "Mbedcrypto": "2ff4ca0bd0d2dd9b6577724ef11379b1b3880f106bfcb61c854a3cae23b9fd56",
    "Mbedtls": "f097633391f1808069c54ad126d8e19ca60546646f5f0f6d890e0e72a614c2fa",
    "Mbedx509": "e970895f9353c2232338c066eea1b56af989f2c19fb1edea16aac7ad574ce69d",
    "Mpv": "5d364a6e5e9d472f9016ccf486b8181fb09ef9fbecb8c45843aca7cee44cc99d",
    "Placebo": "067078472f54519369bfab5b1fbd80d968cf1aa18d71ae5f00abfd5b88c2dcb2",
    "Png16": "cc98d526d97d2b408cadefed93584c04d10bafab9629498bcf148fb6c6f43272",
    "Swresample": "907c512b982e028d7af25d2f9b6c45a58f33802773dc4325884c4dd8877da778",
    "Swscale": "3a2df0fd10a990d170ae7f16c49b130d847eb145dbf03c0120199acdda08a5e6",
    "Uchardet": "716d3730944f04dfed59e8c3acd51735075f0370d5c1d350a2a8a25088cb5bfa",
    "Xml2": "d47d48f8b7422140dd9edea29524200a6675f98a31efea7d434bb2a8671d4bf7"
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
