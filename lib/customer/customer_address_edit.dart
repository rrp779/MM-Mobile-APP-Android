import 'dart:convert' show jsonDecode;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_icon.dart';

final List<String> addressFields = [
	'First name', 'Last name', 'Company', 'Address 1', 'Address 2', 'City', 'Country', 'Province', 'Postal/Zip code', 'Phone'
];

final List<String> countries = [
	'India',
];

class CustomerAddressEdit extends StatefulWidget {
	final Map address;

	const CustomerAddressEdit({super.key, required this.address});

	@override
	State<CustomerAddressEdit> createState() => _CustomerAddressEditState();
}

class _CustomerAddressEditState extends State<CustomerAddressEdit> {
	final _formKey = GlobalKey<FormState>();
	bool _loading = false;
	final Map _addressSavedFields = {};

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

	Future<void> _editAddress() async {
		setState((){
			_loading = true;
		});
		
		final client = GraphQLProvider.of(context).value;

		final prefs = await SharedPreferences.getInstance();
		String? customerEncoded = prefs.getString('customer');

		if (customerEncoded == null) {
			return;
		}

		Map customer = jsonDecode(customerEncoded);
		String accessToken = customer['accessToken'];

		final result = await client.mutate(
			MutationOptions(
				document: gql(r'''
					mutation customerAddressUpdate($accessToken: String! $id: ID! $address: MailingAddressInput!) {
						customerAddressUpdate (customerAccessToken: $accessToken id: $id address: $address) {
							customerUserErrors {
								code
								field
								message
							}
						}
					}
				'''),
				variables: {
					'accessToken': accessToken,
					'id': widget.address['id'],
					'address': {
						'firstName': _addressSavedFields['First name'],
						'lastName': _addressSavedFields['Last name'],
						'company': _addressSavedFields['Company'],
						'address1': _addressSavedFields['Address 1'],
						'address2': _addressSavedFields['Address 2'],
						'city': _addressSavedFields['City'],
						'country': _addressSavedFields['Country'],
						'province': _addressSavedFields['Province'],
						'zip': _addressSavedFields['Postal/Zip code'],
						'phone': _addressSavedFields['Phone'],
					}
				}
			)
		);

		if (kDebugMode) {
			print(result);
		}

		if (context.mounted) {
			if (result.hasException) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(
					content: Text('Error! Message: ${result.exception!.graphqlErrors[0].message}')
				));
			} else {
				List errors = result.data!['customerAddressUpdate']['customerUserErrors'];

				if (errors.isEmpty) {
					ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
						content: Text('Address was successfully edited! Please wait..')
					));

					await Future.delayed(const Duration(seconds: 3));

