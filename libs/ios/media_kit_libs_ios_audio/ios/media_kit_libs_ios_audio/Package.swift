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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.4/libmpv-xcframeworks_v0.8.4_ios-universal-audio-default"
let libmpvChecksums = [
    "Ass": "ca65ee4a0671c54220c39261792229d59be56067f71cdd46227b9f0c5700ea77",
    "Avcodec": "cb505a5e20ef0a6c28fc9b2d816447c447bf050ac59cfd5a14aba441a42c1abc",
    "Avfilter": "548021a53548054dd7dc44de97eb849ddbe7d54b6b90bf3647d970a6b22fd28c",
    "Avformat": "ac25c57b452b9ec0a64ade621d1ae3b8f5d4076bb2b84b0f6924e90ad1a39215",
    "Avutil": "ee77eac301324c865603632eba5719b0eae8f909e32e798c9237477a50e93b94",
    "Freetype": "1e6379d37abc83d3d73f0580f9564751bec6148940802809734f74cc96421467",
    "Fribidi": "6fd1d2b880b62f3c61a3ac1658c8b3b2b6ac381184381fcdab6136db8e1717c4",
    "Harfbuzz": "432b851394689489e632e4a52c4df565a998d20e104bbe01d469f21863bc74e3",
    "Mbedcrypto": "eea6bc2d8267aa464485ac3d7eff68a88991ef7aa3f0869319be530a89d06f20",
    "Mbedtls": "1becc9248869e760cbbe14fb1292c5bb6eb34225a6dc0d73631764c8e38e8978",
    "Mbedx509": "65cb40fc5a70317e7d54a6cdc0a9bc17e577766f8be9f1a2455dc27944e1c7fd",
    "Mpv": "837ce707cf3888caf2635151410d8d20dc6f77785333b1304988051bd0310df7",
    "Placebo": "06eed4a9da1c2f52dddbd5d24ecc26d3d824fb04748536b005b7a234dd9ca77b",
    "Png16": "bf37c589307e21ff9664df40dcc1a8547591bd258d1de9b5533141ab2c7f7a0e",
    "Swresample": "b11069cab0fcac904d08f920cc5f89acf3d6389cf9e8278e22389f36f4ad2402",
    "Swscale": "c1f21604bb539606385d7b967ea8dc4df46bcfdcf67fb0b4c32c88fc5633ebc4"
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
