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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.0/libmpv-xcframeworks_v0.8.0_ios-universal-video-default"
let libmpvChecksums = [
    "Ass": "57c900d20fcfdaa29050770f9eb36abf740d1285c1a43b7639631cdafa28318e",
    "Avcodec": "10b88ae6d237b0e0f3e0274803c6443049627a3bbc3602f1cad9d64901e5a861",
    "Avfilter": "28eb1d91cb985c83e44cad7aee331a7ae776cd16e56167925abb0586a9597fb3",
    "Avformat": "13a7df8d7e4879e8ab10e6eddf2615773744b0bfdf58e4e9702c17da086ace5d",
    "Avutil": "66c04b29db05a95222ada8d2967fd7d9bfdeb1d51c34aae12765e42d3ff3cf0e",
    "Dav1d": "1b716ccbfa105d831b430c4c0d05e5d8e0b2eb3728c7d59e5956530ecdc05235",
    "Freetype": "c97587b4c33b9a44a3e51250a0d2c56d1150cf6468b8efe22a718920633c591f",
    "Fribidi": "45e0e277d07a608e8c873ebab013d8f1d23e1c7a32cc91add61bd2099cd7399d",
    "Harfbuzz": "0dfed702f33581ad958ecc41dab8728824cb642e8f8907ce60dd6b2cf71c8800",
    "Mbedcrypto": "b0672f51b33010afbca027f71f8136e35daf036b909532339ba2626dbd1dde81",
    "Mbedtls": "9445cbf33f0c8a04eb452a5442eabe863a5e5318e81e180493c797f7ef0d8daa",
    "Mbedx509": "19fa3206248d62c57508afdbe0a4e9088ad9c902585ddc059eaad14a1b848fce",
    "Mpv": "bc6e22f53445e75f02ab1d4c947e7efde433333808bbd0f8de9b5c5cb93ac549",
    "Placebo": "68ac365b99634a0d80b7ebc71ffd58a6a2f65c995c8eb4a60ee1a6e251541593",
    "Png16": "72b965993fb803b09d2e1d741fd084a742d3522011f86f8cde63c8c62f78ff50",
    "Swresample": "f4899a5388df8acd2809f52e1530a52141e16698ab862fa1569a719135b3ce68",
    "Swscale": "28c98d94fe89bb132f546d7eb7bb44cf28897035fa160d17288adc97cef447fd",
    "Uchardet": "42635929350ff9661107141f1414e300ad5cc79a161e1b7f6571ef33fd9b0919",
    "Xml2": "5e3ca0770d0e01ca2d8d63585d4adb56caa31bd1ce94c0a4181600ec7593301c"
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