					if (context.mounted) {
						Navigator.of(context).pop();
					}
					
				} else {
					ScaffoldMessenger.of(context).showSnackBar(SnackBar(
						content: Text('Error! Message: ${errors[0]['message']}')
					));
				}
			}
		}

		setState(() {
			_loading = false;
		});
	}

	String? getInitialValueEditAddress(String field) {
		switch (field) {
			case 'First name': return widget.address['firstName'];
			case 'Last name': return widget.address['lastName'];
			case 'Company': return widget.address['company'];
			case 'Address 1': return widget.address['address1'];
			case 'Address 2': return widget.address['address2'];
			case 'City': return widget.address['city'];
			case 'Country': return widget.address['country'];
			case 'Province': return widget.address['province'];
			case 'Postal/Zip code': return widget.address['zip'];
			case 'Phone': return widget.address['phone'];
			default: return '';
		}
	}

	Widget _buildAddressField(String field) {

		/// COUNTRY FIELD
		if (field == 'Country') {
			return Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [

					Text(
						field,
						style: const TextStyle(
							fontSize: 14,
							fontWeight: FontWeight.w500,
						),
					),

					const SizedBox(height: 8),

					Autocomplete<String>(
						optionsBuilder: (TextEditingValue textEditingValue) {

							if (textEditingValue.text.isEmpty) {
								return const Iterable<String>.empty();
							}

							return countries.where((country) {
								return country
										.toLowerCase()
										.contains(textEditingValue.text.toLowerCase());
							});
						},

						initialValue: TextEditingValue(
								text: getInitialValueEditAddress(field) ?? ''),

						fieldViewBuilder:
								(context, controller, focusNode, onFieldSubmitted) {

							return TextFormField(
								controller: controller,
								focusNode: focusNode,
								decoration: input(field),
								style: const TextStyle(fontSize: 16),

								validator: (value) {
									if (value == null || value.isEmpty) {
										return 'Please enter your $field';
									}
									return null;
								},

								onSaved: (value) {
									_addressSavedFields[field] = value;
								},
							);
						},

						onSelected: (value) {
							_addressSavedFields[field] = value;
						},
					),

					const SizedBox(height: 16),
				],
			);
		}

		/// NORMAL FIELD
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [

				Text(
					field,
					style: const TextStyle(
						fontSize: 14,
						fontWeight: FontWeight.w500,
					),
				),

				const SizedBox(height: 8),

				TextFormField(
					autofocus: field == 'First name',
					initialValue: getInitialValueEditAddress(field),
					decoration: input(field),
					style: const TextStyle(fontSize: 16),

					validator: (value) {

						if (field == 'Company' ||
								field == 'Phone' ||
								field == 'Address 2') {
							return null;
						}

						if (value == null || value.isEmpty) {
							return 'Please enter your $field';
						}

						return null;
					},

					onSaved: (value) {
						_addressSavedFields[field] = value;
					},
				),

				const SizedBox(height: 16),
			],
		);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: Colors.white,
			appBar: AppBar(
				backgroundColor: Colors.white,
				elevation: 0,
				title: const Text(
					'Edit Your Address',
					style: TextStyle(
						fontSize: 18,
						fontWeight: FontWeight.w600,
						color: Colors.black,
					),
				),
				/// BACK ICON
				leading: IconButton(
					padding: EdgeInsets.zero,
					constraints: const BoxConstraints(),
					icon: const SizedBox(
						width: 22,
						height: 22,
						child: AppIcon(
							isActive: false,
							outlinePath: 'assets/icons/ArrowLeft.svg',
							filledPath: 'assets/icons/ArrowLeft.svg',
						),
					),
					onPressed: () {
						Navigator.pop(context);
					},
				),
			),
			body: Form(
				key: _formKey,
				child:  SingleChildScrollView(
					padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
					child: Column(
						children: <Widget>[
							for (String field in addressFields)
								_buildAddressField(field),
							SizedBox(
								width: double.infinity,
								child: ElevatedButton(
										style: ElevatedButton.styleFrom(
											backgroundColor:
											const  Color(0xFFEA0180),
											shape: RoundedRectangleBorder(
												borderRadius:
												BorderRadius.circular(10),
											),
										),
									onPressed: () async {
										if (_formKey.currentState!.validate()) {
											_formKey.currentState!.save();
											_editAddress();
										}
									}, 
									child: _loading
										?  const SizedBox(
												height: 19,
												width: 19,
												child: CircularProgressIndicator(
													color: Colors.white,
													strokeWidth: 2,
												),
											)
										: const Text('Submit',
										style: TextStyle(
											color: Colors.white,
											fontSize: 16,// optional (safe)
											fontWeight: FontWeight.w600,
										),
									)
								),
							),
							SizedBox(
								width: double.infinity,
								child: TextButton(
										onPressed: () async {
											await Future.delayed(const Duration(milliseconds: 200));
											if (context.mounted) {
												Navigator.of(context).pop();
											}
										},
										child: const Text('Cancel',
											style: TextStyle(
												color: Colors.black,
												fontSize: 12,// optional (safe)
												fontWeight: FontWeight.w600,
											),
										)
								),
							),
						],
					),
				)
			),
		);
	}
}