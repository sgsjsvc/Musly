import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../l10n/app_localizations.dart';
import '../models/server_config.dart';
import '../providers/auth_provider.dart';
import '../services/local_music_service.dart';
import '../theme/app_theme.dart';
import '../utils/screen_helper.dart';

enum _LoginErrorType {
  ssl,
  credentials,
  notFound,
  timeout,
  connection,
  format,
  generic,
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _useLegacyAuth = false;
  bool _allowSelfSignedCertificates = false;
  bool _obscurePassword = true;
  bool _showAdvancedOptions = false;
  String _serverFamily = 'subsonic'; // 'subsonic' | 'jellyfin' | 'youtube'
  String? _customCertificatePath;
  String? _customCertificateName;
  final _profileNameController = TextEditingController();
  
  String? _clientCertificatePath;
  String? _clientCertificateName;
  final _clientCertPasswordController = TextEditingController();
  bool _obscureClientCertPassword = true;
  bool _isScanning = false;
  double _scanProgress = 0.0;
  String _scanStatus = '';

  String? _loginError;

  @override
  void initState() {
    super.initState();
    
    _serverController.addListener(_clearError);
    _usernameController.addListener(_clearError);
    _passwordController.addListener(_clearError);
    _profileNameController.addListener(_clearError);
  }

  void _clearError() {
    if (_loginError != null && mounted) {
      setState(() => _loginError = null);
    }
  }

