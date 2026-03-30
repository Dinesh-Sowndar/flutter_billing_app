import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/supplier_entity.dart';
import '../bloc/supplier_bloc.dart';
import '../bloc/supplier_event.dart';
import '../bloc/supplier_state.dart';
import '../../../../core/service_locator.dart' as di;

class AddSupplierPage extends StatefulWidget {
  final bool asSheet;
  const AddSupplierPage({super.key, this.asSheet = false});

  static Future<void> showSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddSupplierPage(asSheet: true),
    );
  }

  @override
  State<AddSupplierPage> createState() => _AddSupplierPageState();
}

class _AddSupplierPageState extends State<AddSupplierPage> {
  static const Color _primary = Color(0xFF0F766E);
  static const Color _primaryDark = Color(0xFF115E59);
  static const Color _surface = Color(0xFFF1F5F9);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  // Hold the bloc directly so _submit can use it without relying on
  // context.read (which would fail because context is above the BlocProvider).
  late final SupplierBloc _bloc = di.sl<SupplierBloc>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _bloc.close();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final supplier = SupplierEntity(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
    );
    // Dispatch directly on the bloc we created — avoids the context-scope issue.
    _bloc.add(AddSupplierEvent(supplier));

    // Wait for the bloc to emit a loaded or error state.
    final resultState = await _bloc.stream.firstWhere(
      (s) =>
          s.status == SupplierStatus.loaded || s.status == SupplierStatus.error,
    );

    if (!mounted) return;

    if (resultState.status == SupplierStatus.error) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultState.error ?? 'Failed to add supplier'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            widget.asSheet ? 8 : 20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.asSheet) ...[
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Add Supplier',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF0F172A),
                      ),
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create Supplier Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Add basic details now. You can start recording purchases immediately.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildCard(
                children: [
                  _buildField(
                    controller: _nameCtrl,
                    label: 'Supplier Name',
                    hint: 'e.g. ABC Wholesale',
                    icon: Icons.business_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _phoneCtrl,
                    label: 'Phone Number',
                    hint: 'e.g. 9876543210',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Phone is required';
                      }
                      if (v.trim().length != 10) {
                        return 'Phone number must be exactly 10 digits';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Tip: Phone number helps avoid duplicate supplier entries.',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Save Supplier',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return BlocProvider.value(
      value: _bloc,
      child: widget.asSheet
          ? Container(
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(top: false, child: content),
            )
          : Scaffold(
              backgroundColor: _surface,
              appBar: AppBar(
                backgroundColor: _surface,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  color: const Color(0xFF0F172A),
                  onPressed: () => context.pop(),
                ),
                title: const Text(
                  'Add Supplier',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              body: content,
            ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _primary, size: 20),
        labelStyle: const TextStyle(
            color: Color(0xFF64748B), fontWeight: FontWeight.w600),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }
}
