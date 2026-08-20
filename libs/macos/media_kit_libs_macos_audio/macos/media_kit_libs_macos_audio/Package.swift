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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.0/libmpv-xcframeworks_v0.8.0_macos-universal-audio-full"
let libmpvChecksums = [
    "Ass": "d1f86724b3581389388d8e4be791b1254fd6feaee0f3f602622d566dc7a1b307",
    "Avcodec": "418a1eb0c25474e5369d99e06296d286e695e6da19e964e482cda06ba7d342d5",
    "Avfilter": "7bcd93f00c81eca02d618692f910515d80b9ef28925436c62e04c1c3398261b5",
    "Avformat": "1c7e49d9798ec6f22455c9c21dd212c37fe12838069619db8665dc6d5b6fcd05",
    "Avutil": "554190cf19f3049b3ada516615c0b3d3a4c3cf83539224641f9480a0d09f00c5",
    "Freetype": "3cd29f75c57eb48be2d18fd78460aba58d25fcf2679119790650c0d042dcac0e",
    "Fribidi": "6034fa4bf040e6da2ccc9f267371df4d663869ec77181d3172ea44616a7def1d",
    "Harfbuzz": "da26f7cdb52b662e54065cf9910cb3d81641ca706f4a2212daccfde34fbdc961",
    "Mbedcrypto": "0c6931a4cf674eb83ab7f460beccab2d2000e7695f372935b039aff7b217f2eb",
    "Mbedtls": "71f82da99a3e9faf56f6b5c9c7dddc920631b20123371af4b6e6e0f4dcef8282",
    "Mbedx509": "1307aae500ff6edd03b2faf648e10a52ca90b38fa218e49e2d7db15e71810d21",
    "Mpv": "edba66c2e7464c9a65367b19ff2e54a457563142f9b181a3f34fc186d1079daf",
    "Placebo": "f95893cbb55e9b82da88b4cb787aba408a02e814dd59990237ac2c1dcee88109",
    "Png16": "d38b1f8f68ff0ef6cba71c39aa9208eebbd44d67f4043e8ffb0e4f2de532d284",
    "Swresample": "93849679dce740b7101d972f1cd0b3adcc2d387e88c2198935cb9a48d67bdc34",
    "Swscale": "f9ee305594c348dfdba7cdf7e4b860deaff19032e2af5e7fe0de936d71c71594"
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