  _LoginErrorType _categoriseError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('ssl') ||
        lower.contains('certificate') ||
        lower.contains('handshake') ||
        lower.contains('tls')) {
      return _LoginErrorType.ssl;
    }
    if (lower.contains('invalid username') ||
        lower.contains('wrong password') ||
        lower.contains('unauthorized') ||
        lower.contains('401')) {
      return _LoginErrorType.credentials;
    }
    if (lower.contains('not found') ||
        lower.contains('404') ||
        lower.contains('url path')) {
      return _LoginErrorType.notFound;
    }
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return _LoginErrorType.timeout;
    }
    if (lower.contains('cannot connect') ||
        lower.contains('connection refused') ||
        lower.contains('network') ||
        lower.contains('socket')) {
      return _LoginErrorType.connection;
    }
    if (lower.contains('url format') || lower.contains('http')) {
      return _LoginErrorType.format;
    }
    return _LoginErrorType.generic;
  }

  Widget _buildErrorCard(ThemeData theme) {
    final error = _loginError;
    if (error == null) return const SizedBox.shrink();

    final type = _categoriseError(error);

    IconData icon;
    Color color;
    String? hint;

    switch (type) {
      case _LoginErrorType.ssl:
        icon = CupertinoIcons.lock_slash;
        color = const Color(0xFFFF9500); 
        if (!_allowSelfSignedCertificates) {
          hint = '请尝试在下方启用"允许自签名证书"。';
        }
      case _LoginErrorType.credentials:
        icon = CupertinoIcons.person_badge_minus;
        color = AppTheme.appleMusicRed;
        hint = '请检查您的用户名和密码后重试。';
      case _LoginErrorType.notFound:
        icon = CupertinoIcons.question_circle;
        color = const Color(0xFFFF9500);
        hint = '请验证服务器 URL 路径（例如 /navidrome、/airsonic）。';
      case _LoginErrorType.timeout:
        icon = CupertinoIcons.timer;
        color = const Color(0xFFFF9500);
        hint = '服务器响应时间过长，请检查您的网络。';
      case _LoginErrorType.connection:
        icon = CupertinoIcons.wifi_slash;
        color = const Color(0xFFFF9500);
        hint = null;
      case _LoginErrorType.format:
        icon = CupertinoIcons.link;
        color = const Color(0xFFFF9500);
        hint = 'URL 必须以 http:// 或 https:// 开头';
      case _LoginErrorType.generic:
        icon = CupertinoIcons.exclamationmark_triangle;
        color = AppTheme.appleMusicRed;
        hint = null;
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(
                    error,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy_rounded, size: 16, color: color.withValues(alpha: 0.7)),
                  tooltip: '复制错误',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: error));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('错误已复制到剪贴板'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        width: 260,
                      ),
                    );
                  },
                ),
              ],
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(
                  hint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
            
            if (type == _LoginErrorType.ssl &&
                !_allowSelfSignedCertificates) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _allowSelfSignedCertificates = true;
                      _loginError = null;
                    });
                  },
                  child: Text(
                    '点击启用自签名证书',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: color,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _serverController.removeListener(_clearError);
    _usernameController.removeListener(_clearError);
    _passwordController.removeListener(_clearError);
    _profileNameController.removeListener(_clearError);
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _profileNameController.dispose();
    _clientCertPasswordController.dispose();
    _serverFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickClientCertificate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['p12', 'pfx', 'pem'],
        dialogTitle: '选择客户端证书',
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _clientCertificatePath = result.files.single.path;
          _clientCertificateName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.failedToSelectClientCert(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickCertificateFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pem', 'crt', 'cer', 'p12', 'pfx', 'der'],
        dialogTitle: '选择 TLS/SSL 证书',
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _customCertificatePath = result.files.single.path;
          _customCertificateName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.failedToSelectCertificate(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _login() async {
    // YouTube Music requires no credentials — skip form validation
    if (_serverFamily != 'youtube') {
      if (!_formKey.currentState!.validate()) return;
    }

    setState(() => _loginError = null);

    final serverUrl = _serverFamily == 'youtube'
        ? 'https://music.youtube.com'
        : _serverController.text.trim();

    if (_serverFamily != 'youtube' &&
        !serverUrl.startsWith('http://') &&
        !serverUrl.startsWith('https://')) {
      setState(
        () => _loginError = '服务器地址必须以 http:// 或 https:// 开头',
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileName = _profileNameController.text.trim();
    final success = await authProvider.login(
      serverUrl: serverUrl,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      useLegacyAuth: _useLegacyAuth,
      allowSelfSignedCertificates: _allowSelfSignedCertificates,
      customCertificatePath: _customCertificatePath,
      clientCertificatePath: _clientCertificatePath,
      clientCertificatePassword: _clientCertPasswordController.text.isEmpty
          ? null
          : _clientCertPasswordController.text,
      profileName: profileName.isEmpty ? null : profileName,
      serverFamily: _serverFamily,
    );

    if (!success && mounted) {
      setState(
        () => _loginError = authProvider.error ?? '连接服务器失败',
      );
    }
    
  }

  Future<void> _useLocalFiles() async {
    final localService = Provider.of<LocalMusicService>(context, listen: false);

    final granted = await localService.requestPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.storagePermissionRequired,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (Platform.isIOS) {
      setState(() {
        _isScanning = true;
        _scanProgress = 0.0;
        _scanStatus = '选择您的音乐文件...';
      });
      try {
        final added = await localService.pickAndAddFiles();
        if (mounted) {
          if (localService.songs.isNotEmpty) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            await authProvider.setLocalOnlyMode(true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(added == 0
                    ? '未选择文件。点击"使用本地文件"选择您的音乐文件。'
                    : AppLocalizations.of(context)!.noMusicFilesFound),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } finally {
        if (mounted) setState(() => _isScanning = false);
      }
      return;
    }

    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
      _scanStatus = '正在开始扫描...';
    });

    void updateProgress() {
      if (mounted) {
        setState(() {
          _scanProgress = localService.scanProgress;
          _scanStatus = localService.scanStatus;
        });
      }
    }

    localService.addListener(updateProgress);

    try {
      await localService.scanForMusic();

      if (mounted) {
        if (localService.songs.isNotEmpty) {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          await authProvider.setLocalOnlyMode(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.noMusicFilesFound),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } finally {
      localService.removeListener(updateProgress);
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoading = authProvider.state == AuthState.authenticating;
    final theme = Theme.of(context);
    final isBusy = isLoading || _isScanning;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(ScreenHelper.loginPadding(context)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Center(
                    child: Container(
                      width: ScreenHelper.loginLogoSize(context),
                      height: ScreenHelper.loginLogoSize(context),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.appleMusicRed.withValues(
                              alpha: 0.4,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Transform.translate(
                          offset: const Offset(0, 8),
                          child: Image.asset(
                            'assets/logobig.png',
                            width: ScreenHelper.loginLogoSize(context),
                            height: ScreenHelper.loginLogoSize(context),
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    AppLocalizations.of(context)!.appName,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: ScreenHelper.isSmallScreen(context) ? 32 : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.connectToServerSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.lightSecondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _SavedProfilesSwitcher(
                    onProfileSelected: (profile) async {
                      final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
                      await authProvider.switchProfile(profile);
                      if (mounted && authProvider.error != null) {
                        setState(
                          () => _loginError = authProvider.error,
                        );
                      }
                    },
                    onProfileDeleted: (profile) async {
                      final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
                      await authProvider.deleteProfile(profile);
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 16),
                  _ServerFamilyToggle(
                    serverFamily: _serverFamily,
                    onChanged: (v) => setState(() {
                      _serverFamily = v;
                      _useLegacyAuth = false;
                    }),
                  ),
                  const SizedBox(height: 16),

                  if (_serverFamily == 'youtube') ...[                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000).withAlpha(20),
                        border: Border.all(
                          color: const Color(0xFFFF0000).withAlpha(80),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.info_circle,
                            color: Color(0xFFFF0000),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'YouTube Music 直接从 YouTube 流式传输音乐。无需账户——点击连接开始。',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[                    
                  TextFormField(
                    controller: _serverController,
                    focusNode: _serverFocusNode,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _usernameFocusNode.requestFocus(),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.serverUrl,
                      hintText: 'https://your-server.com',
                      prefixIcon: const Icon(CupertinoIcons.globe),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppLocalizations.of(context)!.pleaseEnterServerUrl;
                      }
                      final url = value.trim();
                      if (!url.startsWith('http://') &&
                          !url.startsWith('https://')) {
                        return AppLocalizations.of(context)!.serverUrlMustStartWith;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _usernameController,
                    focusNode: _usernameFocusNode,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.username,
                      prefixIcon: const Icon(CupertinoIcons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppLocalizations.of(context)!.pleaseEnterUsername;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) { if (!isBusy) _login(); },
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.password,
                      prefixIcon: const Icon(CupertinoIcons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? CupertinoIcons.eye
                              : CupertinoIcons.eye_slash,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.pleaseEnterPassword;
                      }
                      return null;
                    },
                  ),
                  ],
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      CupertinoSwitch(
                        value: _useLegacyAuth,
                        activeTrackColor: AppTheme.appleMusicRed,
                        onChanged: (value) {
                          setState(() {
                            _useLegacyAuth = value;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '旧版认证',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              '用于较旧的 Subsonic 服务器',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      CupertinoSwitch(
                        value: _allowSelfSignedCertificates,
                        activeTrackColor: AppTheme.appleMusicRed,
                        onChanged: (value) {
                          setState(() {
                            _allowSelfSignedCertificates = value;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '允许自签名证书',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              '用于具有自定义 TLS/SSL 证书的服务器',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  InkWell(
                    onTap: () {
                      setState(() {
                        _showAdvancedOptions = !_showAdvancedOptions;
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          _showAdvancedOptions
                              ? CupertinoIcons.chevron_down
                              : CupertinoIcons.chevron_right,
                          size: 18,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '高级选项',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_showAdvancedOptions) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _profileNameController,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: '配置名称（可选）',
                        hintText: '例如：家庭、工作、VPN',
                        prefixIcon: const Icon(CupertinoIcons.tag),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '自定义 TLS/SSL 证书',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '为使用非标准 CA 的服务器上传自定义证书',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          if (_customCertificateName != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFF3C3C3E)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.doc_fill,
                                    size: 20,
                                    color: AppTheme.appleMusicRed,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _customCertificateName!,
                                      style: theme.textTheme.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _customCertificatePath = null;
                                        _customCertificateName = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _pickCertificateFile,
                                icon: const Icon(
                                  CupertinoIcons.doc_on_clipboard,
                                ),
                                label: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.selectCertificateFile,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.appleMusicRed,
                                  side: BorderSide(
                                    color: AppTheme.appleMusicRed.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.clientCertificate,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.clientCertificateSubtitle,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          if (_clientCertificateName != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFF3C3C3E)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.security_rounded,
                                    size: 20,
                                    color: AppTheme.appleMusicRed,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _clientCertificateName!,
                                      style: theme.textTheme.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _clientCertificatePath = null;
                                        _clientCertificateName = null;
                                        _clientCertPasswordController.clear();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _clientCertPasswordController,
                              obscureText: _obscureClientCertPassword,
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(
                                  context,
                                )!.clientCertPassword,
                                prefixIcon: const Icon(
                                  CupertinoIcons.lock,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureClientCertPassword
                                        ? CupertinoIcons.eye
                                        : CupertinoIcons.eye_slash,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() {
                                    _obscureClientCertPassword =
                                        !_obscureClientCertPassword;
                                  }),
                                ),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ] else
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _pickClientCertificate,
                                icon: const Icon(Icons.security_rounded),
                                label: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.selectClientCertificate,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.appleMusicRed,
                                  side: BorderSide(
                                    color: AppTheme.appleMusicRed.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  _buildErrorCard(theme),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.appleMusicRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              AppLocalizations.of(context)!.connect,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '或者',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.lightSecondaryText,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (!Platform.isIOS) SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: isBusy ? null : _useLocalFiles,
                      icon: _isScanning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.appleMusicRed,
                                ),
                              ),
                            )
                          : const Icon(CupertinoIcons.folder),
                      label: Text(
                        _isScanning ? _scanStatus : '使用本地文件',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.appleMusicRed,
                        side: const BorderSide(color: AppTheme.appleMusicRed),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  if (!Platform.isIOS && _isScanning) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _scanProgress > 0 ? _scanProgress : null,
                      backgroundColor: AppTheme.appleMusicRed.withValues(
                        alpha: 0.2,
                      ),
                      color: AppTheme.appleMusicRed,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedProfilesSwitcher extends StatefulWidget {
  final Future<void> Function(ServerConfig) onProfileSelected;
  final Future<void> Function(ServerConfig) onProfileDeleted;

  const _SavedProfilesSwitcher({
    required this.onProfileSelected,
    required this.onProfileDeleted,
  });

  @override
  State<_SavedProfilesSwitcher> createState() => _SavedProfilesSwitcherState();
}

class _SavedProfilesSwitcherState extends State<_SavedProfilesSwitcher> {
  Future<List<ServerConfig>>? _profilesFuture;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _reload();
    }
  }

  void _reload() {
    _profilesFuture = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).getSavedProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServerConfig>>(
      future: _profilesFuture,
      builder: (context, snap) {
        final profiles = snap.data ?? [];
        if (profiles.isEmpty) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '已保存的配置',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profiles.map((profile) {
                final label = profile.name?.isNotEmpty == true
                    ? profile.name!
                    : '${profile.username}@${Uri.tryParse(profile.serverUrl)?.host ?? profile.serverUrl}';
                return InputChip(
                  avatar: const Icon(
                    CupertinoIcons.person_crop_circle,
                    size: 18,
                  ),
                  label: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  tooltip: '${profile.username} – ${profile.serverUrl}',
                  onPressed: () async {
                    await widget.onProfileSelected(profile);
                    if (mounted) setState(_reload);
                  },
                  onDeleted: () async {
                    await widget.onProfileDeleted(profile);
                    if (mounted) setState(_reload);
                  },
                  deleteIcon: const Icon(CupertinoIcons.xmark_circle, size: 16),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            Text(
              '点击配置连接 • 点击 × 删除',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ServerFamilyToggle extends StatelessWidget {
  final String serverFamily;
  final ValueChanged<String> onChanged;

  const _ServerFamilyToggle({
    required this.serverFamily,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white70 : Colors.black87;

    final chips = [
      (
        label: 'Subsonic',
        family: 'subsonic',
        icon: CupertinoIcons.music_note,
        activeColor: const Color(0xFF6366F1),
      ),
      (
        label: 'Emby / Jellyfin',
        family: 'jellyfin',
        icon: CupertinoIcons.tv,
        activeColor: const Color(0xFF6366F1),
      ),
      // (
      //   label: 'YouTube Music',
      //   family: 'youtube',
      //   icon: CupertinoIcons.play_rectangle,
      //   activeColor: const Color(0xFFFF0000),
      // ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '服务器类型',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips.map((c) {
            final selected = serverFamily == c.family;
            return GestureDetector(
              onTap: () => onChanged(c.family),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? c.activeColor.withAlpha(30)
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? c.activeColor
                        : (isDark ? Colors.white24 : Colors.black26),
                    width: selected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      c.icon,
                      size: 16,
                      color: selected ? c.activeColor : labelColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? c.activeColor : labelColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
