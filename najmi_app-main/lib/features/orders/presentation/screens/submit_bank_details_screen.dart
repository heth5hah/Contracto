import 'package:flutter/material.dart';
import 'package:contracto_app/features/orders/data/services/return_service.dart';
import 'package:contracto_app/features/orders/data/models/return_model.dart';

/// Customer submits (or edits) bank details for refund processing
class SubmitBankDetailsScreen extends StatefulWidget {
  final String returnId;
  final ReturnBankDetails? existingDetails;

  const SubmitBankDetailsScreen({
    super.key,
    required this.returnId,
    this.existingDetails,
  });

  @override
  State<SubmitBankDetailsScreen> createState() => _SubmitBankDetailsScreenState();
}

class _SubmitBankDetailsScreenState extends State<SubmitBankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _returnService = ReturnService();

  final _nameCtrl     = TextEditingController();
  final _bankCtrl     = TextEditingController();
  final _acCtrl       = TextEditingController();
  final _acConfirmCtrl = TextEditingController();
  final _ifscCtrl     = TextEditingController();
  final _upiCtrl      = TextEditingController();

  bool _isSubmitting = false;
  bool _showAccountNumber = false;

  bool get _isEditing => widget.existingDetails != null;

  @override
  void initState() {
    super.initState();
    // Pre-fill if editing
    final e = widget.existingDetails;
    if (e != null) {
      _nameCtrl.text = e.accountHolderName;
      _bankCtrl.text = e.bankName;
      _acCtrl.text   = e.accountNumber;
      _acConfirmCtrl.text = e.accountNumber;
      _ifscCtrl.text = e.ifscCode;
      _upiCtrl.text  = e.upiId ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bankCtrl.dispose();
    _acCtrl.dispose();
    _acConfirmCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await _returnService.submitBankDetails(
        returnId: widget.returnId,
        accountHolderName: _nameCtrl.text.trim(),
        bankName: _bankCtrl.text.trim(),
        accountNumber: _acCtrl.text.trim(),
        ifscCode: _ifscCtrl.text.trim().toUpperCase(),
        upiId: _upiCtrl.text.trim().isNotEmpty ? _upiCtrl.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Bank details updated successfully.'
                : 'Bank details submitted! Pickup will be scheduled soon.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Bank Details' : 'Submit Bank Details'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, color: Color(0xFF3B82F6), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your bank details are safe. Account number is stored securely and shown masked.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Account holder name
              _buildField(
                controller: _nameCtrl,
                label: 'Account Holder Name',
                hint: 'As per bank records',
                icon: Icons.person,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                textCaps: TextCapitalization.words,
              ),
              const SizedBox(height: 14),

              // Bank name
              _buildField(
                controller: _bankCtrl,
                label: 'Bank Name',
                hint: 'e.g. State Bank of India',
                icon: Icons.account_balance,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                textCaps: TextCapitalization.words,
              ),
              const SizedBox(height: 14),

              // Account number
              _buildField(
                controller: _acCtrl,
                label: 'Account Number',
                hint: 'Enter your account number',
                icon: Icons.credit_card,
                keyboardType: TextInputType.number,
                obscure: !_showAccountNumber,
                suffixIcon: IconButton(
                  icon: Icon(_showAccountNumber ? Icons.visibility_off : Icons.visibility, size: 18),
                  onPressed: () => setState(() => _showAccountNumber = !_showAccountNumber),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length < 9) return 'Account number too short';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Confirm account number
              _buildField(
                controller: _acConfirmCtrl,
                label: 'Confirm Account Number',
                hint: 'Re-enter account number',
                icon: Icons.credit_card,
                keyboardType: TextInputType.number,
                obscure: !_showAccountNumber,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim() != _acCtrl.text.trim()) return 'Account numbers do not match';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // IFSC code
              _buildField(
                controller: _ifscCtrl,
                label: 'IFSC Code',
                hint: 'e.g. SBIN0001234',
                icon: Icons.code,
                textCaps: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final ifscRegex = RegExp(r'^[A-Za-z]{4}0[A-Za-z0-9]{6}$');
                  if (!ifscRegex.hasMatch(v.trim())) {
                    return 'Invalid IFSC. Format: XXXX0XXXXXX';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // UPI (optional)
              _buildField(
                controller: _upiCtrl,
                label: 'UPI ID (Optional)',
                hint: 'e.g. name@paytm',
                icon: Icons.phone_android,
                isRequired: false,
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle, size: 20),
                  label: Text(_isSubmitting
                      ? 'Saving...'
                      : _isEditing
                          ? 'Update Bank Details'
                          : 'Submit Bank Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '* Refund will be processed within 2 working days after product inspection.',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    TextCapitalization textCaps = TextCapitalization.none,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      textCapitalization: textCaps,
      validator: isRequired ? validator : null,
      decoration: InputDecoration(
        labelText: isRequired ? label : '$label (Optional)',
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
