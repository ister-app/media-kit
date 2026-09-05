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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.4/libmpv-xcframeworks_v0.8.4_macos-universal-audio-full"
let libmpvChecksums = [
    "Ass": "55e7cd52e4f9f54a7ca4b65de94d43392f5f861b57b8bc72e8f181d053361018",
    "Avcodec": "d7b6a0fb74d34151beaf29b893b9acae48e3060b51169e38e3803bf2771d6f4c",
    "Avfilter": "ef4abb947c33fd5b894da3b6456b91e03ad3a86310d5dc89d935b40ea8b3122f",
    "Avformat": "b53877f6df7d31c775a84d2529c5a18173168236620ff26b721e06b274773091",
    "Avutil": "fef9991b1ee7c7881d254715feedb33d2d3f81e942cc555e6652a256e16e2a11",
    "Freetype": "e79ba7f0e22de2217bb9cabd7ae691120e9634d9920e074785796368b01cce72",
    "Fribidi": "ab2acd652cc1d9c91d57e025dc9ff236b78d619d3107c9ae7185361480d79730",
    "Harfbuzz": "2ba85a1506847f169309916174b077c022bce12195c573162bb68104e61225cc",
    "Mbedcrypto": "ef39f37a9ceb9e173c7da12835ae62b2f91e1d0e9465ac8892a4def8279d5928",
    "Mbedtls": "4b40eaf475a465bbfab73be93aafb2eeb8ca1e7843d700f11613764050d490af",
    "Mbedx509": "3b4ed2d19fe56af709382866b2b75ea54b025f3beed5d4512a7a1be5816c6c52",
    "Mpv": "c4a9affdb44f30a68783ca18983e24531f8ccbb587fc2b01aeb2e1b0b674d115",
    "Placebo": "083c7f89c5abb6257658723f89b58d5b7e05c72e1c5ab260e455cec27cb4e8be",
    "Png16": "12421c2e46a60f99339aef372325e3ed75b54d2789f8ab7cd483441b3caa8de6",
    "Swresample": "7c2b45dc9110d508a14531e001ef77f0465702aa25f71b9a2ee6d5587cdd098b",
    "Swscale": "6513f5cd8f3b3a01c7013109ed70af7d81963496ccf65699de9d7610eeb88bec"
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
