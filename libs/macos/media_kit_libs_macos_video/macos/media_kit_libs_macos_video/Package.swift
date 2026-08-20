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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.1/libmpv-xcframeworks_v0.8.1_macos-universal-video-default"
let libmpvChecksums = [
    "Ass": "b58ccc1881592830b250af98d621361120c0d399b4f2dca103eebca1f5db0713",
    "Avcodec": "53cb0bde98fbd72e1e82b2fe18f6b6d366d390f5859b3606f5a8c6c8b284640a",
    "Avfilter": "3e1d300ca92f54c3cd80c04fcb22a69b476333fb53cb5a6f68f845c89facea4b",
    "Avformat": "fc7f528fe440065b2c54032bb035cbc4173b4d86172f1dc18bfc189f2fa5aab6",
    "Avutil": "c7f22a28a5186fd35ce60e2784ffb5dd0ad5faf3733b03e667c00ae77d2e8c7b",
    "Dav1d": "884d352c73f746e6bb2a63e34ea5d3062c92c406c345ba55f355db670cc7a1d0",
    "Freetype": "d53a8d119246146dbb68e0ded432f5b9e592c3a7a91d2efa836047ad324da350",
    "Fribidi": "c30cd27dab115c3c1d75ac46f6185322bcd2fd9ece0d93bc8af0ba23d1c5e6ce",
    "Harfbuzz": "3801f24bd69740b9c73bc0ba7dfab22fe39e9333513a8d38343308c5151533cb",
    "Mbedcrypto": "d8c97c7ae4b5121b4cfa692f42347112690a7f71b5cdcd35c6dadb78276aa762",
    "Mbedtls": "cb2c522dc4573777b79599c1bea404c894ef46beac3a896c7efccde8ef587b5b",
    "Mbedx509": "f6a3604a975a439201c922bc76c1134e3ac70e11325918773228eaf9f0487f16",
    "Mpv": "e209ba04218158bc301ca64cb24ad85bdd9b195974959f74d1b3b881bcfdcbfe",
    "Placebo": "a2c1453f1a58a4b02fdae2bfb0acbc149a3efa3e3b410829a664e296058101ed",
    "Png16": "52657eb2e7d8ea7b71df3d7f73a9552b4c0c4a77fd24b1a4d8fe9e8d88e5cada",
    "Swresample": "c5e293422f3a3835a4e1cd8dbbcbdd5af0357e4069c6847d91a11da42a004661",
    "Swscale": "49eb09aba001e33d3ae5727070cdc782a7f7bfde2dde89b8262680239353d36f",
    "Uchardet": "e18d2c5d007cb885acf9f07c443b6677de5aa9835e60dd2341a54aa9100ec80c",
    "Xml2": "976cc22a2ebccab3c1ec17f1d91fce70d1a452e069623a7140819063ba3409ee"
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
