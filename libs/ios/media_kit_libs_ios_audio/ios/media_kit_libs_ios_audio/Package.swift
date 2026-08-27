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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.3/libmpv-xcframeworks_v0.8.3_ios-universal-audio-default"
let libmpvChecksums = [
    "Ass": "2e4f9267bd67766b5e01e08bf87d75a6406edaa9f4b85fb648f2b760fdab7af9",
    "Avcodec": "2ae75f1a5b9d96ffbf3e9c16bb3dce041fb02d0e5b0ad20be5f72222d1c34d65",
    "Avfilter": "09f0364853286440d1acfa3d34f8c729183a5711c6f5428465474645df6ea425",
    "Avformat": "04929638b2972da5acbb5e4da1dcdc40a42df0ecac5f0d65d59ec5e9be904536",
    "Avutil": "3ed183f1a3c0c586b059b5b31fb2813253330934fe1b665ff000a59ffd67469f",
    "Freetype": "9cc79cdab5359d9e769b924573063bec819a0f54697bb6f9d2b59a6df4d7b99c",
    "Fribidi": "0068524bdd7cf724bff6a61bb52860ee55d092acc5a3b979d341c42886af89d3",
    "Harfbuzz": "45795a50ade93e93cec50583b3e62d69c385da50902347bb7fce4b0c360dc230",
    "Mbedcrypto": "6dbb5759ec7c09b74464ae5fe7839838939bc3ce697a8c7034e36170363de0f7",
    "Mbedtls": "0f785edfd574225048b3ffd2dc7d4d8b9360417f0dadd1d14ba3e195e6bf4036",
    "Mbedx509": "9739f8d2862c247c03da77a7fbdb7854211dd6af7aa26c3e43bd734e64ef2778",
    "Mpv": "5018a3d9644a02dde210428f6842b1b1ebc3a854d1d50065955cca6eb2914b07",
    "Placebo": "0faac2fef7855a65babc4ed7c4c6cfa4e56522869e91c6a62134c2ad76826cff",
    "Png16": "777e80a35f1a2497ecbc139ca785e1470e8363d3b5608636cc970172c1d5948a",
    "Swresample": "f595dafbf484c4f5347699cf61593eb0dce13b4e6c0c9697067260fcb5566a40",
    "Swscale": "3b8463871961828949f887029192ec12abf4564048a2244a9fb2dbf54bebce4e"
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
