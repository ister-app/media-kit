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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.3/libmpv-xcframeworks_v0.8.3_macos-universal-audio-full"
let libmpvChecksums = [
    "Ass": "dae6e549f61195d7019db759d70e035d0bad11a1e3b6fae7d7bc1c5e4383f337",
    "Avcodec": "a4fd8b7e0d7e1439400d15bae194f84d713cff881a7f2eb1885ed883b241bc34",
    "Avfilter": "29d8aa2ec67229a07e4473c511b9ff6fa8e51cefd534cef82e3b78fb6f484d2e",
    "Avformat": "12895b6773925081c3155e4aea97a99508d698e576824b97598c1bfa73487179",
    "Avutil": "1b24887751add847b48d32266c41eb3b83437db005564cf9fb4d73d3b147ba41",
    "Freetype": "dfb32f16e76c26e14854adbd7c51e6d06ced8ff8368b2da7521459b62bea9dfe",
    "Fribidi": "8a74bb09c5b9408f40c5b3545226829bab5c583121d20e2dd80d0249afae71ab",
    "Harfbuzz": "cb05c64adbf5eb308e1d694be25b508f685d3f47e9792f8006eaa48053cb5b85",
    "Mbedcrypto": "3ab407426bc1fc42af43e3d028c23af2102c2994378fb6ada89ff504a3f9e1be",
    "Mbedtls": "b5d00a718f621f15e4fbc27a3e5297568d8e6920f930064fccb81d6a3d717218",
    "Mbedx509": "dab42f7af74060bf5b4deda687bce85020fa3c4755dbe19b37340943b59180a3",
    "Mpv": "b306fba47165ae8480d9af2fc88cb7f3e1216ea23de0035a2491fa3956f4763e",
    "Placebo": "77d3225224dd456db4ed15dfe3292d44abdb44c150e715ade9dc0ce5a8e964a2",
    "Png16": "9913cab780adc3b939d659490375d24291cba4e89290891cffb38593b3d31e0d",
    "Swresample": "0a7fe65a76801e6d7f1d76a8a8b796d0c82ed156b43d74630f08c4166fd74946",
    "Swscale": "f76330dba27f5757445be0af703705d5baa74ecec71776f687f007834333436d"
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
