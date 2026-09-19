# Vendored dependencies

此目录用于保证 NotTerminal 在首次克隆后可以完全离线构建。

| 目录 | 内容 | 固定版本 |
| --- | --- | --- |
| `GhosttySource` | Ghostty 上游完整源码 | `82938b633ba646db38591d969c3c526332bd7e65` |
| `libghostty-spm` | Ghostty 的 Swift/AppKit 封装、资源与构建补丁 | `7e45d27160f9b34aca9ca5c9820e9207482f9f04` |
| `MSDisplayLink` | 屏幕刷新驱动源码 | `87eb0af130744c8cbe2e31b6e1a5bcd659f1c220` |

`libghostty-spm/BinaryTarget/GhosttyKit.xcframework` 只保留 NotTerminal 所需的 macOS 通用静态库，以避免把 iOS、Mac Catalyst 和 visionOS 构建产物一并提交。该文件同时包含 Apple Silicon 与 Intel 架构，单文件大小低于 GitHub 的 100 MB 限制。

根目录 `Package.swift` 及本目录内生效的 Package manifest 均只使用本地路径。README、历史模板和维护脚本中出现的网络地址不会参与普通 `swift build`。

许可证：

- Ghostty：`GhosttySource/LICENSE`
- libghostty-spm：`libghostty-spm/LICENSE`
- MSDisplayLink：`MSDisplayLink/LICENSE`
