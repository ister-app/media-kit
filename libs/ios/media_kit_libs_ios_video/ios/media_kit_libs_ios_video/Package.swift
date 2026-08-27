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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.3/libmpv-xcframeworks_v0.8.3_ios-universal-video-default"
let libmpvChecksums = [
    "Ass": "3a5c77d9a6714a0d0cec5d98b481fb88f5ea4bfa443329e422cf075827b42b6f",
    "Avcodec": "58319a674f755bc42c7d241dd21ce3b8aa0e6d064929f07e8edc92ae34238636",
    "Avfilter": "1bb98c7c9129b22003d342a4dd9b2a60c82e11772f9b9595dfad3ac2b384c9eb",
    "Avformat": "06d0555c9add4805fba5e239a0cdb52d3ace2df21fe83be785529a3da4ce2563",
    "Avutil": "5f3c753c307a0135a5f1800b1cd62a2707bb27fcbacf49b85f7febc3b5436c7a",
    "Dav1d": "7511781265810660bb4c25c6da25932814a562131bd1a5d63bb07b572b3928c2",
    "Freetype": "8fb57b75eab612c1ee169e6bbaa5aeb5b06cd40f7cd1287a92bb6027ed5c3373",
    "Fribidi": "7e00135ff2214e5c985d56eaac6c2f970d8de6a42b9a1f4f041ecdceefe79f0a",
    "Harfbuzz": "8e18648979cb7621a204f936b15036db3cdfe306ae7a1760ff347b776566b3c7",
    "Mbedcrypto": "da2c627cff4e006e9de8401583c646104f0df9af35b94e793e8613be52dabfc4",
    "Mbedtls": "743162ef99b0125c8fa112ff556f35b8cd037171f0a077e0fefad79e99a05973",
    "Mbedx509": "3af4b3e7d51e73ff5380abf14b887dca3af1b425a1827892b3b6960d6b186dfc",
    "Mpv": "2f792242206f409399536712ff797bd19bc0299713bad8367b728c65050eba27",
    "Placebo": "9ed60eb3c233ffedebf0d215f961bf9d7576e2c8f5bc31e92769ba4857be5582",
    "Png16": "9dadcfe5cf695a27558656ebcff07382087f557cc670868299beb3ba0e4e814a",
    "Swresample": "e62cd8c51696185ed22d39032952989ffc6df64f1a2a0a0b6e731bd9974e8563",
    "Swscale": "9d65a3bd1dba879f909ca303daef1382a39b35796aa45288d2301d8a0418ed3d",
    "Uchardet": "2e06e403faa4a4b2b8ebec67411d6535608e48381849ada1ab2bde607584844c",
    "Xml2": "9d0f1ce20997101c9decc21ae1cda076b7a01ad82d5905c19075383ed738a813"
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
