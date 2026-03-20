import 'package:app_settings/app_settings.dart';
import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/printer_bloc.dart';
import '../bloc/printer_event.dart';
import '../bloc/printer_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _appVersionLabel = 'App Version';

  static const String _fallbackBuildName =
      String.fromEnvironment('FLUTTER_BUILD_NAME');
  static const String _fallbackBuildNumber =
      String.fromEnvironment('FLUTTER_BUILD_NUMBER');

  @override
  void initState() {
    super.initState();
    context.read<PrinterBloc>().add(InitPrinterEvent());
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersionLabel = 'App Version ${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_fallbackBuildName.isNotEmpty) {
          final buildText =
              _fallbackBuildNumber.isNotEmpty ? ' ($_fallbackBuildNumber)' : '';
          _appVersionLabel = 'App Version $_fallbackBuildName$buildText';
        } else {
          _appVersionLabel = 'App Version 1.0.0 (1)';
        }
      });
    }
  }

  void _showLogoutDialog(BuildContext context) {
    final hasUnsynced = HiveDatabase.hasUnsyncedData();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          elevation: 12,
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppTheme.errorColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Confirm Logout',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hasUnsynced
                      ? 'Your data is not synched! If you logout, your unsynched data will be lost. Are you sure you want to sign out?'
                      : 'Are you sure you want to sign out of your account? You will need to sign in again to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: hasUnsynced
                        ? AppTheme.errorColor
                        : const Color(0xFF64748B),
                    fontWeight:
                        hasUnsynced ? FontWeight.w600 : FontWeight.normal,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          foregroundColor: const Color(0xFF64748B),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          context
                              .read<AuthBloc>()
                              .add(const AuthLogoutRequested());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Options',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: Color(0xFF0F172A),
            )),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 8,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              shadowColor: Colors.black12,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                color: const Color(0xFF0F172A),
                onPressed: () => context.pop(),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            _appVersionLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            SizedBox(height: isCompact ? 6 : 10),
            _buildReveal(
              index: 0,
              child: _buildProfileSection(isCompact: isCompact),
            ),
            SizedBox(height: isCompact ? 20 : 24),
            _buildReveal(
              index: 1,
              child: _buildSectionHeader(
                'Management',
                isCompact: isCompact,
              ),
            ),
            _buildReveal(
              index: 2,
              child: _buildListGroup(
                isCompact: isCompact,
                children: [
                  _buildListItem(
                    icon: Icons.inventory_2_rounded,
                    iconColor: AppTheme.secondaryColor,
                    title: 'Inventory',
                    subtitle: 'Manage products & stock',
                    onTap: () => context.push('/products'),
                    isCompact: isCompact,
                  ),
                  _buildDivider(),
                  _buildListItem(
                    icon: Icons.storefront_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Shop Details',
                    subtitle: 'Business info & digital receipts',
                    onTap: () => context.push('/shop'),
                    isCompact: isCompact,
                  ),
                ],
              ),
            ),
            SizedBox(height: isCompact ? 22 : 28),
            _buildReveal(
              index: 3,
              child: _buildSectionHeader(
                'Hardware Connections',
                isCompact: isCompact,
              ),
            ),
            _buildReveal(
              index: 4,
              child: _buildPrinterSection(isCompact: isCompact),
            ),
            SizedBox(height: isCompact ? 22 : 28),
            _buildReveal(
              index: 5,
              child: _buildSectionHeader(
                'Account',
                isCompact: isCompact,
              ),
            ),
            _buildReveal(
              index: 6,
              child: _buildListGroup(
                isCompact: isCompact,
                children: [
                  _buildListItem(
                    icon: Icons.logout_rounded,
                    iconColor: AppTheme.errorColor,
                    title: 'Logout',
                    subtitle: 'Sign out securely',
                    trailingIcon: null,
                    onTap: () => _showLogoutDialog(context),
                    isCompact: isCompact,
                  ),
                ],
              ),
            ),
            SizedBox(height: isCompact ? 32 : 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection({required bool isCompact}) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
      padding: EdgeInsets.all(isCompact ? 20 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), AppTheme.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: BlocBuilder<ShopBloc, ShopState>(
        builder: (context, state) {
          String shopName = 'Your Shop';
          String initials = 'YS';
          if (state is ShopLoaded && state.shop.name.isNotEmpty) {
            shopName = state.shop.name;
            final parts = shopName.split(' ');
            initials = parts
                .take(2)
                .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
                .join('');
            if (initials.isEmpty) initials = 'S';
          }

          return Row(
            children: [
              Container(
                width: isCompact ? 58 : 64,
                height: isCompact ? 58 : 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                alignment: Alignment.center,
                child: Text(initials,
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: isCompact ? 22 : 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1)),
              ),
              SizedBox(width: isCompact ? 14 : 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(shopName,
                              style: TextStyle(
                                  fontSize: isCompact ? 18 : 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => context.push('/shop'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: EdgeInsets.all(isCompact ? 6 : 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              size: isCompact ? 14 : 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text('Admin Panel',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPrinterSection({required bool isCompact}) {
    return BlocConsumer<PrinterBloc, PrinterState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))));
        } else if (state.status == PrinterStatus.connected) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Connected to printer'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))));
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            _buildListGroup(
              isCompact: isCompact,
              children: [
                _buildListItem(
                  icon: Icons.print_rounded,
                  iconColor: AppTheme.primaryColor,
                  title: 'Thermal Printer',
                  isCompact: isCompact,
                  subtitleWidget: Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.connectedMac != null
                              ? (state.connectedName ?? 'Connected')
                              : 'No printer connected',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (state.connectedMac != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('ON',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF047857))),
                        ),
                      ]
                    ],
                  ),
                  trailingWidget: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.status == PrinterStatus.scanning ||
                          state.status == PrinterStatus.connecting)
                        const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5))
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => context
                              .read<PrinterBloc>()
                              .add(RefreshPrinterEvent()),
                          color: AppTheme.primaryColor,
                        ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.bluetooth_rounded),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          AppSettings.openAppSettings(
                              type: AppSettingsType.bluetooth);
                        },
                        color: const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 24 : 36,
                16,
                isCompact ? 24 : 36,
                0,
              ),
              child: const Text(
                "Tap the Bluetooth icon to pair a new device in your phone's settings, then return here and hit refresh.",
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    height: 1.5,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, {required bool isCompact}) {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(isCompact ? 24 : 32, 0, isCompact ? 24 : 32, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 1.2),
        ),
      ),
    );
  }

  Widget _buildListGroup({
    required List<Widget> children,
    required bool isCompact,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 68),
      child: Divider(height: 1, thickness: 1.5, color: Color(0xFFF1F5F9)),
    );
  }

  Widget _buildListItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    Widget? trailingWidget,
    IconData? trailingIcon = Icons.chevron_right_rounded,
    VoidCallback? onTap,
    bool isCompact = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 14 : 16),
        child: Row(
          children: [
            Container(
              width: isCompact ? 42 : 46,
              height: isCompact ? 42 : 46,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: isCompact ? 20 : 22),
            ),
            SizedBox(width: isCompact ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isCompact ? 15 : 16,
                          color: const Color(0xFF1E293B))),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: isCompact ? 12 : 13,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500)),
                  ],
                  if (subtitleWidget != null) ...[
                    const SizedBox(height: 4),
                    subtitleWidget,
                  ]
                ],
              ),
            ),
            if (trailingWidget != null)
              trailingWidget
            else if (trailingIcon != null)
              Icon(trailingIcon, color: const Color(0xFFCBD5E1), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildReveal({required int index, required Widget child}) {
    final duration = Duration(milliseconds: 260 + (index * 70));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
    );
  }
}
