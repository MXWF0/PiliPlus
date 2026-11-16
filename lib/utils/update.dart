import 'dart:io' show Platform;

import 'package:PiliPlus/build_config.dart';
import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

abstract final class Update {
  static final _versionPattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$');

  static List<int>? _version(String name) => _versionPattern
      .firstMatch(name)
      ?.groups(const [1, 2, 3])
      .map((part) => int.parse(part!))
      .toList();

  static int _compareVersions(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      final difference = a[i].compareTo(b[i]);
      if (difference != 0) return difference;
    }
    return 0;
  }

  static Map<String, dynamic>? latestMxRelease(
    Object? releases, {
    required String currentVersion,
  }) {
    if (releases is! List) throw const FormatException('Invalid release list');
    var latest = _version(currentVersion);
    Map<String, dynamic>? selected;
    for (final release in releases.whereType<Map<String, dynamic>>()) {
      if (release['draft'] != false ||
          release['prerelease'] != false ||
          release['tag_name'] is! String ||
          release['assets'] is! List) {
        continue;
      }
      final version = _version(release['tag_name'] as String);
      if (version == null ||
          (latest != null && _compareVersions(version, latest) <= 0)) {
        continue;
      }
      final assets = (release['assets'] as List)
          .whereType<Map<String, dynamic>>()
          .where((asset) {
            if (asset['name'] is! String ||
                asset['browser_download_url'] is! String)
              return false;
            final name = asset['name'] as String;
            if (!name.startsWith('PiliPlus_MX_')) return false;
            final url = Uri.tryParse(asset['browser_download_url'] as String);
            return url != null &&
                url.scheme == 'https' &&
                url.host == 'github.com' &&
                url.port == 443 &&
                url.userInfo.isEmpty &&
                url.path.toLowerCase().startsWith(
                  '/${Constants.mxRepository.toLowerCase()}/releases/download/',
                );
          })
          .toList();
      if (assets.isEmpty) continue;
      latest = version;
      selected = {...release, 'assets': assets};
    }
    return selected;
  }

  // 检查 MX 分支更新
  static Future<void> checkUpdate([bool isAuto = true]) async {
    if (kDebugMode) return;
    SmartDialog.dismiss();
    try {
      final res = await Request().get(
        Api.mxReleases,
        options: Options(
          headers: {
            'user-agent': BrowserUa.mob,
            'accept': 'application/vnd.github+json',
          },
          followRedirects: false,
          extra: {'account': const NoAccount()},
        ),
      );
      final data = latestMxRelease(
        res.data,
        currentVersion: BuildConfig.versionName,
      );
      if (data == null) {
        if (!isAuto) SmartDialog.showToast('暂无更新的 MX 版');
      } else {
        SmartDialog.show(
          animationType: SmartAnimationType.centerFade_otherSlide,
          builder: (context) {
            final colorScheme = ColorScheme.of(context);
            Widget downloadBtn(String text, {String? ext}) => TextButton(
              onPressed: () => onDownload(data, ext: ext),
              child: Text(text),
            );
            return AlertDialog(
              title: const Text('发现 MX 版更新'),
              content: SizedBox(
                height: 280,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['tag_name']}',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Text('${data['body']}'),
                      TextButton(
                        onPressed: () => PageUtils.launchURL(
                          '${Constants.mxSourceCodeUrl}/commits/main',
                        ),
                        child: Text(
                          "点此查看完整更新(即commit)内容",
                          style: TextStyle(color: colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (isAuto)
                  TextButton(
                    onPressed: () {
                      SmartDialog.dismiss();
                      GStorage.setting.put(SettingBoxKey.autoUpdate, false);
                    },
                    child: Text(
                      '不再提醒',
                      style: TextStyle(color: colorScheme.outline),
                    ),
                  ),
                TextButton(
                  onPressed: SmartDialog.dismiss,
                  child: Text(
                    '取消',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ),
                if (Platform.isWindows) ...[
                  downloadBtn('zip', ext: 'zip'),
                  downloadBtn('exe', ext: 'exe'),
                ] else if (Platform.isLinux) ...[
                  downloadBtn('rpm', ext: 'rpm'),
                  downloadBtn('deb', ext: 'deb'),
                  downloadBtn('targz', ext: 'tar.gz'),
                ] else
                  downloadBtn('下载 MX 版'),
              ],
            );
          },
        );
      }
    } on DioException catch (error) {
      debugPrint('MX update check failed: $error');
      if (!isAuto) SmartDialog.showToast('无法连接 MX 更新源');
    } on FormatException catch (error) {
      debugPrint('MX update response is invalid: $error');
      if (!isAuto) SmartDialog.showToast('MX 更新源返回异常');
    }
  }

  // 下载适用于当前系统的安装包
  static Future<void> onDownload(Map data, {String? ext}) async {
    SmartDialog.dismiss();
    try {
      void download(String plat) {
        if (data['assets'].isNotEmpty) {
          for (Map<String, dynamic> i in data['assets']) {
            final String name = i['name'];
            final matchesPlatform = Platform.isAndroid
                ? name.endsWith('.apk') &&
                      (name.contains(plat) ||
                          (plat == 'arm64-v8a' &&
                              RegExp(r'^PiliPlus_MX_\d+\.\d+\.\d+\.apk$')
                                  .hasMatch(name)))
                : name.contains(plat);
            if (matchesPlatform &&
                (ext == null || ext.isEmpty ? true : name.endsWith(ext))) {
              PageUtils.launchURL(i['browser_download_url']);
              return;
            }
          }
          throw UnsupportedError('platform not found: $plat');
        }
      }

      if (Platform.isAndroid) {
        // 获取设备信息
        AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
        // [arm64-v8a]
        download(androidInfo.supportedAbis.first);
      } else {
        download(Platform.operatingSystem);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('download error: $e');
      PageUtils.launchURL('${Constants.mxSourceCodeUrl}/releases');
    }
  }
}
