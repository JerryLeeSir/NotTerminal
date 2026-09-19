# NotTerminal

NotTerminal 是一个面向 macOS 的工作空间终端与轻量代码编辑器。

## 构建

仓库已经包含构建应用所需的全部 Ghostty 代码和 macOS 核心库。首次克隆后不需要联网解析 Swift Package，也不需要单独安装 Ghostty 或 Zig。

```bash
git clone https://github.com/JerryLeeSir/NotTerminal.git
cd NotTerminal
make app
open dist/NotTerminal.app
```

也可以只构建或运行测试：

```bash
swift build
swift test
```

开发环境需要 macOS 13 或更高版本，以及能够编译 Swift Tools 6.0 Package 的 Xcode/Swift 工具链。

## 内置 Ghostty

本项目没有在构建时引用远程 Ghostty Package。相关内容位于 `Vendor/`：

- `Vendor/GhosttySource`：Ghostty 上游源码，固定于提交 `82938b633ba646db38591d969c3c526332bd7e65`。
- `Vendor/libghostty-spm`：NotTerminal 使用的 Swift/AppKit 接入层源码，基于提交 `7e45d27160f9b34aca9ca5c9820e9207482f9f04`。
- `Vendor/MSDisplayLink`：终端刷新使用的显示链路源码，基于提交 `87eb0af130744c8cbe2e31b6e1a5bcd659f1c220`。
- `Vendor/libghostty-spm/BinaryTarget/GhosttyKit.xcframework`：由上述 Ghostty 源码构建的 macOS `arm64`/`x86_64` 静态核心库，供普通离线构建直接链接。

普通 NotTerminal 开发不需要重新编译 Ghostty 核心。各上游组件的许可证随源码保留在对应目录中。

## 发布 DMG

使用 Release 配置构建应用并生成带有 `Applications` 快捷方式的 DMG：

```bash
make dmg VERSION=0.1
```

产物位于 `dist/NotTerminal-0.1-macOS.dmg`。
