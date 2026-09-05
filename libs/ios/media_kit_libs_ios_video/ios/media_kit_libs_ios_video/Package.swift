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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.4/libmpv-xcframeworks_v0.8.4_ios-universal-video-default"
let libmpvChecksums = [
    "Ass": "4d8f10902547b98dfad158f9e601666e091d43cf9b3e9a2326ae4c8adbae4089",
    "Avcodec": "2e1ee3bc8fea44844b98d003696870d09cf7b95ba58dd7b3d3388e4e97d4effb",
    "Avfilter": "2264909627b2b0a3ba32b8fe1b67fa2174d5de790909fb41ac9a3421e0d5bbd9",
    "Avformat": "3439d68952fbbc7663932e6a7a6ea28c84be9580e718926099533d16f1fcee9d",
    "Avutil": "fe13da1cb5a7e9f7c498ae9b42a0c0c0e8820978922299a6577fd822bdd5eb2d",
    "Dav1d": "d4bb71523b2ba5cf8d5f2f255fd19cc6b285a53c2e801acf2415818facd409ce",
    "Freetype": "9ec33053d3cacae8dd63f799f83c27676edd5cb394d066e8c53e78ebf89ca9ed",
    "Fribidi": "5c7378f8130b10291a6e231422242654e4128fe0320f4fdeeeab82932413b090",
    "Harfbuzz": "6ec40aa3ef877f2ee069730f436b92f35493b0a140d5cf2685f9a9186b6843e4",
    "Mbedcrypto": "3a9f84a36a0bb5b59a7e113f33b108474166d155f3899df542a9c6e46b4cbc73",
    "Mbedtls": "eeaebd228f9cc2cac77cfdcb11ac9e2c6e72552bc9374629b7c65f69dcf354a4",
    "Mbedx509": "74e2292d424ff99ab5c90505dfc55d04aa5946d60baf85b7d632551f13f950b4",
    "Mpv": "cd757e269b154d0190caaa2d334174ce4ec1aad5835f50a36fbb0e006f592fdb",
    "Placebo": "0fc302ef90cd0d76e2e840ab4cea513a3f2417b67cc544978cc6cf520e02fdf9",
    "Png16": "aa5560da534a253e8d40b296b9be92836c3452d5027f069b0a36a50f859ba766",
    "Swresample": "6273b4970fca0006e3f0db79a98a4ecd802525ff897597881d94fe14631d8310",
    "Swscale": "2a0a0c31d2324a75b1c400a008f39ade2442eb40c41c55b4c0c30f2c7882e29f",
    "Uchardet": "9cc2f1a62f4a89c76897eedcfa0f67d543660258eefe21b854de38a8bc1991f7",
    "Xml2": "cb4ab79efc8ead8fcabc51e8118c71647e1e6e6567f7537802e7ef220d2c63fa"
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
