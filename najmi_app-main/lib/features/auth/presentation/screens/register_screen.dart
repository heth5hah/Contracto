import 'package:flutter/material.dart';
import 'package:contracto_app/features/auth/data/services/auth_service.dart';
import 'package:contracto_app/features/auth/data/models/user_model.dart';
import 'package:contracto_app/shared/widgets/main_navigation.dart';
import 'package:contracto_app/shared/widgets/app_button.dart';
import 'package:contracto_app/core/utils/error_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final AuthService _authService = AuthService();
  UserType _selectedUserType = UserType.individual;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _mobileController.dispose();
    _panController.dispose();
    _gstController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final mobile = _mobileController.text.trim();
    final pan = _panController.text.trim().toUpperCase();
    final gst = _gstController.text.trim().toUpperCase();

    // Validation
    if (name.isEmpty) {
      _showSnackBar('Please enter your full name', isError: true);
      return;
    }

    if (email.isEmpty) {
      _showSnackBar('Please enter your email address', isError: true);
      return;
    }

    if (!_isValidEmail(email)) {
      _showSnackBar('Please enter a valid email address', isError: true);
      return;
    }

    if (password.isEmpty) {
      _showSnackBar('Please enter a password', isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters', isError: true);
      return;
    }

    if (confirmPassword.isEmpty) {
      _showSnackBar('Please confirm your password', isError: true);
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match', isError: true);
      return;
    }

    if (mobile.isEmpty) {
      _showSnackBar('Please enter your mobile number', isError: true);
      return;
    }

    if (!_isValidMobile(mobile)) {
      _showSnackBar('Please enter a valid 10-digit mobile number',
          isError: true);
      return;
    }

    // Company-specific validations
    if (_selectedUserType == UserType.company) {
      final companyName = _companyNameController.text.trim();
      if (companyName.isEmpty) {
        _showSnackBar('Company name is required for business accounts',
            isError: true);
        return;
      }

      if (gst.isEmpty) {
        _showSnackBar('GST number is required for business accounts',
            isError: true);
        return;
      }
    }

    // Validate PAN format if provided (only for company users)
    if (_selectedUserType == UserType.company &&
        pan.isNotEmpty &&
        !_isValidPan(pan)) {
      _showSnackBar('Please enter a valid PAN number', isError: true);
      return;
    }

    // Validate GST format if provided
    if (gst.isNotEmpty && !_isValidGst(gst)) {
      _showSnackBar('Please enter a valid GST number', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if email is already registered
      final isEmailExists = await _authService.isEmailRegistered(email);
      if (isEmailExists) {
        _showSnackBar('This email is already registered. Please login instead.',
            isError: true);
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Check if mobile is already registered
      final isMobileExists = await _authService.isMobileRegistered(mobile);
      if (isMobileExists) {
        _showSnackBar(
            'This mobile number is already registered with another account',
            isError: true);
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Check if PAN is already registered (only for company users)
      if (_selectedUserType == UserType.company && pan.isNotEmpty) {
        final isPanExists = await _authService.isPanRegistered(pan);
        if (isPanExists) {
          _showSnackBar('This PAN number is already registered with another account',
              isError: true);
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Check if GST is already registered (if provided)
      if (gst.isNotEmpty) {
        final isGstExists = await _authService.isGstRegistered(gst);
        if (isGstExists) {
          _showSnackBar('This GST number is already registered with another account',
              isError: true);
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Register the user
      final user = await _authService.registerWithEmailPassword(
        email: email,
        password: password,
        name: name,
        mobile: mobile,
        pan: _selectedUserType == UserType.company && pan.isNotEmpty
            ? pan
            : null,
        gstNumber: gst.isEmpty ? null : gst,
        userType: _selectedUserType,
        companyName: _companyNameController.text.trim().isEmpty
            ? null
            : _companyNameController.text.trim(),
      );

      if (user != null) {
        _showSnackBar(
            'Registration successful! Welcome to Contracto, ${user.name}!');

        // Navigate to home screen
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const MainNavigation(),
            ),
            (route) => false,
          );
        }
      } else {
        _showSnackBar('Registration failed. Please try again.', isError: true);
      }
    } catch (e) {
      // Check if the error is about user already existing (from Supabase)
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('user already registered') || 
          errorString.contains('email already exists') ||
          errorString.contains('already registered') ||
          errorString.contains('duplicate')) {
        _showSnackBar(
          'This email is already registered. Please login instead.',
          isError: true,
        );
      } else {
        final humanReadableError = ErrorHelper.getHumanReadableError(e);
        final errorTitle = ErrorHelper.getErrorTitle(e);

        _showSnackBar(humanReadableError, isError: true);

        // Also show a more detailed error dialog for other errors
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(errorTitle),
              content: Text(humanReadableError),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool _isValidMobile(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length == 10;
  }

  bool _isValidPan(String pan) {
    // PAN format: ABCDE1234F (5 letters, 4 digits, 1 letter)
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    return panRegex.hasMatch(pan);
  }

  bool _isValidGst(String gst) {
    // GST format: 15 characters
    final gstRegex =
        RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
    return gstRegex.hasMatch(gst);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Text
            const Text(
              'Join Contracto',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your account to start ordering',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 32),

            // User Type Selection
            _buildUserTypeSelection(),
            const SizedBox(height: 20),

            // Full Name Field
            Text(
              _selectedUserType == UserType.company
                  ? 'Contact Person Name'
                  : 'Full Name',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: _selectedUserType == UserType.company
                    ? 'Enter contact person name'
                    : 'Enter your full name',
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),

            const SizedBox(height: 20),

            // Email Field
            const Text(
              'Email Address',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Enter your email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),

            const SizedBox(height: 20),

            // Password Field
            const Text(
              'Password',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Enter your password (min 6 characters)',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Confirm Password Field
            const Text(
              'Confirm Password',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                hintText: 'Confirm your password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Mobile Number Field
            const Text(
              'Mobile Number',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                hintText: 'Enter 10-digit mobile number',
                prefixIcon: Icon(Icons.phone_outlined),
                counterText: '',
              ),
              onChanged: (value) {
                final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                if (digits.length <= 10) {
                  _mobileController.value = TextEditingValue(
                    text: digits,
                    selection: TextSelection.collapsed(offset: digits.length),
                  );
                }
              },
            ),

            const SizedBox(height: 20),

            // Company Name Field (if company is selected)
            if (_selectedUserType == UserType.company) ...[
              const Text(
                'Company Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  hintText: 'Enter company name',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // PAN Number Field (only for company users)
            if (_selectedUserType == UserType.company) ...[
              const Text(
                'PAN Number',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _panController,
                maxLength: 10,
                decoration: const InputDecoration(
                  hintText: 'Enter PAN number (optional, e.g., ABCDE1234F)',
                  prefixIcon: Icon(Icons.credit_card_outlined),
                  counterText: '',
                ),
                onChanged: (value) {
                  _panController.value = TextEditingValue(
                    text: value.toUpperCase(),
                    selection: TextSelection.collapsed(offset: value.length),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            // GST Number Field
            Text(
              _selectedUserType == UserType.company
                  ? 'GST Number *'
                  : 'GST Number (Optional)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _gstController,
              maxLength: 15,
              decoration: InputDecoration(
                hintText: _selectedUserType == UserType.company
                    ? 'Enter 15-digit GST number'
                    : 'Enter GST number (optional)',
                prefixIcon: const Icon(Icons.business_outlined),
                counterText: '',
              ),
              onChanged: (value) {
                _gstController.value = TextEditingValue(
                  text: value.toUpperCase(),
                  selection: TextSelection.collapsed(offset: value.length),
                );
              },
            ),

            const SizedBox(height: 32),

            // Register Button
            AppButton(
              text: _isLoading ? 'Creating Account...' : 'Create Account',
              onPressed: _isLoading ? null : _register,
              isLoading: _isLoading,
            ),

            const SizedBox(height: 24),

            // Login Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Terms and Privacy
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'By creating an account, you agree to our Terms of Service and Privacy Policy',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTypeSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildUserTypeOption(
                  type: UserType.individual,
                  title: 'Individual',
                  subtitle: 'Personal account',
                  icon: Icons.person,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUserTypeOption(
                  type: UserType.company,
                  title: 'Company',
                  subtitle: 'Business account',
                  icon: Icons.business,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserTypeOption({
    required UserType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedUserType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUserType = type;
          // Clear company fields if switching to individual
          if (type == UserType.individual) {
            _companyNameController.clear();
            _gstController.clear();
            _panController.clear();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF1E293B),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
