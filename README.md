# Pica Comic

[![flutter](https://img.shields.io/badge/flutter-3.41.6-blue)](https://flutter.dev/)
[![License](https://img.shields.io/github/license/Pacalini/PicaComic)](https://github.com/Pacalini/PicaComic/blob/master/LICENSE)
[![Download](https://img.shields.io/github/v/release/pininkara/PicaComic)](https://github.com/pininkara/PicaComic/releases)
[![stars](https://img.shields.io/github/stars/Pacalini/PicaComic)](https://github.com/Pacalini/PicaComic/stargazers)

A comic app with multiple sources built with flutter.

## nhentai Cloudflare 验证修复（2026-10-07）

### 错误报告

打开 nhentai 画廊提示“需要进行 Cloudflare 验证”；点击“继续”在 WebView
验证后自动返回，应用却仍提示验证。反复继续可能触发 HTTP 429。

旧实现通过标题回调和 `document.head` 中的一段文本判断完成，只检查
`cf_clearance` 是否存在，可能把残留 Cookie 当作成功；用户手动退出也会重试。
验证后把 Cookie/UA 复制到 Dio 再读取页面，无法完整复用原生浏览器的会话环境。

### 修复情况

- 在页面加载完成后检查挑战 DOM、页面来源及 nhentai 内容，再保存会话并返回。
- 验证窗口只允许打开一次；重叠回调只完成一次；手动取消不重试。
- 清除同站点所有路径的旧 `cf_clearance`，保留登录 Cookie。
- Android/iOS 遇到 Dio 挑战后使用原生 WebView 读取；验证后的 GET 继续使用
  相同浏览器 Cookie 存储，不再立即切回 Dio。浏览器请求有超时并释放实例。
- 429 遵守 `Retry-After`（秒数或 HTTP 日期）；缺失时冷却 60 秒。
  冷却期间重试不发送网络请求。不会自动重复提交验证。

### APK 与验证

[Android 构建工作流](https://github.com/pininkara/PicaComic/actions/workflows/android-cloudflare.yml)
运行回归测试、静态检查，构建并验证 APK 签名，上传通用、arm64-v8a 和 x86_64
APK 以及 SHA256SUMS。该工作流用于开发验证，产物保留 30 天。持续发布的 APK 请从
[本仓库 Releases](https://github.com/pininkara/PicaComic/releases) 下载，见下方自动发布说明。

修复测试包使用 `com.github.pacalini.pica_comic.cf_fix`，采用 Android 调试密钥签名的
release 构建，可与原版并存，不能覆盖原版；需要数据时请先从原版导出，再导入测试包。

回归测试覆盖重复完成、取消、加载失败、旧 Cookie 覆盖和 429 冷却。
验证结果：2026-10-07 的 [Actions 构建 #1](https://github.com/pininkara/PicaComic/actions/runs/37573017860)
成功完成。13 项回归测试全部通过；改动文件的静态分析没有错误（3 条非致命提示）；
release APK 编译、签名检查和上传均成功，下载后也核对了全部 APK 的 SHA-256。
构建对应源码提交 `89f704bc328a61855bde9738d82e8ffd842a855c`。

[下载 APK 压缩包](https://github.com/pininkara/PicaComic/actions/runs/37573017860/artifacts/11460874286)
（GitHub Actions 产物，有效期至 2026-11-06）：

| 文件 | 内容 |
| --- | --- |
| `PicaComic-4.2.11-cf-fix.apk` | 通用 APK |
| `PicaComic-4.2.11-cf-fix-arm64-v8a.apk` | ARM64 APK |
| `PicaComic-4.2.11-cf-fix-x86_64.apk` | x86_64 APK |
| `SHA256SUMS.txt` | 每个 APK 的校验值 |

真实设备的 Cloudflare 验证、画廊打开、评论和登录
仍需实机确认；测试不访问线上 nhentai，不保证绕过站点未来的挑战策略。
如果已有 429，请等待界面提示的冷却时间后再验证。

**Forked from [nyne](https://github.com/wgh136), provide extended support & fix, no guaranteed roadmap.**

## Download

从 [本仓库 Releases](https://github.com/pininkara/PicaComic/releases) 下载 APK。
通常选通用 APK；ARM64 设备可选文件名带 `arm64-v8a` 的包，x86_64 设备或模拟器
选择 `x86_64`。每个 Release 同时提供 `SHA256SUMS.txt`。
首次配置签名并成功运行发布工作流之前，本仓库可能还没有 Release；
上面的 Cloudflare 修复测试包仍可用于测试。


<a href="https://github.com/pininkara/PicaComic/releases">
<img src="https://user-images.githubusercontent.com/69304392/148696068-0cfea65d-b18f-4685-82b5-329a330b1c0d.png"
alt="Get it on GitHub" align="center" height="80" /></a>

<a href="https://github.com/Pacalini/PicaComic/blob/master/INSTALL.md#obtainium">
<img src="https://github.com/ImranR98/Obtainium/blob/main/assets/graphics/badge_obtainium.png"
alt="Get it on Obtainium" align="center" height="54" />
</a>

An [AUR package](https://aur.archlinux.org/packages/pica-comic-bin) is packed by [Lilinzta](https://github.com/Lilinzta):
```shell
paru -S pica-comic-bin
```

## Build

1. Clone the repository
```shell
git clone https://github.com/pininkara/PicaComic
```
2. Install flutter: https://docs.flutter.dev/get-started/install
3. Build Application: https://docs.flutter.dev/deployment

## Android APK 自动发布

[Android APK Release](https://github.com/pininkara/PicaComic/actions/workflows/android-release.yml)
在**推送任意新的 git tag**时自动运行，也支持在 Actions 页面点击 **Run workflow**，
选择 `master` 并填写仓库中**已存在的 tag**。手动输入分支名或不存在的 tag 会失败；
工作流不会自动创建 tag。工作流合并到默认分支后，手动触发入口才会显示。

### 首次配置签名

在仓库 **Settings → Secrets and variables → Actions → Repository secrets** 设置：

| Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 固定 Android keystore 文件的 Base64 内容 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 签名密钥别名，例如 `release` |
| `ANDROID_KEY_PASSWORD` | 该密钥的密码 |

可使用已有密钥，或在自己的电脑生成一次并妥善备份（密码由 keytool 交互输入）：

```shell
keytool -genkeypair -v -keystore pica-release.jks -storetype JKS \
  -alias release -keyalg RSA -keysize 2048 -validity 10000
base64 < pica-release.jks > pica-release.jks.base64
```

将 `.base64` 文件的完整内容填入 `ANDROID_KEYSTORE_BASE64`，不要提交 keystore、
Base64 文件或密码到 git。缺少任一 Secret 时工作流会在编译前失败；
自动发布始终使用固定密钥签名，不会退回临时调试密钥。
后续发布必须继续使用相同密钥，才能覆盖安装更新。

Release APK 保留修复包包名 `com.github.pacalini.pica_comic.cf_fix`，与原版并存。
之前从 Actions 下载的 Cloudflare 测试 APK 使用调试签名，不能直接被新密钥签名的
Release 覆盖：先在应用内导出数据，卸载旧测试包，再安装 Release 并导入数据。

### 推送 tag 或手动发布

先确保要发布的提交包含新工作流及 Android 修复；推荐使用 `vX.Y.Z` 格式：

```shell
git switch master
git pull --ff-only origin master
git tag -a v4.2.12 -m "PicaComic 4.2.12"
git push origin v4.2.12
```

该命令会触发发布；示例版本号请按实际版本修改。
若已经推送 tag，可在 **Actions → Android APK Release → Run workflow** 填写它。
`prerelease` 可手动勾选；`v4.2.12-beta.1` 这类 tag 自动标记为预发布。

工作流会解析轻量或带注释 tag，检出其确切提交，使用 Flutter 3.41.6 / Java 17
运行测试并编译 APK，再验证签名与 SHA-256，发布到对应 tag 的 GitHub Release。
发布先创建草稿，全部附件上传成功后才公开；失败草稿可重试。
已公开的同名 Release 不覆盖附件，再次发布更新请创建新 tag。
稳定版本发布时设为 Latest；预发布不替换 Latest。

`vX.Y.Z`（可带预发布后缀）使用 tag 的 `X.Y.Z` 作为 Android 版本名；
其他 tag 使用该提交 `pubspec.yaml` 的版本名。APK 名仍有 `-cf-fix` 后缀。
Android `versionCode` 使用 `1000000 + github.run_number`，让新的工作流运行递增；
同一次运行的 **Re-run jobs** 保持原值。请保持串行发布顺序，避免并行发布旧版本。

每个 Release 提供通用、arm64-v8a、x86_64 APK 及 `SHA256SUMS.txt`，
不依赖 Actions 产物的 30 天保留期限。构建产物也会在 Actions 中保留 30 天便于排错。
下载后可在 APK 所在目录执行：

```shell
sha256sum --check SHA256SUMS.txt
```

只下载单个 APK 时，可计算 `sha256sum 文件名.apk` 并与清单对应条目核对。

## Introduction

### Built-in Comic Source

Pica Comic has 6 built-in comic sources:
- picacg
- e-hentai/exhentai
- jmcomic
- hitomi
- htcomic
- nhentai

### Features

- Browse manga
- Online reading
- Download manga
- Manage local favorites and network favorites
- Data sync(using webdav)
- Reading history

### History

This project initially started as an unofficial app for picacg
and later evolved into an app that supports multiple comic sources.

## Thanks

### Projects
[![Readme Card](https://github-readme-stats.vercel.app/api/pin/?username=tonquer&repo=JMComic-qt)](https://github.com/tonquer/JMComic-qt)

The image restructuring algorithm used to display jm images is from this project.

### Tags Translation
[![Readme Card](https://github-readme-stats.vercel.app/api/pin/?username=EhTagTranslation&repo=Database)](https://github.com/EhTagTranslation/Database)

The Chinese translation of the manga tags is from this project.
