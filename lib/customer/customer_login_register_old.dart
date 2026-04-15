import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'customer_model.dart';

class CustomerLoginRegister extends StatefulWidget {
	const CustomerLoginRegister({super.key});

	@override
	State<CustomerLoginRegister> createState() => _CustomerLoginRegisterState();
}

class _CustomerLoginRegisterState extends State<CustomerLoginRegister>
		with SingleTickerProviderStateMixin {

	final _loginFormKey = GlobalKey<FormState>();
	final _registrationFormKey = GlobalKey<FormState>();
	final _forgotPasswordFormKey = GlobalKey<FormState>();

	late TabController _tabController;

	final TextEditingController _emailController = TextEditingController();
	final TextEditingController _passwordController = TextEditingController();
	final TextEditingController _firstNameController = TextEditingController();
	final TextEditingController _lastNameController = TextEditingController();

	bool _passwordObscure = true;
	bool _loading = false;

	/// LOGIN
	Future<void> _login(BuildContext context) async {

		setState(() => _loading = true);

		final client = GraphQLProvider.of(context).value;

		final result = await client.mutate(
			MutationOptions(
				document: gql(r'''
mutation customerAccessTokenCreate ($input: CustomerAccessTokenCreateInput!) {
  customerAccessTokenCreate(input: $input)  {
    customerAccessToken {
      accessToken
      expiresAt
    }
    customerUserErrors {
      code
      field
      message
    }
  }
}
'''),
				variables: {
					'input': {
						'email': _emailController.text,
						'password': _passwordController.text,
					}
				},
			),
		);

		if (kDebugMode) {
			print(result);
		}

		final errors =
		result.data?['customerAccessTokenCreate']['customerUserErrors'];

		if (errors != null && errors.isNotEmpty) {
			setState(() => _loading = false);

			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text(errors[0]['message'])),
				);
			}

			return;
		}

		final token =
		result.data!['customerAccessTokenCreate']['customerAccessToken'];

		final prefs = await SharedPreferences.getInstance();

		await prefs.setString(
			'customer',
			jsonEncode({
				'accessToken': token['accessToken'],
				'expiresAt': token['expiresAt'],
			}),
		);

		if (mounted) {
			context.read<CustomerModel>().getCustomer(context);
		}

		setState(() => _loading = false);

		/// CLOSE LOGIN SHEET AND RETURN TRUE
		if (mounted) {
			Navigator.pop(context, true);
		}
	}

	/// REGISTER
	Future<void> _register(BuildContext context) async {

		setState(() => _loading = true);

		final client = GraphQLProvider.of(context).value;

		final result = await client.mutate(
			MutationOptions(
				document: gql(r'''
mutation customerCreate ($input: CustomerCreateInput!) {
  customerCreate(input: $input)  {
    customer { id }
    customerUserErrors {
      code
      field
      message
    }
  }
}
'''),
				variables: {
					'input': {
						'firstName': _firstNameController.text,
						'lastName': _lastNameController.text,
						'email': _emailController.text,
						'password': _passwordController.text,
					}
				},
			),
		);

		if (kDebugMode) {
			print(result);
		}

		if (result.hasException) {
			setState(() => _loading = false);

			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text(result.exception.toString())),
			);
			return;
		}

		final errors = result.data!['customerCreate']['customerUserErrors'];

		if (errors.isNotEmpty) {
			setState(() => _loading = false);

			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text(errors[0]['message'])),
			);
			return;
		}

		/// Auto login after register
		_login(context);
	}

	@override
	void initState() {
		super.initState();
		_tabController = TabController(length: 2, vsync: this);
	}

	@override
	Widget build(BuildContext context) {

		return SafeArea(
			child: Container(
				height: MediaQuery.of(context).size.height * 0.9,
				color: Colors.white,

				child: Column(
					children: [

						/// Drag handle
						Container(
							width: 40,
							height: 4,
							margin: const EdgeInsets.only(top: 12, bottom: 10),
							decoration: BoxDecoration(
								color: Colors.grey.shade300,
								borderRadius: BorderRadius.circular(10),
							),
						),

						const Text(
							"Login or Register",
							style: TextStyle(
								fontSize: 18,
								fontWeight: FontWeight.bold,
							),
						),

						const SizedBox(height: 10),

						TabBar(
							controller: _tabController,
							labelColor: Colors.black,
							tabs: const [
								Tab(text: "Login"),
								Tab(text: "Register"),
							],
						),

						Expanded(
							child: TabBarView(
								controller: _tabController,
								children: [

									/// LOGIN
									Form(
										key: _loginFormKey,
										child: ListView(
											padding: const EdgeInsets.all(20),
											children: [

												TextFormField(
													controller: _emailController,
													decoration: const InputDecoration(
														labelText: "Email",
														border: OutlineInputBorder(),
													),
													validator: (v) =>
													v!.isEmpty ? "Enter email" : null,
												),

												const SizedBox(height: 16),

												TextFormField(
													controller: _passwordController,
													obscureText: _passwordObscure,
													decoration: InputDecoration(
														labelText: "Password",
														border: const OutlineInputBorder(),
														suffixIcon: IconButton(
															icon: Icon(_passwordObscure
																	? Icons.visibility_off
																	: Icons.visibility),
															onPressed: () {
																setState(() {
																	_passwordObscure = !_passwordObscure;
																});
															},
														),
													),
													validator: (v) =>
													v!.isEmpty ? "Enter password" : null,
												),

												const SizedBox(height: 20),

												ElevatedButton(
													onPressed: () {
														if (_loginFormKey.currentState!.validate()) {
															_login(context);
														}
													},
													child: _loading
															? const CircularProgressIndicator(
														color: Colors.white,
													)
															: const Text("Sign In"),
												),

												TextButton(
													onPressed: () {
														_tabController.animateTo(1);
													},
													child: const Text("Create account"),
												)
											],
										),
									),

									/// REGISTER
									Form(
										key: _registrationFormKey,
										child: ListView(
											padding: const EdgeInsets.all(20),
											children: [

												TextFormField(
													controller: _firstNameController,
													decoration: const InputDecoration(
														labelText: "First Name",
														border: OutlineInputBorder(),
													),
													validator: (v) =>
													v!.isEmpty ? "Enter first name" : null,
												),

												const SizedBox(height: 16),

												TextFormField(
													controller: _lastNameController,
													decoration: const InputDecoration(
														labelText: "Last Name",
														border: OutlineInputBorder(),
													),
													validator: (v) =>
													v!.isEmpty ? "Enter last name" : null,
												),

												const SizedBox(height: 16),

												TextFormField(
													controller: _emailController,
													decoration: const InputDecoration(
														labelText: "Email",
														border: OutlineInputBorder(),
													),
													validator: (v) =>
													v!.isEmpty ? "Enter email" : null,
												),

												const SizedBox(height: 16),

												TextFormField(
													controller: _passwordController,
													obscureText: _passwordObscure,
													decoration: const InputDecoration(
														labelText: "Password",
														border: OutlineInputBorder(),
													),
													validator: (v) =>
													v!.isEmpty ? "Enter password" : null,
												),

												const SizedBox(height: 20),

												ElevatedButton(
													onPressed: () {
														if (_registrationFormKey.currentState!
																.validate()) {
															_register(context);
														}
													},
													child: _loading
															? const CircularProgressIndicator(
														color: Colors.white,
													)
															: const Text("Create Account"),
												),

												TextButton(
													onPressed: () {
														_tabController.animateTo(0);
													},
													child: const Text("Login"),
												)
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