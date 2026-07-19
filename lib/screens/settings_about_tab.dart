import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsAboutTab extends StatefulWidget {
  const SettingsAboutTab({super.key});

  @override
  State<SettingsAboutTab> createState() => _SettingsAboutTabState();
}

class _SettingsAboutTabState extends State<SettingsAboutTab> {
  bool _analyticsEnabled = true;
  bool _hasRated = false;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final analytics = AnalyticsService();
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await analytics.getDeviceId();
    setState(() {
      _analyticsEnabled = analytics.isEnabled;
      _hasRated = prefs.getBool('has_rated_app') ?? false;
      _deviceId = deviceId ?? 'not-available';
    });
  }

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _buildSection(
          context,
          title: AppLocalizations.of(context)!.sectionAboutInformation,
          children: [
            _buildInfoTile(
              context,
              icon: CupertinoIcons.info,
              iconColor: Theme.of(context).colorScheme.primary,
              title: AppLocalizations.of(context)!.aboutVersion,
              subtitle: '1.0.13',
            ),
            _buildDivider(context),
            _buildInfoTile(
              context,
              icon: CupertinoIcons.device_phone_portrait,
              iconColor: const Color(0xFF007AFF),
              title: AppLocalizations.of(context)!.aboutPlatform,
              subtitle: Theme.of(context).platform.name.toUpperCase(),
            ),
          ],
        ),

        const SizedBox(height: 24),
        _buildSection(
          context,
          title: 'Analytics & Privacy',
          children: [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              secondary: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF34C759), Color(0xFF30D158)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.chart_bar,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              title: Text(
                isZh ? '匿名分析数据' : 'Anonymous Analytics',
                style: const TextStyle(fontSize: 16),
              ),
              subtitle: Text(
                isZh ? '通过发送匿名崩溃报告和使用统计数据，帮助改进 Musly' : 'Help improve Musly with anonymous crash reports and usage stats',
                style: const TextStyle(fontSize: 12),
              ),
              value: _analyticsEnabled,
              onChanged: (value) async {
                await AnalyticsService().setEnabled(value);
                setState(() => _analyticsEnabled = value);
              },
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.device_phone_portrait,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              title: const Text('设备 ID', style: TextStyle(fontSize: 16)),
              subtitle: Text(
                _analyticsEnabled
                    ? '匿名 ID：${_deviceId ?? "加载中..."}'
                    : '启用分析以查看您的匿名设备 ID',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: _analyticsEnabled
                  ? IconButton(
                      icon: const Icon(CupertinoIcons.doc_on_doc, size: 18),
                      tooltip: isZh ? '复制设备 ID' : 'Copy device ID',
                      onPressed: () {
                        if (_deviceId != null) {
                          Clipboard.setData(ClipboardData(text: _deviceId!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('设备 ID 已复制到剪贴板'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    )
                  : null,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.info,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              title: Text(
                isZh ? '关于设备 ID' : 'About Device ID',
                style: const TextStyle(fontSize: 16),
              ),
              subtitle: Text(
                isZh
                    ? '这是由应用生成的匿名标识符。它无法与您的个人身份关联，仅用于分析统计。'
                    : 'This is an anonymous identifier generated by the app. It cannot be linked to your personal identity and is used only for analytics.',
                style: const TextStyle(fontSize: 12, height: 1.3),
              ),
            ),
          ],
        ),

      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: _isDark(context)
                  ? AppTheme.darkSecondaryText
                  : AppTheme.lightSecondaryText,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _isDark(context) ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Container(
        height: 0.5,
        color: _isDark(context) ? AppTheme.darkDivider : AppTheme.lightDivider,
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: Text(
        subtitle,
        style: TextStyle(
          fontSize: 16,
          color: _isDark(context)
              ? AppTheme.darkSecondaryText
              : AppTheme.lightSecondaryText,
        ),
      ),
    );
  }

}
