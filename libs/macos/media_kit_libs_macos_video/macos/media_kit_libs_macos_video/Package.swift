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

let libmpvArtifactBase = "https://github.com/ister-app/libmpv-darwin-build/releases/download/v0.8.0/libmpv-xcframeworks_v0.8.0_macos-universal-video-default"
let libmpvChecksums = [
    "Ass": "d73e16be5a8578728d62500d488cb6a89e0f776cdbc11ce7d58e8180d115a594",
    "Avcodec": "83f77b52c4a709dd8e11c5235009a3d29f19fe85b9a7973825ef27d658660c9d",
    "Avfilter": "f075d75fc825641c8818064c2a35c22afa68f7c907aaa120175ed0f725658eb2",
    "Avformat": "3a37103a349d7753dfba6bfb3f56aeb06ffd4ada862a58b1a39bffad7dc80b96",
    "Avutil": "149ec61680707ee4164afdc6534449ee6417d87ba573839466441bd357c33fcd",
    "Dav1d": "7d0a5dcaa051f2eedb3f3c957250a8083b35497f80de1924253fe81ab8cc3344",
    "Freetype": "6231a310cb0e61e39246171597d40bb48c80cf59b5f0104deb403bf51ba49251",
    "Fribidi": "3681655c3e5776b5fa3b145aedf8786f16e45d9e97fa3eb10e92d259e26a5b54",
    "Harfbuzz": "059093933c08787dece7279187b8c0b4b069542091c7314f0a1b8240cccd9407",
    "Mbedcrypto": "ed0efcaff42ac01ae0f9b9cb53903e50328c899c5bc2cbb58ce31e949b0a61fd",
    "Mbedtls": "874fcdbd133e02c7c0a93714286dfcadeed8161379c8362cb0e148c3bbff5f60",
    "Mbedx509": "d402fd5afdcecb8cb29cfa2e42a7ab23f78a7ee613ced21f68826c799fbabf50",
    "Mpv": "1a322c84be437813f8b228cef5f3aa1c89d1e5ddf9c7f9723731269301e54693",
    "Placebo": "3fb9276761581f05802169961c3227e1e016d5df9f97cc0b39cb71e354fbaf97",
    "Png16": "4ac5ff0ddbde8ece05ac80a3d6ee7518fdaa085492d3371cf17965600683ba02",
    "Swresample": "6406c95a714802fe9d01d1f7c9bc467e826ff2591988fd59ee405cea6ced4ac7",
    "Swscale": "38fea493705595c906852f9a3e38d47c144197592683dbca00b76b9783d50498",
    "Uchardet": "57421d083afbc6affe0cc358ce6138141ae3515eb41740def8ab6f65c283c1fc",
    "Xml2": "625485dc1c8bd2f1fe88beb79371253088c8d8cd03f15479c56a7037f278ef5a"
]
let libmpvProductTargets: [String] = ["media_kit_libs_macos_video"] + libmpvTargets

let package = Package(
    name: "media_kit_libs_macos_video",
    platforms: [
        .macOS("10.9")
    ],
    products: [
        .library(name: "media-kit-libs-macos-video", targets: libmpvProductTargets),
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
            name: "media_kit_libs_macos_video",
            dependencies: libmpvTargets.map { framework in .target(name: framework) },
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
