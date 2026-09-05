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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.4/libmpv-xcframeworks_v0.8.4_macos-universal-video-default"
let libmpvChecksums = [
    "Ass": "75ed1e084b77a7bfcc9267828bf6ff04f073462aa287c9261a485ec98f26cc1b",
    "Avcodec": "7eb11c45ff562bdfb3344b0afaacf85e0f51e0ada8862436e5d738e628d3ba9d",
    "Avfilter": "2d9f892c3e08c236844b651bd8689be49426551a04a856fd034da5f21b4b4a33",
    "Avformat": "c7c4210ea5b6c34e7d8b23722d7fa9d72379845cd5679df729c9effbf43889a9",
    "Avutil": "736c5923a243e2d69faa522d708eca7e48aa8019c3e26ad049c1b99d593061e4",
    "Dav1d": "4d0d2ec1de37c805833b4dde67d1f410e0e16ff3fff1cdca9987d1e6d2285d11",
    "Freetype": "14dbd23ae22da740940ea30c7d5e39f13b74c903ae83454facf06499e2bf6cb4",
    "Fribidi": "0cfd7a716001548b145519cc0da0802a781ca6045eb6eb2814b7e2359ef82736",
    "Harfbuzz": "2303df58c1dcc35a6ce4077a0efce56a9804c348bec8d3ffac82998978752c91",
    "Mbedcrypto": "4ce0ea4d14b24058dcc485ec64c637cc3df70dada3536faec26ba45838e4af41",
    "Mbedtls": "905415aaf1199cd876f19ec164a26ff481876514fbcf7407710954364b2e657a",
    "Mbedx509": "54a51e721b0f1072e7fafbc37cee2eb2e85951abab4f8543a0715835daa355ac",
    "Mpv": "2462e349eade0d06315af23e656dafb161523146813874e6254d9f171a4d2520",
    "Placebo": "98e8695d48391c9ed682b370bb8f184b0d30e11689f145cf00e2f30adf48adc4",
    "Png16": "aa37a44861c35d259f8072a0cf7200d7e905a426f9aeaaeba3b70c50d6643bfa",
    "Swresample": "7a3599c8ff07ca4a84848b135c8eebd39d8a6b2ecc6c39340defaf6e545f3e0c",
    "Swscale": "75724282c4fa81143a0d3c22463663b068535bcb4f0e273667f9601482b1e271",
    "Uchardet": "588c82a438c98b4d3b5df842cb1a04da5bf02cac3ea9af866f4083ec67e9c43d",
    "Xml2": "210a4f8c0f22752cdbc7d4a51460da5dc55e6d9f06eb2ce792015d1db954ca24"
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
