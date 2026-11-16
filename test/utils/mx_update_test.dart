import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/utils/update.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _release(
  String tag,
  List<Map<String, String>> assets, {
  bool draft = false,
  bool prerelease = false,
}) => {
  'tag_name': tag,
  'draft': draft,
  'prerelease': prerelease,
  'assets': assets,
};

Map<String, String> _asset(
  String name, {
  String repo = 'MXWF0/PiliPlus',
}) => {
  'name': name,
  'browser_download_url':
      'https://github.com/$repo/releases/download/v-test/$name',
};

void main() {
  test('automatic update source is the MX fork', () {
    expect(
      Api.mxReleases,
      'https://api.github.com/repos/MXWF0/PiliPlus/releases',
    );
  });

  test('skips original packages, cross-repository URLs and previews', () {
    final original = _asset('PiliPlus_4.0.0.apk');
    final wrongRepo = _asset(
      'PiliPlus_MX_4.0.0.apk',
      repo: 'bggRGjQaUbCoE/PiliPlus',
    );
    final wanted = _asset('PiliPlus_MX_2.3.0.apk');
    final data = Update.latestMxRelease([
      _release('v4.0.0', [original, wrongRepo]),
      _release('v3.0.0', [_asset('PiliPlus_MX_3.0.0.apk')], prerelease: true),
      _release('v2.4.0', [_asset('PiliPlus_MX_2.4.0.apk')], draft: true),
      _release('v2.2.9', [_asset('PiliPlus_MX_2.2.9.apk')]),
      _release('v2.3.0', [wanted, original, wrongRepo]),
    ], currentVersion: '2.2.0');
    expect(data?['tag_name'], 'v2.3.0');
    expect(data?['assets'], [wanted]);
  });

  test('keeps current MX version when only equal or older packages exist', () {
    expect(
      Update.latestMxRelease([
        _release('v2.2.0', [_asset('PiliPlus_MX_2.2.0.apk')]),
        _release('v2.1.7', [_asset('PiliPlus_MX_2.1.7.apk')]),
      ], currentVersion: '2.2.0'),
      isNull,
    );
  });
}
