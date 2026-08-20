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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.1/libmpv-xcframeworks_v0.8.1_ios-universal-video-default"
let libmpvChecksums = [
    "Ass": "53d0b6f82c6cfef8500467e341618119bf35dcc412338bf739e0ebd7d8ef618c",
    "Avcodec": "28640ec20ee39ab58188292517b57cd185cb748f8b5dea0f08a26603602ffcf9",
    "Avfilter": "4e05b0761e2b90351ce61170f077022f837b95dff42cce15d2ea09fe36ff94a4",
    "Avformat": "69c1e2e6e513384ffd4090a8a4dbde68693565d6697d551c3f5adacc6fae0c1b",
    "Avutil": "3b5ea900b02cec635fd9c2a368699a342ec49dc62fd85c3478b0ad14098f6473",
    "Dav1d": "dc5404e6581b5f034933e18edcb04d665dd8b79ab98989a69441a9e0c3ddba3f",
    "Freetype": "5992550ae69b5e5089d3d8d724f027fb2960950102bd9ba6ad778f3fe86ae758",
    "Fribidi": "807392ccadc0ff10d0688538d86bcdf0b2e5f9e2ca373a02b73e630e334583cd",
    "Harfbuzz": "1e852a6a4d2a6bce2f8377ea432d39b0370a50ad804e083097ee04db89e7f68b",
    "Mbedcrypto": "a9ebae6efe57901bb4f73d0551e7a22f0c4a37d4ae846bb3f9ea7853eb61d125",
    "Mbedtls": "5d84ff5a86ca51aea1b0967b0f404c4a1adf9af3d3336d87240ad6491af38fbf",
    "Mbedx509": "cf87602505c1a45c3ac556688ee2de389f4854d7174fb2ed9ccf1d10f5753683",
    "Mpv": "967bb94cf6e71da45bd6e09814bedb92506b4c93b898938e4a379d818532fc8d",
    "Placebo": "4c2f77d2b32567c4475029cefe62f6e4a47c27233014641afe0e32552ea4b248",
    "Png16": "a974b0bace32cefaf16171d9e607a15f1a6e0c6f373736d36e4330757602779c",
    "Swresample": "7092ce5aad715098d63f764462c72b49676b0018c9eff9a2f2e227a4b0c5e66a",
    "Swscale": "bd394b2f9482c990d8720d9265d10eb83178c65bc223840ccc0b685662f58ce7",
    "Uchardet": "91c99b41e90e41642134f9a4b55296e14c5662bf371a7ab9859cbd161bc8d6c5",
    "Xml2": "bc32707431c5d84ddfd2f82b8be924bdf6fcf4616798371a5cd08cb702b74e0e"
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
