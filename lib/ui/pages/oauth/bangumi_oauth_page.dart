import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:mikan_player/gen/app_localizations.dart';
import 'package:mikan_player/main.dart' show webViewEnvironment;
import 'package:mikan_player/services/bangumi_auth_manager.dart';
import 'package:mikan_player/services/bangumi_oauth_callback.dart';

/// Full-screen OAuth login page.
///
/// Loads Bangumi's authorization page in an [InAppWebView], watches every
/// navigation for the registered redirect URI, and — the moment it sees
/// `<redirect_uri>?code=...` — cancels the navigation, extracts the `code`,
/// and pops with it. No local HTTP server is involved: the redirect target
/// never has to actually load, we only need to observe the browser trying to
/// reach it.
///
/// Returns the authorization `code` via [Navigator.pop], or `null` if the user
/// backed out / the provider returned an error.
class BangumiOAuthPage extends StatefulWidget {
  const BangumiOAuthPage({super.key});

  /// Pushes the login page and returns the captured authorization code, or
  /// `null` when the user cancels.
  static Future<String?> show(BuildContext context) {
    return Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const BangumiOAuthPage()));
  }

  @override
  State<BangumiOAuthPage> createState() => _BangumiOAuthPageState();
}

class _BangumiOAuthPageState extends State<BangumiOAuthPage> {
  final BangumiAuthManager _auth = BangumiAuthManager();
  late final String _oauthState;

  String? _authorizeUrl;
  String? _initError;
  bool _handled = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _oauthState = BangumiAuthManager.generateOAuthState();
    _prepareAuthorizeUrl();
  }

  Future<void> _prepareAuthorizeUrl() async {
    try {
      final url = await _auth.buildAuthorizeUrl(state: _oauthState);
      if (!mounted) return;
      setState(() => _authorizeUrl = url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = '$e');
    }
  }

  /// Inspects a candidate navigation URL. When it matches the redirect URI and
  /// carries a `code`, pops the page with that code and returns true so the
  /// caller can cancel the navigation.
  bool _maybeCaptureCode(WebUri? url) {
    if (_handled || url == null) return false;
    final candidate = Uri.parse(url.toString());
    if (!BangumiOAuthCallback.isRedirectTarget(
      candidate: candidate,
      redirectUri: BangumiAuthManager.redirectUri,
    )) {
      return false;
    }

    final code = BangumiOAuthCallback.extractCode(
      candidate: candidate,
      redirectUri: BangumiAuthManager.redirectUri,
      expectedState: _oauthState,
    );
    _handled = true;
    if (code == null) {
      final l10n = AppLocalizations.of(context);
      setState(() => _initError = l10n.bangumiLoginCallbackError);
    } else {
      Navigator.of(context).pop(code);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bangumiLoginTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(l10n.bangumiLoginInitError, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                _initError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final url = _authorizeUrl;
    if (url == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (_progress < 1.0)
          LinearProgressIndicator(value: _progress == 0 ? null : _progress),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(url)),
            webViewEnvironment: webViewEnvironment,
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              isFraudulentWebsiteWarningEnabled: false,
              useHybridComposition: true,
              // Bangumi's login page is a normal first-party page; keep the
              // default UA so the site renders its standard login form.
              clearCache: false,
            ),
            shouldOverrideUrlLoading: (controller, action) async {
              if (_maybeCaptureCode(action.request.url)) {
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStart: (controller, requestUrl) {
              _maybeCaptureCode(requestUrl);
            },
            onProgressChanged: (controller, progress) {
              if (!mounted) return;
              setState(() => _progress = progress / 100.0);
            },
          ),
        ),
      ],
    );
  }
}
