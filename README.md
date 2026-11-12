
<div align="center">
  <img src="assets/images/logo/logo.png" width="150" alt="PiliPlus Logo">

  # PiliPlus

  基于 Flutter 开发的哔哩哔哩第三方客户端

  **简体中文** | [English](README.en.md)

  <p>
    <a href="https://github.com/MXWF0/PiliPlus/stargazers">
      <img src="https://img.shields.io/github/stars/MXWF0/PiliPlus?style=flat-square" alt="Stars">
    </a>
    <a href="https://github.com/MXWF0/PiliPlus">
      <img src="https://img.shields.io/github/repo-size/MXWF0/PiliPlus?style=flat-square" alt="Repository Size">
    </a>
    <a href="LICENSE">
      <img src="https://img.shields.io/github/license/MXWF0/PiliPlus?style=flat-square" alt="License">
    </a>
    <a href="https://github.com/bggRGjQaUbCoE/PiliPlus/releases">
      <img src="https://img.shields.io/github/v/release/bggRGjQaUbCoE/PiliPlus?style=flat-square&label=upstream%20release" alt="Upstream Release">
    </a>
  </p>

  [下载安装](#下载安装) · [主要功能](#主要功能) · [界面预览](#界面预览) · [本地构建](#本地构建)

</div>

---

## 界面预览

<div align="center">
  <img src="assets/screenshots/510shots_so.png" width="32%" alt="PiliPlus Screenshot 1">
  <img src="assets/screenshots/174shots_so.png" width="32%" alt="PiliPlus Screenshot 2">
  <img src="assets/screenshots/850shots_so.png" width="32%" alt="PiliPlus Screenshot 3">

  <img src="assets/screenshots/main_screen.png" width="97%" alt="PiliPlus Main Screen">
</div>

## 支持平台

- [x] Android
- [x] iOS
- [x] Pad
- [x] Windows
- [x] Linux

[![Packaging status](https://repology.org/badge/vertical-allrepos/piliplus.svg)](https://repology.org/project/piliplus/versions)

## 主要功能

### 视频播放

- 支持视频、番剧、直播及音频播放
- 多 P 视频、合集播放与播放列表管理
- 倍速播放、长按倍速及播放手势控制
- 画质、音质与解码格式选择
- 硬件加速、画中画与横屏适配
- 离线缓存与播放进度记忆
- 高能进度条与视频缩略图预览
- 弹幕、字幕及高级弹幕设置
- DLNA 投屏与 SponsorBlock
- 跳过番剧片头、片尾
- 视频超分辨率与 AI 原声翻译

### 内容浏览

- 首页推荐、热门视频、番剧及直播
- 用户主页、动态、专栏及图文内容
- 视频搜索、热搜及搜索历史
- 搜索排序与筛选
- 互动视频与课堂视频
- 直播分区与直播弹幕
- 视频标签及相关推荐

### 社区互动

- 视频点赞、投币、收藏与分享
- 评论浏览、回复、点赞及点踩
- 楼中楼评论查看、排序与定位
- 发布、编辑、删除及转发动态
- 富文本编辑、表情及 @用户
- 私信聊天、图片发送与消息管理
- 直播弹幕与表情发送
- 动态话题、投票及 SuperChat

### 个人管理

- 多账号支持
- 观看历史与稍后再看
- 收藏夹创建、编辑、排序与批量管理
- 关注分组与粉丝管理
- 修改个人资料
- Cookie 登录
- WebDAV 设置备份与恢复
- 无痕模式与游客模式

### 个性化设置

- 亮色、暗色及跟随系统主题
- 视频画质、音质及解码方式预设
- 弹幕大小、字幕大小与显示设置
- 播放手势与全屏方向设置
- 图片质量与高帧率设置
- 亮度调节与振动反馈
- 横屏界面适配

<details>
<summary><b>更多功能与优化</b></summary>

- 移动端点击弹幕悬停及互动
- 高级弹幕与会员彩色弹幕
- 弹幕合并与直播弹幕表情
- 视频截取动图与 Live Photo
- 收藏夹及稍后再看批量操作
- 显示视频完整合集与分段信息
- 评论、动态保存及评论笔记
- 带图评论与图文动态
- 评论及动态举报
- 粉丝移除与关注分组管理
- 修改消息及聊天设置
- 屏蔽带货动态、评论及黑名单用户
- 投币动画与三连动画
- 专栏、私信、收藏及评论界面优化
- 视频封面、播放体验及画中画优化
- 系统通知与界面交互优化

</details>

## 下载安装

可通过以下链接获取安装包或源代码：

- **[上游 Releases](https://github.com/bggRGjQaUbCoE/PiliPlus/releases)** — 下载已发布的安装包
- **[本仓库源码](https://github.com/MXWF0/PiliPlus)** — 查看、克隆或下载源代码

## 本地构建

项目使用 Flutter 开发，构建前请安装相应版本的 Flutter SDK。

```bash
git clone https://github.com/MXWF0/PiliPlus.git

cd PiliPlus

flutter pub get

flutter run
```

具体环境要求可参考 [pubspec.yaml](pubspec.yaml)。

## 项目来源

本仓库基于 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 开源项目。

感谢以下项目及其开发者：

- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
- [PiliPalaX](https://github.com/orz12/PiliPalaX)
- [PiliPala](https://github.com/guozhigq/pilipala)

同时感谢所有参与项目开发、维护和贡献的开发者。

## 开源项目致谢

- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
- [media-kit](https://github.com/media-kit/media-kit)
- [dio](https://pub.dev/packages/dio)

## 声明

PiliPlus 为非官方哔哩哔哩第三方客户端，仅供学习与测试使用。

本项目与哔哩哔哩官方无隶属关系，不提供任何破解内容。

项目基于 [GPL-3.0 License](LICENSE) 开源。

## Star History

<div align="center">
  <a href="https://star-history.com/#MXWF0/PiliPlus&Date">
    <picture>
      <source
        media="(prefers-color-scheme: dark)"
        srcset="https://api.star-history.com/svg?repos=MXWF0/PiliPlus&type=Date&theme=dark"
      />
      <source
        media="(prefers-color-scheme: light)"
        srcset="https://api.star-history.com/svg?repos=MXWF0/PiliPlus&type=Date"
      />
      <img
        alt="Star History Chart"
        src="https://api.star-history.com/svg?repos=MXWF0/PiliPlus&type=Date"
      />
    </picture>
  </a>
</div>
