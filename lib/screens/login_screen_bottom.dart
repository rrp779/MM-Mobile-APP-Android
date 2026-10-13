import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../customer/customer_model.dart';
import '../config/backend_config.dart';
import '../services/api_client.dart';

class CustomerLoginRegisterBottom extends StatefulWidget {
  const CustomerLoginRegisterBottom({super.key});

  @override
  State<CustomerLoginRegisterBottom> createState() =>
      _CustomerLoginRegisterBottomState();
}

class _CustomerLoginRegisterBottomState
    extends State<CustomerLoginRegisterBottom>
    with SingleTickerProviderStateMixin {
  final _loginKey = GlobalKey<FormState>();
  final _registerKey = GlobalKey<FormState>();

  late TabController _tabController;

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final otpController = TextEditingController();
  final registerPhoneController = TextEditingController();
  final registerOtpController = TextEditingController();

  bool loading = false;
  bool otpSent = false;
  bool registerOtpSent = false;
  bool registerPhoneVerified = false;
  String? registerVerifiedPhone;
  Map<String, dynamic>? registerVerifiedCustomer;

  Timer? _loginResendTimer;
  int _loginResendCountdown = 0;
  Timer? _registerResendTimer;
  int _registerResendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _startLoginResendTimer() {
    _loginResendTimer?.cancel();
    setState(() => _loginResendCountdown = 60);
    _loginResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_loginResendCountdown > 0) {
        setState(() => _loginResendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _startRegisterResendTimer() {
    _registerResendTimer?.cancel();
    setState(() => _registerResendCountdown = 60);
    _registerResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_registerResendCountdown > 0) {
        setState(() => _registerResendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _loginResendTimer?.cancel();
    _registerResendTimer?.cancel();
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    otpController.dispose();
    registerPhoneController.dispose();
    registerOtpController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void showMessage(String message, {bool isError = true, bool autoClose = false}) {
    showDialog(
      context: context,
      barrierDismissible: isError || !autoClose,
      builder: (_) {
        if (!isError && autoClose) {
          Future.delayed(const Duration(seconds: 1), () {
            if (!mounted) return;
            if (Navigator.canPop(context)) Navigator.pop(context); // close dialog
            if (Navigator.canPop(context)) Navigator.pop(context, true); // close bottom sheet
          });
        }

        return AlertDialog(
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
              Text(isError ? "Error" : "Success"),
            ],
          ),
          content: Text(message),
          actions: (isError || !autoClose)
              ? [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("OK"),
                  )
                ]
              : [],
        );
      },
    );
  }

  Future<void> sendWhatsAppOtp({bool forRegister = false}) async {
    final rawPhone =
        (forRegister ? registerPhoneController : phoneController).text.trim();
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    final last10 =
        digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
    if (last10.isEmpty) {
      showMessage("Please enter your WhatsApp number");
      return;
    }
    if (last10.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(last10)) {
      showMessage("Please enter a valid 10-digit WhatsApp number");
      return;
    }
    final phone = last10;

    setState(() => loading = true);

    try {
      final response = await ApiClient.post(
        Uri.parse("${BackendConfig.baseUrl}/auth/whatsapp/send-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone}),
      );

      if (response.statusCode == 404) {
        showMessage(
            "Endpoint not found (404). Please ensure the backend is deployed with WhatsApp OTP routes.");
        return;
      }

      final data = jsonDecode(response.body);
      if (response.statusCode >= 400 || data["success"] != true) {
        showMessage(data["message"] ?? "Unable to send OTP");
        return;
      }

      setState(() {
        if (forRegister) {
          registerOtpSent = true;
          registerPhoneVerified = false;
          registerVerifiedPhone = null;
          registerVerifiedCustomer = null;
          _startRegisterResendTimer();
        } else {
          otpSent = true;
          _startLoginResendTimer();
        }
      });

      showMessage(
        data["message"]?.toString() ?? "OTP sent on WhatsApp",
        isError: false,
      );
    } catch (_) {
      showMessage(
        "We could not send the WhatsApp OTP right now. Please check your internet connection and try again.",
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<bool> verifyWhatsAppOtp({
    bool forRegister = false,
    bool showVerifiedDialog = true,
  }) async {
    final phone =
        (forRegister ? registerPhoneController : phoneController).text.trim();
    final otp =
        (forRegister ? registerOtpController : otpController).text.trim();
    if (phone.isEmpty || otp.length != 6) {
      showMessage("Enter the 6 digit OTP");
      return false;
    }

    setState(() => loading = true);

    try {
      final response = await ApiClient.post(
        Uri.parse("${BackendConfig.baseUrl}/auth/whatsapp/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": phone,
          "otp": otp,
          "firstName": firstNameController.text.trim(),
          "lastName": lastNameController.text.trim(),
          "verifyOnly": false,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode >= 400 || data["success"] != true) {
        showMessage(data["message"] ?? "Invalid OTP");
        return false;
      }

      final customer = data["customer"] as Map<String, dynamic>?;

      if (forRegister) {
        setState(() {
          registerPhoneVerified = true;
          registerVerifiedPhone =
              customer?["phone"]?.toString() ?? data["phone"]?.toString() ?? phone;
          registerVerifiedCustomer = customer;
        });
        if (showVerifiedDialog) {
          showMessage("WhatsApp number verified", isError: false);
        }
        return true;
      }

      if (customer != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("customer", jsonEncode(customer));
      }

      if (!mounted) return false;
      context.read<CustomerModel>().getCustomer(context);
      showMessage("Login successful", isError: false, autoClose: true);
      return true;
    } catch (_) {
      showMessage(
        "We could not verify the OTP right now. Please check your internet connection and try again.",
      );
      return false;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// REGISTER WITH WHATSAPP ONLY
  Future<void> register() async {
    if (!_registerKey.currentState!.validate()) return;

    if (!registerPhoneVerified) {
      if (registerOtpSent && registerOtpController.text.trim().length == 6) {
        final ok = await verifyWhatsAppOtp(
          forRegister: true,
          showVerifiedDialog: false,
        );
        if (!ok) return;
      } else {
        showMessage(
          "Please verify your WhatsApp number with the OTP before registering.",
        );
        return;
      }
    }

    if (registerVerifiedCustomer == null) {
      showMessage("Unable to complete registration. Please verify OTP again.");
      return;
    }

    setState(() => loading = true);

    try {
      final accessToken = registerVerifiedCustomer!["accessToken"]?.toString();
      final fName = firstNameController.text.trim();
      final lName = lastNameController.text.trim();

      if (accessToken != null && accessToken.isNotEmpty && (fName.isNotEmpty || lName.isNotEmpty)) {
        try {
          final client = GraphQLProvider.of(context).value;
          await client.mutate(
            MutationOptions(
              document: gql(r'''
                mutation customerUpdate($customerAccessToken: String!, $customer: CustomerUpdateInput!) {
                  customerUpdate(customerAccessToken: $customerAccessToken, customer: $customer) {
                    customer { id firstName lastName }
                    customerUserErrors { message }
                  }
                }
              '''),
              variables: {
                "customerAccessToken": accessToken,
                "customer": {
                  if (fName.isNotEmpty) "firstName": fName,
                  if (lName.isNotEmpty) "lastName": lName,
                },
              },
            ),
          );
        } catch (e) {
          if (kDebugMode) {
            print("Optional customerUpdate error: $e");
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("customer", jsonEncode(registerVerifiedCustomer));

      if (!mounted) return;
      setState(() => loading = false);

      context.read<CustomerModel>().getCustomer(context);
      showMessage("Account created successfully", isError: false, autoClose: true);
    } catch (e) {
      if (mounted) setState(() => loading = false);
      showMessage("Something went wrong. Please try again.");
    }
  }

  InputDecoration input(String hint) {
    return InputDecoration(
      hintText: "Enter your ${hint.toLowerCase()}",
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEA0180)),
      ),
    );
  }

  Widget label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
    );
  }

  Widget phoneVerificationFields({
    required TextEditingController phone,
    required TextEditingController otp,
    required bool otpWasSent,
    required bool verified,
    required bool forRegister,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label("WhatsApp Number"),
        const SizedBox(height: 6),
        TextFormField(
          controller: phone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: input("10-digit WhatsApp number").copyWith(
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text(
                "+91",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            ),
            suffixIcon: verified
                ? const Icon(Icons.verified, color: Colors.green)
                : null,
            counterText: "",
          ),
          onChanged: (_) {
            if (forRegister && registerPhoneVerified) {
              setState(() {
                registerPhoneVerified = false;
                registerVerifiedPhone = null;
                registerVerifiedCustomer = null;
              });
            }
          },
          validator: (v) {
            final val = v?.trim() ?? "";
            if (val.isEmpty) return "Please enter your WhatsApp number";
            final digits = val.replaceAll(RegExp(r'\D'), '');
            final last10 =
                digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
            if (last10.length != 10 ||
                !RegExp(r'^[6-9]\d{9}$').hasMatch(last10)) {
              return "Please enter a valid 10-digit WhatsApp number";
            }
            return null;
          },
        ),
        if (otpWasSent && !verified) ...[
          const SizedBox(height: 12),
          label("OTP"),
          const SizedBox(height: 6),
          TextFormField(
            controller: otp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: input("6-digit OTP").copyWith(counterText: ""),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: loading
                ? null
                : verified
                    ? null
                    : otpWasSent
                        ? () => verifyWhatsAppOtp(forRegister: forRegister)
                        : () => sendWhatsAppOtp(forRegister: forRegister),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: verified ? Colors.green : const Color(0xFF25D366),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: loading && !forRegister
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF128C7E),
                    ),
                  )
                : Text(
                    verified
                        ? "WhatsApp Verified"
                        : otpWasSent
                            ? (forRegister
                                ? "Verify WhatsApp OTP"
                                : "Verify OTP & Log In")
                            : "Send WhatsApp OTP",
                    style: TextStyle(
                      color: verified ? Colors.green : const Color(0xFF128C7E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        if (otpWasSent && !verified)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: loading ||
                      (forRegister
                          ? _registerResendCountdown > 0
                          : _loginResendCountdown > 0)
                  ? null
                  : () => sendWhatsAppOtp(forRegister: forRegister),
              child: Text(
                (forRegister
                            ? _registerResendCountdown
                            : _loginResendCountdown) >
                        0
                    ? "Resend OTP in ${(forRegister ? _registerResendCountdown : _loginResendCountdown)}s"
                    : "Resend OTP",
                style: TextStyle(
                  color: (forRegister
                              ? _registerResendCountdown
                              : _loginResendCountdown) ==
                          0
                      ? const Color(0xFFEA0180)
                      : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Image.asset('assets/logo.png', height: 50),
            const SizedBox(height: 20),
            const Text(
              "Create an account or log in",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Container(
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xffF1F1F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: _tabController.index == 0
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      width: MediaQuery.of(context).size.width / 2 - 24,
                      margin: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _tabController.animateTo(0);
                            setState(() {});
                          },
                          child: const Center(
                            child: Text(
                              "Log In",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _tabController.animateTo(1);
                            setState(() {});
                          },
                          child: const Center(
                            child: Text(
                              "Sign Up",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  /// LOGIN FORM (WHATSAPP ONLY)
                  Form(
                    key: _loginKey,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FFFB),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE0F4E8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Fast login with WhatsApp",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Enter your WhatsApp number and verify the OTP.",
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 18),
                              phoneVerificationFields(
                                phone: phoneController,
                                otp: otpController,
                                otpWasSent: otpSent,
                                verified: false,
                                forRegister: false,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// REGISTER FORM (WHATSAPP ONLY)
                  Form(
                    key: _registerKey,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        label("First Name"),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: firstNameController,
                          decoration: input("First Name"),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? "Enter first name" : null,
                        ),
                        const SizedBox(height: 12),
                        label("Last Name"),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: lastNameController,
                          decoration: input("Last Name"),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? "Enter last name" : null,
                        ),
                        const SizedBox(height: 12),
                        phoneVerificationFields(
                          phone: registerPhoneController,
                          otp: registerOtpController,
                          otpWasSent: registerOtpSent,
                          verified: registerPhoneVerified,
                          forRegister: true,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: loading ? null : register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA0180),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    "Register",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}