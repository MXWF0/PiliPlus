import 'dart:async' show Timer;
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/main.dart' show webViewEnvironment;
import 'package:PiliPlus/pages/mall/navigation.dart';
import 'package:PiliPlus/pages/mall/view.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class MallWebView extends StatefulWidget {
  const MallWebView({
    super.key,
    required this.onRootBack,
    required this.adapterSource,
    required this.homeStyleSource,
    required this.bottomOverlayInset,
    this.initialUrl,
  });
  final VoidCallback onRootBack;
  final String adapterSource;
  final String homeStyleSource;
  final double bottomOverlayInset;
  final Uri? initialUrl;

  @override
  State<MallWebView> createState() => MallWebViewState();
}

class _MallFrame {
  _MallFrame({required this.current, this.windowId});
  final key = UniqueKey();
  final int? windowId;
  Uri current;
  InAppWebViewController? controller;
  double progress = 0;
  String? failure;
  bool rendererGone = false;
}

class MallWebViewState extends State<MallWebView> with WidgetsBindingObserver {
  late final _frames = [
    _MallFrame(
      current: widget.initialUrl ?? Uri.parse(MallDestination.home.url),
    ),
  ];
  bool _openingPage = false;
  _MallFrame? _backFrame;
  bool _opensSecondary(_MallFrame frame, Uri target) =>
      MallNavigation.opensSecondary(
        frame.windowId == null ? frame.current : _frames.first.current,
        target,
      );
  _MallFrame get _active => _frames.last;
  double _viewportWidth = 0;
  bool _externalPrompt = false;
  Map<String, Object> _webTheme = const {};
  String _themeKey = '';
  Timer? _themeUpdate;

  String get _adapter =>
      '${widget.adapterSource}\nwindow.__piliMallAdapter?.update(${jsonEncode({'width': _viewportWidth, 'bottom': widget.bottomOverlayInset, 'theme': _webTheme, 'homeStyle': widget.homeStyleSource})});';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyMedium!;
    final label = theme.textTheme.labelMedium!;
    final scaler = MediaQuery.textScalerOf(context);
    String cssColor(Color color) {
      final argb = color.toARGB32();
      return '#${(argb & 0xffffff).toRadixString(16).padLeft(6, '0')}${(argb >> 24).toRadixString(16).padLeft(2, '0')}';
    }

    final variables = <String, Object>{
      'surface': cssColor(theme.scaffoldBackgroundColor),
      'card': cssColor(theme.cardTheme.color ?? scheme.surfaceContainerLow),
      'search': cssColor(scheme.surfaceContainerHigh),
      'on-surface': cssColor(scheme.onSurface),
      'on-surface-variant': cssColor(scheme.onSurfaceVariant),
      'outline': cssColor(scheme.outlineVariant.withValues(alpha: .45)),
      'primary': cssColor(scheme.primary),
      'on-primary': cssColor(scheme.onPrimary),
      'primary-container': cssColor(scheme.primaryContainer),
      'on-primary-container': cssColor(scheme.onPrimaryContainer),
      'font-family':
          '${jsonEncode(body.fontFamily ?? 'Roboto')}, system-ui, sans-serif',
      'font-size': scaler.scale(body.fontSize!),
      'label-size': scaler.scale(label.fontSize!),
      'font-weight': body.fontWeight!.value,
      'line-height': body.height!,
      'radius': Style.imgRadius.x,
      'space': Style.cardSpace,
      'gutter': Style.safeSpace,
      'glass': cssColor(
        Color.lerp(scheme.surface, scheme.primary, .06)!.withValues(
          alpha: Pref.advancedMaterials
              ? (scheme.brightness == Brightness.dark ? .67 : .75)
              : 1,
        ),
      ),
      'glass-blur': Pref.advancedMaterials ? 6 : 0,
    };
    final key = jsonEncode(variables);
    if (_themeKey == key) return;
    _themeKey = key;
    _webTheme = variables;
    // AnimatedTheme publishes intermediate colors every frame. Send the settled
    // values once; this is an event debounce, not a polling timer.
    _themeUpdate?.cancel();
    _themeUpdate = Timer(const Duration(milliseconds: 100), () {
      for (final frame in _frames) {
        _adapt(frame);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _themeUpdate?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (final frame in _frames) {
      frame.controller = null;
    }
    super.dispose();
  }

  Future<void> _adapt(_MallFrame frame) async {
    if (const {
          'mall.bilibili.com',
          'show.bilibili.com',
        }.contains(frame.current.host) &&
        frame.controller != null) {
      await frame.controller!.evaluateJavascript(source: _adapter);
    }
  }

  @override
  void didUpdateWidget(covariant MallWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bottomOverlayInset != widget.bottomOverlayInset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _adapt(_active);
      });
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (!Platform.isAndroid) return;
    for (final frame in _frames.toList()) {
      if (state == AppLifecycleState.paused) await frame.controller?.pause();
      if (state == AppLifecycleState.resumed) await frame.controller?.resume();
    }
    if (state == AppLifecycleState.resumed && mounted) await _adapt(_active);
  }

