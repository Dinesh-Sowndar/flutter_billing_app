import 'package:app_settings/app_settings.dart';
import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/widgets/app_back_button.dart';
import 'package:billing_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/service_locator.dart' as di;
import '../../../../core/services/sync_service.dart';
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
  bool _isManualSyncing = false;

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

  Future<void> _showLogoutDialog(BuildContext context) async {
    // Force-push all pending records to Firestore (if online) BEFORE checking
    // so users who are already synced don't see a false warning.
    await di.sl<SyncService>().syncAllPending();

    if (!mounted) return;
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

  Future<void> _syncDataNow() async {
    if (_isManualSyncing) return;

    setState(() => _isManualSyncing = true);
    String message = 'Sync completed.';
    Color color = const Color(0xFF10B981);

    try {
      final synced = await di.sl<SyncService>().syncNow();
      if (!mounted) return;
      if (synced) {
        final hasUnsynced = HiveDatabase.hasUnsyncedData();
        if (hasUnsynced) {
          message =
              'Sync started, but some items are still pending. Please try again.';
          color = const Color(0xFFF59E0B);
        } else {
          message = 'All data synced successfully.';
          color = const Color(0xFF10B981);
        }
      } else {
        message = 'You are offline or not signed in. Connect and try again.';
        color = const Color(0xFFF59E0B);
      }
    } catch (_) {
      if (!mounted) return;
      message = 'Sync failed. Please try again.';
      color = AppTheme.errorColor;
    } finally {
      if (mounted) {
        setState(() => _isManualSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    }
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
        leading: AppBackButton(onPressed: () => context.pop()),
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
                  _buildDivider(),
                  _buildListItem(
                    icon: Icons.local_shipping_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Manage Suppliers',
                    subtitle: 'Track purchases & dues',
                    onTap: () => context.push('/suppliers'),
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
                'Billing',
                isCompact: isCompact,
              ),
            ),
            _buildReveal(
              index: 6,
              child: _buildGstSection(isCompact: isCompact),
            ),
            SizedBox(height: isCompact ? 22 : 28),
            _buildReveal(
              index: 7,
              child: _buildSectionHeader(
                'Account',
                isCompact: isCompact,
              ),
            ),
            _buildReveal(
              index: 8,
              child: _buildListGroup(
                isCompact: isCompact,
                children: [
                  _buildListItem(
                    icon: Icons.sync_rounded,
                    iconColor: const Color(0xFF0EA5E9),
                    title: 'Sync Data Now',
                    subtitle: _isManualSyncing
                        ? 'Syncing your latest changes...'
                        : 'Manually sync local and cloud data',
                    trailingWidget: _isManualSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0EA5E9)),
                            ),
                          )
                        : null,
                    trailingIcon:
                        _isManualSyncing ? null : Icons.chevron_right_rounded,
                    onTap: _isManualSyncing
                        ? null
                        : () {
                            _syncDataNow();
                          },
                    isCompact: isCompact,
                  ),
                  _buildDivider(),
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

  Widget _buildGstSection({required bool isCompact}) {
    final settingsBox = HiveDatabase.settingsBox;
    bool gstEnabled =
        settingsBox.get('gst_enabled', defaultValue: false) as bool;
    double gstRate =
        (settingsBox.get('gst_rate', defaultValue: 0.0) as num).toDouble();

    return StatefulBuilder(
      builder: (context, setLocalState) {
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
          child: Column(
            children: [
              // ── GST Toggle ──
              Padding(
                padding: EdgeInsets.all(isCompact ? 14 : 16),
                child: Row(
                  children: [
                    Container(
                      width: isCompact ? 42 : 46,
                      height: isCompact ? 42 : 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.receipt_long_rounded,
                          color: const Color(0xFF10B981),
                          size: isCompact ? 20 : 22),
                    ),
                    SizedBox(width: isCompact ? 12 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GST Billing',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: isCompact ? 15 : 16,
                                  color: const Color(0xFF1E293B))),
                          const SizedBox(height: 4),
                          Text(
                            gstEnabled
                                ? 'GST breakdown will appear on receipts'
                                : 'Enable for tax-compliant invoices',
                            style: TextStyle(
                                fontSize: isCompact ? 12 : 13,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: gstEnabled,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) {
                        setLocalState(() {
                          gstEnabled = val;
                          settingsBox.put('gst_enabled', val);
                          if (!val) {
                            gstRate = 0.0;
                            settingsBox.put('gst_rate', 0.0);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),

              // ── GST Rate Selector (visible when enabled) ──
              if (gstEnabled) ...[
                Divider(height: 1, color: Colors.grey.shade100),
                Padding(
                  padding: EdgeInsets.all(isCompact ? 14 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GST Rate',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [5.0, 12.0, 18.0, 28.0].map((rate) {
                          final isSelected = gstRate == rate;
                          return GestureDetector(
                            onTap: () {
                              setLocalState(() {
                                gstRate = rate;
                                settingsBox.put('gst_rate', rate);
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF10B981)
                                      : Colors.grey.shade200,
                                  width: 1.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF10B981)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Text(
                                '${rate.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (gstRate > 0) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 16, color: Color(0xFF16A34A)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'CGST: ${(gstRate / 2).toStringAsFixed(1)}% + SGST: ${(gstRate / 2).toStringAsFixed(1)}% = ${gstRate.toStringAsFixed(0)}%\nPrices are treated as GST-inclusive.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF15803D),
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrinterSection({required bool isCompact}) {
    return BlocConsumer<PrinterBloc, PrinterState>(
      listenWhen: (prev, curr) =>
          curr.status == PrinterStatus.connected &&
          (prev.status == PrinterStatus.scanning ||
              prev.status == PrinterStatus.connecting),
      listener: (context, state) {
        if (state.status == PrinterStatus.connected) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Connected to ${state.connectedName ?? 'printer'}'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))));
        }
      },
      builder: (context, state) {
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
          child: Column(
            children: [
              // ── Header row: icon + title + status badge ──
              Padding(
                padding: EdgeInsets.all(isCompact ? 14 : 16),
                child: Row(
                  children: [
                    Container(
                      width: isCompact ? 42 : 46,
                      height: isCompact ? 42 : 46,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.print_rounded,
                          color: AppTheme.primaryColor,
                          size: isCompact ? 20 : 22),
                    ),
                    SizedBox(width: isCompact ? 12 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Thermal Printer',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: isCompact ? 15 : 16,
                                  color: const Color(0xFF1E293B))),
                          const SizedBox(height: 4),
                          _printerStatusLine(state),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Error banner ──
              if (state.errorMessage != null &&
                  state.errorMessage!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    border: Border(
                      top: BorderSide(color: Colors.red.shade100, width: 1),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Action area — changes based on state ──
              Divider(height: 1, color: Colors.grey.shade100),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: _printerActions(context, state),
              ),

              // ── Bluetooth settings link ──
              Divider(height: 1, color: Colors.grey.shade100),
              InkWell(
                onTap: () {
                  AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
                },
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bluetooth_rounded,
                          size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        'Open Bluetooth Settings',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Printer status line (subtitle under title) ───────────────────────

  Widget _printerStatusLine(PrinterState state) {
    if (state.isLiveConnected) {
      return Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              state.connectedName ?? 'Connected',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF059669),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (state.isBusy) {
      String label;
      switch (state.status) {
        case PrinterStatus.scanning:
          label = 'Scanning for printers…';
          break;
        case PrinterStatus.connecting:
          label = 'Connecting…';
          break;
        case PrinterStatus.checking:
          label = 'Verifying connection…';
          break;
        case PrinterStatus.testPrinting:
          label = 'Sending test page…';
          break;
        default:
          label = 'Please wait…';
      }
      return Row(
        children: [
          const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5)),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB45309),
                  fontWeight: FontWeight.w600)),
        ],
      );
    }

    if (state.hasSavedPrinter) {
      return Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${state.connectedName ?? 'Saved printer'} – offline',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return const Text(
      'No printer paired',
      style: TextStyle(
        fontSize: 13,
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // ── Printer action buttons based on state ────────────────────────────

  Widget _printerActions(BuildContext context, PrinterState state) {
    // ── Busy: show nothing, the status line already has a spinner ──
    if (state.isBusy) {
      return const SizedBox.shrink();
    }

    // ── Connected: Test Print  |  Disconnect ──
    if (state.isLiveConnected) {
      return Row(
        children: [
          Expanded(
            child: _actionButton(
              icon: Icons.receipt_long_rounded,
              label: 'Test Print',
              color: AppTheme.primaryColor,
              borderColor: const Color(0xFFE2E8F0),
              onTap: () {
                String shopName = 'Shop';
                final shopState = context.read<ShopBloc>().state;
                if (shopState is ShopLoaded) {
                  shopName = shopState.shop.name;
                }
                context.read<PrinterBloc>().add(TestPrintEvent(shopName));
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionButton(
              icon: Icons.link_off_rounded,
              label: 'Disconnect',
              color: const Color(0xFFDC2626),
              borderColor: const Color(0xFFFECACA),
              onTap: () =>
                  context.read<PrinterBloc>().add(DisconnectPrinterEvent()),
            ),
          ),
        ],
      );
    }

    // ── Disconnected / Failed: single prominent Connect button ──
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.read<PrinterBloc>().add(RefreshPrinterEvent()),
        icon: const Icon(Icons.print_rounded, size: 20),
        label: Text(
          state.hasSavedPrinter ? 'Reconnect Printer' : 'Connect Printer',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
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
