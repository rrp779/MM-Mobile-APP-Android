import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_icon.dart';
import '../customer/customer_model.dart';
import '../screens/profile_screen.dart';

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

  bool obscure = true;
  bool loading = false;
  bool remember = false;

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
    _tabController.dispose();
    super.dispose();
  }

  void showMessage(String message, {bool isError = true}) {
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
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        );
      },
    );
  }
  /// LOGIN
  Future<void> login() async {
    if (!_loginKey.currentState!.validate()) return;

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
      showMessage("Login successful");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AccountPage(),
        ),
      );
    }
  }

  /// REGISTER
  Future<void> register() async {
    if (!_registerKey.currentState!.validate()) return;

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

    showMessage("Account created successfully");

    /// Auto login
    login();
  }

  /// FORGOT PASSWORD
  Future<void> forgotPassword() async {
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
        variables: {"email": emailController.text},
      ),
    );

    if (result.hasException) {
      showMessage(result.exception.toString());
      return;
    }

    final errors = result.data!['customerRecover']['customerUserErrors'];

    if (errors.isNotEmpty) {
      showMessage(errors[0]['message']);
    } else {
      showMessage("Password reset email sent");
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

                          const Text("Email"),
                          const SizedBox(height: 6),

                          TextFormField(
                            controller: emailController,
                            decoration: input("Email"),
                            validator: (v) =>
                            v!.isEmpty ? "Enter email" : null,
                          ),

                          const SizedBox(height: 16),

                          const Text("Password"),
                          const SizedBox(height: 6),

                          TextFormField(
                            controller: passwordController,
                            obscureText: obscure,
                            decoration: input("Password").copyWith(
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
                                  style: TextStyle(color: const  Color(0xFFEA0180)),
                                ),
                              )
                            ],
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            height: 50,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: loading ? null : login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                const  Color(0xFFEA0180),

                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(12),
                                ),
                              ),
                              child: loading
                                  ? const CircularProgressIndicator(
                                  color: Colors.white)
                                  : const Text(
                                "Log In",
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

                    /// REGISTER FORM

                    Form(
                      key: _registerKey,
                      child: ListView(
                        children: [
                          const Text("First Name"),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: firstNameController,
                            decoration: input("First Name"),
                            validator: (v) =>
                            v!.isEmpty ? "Enter first name" : null,
                          ),

                          const SizedBox(height: 12),
                          const Text("Last Name"),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: lastNameController,
                            decoration: input("Last Name"),
                            validator: (v) =>
                            v!.isEmpty ? "Enter last name" : null,
                          ),

                          const SizedBox(height: 12),
                          const Text("Email"),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: emailController,
                            decoration: input("Email"),
                            validator: (v) =>
                            v!.isEmpty ? "Enter email" : null,
                          ),

                          const SizedBox(height: 12),
                          const Text("Password"),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: passwordController,
                            obscureText: obscure,
                            decoration: input("Password"),
                            validator: (v) =>
                            v!.isEmpty ? "Enter password" : null,
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: loading ? null : register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                const  Color(0xFFEA0180),

                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(12),
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