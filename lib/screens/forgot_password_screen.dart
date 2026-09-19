import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/backend_config.dart';
import '../customer/customer_model.dart';
import '../services/api_client.dart';
import '../widgets/app_icon.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialPhoneOrEmail;

  const ForgotPasswordScreen({
    super.key,
    this.initialPhoneOrEmail,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 1; // 1 = Phone Input, 2 = Verify OTP, 3 = Generate New Password

  final _phoneKey = GlobalKey<FormState>();
  final _otpKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _verifiedPhone;
  String? _maskedPhone;
  String? _resetToken;

  Timer? _resendTimer;
  int _resendCountdown = 30;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoneOrEmail != null && widget.initialPhoneOrEmail!.trim().isNotEmpty) {
      final input = widget.initialPhoneOrEmail!.trim();
      final digits = input.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        _phoneController.text = digits.substring(digits.length - 10);
      } else if (!input.contains('@')) {
        _phoneController.text = input;
      }
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _showMessage(
    String message, {
    bool isError = true,
    VoidCallback? onOk,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Text(
              isError ? "Error" : "Success",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onOk?.call();
            },
            child: const Text(
              "OK",
              style: TextStyle(color: Color(0xFFEA0180), fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {Widget? prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEA0180), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  /// Step 1: Send OTP to mobile/WhatsApp
  Future<void> _sendOtp() async {
    if (!_phoneKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    setState(() => _loading = true);

    try {
      final response = await ApiClient.post(
        Uri.parse("${BackendConfig.baseUrl}/auth/forgot-password/send-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone}),
      ).timeout(const Duration(seconds: 15));

      Map<String, dynamic> data = {};
      try {
        if (response.body.isNotEmpty) {
          data = jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (_) {}

      if (response.statusCode >= 400 || data["success"] != true) {
        final msg = data["message"]?.toString() ?? "Unable to send verification OTP (Status ${response.statusCode})";
        _showMessage(msg);
        return;
      }

      setState(() {
        _verifiedPhone = data["phone"]?.toString() ?? phone;
        _maskedPhone = data["maskedPhone"]?.toString() ?? phone;
        _otpController.clear();
        _currentStep = 2; // Move to OTP step
      });

      _startResendTimer();

      final infoMsg = data["message"]?.toString() ?? "OTP sent to your WhatsApp number";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(infoMsg),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      _showMessage("Could not send verification OTP. ${e.toString().replaceAll('Exception: ', '')}");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Step 2: Verify 6-digit OTP
  Future<void> _verifyOtp() async {
    if (!_otpKey.currentState!.validate()) return;

    final otp = _otpController.text.trim();
    final phone = _verifiedPhone ?? _phoneController.text.trim();

    setState(() => _loading = true);

    try {
      final response = await ApiClient.post(
        Uri.parse("${BackendConfig.baseUrl}/auth/forgot-password/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone, "otp": otp}),
      ).timeout(const Duration(seconds: 15));

      Map<String, dynamic> data = {};
      try {
        if (response.body.isNotEmpty) {
          data = jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (_) {}

      if (response.statusCode >= 400 || data["success"] != true) {
        final msg = data["message"]?.toString() ?? "Invalid verification code (Status ${response.statusCode})";
        _showMessage(msg);
        return;
      }

      setState(() {
        _resetToken = data["resetToken"]?.toString();
        _currentStep = 3; // Redirect to generate new password
      });

      _resendTimer?.cancel();
    } catch (e) {
      _showMessage("Could not verify OTP. ${e.toString().replaceAll('Exception: ', '')}");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Step 3: Generate New Password & Redirect to Homepage
  Future<void> _resetPasswordAndLogin() async {
    if (!_passwordKey.currentState!.validate()) return;

    final newPassword = _passwordController.text;
    final resetToken = _resetToken;

    if (resetToken == null || resetToken.isEmpty) {
      _showMessage("Reset session expired. Please request a new OTP.", onOk: () {
        setState(() => _currentStep = 1);
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await ApiClient.post(
        Uri.parse("${BackendConfig.baseUrl}/auth/forgot-password/reset-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "resetToken": resetToken,
          "newPassword": newPassword,
        }),
      ).timeout(const Duration(seconds: 20));

      Map<String, dynamic> data = {};
      try {
        if (response.body.isNotEmpty) {
          data = jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (_) {}

      if (response.statusCode >= 400 || data["success"] != true) {
        final msg = data["message"]?.toString() ?? "Could not reset password. Please try again.";
        _showMessage(msg);
        return;
      }

      // If customer session returned, log in automatically
      if (data["customer"] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("customer", jsonEncode(data["customer"]));
        if (mounted) {
          context.read<CustomerModel>().getCustomer(context);
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password updated successfully! Welcome back."),
          backgroundColor: Color(0xFFEA0180),
          duration: Duration(seconds: 3),
        ),
      );

      // Redirect to homepage
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (e) {
      _showMessage("Could not update password. ${e.toString().replaceAll('Exception: ', '')}");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () {
            if (_currentStep == 2) {
              setState(() => _currentStep = 1);
            } else if (_currentStep == 3) {
              setState(() => _currentStep = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          "Forgot Password",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepIndicator(),
                const SizedBox(height: 30),
                if (_currentStep == 1) _buildStep1PhoneInput(),
                if (_currentStep == 2) _buildStep2OtpVerification(),
                if (_currentStep == 3) _buildStep3GenerateNewPassword(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Step progress indicator (1 -> 2 -> 3)
  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepBadge(1, "Phone"),
        _buildStepDivider(1),
        _buildStepBadge(2, "Verify"),
        _buildStepDivider(2),
        _buildStepBadge(3, "New Password"),
      ],
    );
  }

  Widget _buildStepBadge(int step, String label) {
    final bool isCompleted = _currentStep > step;
    final bool isActive = _currentStep == step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? Colors.green
                  : isActive
                      ? const Color(0xFFEA0180)
                      : const Color(0xFFF0F0F0),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      "$step",
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? const Color(0xFFEA0180) : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider(int step) {
    final bool isPassed = _currentStep > step;
    return Container(
      width: 30,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: isPassed ? Colors.green : const Color(0xFFE0E0E0),
    );
  }

  /// STEP 1: Phone Input
  Widget _buildStep1PhoneInput() {
    return Form(
      key: _phoneKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFDF0F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: Color(0xFFEA0180),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Reset Password",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter your registered WhatsApp or mobile number to receive a verification OTP.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            "Mobile Number",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: _inputDecoration(
              "10-digit mobile number",
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Text(
                  "+91",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ),
              suffixIcon: const Icon(Icons.phone_android_outlined, color: Colors.grey),
            ).copyWith(counterText: ""),
            validator: (v) {
              final val = v?.trim() ?? "";
              if (val.isEmpty) return "Please enter your mobile number";
              if (val.length != 10 || !RegExp(r'^\d{10}$').hasMatch(val)) {
                return "Please enter a valid 10-digit mobile number";
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA0180),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      "Send OTP",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// STEP 2: OTP Verification
  Widget _buildStep2OtpVerification() {
    return Form(
      key: _otpKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: Color(0xFF25D366),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Enter OTP",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We have sent a 6-digit verification code to ${_maskedPhone ?? _verifiedPhone ?? 'your WhatsApp'}.",
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            "6-Digit OTP",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
            decoration: _inputDecoration(
              "• • • • • •",
              prefixIcon: const Icon(Icons.security, color: Colors.grey),
            ).copyWith(counterText: ""),
            validator: (v) {
              final val = v?.trim() ?? "";
              if (val.length != 6) return "Please enter the complete 6-digit OTP";
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() => _currentStep = 1);
                },
                child: const Text(
                  "Change Number",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: _resendCountdown == 0 && !_loading ? _sendOtp : null,
                child: Text(
                  _resendCountdown > 0
                      ? "Resend in ${_resendCountdown}s"
                      : "Resend OTP",
                  style: TextStyle(
                    color: _resendCountdown == 0 ? const Color(0xFFEA0180) : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA0180),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      "Verify OTP",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// STEP 3: Generate New Password
  Widget _buildStep3GenerateNewPassword() {
    return Form(
      key: _passwordKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFDF0F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFFEA0180),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Generate New Password",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your new password must be at least 6 characters long.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "New Password",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: _inputDecoration(
              "Enter new password",
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: AppIcon(
                  isActive: false,
                  outlinePath: _obscurePassword
                      ? 'assets/icons/HideOutline.svg'
                      : 'assets/icons/ShowOutline.svg',
                  filledPath: _obscurePassword
                      ? 'assets/icons/HideOutline.svg'
                      : 'assets/icons/ShowOutline.svg',
                  size: 22,
                ),
              ),
            ),
            validator: (v) {
              final val = v ?? "";
              if (val.isEmpty) return "Please enter a new password";
              if (val.length < 6) return "Password must be at least 6 characters";
              return null;
            },
          ),
          const SizedBox(height: 18),
          const Text(
            "Confirm New Password",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: _inputDecoration(
              "Re-enter new password",
              prefixIcon: const Icon(Icons.lock_reset, color: Colors.grey),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                },
                icon: AppIcon(
                  isActive: false,
                  outlinePath: _obscureConfirmPassword
                      ? 'assets/icons/HideOutline.svg'
                      : 'assets/icons/ShowOutline.svg',
                  filledPath: _obscureConfirmPassword
                      ? 'assets/icons/HideOutline.svg'
                      : 'assets/icons/ShowOutline.svg',
                  size: 22,
                ),
              ),
            ),
            validator: (v) {
              final val = v ?? "";
              if (val.isEmpty) return "Please confirm your password";
              if (val != _passwordController.text) {
                return "Passwords do not match";
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _resetPasswordAndLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA0180),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      "Update Password",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
