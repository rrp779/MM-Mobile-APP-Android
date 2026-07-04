import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_icon.dart';
import '../customer/customer_model.dart';
import '../screens/profile_screen.dart';
import '../config/backend_config.dart';

class CustomerLoginRegister extends StatefulWidget {
  const CustomerLoginRegister({super.key});

  @override
  State<CustomerLoginRegister> createState() => _CustomerLoginRegisterState();
}

class _CustomerLoginRegisterState extends State<CustomerLoginRegister>
    with SingleTickerProviderStateMixin {

  final _loginKey = GlobalKey<FormState>();
  final _registerKey = GlobalKey<FormState>();

  late TabController _tabController;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final otpController = TextEditingController();
  final registerPhoneController = TextEditingController();
  final registerOtpController = TextEditingController();

  bool obscure = true;
  bool loading = false;
  bool remember = false;
  bool loginWithWhatsApp = true;
  bool otpSent = false;
  bool registerOtpSent = false;
  bool registerPhoneVerified = false;
  String? registerVerifiedPhone;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    otpController.dispose();
    registerPhoneController.dispose();
    registerOtpController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void showMessage(
    String message, {
    bool isError = true,
    VoidCallback? onOk,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {

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
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onOk?.call();
              },
              child: const Text("OK"),
            )
          ],
        );
      },
    );
  }
  /// LOGIN
  Future<void> login({
    bool validateForm = true,
    bool showSuccessMessage = true,
  }) async {
    if (validateForm && !_loginKey.currentState!.validate()) return;

    setState(() => loading = true);

    final client = GraphQLProvider.of(context).value;

    final result = await client.mutate(
      MutationOptions(
        document: gql(r'''
        mutation customerAccessTokenCreate($input: CustomerAccessTokenCreateInput!) {
          customerAccessTokenCreate(input:$input) {
            customerAccessToken {
              accessToken
              expiresAt
            }
            customerUserErrors {
              message
            }
          }
        }
        '''),
        variables: {
          "input": {
            "email": emailController.text.trim(),
            "password": passwordController.text,
          }
        },
      ),
    );

    if (kDebugMode) {
      print(result.data);
      print(result.exception);
    }

    setState(() => loading = false);

    if (result.hasException) {
      showMessage(result.exception.toString());
      return;
    }

    final errors =
    result.data!['customerAccessTokenCreate']['customerUserErrors'];

    if (errors.isNotEmpty) {
      final apiMessage = errors[0]['message'].toString().toLowerCase();

      String userMessage;

      if (apiMessage.contains("unidentified") ||
          apiMessage.contains("invalid") ||
          apiMessage.contains("customer")) {

        userMessage = "Invalid email or password";

      } else {
        userMessage = "Something went wrong. Please try again";
      }

      showMessage(userMessage);
      return;
    }

    final token =
    result.data!['customerAccessTokenCreate']['customerAccessToken'];

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
        "customer",
        jsonEncode({
          "accessToken": token["accessToken"],
          "expiresAt": token["expiresAt"],
        }));

    if (context.mounted) {
      context.read<CustomerModel>().getCustomer(context);
      if (showSuccessMessage) {
        showMessage("Login successful", isError: false);
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AccountPage(),
        ),
      );
    }
  }

  Future<void> sendWhatsAppOtp({bool forRegister = false}) async {
    final phone = (forRegister ? registerPhoneController : phoneController).text.trim();
    if (phone.isEmpty) {
      showMessage("Enter WhatsApp mobile number");
      return;
    }

    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse("${BackendConfig.baseUrl}/auth/whatsapp/send-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone}),
      );

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
        } else {
          otpSent = true;
        }
      });

      final devOtp = data["devOtp"];
      showMessage(
        devOtp == null
            ? "OTP sent on WhatsApp"
            : "OTP sent on WhatsApp. Dev OTP: $devOtp",
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

  Future<void> verifyWhatsAppOtp({bool forRegister = false}) async {
    final phone = (forRegister ? registerPhoneController : phoneController).text.trim();
    final otp = (forRegister ? registerOtpController : otpController).text.trim();
    if (phone.isEmpty || otp.length != 6) {
      showMessage("Enter the 6 digit OTP");
      return;
    }

    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse("${BackendConfig.baseUrl}/auth/whatsapp/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": phone,
          "otp": otp,
          "firstName": firstNameController.text.trim(),
          "lastName": lastNameController.text.trim(),
          "verifyOnly": forRegister,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode >= 400 || data["success"] != true) {
        showMessage(data["message"] ?? "Invalid OTP");
        return;
      }

      if (forRegister) {
        setState(() {
          registerPhoneVerified = true;
          registerVerifiedPhone = data["phone"]?.toString();
        });
        showMessage("WhatsApp number verified", isError: false);
        return;
      }

      final customer = data["customer"];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("customer", jsonEncode(customer));

      if (!mounted) return;
      context.read<CustomerModel>().getCustomer(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AccountPage(),
        ),
      );
    } catch (_) {
      showMessage(
        "We could not verify the OTP right now. Please check your internet connection and try again.",
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// REGISTER
  Future<void> register() async {
    if (!_registerKey.currentState!.validate()) return;
    if (!registerPhoneVerified) {
      showMessage("Please verify your WhatsApp number first");
      return;
    }

    setState(() => loading = true);

    final client = GraphQLProvider.of(context).value;

    final result = await client.mutate(
      MutationOptions(
        document: gql(r'''
        mutation customerCreate($input:CustomerCreateInput!){
          customerCreate(input:$input){
            customer { id }
            customerUserErrors { message }
          }
        }
        '''),
        variables: {
          "input": {
            "firstName": firstNameController.text,
            "lastName": lastNameController.text,
            "email": emailController.text,
            "password": passwordController.text,
            "phone": registerVerifiedPhone ?? registerPhoneController.text.trim(),
          }
        },
      ),
    );

    setState(() => loading = false);

    if (result.hasException) {
      showMessage(result.exception.toString());
      return;
    }

    final errors = result.data!['customerCreate']['customerUserErrors'];

    if (errors.isNotEmpty) {
      showMessage(errors[0]['message']);
      return;
    }

    showMessage(
      "Account created successfully",
      isError: false,
      onOk: () => login(
        validateForm: false,
        showSuccessMessage: false,
      ),
    );
  }

  /// FORGOT PASSWORD
  Future<void> forgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      showMessage("Please enter your email address first, then tap Forgot Password.");
      return;
    }

    final client = GraphQLProvider.of(context).value;

    final result = await client.mutate(
      MutationOptions(
        document: gql(r'''
        mutation customerRecover($email:String!){
          customerRecover(email:$email){
            customerUserErrors{message}
          }
        }
        '''),
        variables: {"email": email},
      ),
    );

    if (result.hasException) {
      showMessage(
        "We could not send the password reset email right now. Please check your internet connection and try again.",
      );
      return;
    }

    final errors = result.data!['customerRecover']['customerUserErrors'];

    if (errors.isNotEmpty) {
      showMessage(errors[0]['message']);
    } else {
      showMessage(
        "Password reset email sent. Please check your inbox and open the reset link.",
        isError: false,
      );
    }
  }

  InputDecoration input(String hint) {
    return InputDecoration(
      hintText: "Enter your ${hint.toLowerCase()}",
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 12,
      ),

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

  Widget authMethodSwitch() {
    Widget option({
      required String text,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 48,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEA0180) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? const Color(0xFFEA0180) : const Color(0xFFE5E5E5),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFEA0180).withOpacity(0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.black87,
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(
          text: "WhatsApp",
          icon: Icons.chat_bubble_outline,
          selected: loginWithWhatsApp,
          onTap: () => setState(() => loginWithWhatsApp = true),
        ),
        const SizedBox(width: 10),
        option(
          text: "Email",
          icon: Icons.mail_outline,
          selected: !loginWithWhatsApp,
          onTap: () => setState(() => loginWithWhatsApp = false),
        ),
      ],
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
          decoration: input("WhatsApp number").copyWith(
            prefixIcon: const Icon(Icons.phone_android_outlined),
            suffixIcon: verified
                ? const Icon(Icons.verified, color: Colors.green)
                : null,
          ),
          onChanged: (_) {
            if (forRegister && registerPhoneVerified) {
              setState(() {
                registerPhoneVerified = false;
                registerVerifiedPhone = null;
              });
            }
          },
          validator: forRegister
              ? (v) => v!.trim().isEmpty ? "Enter WhatsApp number" : null
              : null,
        ),
        if (otpWasSent && !verified) ...[
          const SizedBox(height: 12),
          label("OTP"),
          const SizedBox(height: 6),
          TextFormField(
            controller: otp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: input("OTP").copyWith(counterText: ""),
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
            child: Text(
              verified
                  ? "WhatsApp Verified"
                  : otpWasSent
                      ? "Verify WhatsApp OTP"
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
              onPressed: loading
                  ? null
                  : () => sendWhatsAppOtp(forRegister: forRegister),
              child: const Text(
                "Resend OTP",
                style: TextStyle(color: Color(0xFFEA0180)),
              ),
            ),
          ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Account",
              style: TextStyle(fontSize: 16),
            ),

          ],
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [

              const SizedBox(height: 30),

              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 50,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              const Text(
                "Create an account or log in to explore\nabout our app",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 30),

              /// -------- TAB SWITCH --------

              Container(
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xffF1F1F1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    /// ANIMATED BACKGROUND
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
                    /// BUTTONS
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

              const SizedBox(height: 25),

              /// -------- FORMS --------

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [

                    /// LOGIN FORM

                    Form(
                      key: _loginKey,
                      child: ListView(
                        children: [
                          authMethodSwitch(),
                          const SizedBox(height: 22),

                          if (loginWithWhatsApp) ...[
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
                          ] else ...[
                            label("Email"),
                            const SizedBox(height: 6),

                            TextFormField(
                              controller: emailController,
                              decoration: input("Email").copyWith(
                                prefixIcon: const Icon(Icons.mail_outline),
                              ),
                              validator: (v) =>
                              v!.isEmpty ? "Enter email" : null,
                            ),

                            const SizedBox(height: 16),

                            label("Password"),
                            const SizedBox(height: 6),

                            TextFormField(
                              controller: passwordController,
                              obscureText: obscure,
                              decoration: input("Password").copyWith(
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      obscure = !obscure;
                                    });
                                  },
                                  icon: AppIcon(
                                    isActive: false,
                                    outlinePath: obscure
                                        ? 'assets/icons/HideOutline.svg'
                                        : 'assets/icons/ShowOutline.svg',
                                    filledPath: obscure
                                        ? 'assets/icons/HideOutline.svg'
                                        : 'assets/icons/ShowOutline.svg',
                                    size: 22,
                                  ),
                                ),
                              ),
                              validator: (v) =>
                              v!.isEmpty ? "Enter password" : null,
                            ),

                            const SizedBox(height: 8),

                            Row(
                              children: [
                                Checkbox(
                                  value: remember,
                                  onChanged: (v) {
                                    setState(() {
                                      remember = v!;
                                    });
                                  },
                                ),
                                const Text("Remember me"),
                                const Spacer(),
                                GestureDetector(
                                  onTap: forgotPassword,
                                  child: const Text(
                                    "Forgot Password?",
                                    style: TextStyle(color: Color(0xFFEA0180)),
                                  ),
                                )
                              ],
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              height: 52,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: loading ? null : () => login(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  const  Color(0xFFEA0180),

                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(14),
                                  ),
                                ),
                                child: loading
                                    ? const CircularProgressIndicator(
                                    color: Colors.white)
                                    : const Text(
                                  "Log In",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),

                    /// REGISTER FORM

                    Form(
                      key: _registerKey,
                      child: ListView(
                        children: [
                          label("First Name"),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: firstNameController,
                            decoration: input("First Name"),
                            validator: (v) =>
                            v!.isEmpty ? "Enter first name" : null,
                          ),

                          const SizedBox(height: 12),
                          label("Last Name"),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: lastNameController,
                            decoration: input("Last Name"),
                            validator: (v) =>
                            v!.isEmpty ? "Enter last name" : null,
                          ),

                          const SizedBox(height: 12),
                          phoneVerificationFields(
                            phone: registerPhoneController,
                            otp: registerOtpController,
                            otpWasSent: registerOtpSent,
                            verified: registerPhoneVerified,
                            forRegister: true,
                          ),

                          const SizedBox(height: 12),
                          label("Email"),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: input("Email").copyWith(
                              prefixIcon: const Icon(Icons.mail_outline),
                            ),
                            validator: (v) =>
                            v!.isEmpty ? "Enter email" : null,
                          ),

                          const SizedBox(height: 12),
                          label("Password"),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: passwordController,
                            obscureText: obscure,
                            decoration: input("Password").copyWith(
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    obscure = !obscure;
                                  });
                                },
                                icon: AppIcon(
                                  isActive: false,
                                  outlinePath: obscure
                                      ? 'assets/icons/HideOutline.svg'
                                      : 'assets/icons/ShowOutline.svg',
                                  filledPath: obscure
                                      ? 'assets/icons/HideOutline.svg'
                                      : 'assets/icons/ShowOutline.svg',
                                  size: 22,
                                ),
                              ),
                            ),
                            validator: (v) =>
                            v!.isEmpty ? "Enter password" : null,
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: loading ? null : register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                const  Color(0xFFEA0180),

                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(14),
                                ),
                              ),
                              child: loading
                                  ? const CircularProgressIndicator(
                                  color: Colors.white)
                                  : const Text("Register",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,// optional (safe)
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
