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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.2/libmpv-xcframeworks_v0.8.2_ios-universal-audio-default"
let libmpvChecksums = [
    "Ass": "38814a738a57e2fa4857965dcfccb62ba6a371160786023c4922d6fe2527e493",
    "Avcodec": "055d89b602de4b1858edf25ea0576d119138e6242c2dc12bc2f62e9d0f803cc3",
    "Avfilter": "3a6dd8fa36e6238f07fb7fc1339444e3df7a0af45b3199d69e904e8e526f19a1",
    "Avformat": "55ea89d15e529c5c500c9fc672373f1df71f1b189065224da4eb5a6f633e302c",
    "Avutil": "d355b8053325af06cc4cfc431427feb9caadb06ecbf89c33aedc2a7549335b7b",
    "Freetype": "507fba35df7dafa9c7d34b76bccc0f32726f977ae185a0af0f408c462ab201d5",
    "Fribidi": "25ccf6e242b3455f14e8da155eda8e5387ed2260b821e3f3b8e46e0186fe4411",
    "Harfbuzz": "5c8562f4a8a62ac9cb6cdc30b76ced58351fee0a1f46421e6eaadd577e859ea0",
    "Mbedcrypto": "578e11cdb357912b51494b0506ca1f130b2eae1c50a851da2d9c4e1a0175ce9b",
    "Mbedtls": "77aa8908ee87e0ffc6a4cf4009b64e0e083f00ddf730ef2b42d853b528b62824",
    "Mbedx509": "48d9864acd018da7178287d883926004440aa97eb1add4ea587d4178497f79a1",
    "Mpv": "d7ac60b6f032500ddf3cff300956122abaf22f4aec35ad16229134becac167a8",
    "Placebo": "8fbe6acf923833d1ae693cc8b1e9869b0b9e94a4cb4b1bbcab6da4200a4a7f64",
    "Png16": "6c88b533d6e04645468102620a5f458c467da85d3c3876ff1b512b21c8e8b49d",
    "Swresample": "1aff58f67d07f0e35ff2d22b73e4cded8b151b0ad8850410accf094875560258",
    "Swscale": "da91edf9c47e6a2d1f92201c0420850546a523b2a0bf7eea26df98c3099a513a"
]

let package = Package(
    name: "media_kit_libs_ios_audio",
    platforms: [
        .iOS("9.0")
    ],
    products: [
        .library(name: "media-kit-libs-ios-audio", targets: ["media_kit_libs_ios_audio"] + libmpvTargets),
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
            name: "media_kit_libs_ios_audio",
            dependencies: libmpvTargets.map { framework in .target(name: framework) },
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
