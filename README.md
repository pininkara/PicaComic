# Pica Comic

[![flutter](https://img.shields.io/badge/flutter-3.41.6-blue)](https://flutter.dev/)
[![License](https://img.shields.io/github/license/Pacalini/PicaComic)](https://github.com/Pacalini/PicaComic/blob/master/LICENSE)
[![Download](https://img.shields.io/github/v/release/Pacalini/PicaComic)](https://github.com/Pacalini/PicaComic/releases)
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
APK 以及 SHA256SUMS。构建结果将在 Actions 的 Artifacts 中提供，保留 30 天。

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

<a href="https://github.com/Pacalini/PicaComic/releases">
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
git clone https://github.com/Pacalini/PicaComic
```
2. Install flutter: https://docs.flutter.dev/get-started/install
3. Build Application: https://docs.flutter.dev/deployment

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
