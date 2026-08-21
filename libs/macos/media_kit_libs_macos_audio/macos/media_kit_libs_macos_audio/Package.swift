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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.2/libmpv-xcframeworks_v0.8.2_macos-universal-audio-full"
let libmpvChecksums = [
    "Ass": "c03c9374b08d47e3161e97e792caaf039245bfd1e4fe914ee560612c8bca7547",
    "Avcodec": "33861cd4168941355a78f0a4121280ad4d9e8145792035bf62b34b63a19e9c4d",
    "Avfilter": "64e5ecd04f038dd852773a7b214878097e157207db4ea2d9d34a26472f1e29d1",
    "Avformat": "dcc6c77da57b0bd0410af64411eb81b96a41e5445fcc84e5f2ba154d56ccca72",
    "Avutil": "57126c727113cc24903096a0ecd38bc959184b7eda740442ef39a55bb31f8409",
    "Freetype": "0238fc4bf4cad9142a054b5b65ff4575804150d4ffc5e0df761093b3244655ae",
    "Fribidi": "95707ca0c978a9775302e2716645b7bfef4bbac7b430c0a2e251fad1a05d703d",
    "Harfbuzz": "bfc8b9b4cf98fb734d7c0688dd50dcca166170a2e77165e7a5494000a3778acc",
    "Mbedcrypto": "7d7cc8729060420d56d5cb29f6a39fa7be3ef05a7c05830914c01f4fb911cf8f",
    "Mbedtls": "38a7bad09495a6f7fa60a99d51047efa11569535e9a00d9306281e01c0326700",
    "Mbedx509": "782febde654159238b28be78db3c09c582d20ad37e3e828e02ce354fd2b0cbe3",
    "Mpv": "a629681788562a8e61b57663d198b3ffd55747672657771b4e1498849c2b3e52",
    "Placebo": "64cfe293fad6026c8b289727a2c369de173861fc4c9fc0f66d28938c084b1373",
    "Png16": "ee9cc307eb817be23f63559bcd23c224bc6c246c4ece42e87c7067de97a74e84",
    "Swresample": "236775fb9e85ba4def6de3383191f09f6802764446bc9c943b52f7985c23a2e7",
    "Swscale": "9e882795ca55aa7e34c5f9b69694d53999dbc9a051ff2bb1e7dbae7332103ce6"
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