  Future<bool> goBack() async {
    final frame = _active;
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      await frame.controller?.evaluateJavascript(
        source: 'document.activeElement?.blur();',
      );
      await frame.controller?.clearFocus();
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      return true;
    }
    if (await frame.controller?.evaluateJavascript(
          source: 'window.__piliMallAdapter?.dismissOverlay() ?? false;',
        ) ==
        true) {
      return true;
    }
    if (!mounted || frame != _active) return true;
    if (await frame.controller?.canGoBack() == true) {
      if (mounted && frame == _active) {
        _backFrame = frame;
        await frame.controller!.goBack();
      }
      return true;
    }
    if (_frames.length > 1) {
      _close(frame);
      return true;
    }
    return false;
  }

  void _close(_MallFrame frame) {
    if (!_frames.contains(frame)) return;
    if (_frames.length == 1) {
      widget.onRootBack();
      return;
    }
    setState(() => _frames.remove(frame));
    _adapt(_active);
  }

  void _fail(_MallFrame frame, String message, {bool rendererGone = false}) {
    if (!mounted || !_frames.contains(frame) || frame.rendererGone) return;
    setState(() {
      frame
        ..failure = message
        ..progress = 1
        ..rendererGone = rendererGone;
      if (rendererGone) frame.controller = null;
    });
  }

  Future<void> _retry() async {
    final frame = _active;
    if (frame.failure == null) return;
    if (frame.rendererGone) {
      setState(
        () => _frames[_frames.length - 1] = _MallFrame(current: frame.current),
      );
    } else {
      setState(() {
        frame
          ..failure = null
          ..progress = 0;
      });
      await frame.controller!.reload();
    }
  }

  Future<bool> _allow(Uri uri) async {
    if ((MallNavigation.isOfficial(uri) &&
            uri.host == 'passport.bilibili.com' &&
            const {'/login', '/h5-app/passport/login'}.contains(uri.path)) ||
        (uri.scheme == 'bilibili' && uri.host == 'login')) {
      await Get.toNamed('/loginPage');
      return false;
    }
    if (MallNavigation.isOfficial(uri)) return true;
    await _external(uri);
    return false;
  }

  Future<void> _external(Uri uri) async {
    if (_externalPrompt) return;
    _externalPrompt = true;
    try {
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('打开外部链接'),
          content: Text(
            '此环节将使用外部应用打开 ${uri.host.isEmpty ? uri.scheme : uri.host}。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('打开'),
            ),
          ],
        ),
      );
      if (open == true) await PageUtils.launchURL(uri.toString());
    } finally {
      _externalPrompt = false;
    }
  }

  Future<void> _open(MallDestination destination) async {
    if (MallDestination.fromUri(_active.current) == destination) return;
    final target = Uri.parse(destination.url);
    if (MallNavigation.opensSecondary(_active.current, target)) {
      await _openPage(target);
    } else {
      await _active.controller!.loadUrl(
        urlRequest: URLRequest(url: WebUri.uri(target)),
      );
    }
  }

  Future<void> _openPage(Uri uri, {bool restoreParent = false}) async {
    if (_openingPage || !mounted) return;
    _openingPage = true;
    try {
      if (restoreParent && await _active.controller!.canGoBack()) {
        _backFrame = _active;
        await _active.controller!.goBack();
      }
      await Get.to<void>(
        () => MallPage(initialUrl: uri),
        routeName: MallNavigation.pageKind(uri) == MallPageKind.product
            ? '/mallDetail'
            : '/mall/${MallNavigation.pageKind(uri)!.name}',
      );
    } finally {
      _openingPage = false;
    }
  }

  Widget _webView(_MallFrame frame) => InAppWebView(
    key: frame.key,
    windowId: frame.windowId,
    webViewEnvironment: webViewEnvironment,
    initialUserScripts: UnmodifiableListView([
      UserScript(
        source: _adapter,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        forMainFrameOnly: true,
        allowedOriginRules: {
          'https://mall.bilibili.com',
          'https://show.bilibili.com',
        },
      ),
    ]),
    initialSettings: InAppWebViewSettings(
      clearCache: false,
      userAgent: BrowserUa.mob,
      useHybridComposition: false,
      useShouldOverrideUrlLoading: true,
      javaScriptEnabled: true,
      supportMultipleWindows: true,
      javaScriptCanOpenWindowsAutomatically: true,
      useOnRenderProcessGone: true,
      forceDark: ForceDark.OFF,
      algorithmicDarkeningAllowed: false,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
    ),
    initialUrlRequest: frame.windowId == null
        ? URLRequest(url: WebUri.uri(frame.current))
        : null,
    onWebViewCreated: (controller) {
      if (mounted) setState(() => frame.controller = controller);
    },
    onProgressChanged: (_, progress) {
      if (mounted) setState(() => frame.progress = progress / 100);
    },
    onLoadStart: (controller, url) async {
      if (url == null || frame.rendererGone) return;
      final uri = url.uriValue;
      final normalized = MallNavigation.normalize(uri);
      if (frame.windowId != null && _opensSecondary(frame, normalized)) {
        await controller.stopLoading();
        if (mounted && _frames.contains(frame)) {
          _close(frame);
          _openPage(normalized);
        }
        return;
      }
      if (normalized != uri) {
        await controller.stopLoading();
        if (mounted && await _allow(normalized)) {
          await controller.loadUrl(
            urlRequest: URLRequest(url: WebUri.uri(normalized)),
          );
        }
        return;
      }
      if (!MallNavigation.isOfficial(uri) &&
          !(frame.windowId != null && uri.toString() == 'about:blank')) {
        await controller.stopLoading();
        if (mounted) await _allow(uri);
        return;
      }
      if (mounted) {
        setState(() {
          frame
            ..current = uri
            ..failure = null
            ..progress = 0;
        });
      }
    },
    onUpdateVisitedHistory: (controller, url, _) {
      final returning = identical(_backFrame, frame);
      if (returning && url != null) _backFrame = null;
      if (url != null && !returning && _opensSecondary(frame, url.uriValue)) {
        // A same-document router has already committed its history entry.
        // Restore its parent before opening the one native product route.
        _openPage(url.uriValue, restoreParent: true);
        return;
      }
      if (url != null &&
          MallNavigation.isOfficial(url.uriValue) &&
          mounted &&
          !frame.rendererGone) {
        setState(() => frame.current = url.uriValue);
        _adapt(frame);
      }
    },
    onLoadStop: (_, _) async {
      if (mounted) setState(() => frame.progress = 1);
      await _adapt(frame);
    },
    onReceivedError: (_, request, error) {
      if (request.isForMainFrame == true &&
          request.url.uriValue == frame.current) {
        _fail(frame, '网页加载失败（${error.type}），请检查网络后重试');
      }
    },
    onReceivedHttpError: (_, request, response) {
      if (request.isForMainFrame == true &&
          request.url.uriValue == frame.current) {
        _fail(frame, '网页服务返回 ${response.statusCode}，请稍后重试');
      }
    },
    onRenderProcessGone: (_, _) =>
        _fail(frame, '网页渲染进程已退出，请重新加载', rendererGone: true),
    shouldOverrideUrlLoading: (controller, action) async {
      if (!action.isForMainFrame) return NavigationActionPolicy.ALLOW;
      final target = action.request.url?.uriValue;
      if (target == null) {
        _fail(frame, '无法识别该网页地址');
        return NavigationActionPolicy.CANCEL;
      }
      if (frame.windowId != null && target.toString() == 'about:blank') {
        return NavigationActionPolicy.ALLOW;
      }
      final normalized = MallNavigation.normalize(target);
      if (!await _allow(normalized)) return NavigationActionPolicy.CANCEL;
      if (_opensSecondary(frame, normalized)) {
        if (frame.windowId != null) _close(frame);
        _openPage(normalized);
        return NavigationActionPolicy.CANCEL;
      }
      if (normalized != target) {
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri.uri(normalized)),
        );
        return NavigationActionPolicy.CANCEL;
      }
      return NavigationActionPolicy.ALLOW;
    },
    onCreateWindow: (_, action) async {
      final target = action.request.url?.uriValue;
      if (target != null &&
          target.toString() != 'about:blank' &&
          !await _allow(MallNavigation.normalize(target))) {
        return false;
      }
      if (!mounted || frame.rendererGone || !_frames.contains(frame)) {
        return false;
      }
      setState(
        () => _frames.add(
          _MallFrame(
            current: target ?? Uri.parse('about:blank'),
            windowId: action.windowId,
          ),
        ),
      );
      return true;
    },
    onCloseWindow: (_) {
      if (mounted) _close(frame);
    },
  );

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final frame = _active;
    final selected = MallDestination.fromUri(frame.current);
    return Scaffold(
      primary: false,
      appBar: AppBar(
        primary: false,
        leading: BackButton(onPressed: widget.onRootBack),
        title: Text(
          widget.initialUrl == null
              ? '会员购'
              : MallNavigation.pageKind(frame.current)?.label ?? '会员购',
        ),
        actions: [
          if (widget.initialUrl == null)
            PopupMenuButton<MallTicketDestination>(
              tooltip: '票务工具',
              enabled: frame.controller != null,
              onSelected: (destination) => frame.controller!.loadUrl(
                urlRequest: URLRequest(url: WebUri(destination.url)),
              ),
              itemBuilder: (_) => [
                for (final destination in MallTicketDestination.values)
                  PopupMenuItem(
                    value: destination,
                    child: Text(destination.label),
                  ),
              ],
            ),
          IconButton(
            tooltip: '刷新商城',
            onPressed: frame.controller == null
                ? null
                : () => frame.controller!.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: widget.initialUrl != null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(
                  kMinInteractiveDimension + 2,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (final destination in MallDestination.values)
                          Expanded(
                            child: Semantics(
                              selected: selected == destination,
                              child: TextButton(
                                onPressed: frame.controller == null
                                    ? null
                                    : () => _open(destination),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(
                                    0,
                                    kMinInteractiveDimension,
                                  ),
                                  foregroundColor: selected == destination
                                      ? scheme.onSecondaryContainer
                                      : scheme.onSurfaceVariant,
                                  backgroundColor: selected == destination
                                      ? scheme.secondaryContainer
                                      : Colors.transparent,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: Style.mdRadius,
                                  ),
                                ),
                                child: Text(destination.label),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(
                      height: 2,
                      child: frame.progress < 1
                          ? LinearProgressIndicator(
                              value: frame.progress,
                              minHeight: 2,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_viewportWidth != constraints.maxWidth) {
            _viewportWidth = constraints.maxWidth;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _adapt(_active);
            });
          }
          return Stack(
            children: [
              IndexedStack(
                index: _frames.length - 1,
                children: [
                  for (final frame in _frames)
                    frame.rendererGone
                        ? const SizedBox.expand()
                        : _webView(frame),
                ],
              ),
              if (frame.failure != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: scheme.surface,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined),
                            const SizedBox(height: 12),
                            Text(frame.failure!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _retry,
                              child: const Text('重新加载'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
