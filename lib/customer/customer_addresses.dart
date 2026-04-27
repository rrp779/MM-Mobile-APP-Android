import 'dart:convert' show jsonDecode;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_icon.dart';
import 'customer_address_add.dart';
import 'customer_address_edit.dart';

class CustomerAddresses extends StatefulWidget {
	const CustomerAddresses({super.key});

	@override
	State<CustomerAddresses> createState() => _CustomerAddressesState();
}

class _CustomerAddressesState extends State<CustomerAddresses> {
	final _scaffoldKey = GlobalKey<ScaffoldState>();
	final ScrollController _listViewController = ScrollController();
	String? _defaultAddressId;
	List? _addresses;
	bool _paginationLoading = false;
	Map? _paginationInfo;

	Future<void> _getAddresses({int limit = 24, String? after}) async {
		final client = GraphQLProvider.of(context).value;

		final prefs = await SharedPreferences.getInstance();
		String? customerEncoded = prefs.getString('customer');

		if (customerEncoded == null) {
			return;
		}

		Map customer = jsonDecode(customerEncoded);
		String accessToken = customer['accessToken'];

		final result = await client.query(
			QueryOptions(
				fetchPolicy: FetchPolicy.networkOnly,
				cacheRereadPolicy: CacheRereadPolicy.ignoreAll,
				document: gql(r'''
					query customer($accessToken: String! $limit: Int $after: String) {
						customer (customerAccessToken: $accessToken) {
							defaultAddress {
								id
							}
							addresses (first: $limit after: $after) {
								edges { 
									node {
										id
										address1
										address2
										city
										company
										country
										countryCodeV2
										firstName
										formatted
										formattedArea
										lastName
										latitude
										longitude
										name
										phone
										province
										provinceCode
										zip
									}
								}
								pageInfo {
									endCursor
									hasNextPage
								}
							}
						}
					}
				'''),
				variables: {
					'accessToken': accessToken,
					'limit': limit,
					'after': after,
				}
			)
		);

		if (kDebugMode) {
			print(result);
		}

		if (result.hasException || result.data == null) {
			setState(() {
				_paginationLoading = false;
			});
			return;
		}

		setState(() {
			if (after == null) {
				_addresses = result.data!['customer']['addresses']['edges'];
			} else {
				_addresses = [..._addresses!, ...result.data!['customer']['addresses']['edges']];
			}

			if (result.data!['customer']['defaultAddress'] != null) {
				_defaultAddressId = result.data!['customer']['defaultAddress']['id'];
			}

			_paginationLoading = false;
			_paginationInfo = result.data!['customer']['addresses']['pageInfo'];
		});
	}

	Future<void> _deleteAddress(String id) async {
		if (id == _defaultAddressId) {
			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
					content: Text('Please set another address as default before deleting this one')
				));
			}
			return;
		}

		final client = GraphQLProvider.of(context).value;

		final prefs = await SharedPreferences.getInstance();
		String? customerEncoded = prefs.getString('customer');

		if (customerEncoded == null) {
			return;
		}

		Map customer = jsonDecode(customerEncoded);
		String accessToken = customer['accessToken'];

		// Optimistic UI update: remove locally immediately
		final previousAddresses = _addresses == null ? null : List.from(_addresses!);
		setState(() {
			_addresses = (_addresses ?? [])
				.where((edge) => edge['node']?['id'] != id)
				.toList();
		});

		final result = await client.mutate(
			MutationOptions(
				document: gql(r'''
					mutation customerAddressDelete($accessToken: String! $id: ID!) {
						customerAddressDelete (customerAccessToken: $accessToken id: $id) {
							deletedCustomerAddressId
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
					'id': id
				}
			)
		);

		if (kDebugMode) {
			print('customerAddressDelete response: ${result.data}');
			if (result.hasException) {
				print('customerAddressDelete exception: ${result.exception}');
			}
		}

		if (result.hasException || result.data == null) {
			// Roll back optimistic update and refetch fresh data
			setState(() {
				_addresses = previousAddresses;
			});
			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
					content: Text('Failed to delete address. Please try again.')
				));
			}
			_getAddresses();
			return;
		}

		final List errors =
			result.data!['customerAddressDelete']?['customerUserErrors'] ?? [];
		final String? deletedId =
			result.data!['customerAddressDelete']?['deletedCustomerAddressId'];

		if (errors.isNotEmpty || deletedId == null) {
			// Roll back optimistic update and refetch fresh data
			setState(() {
				_addresses = previousAddresses;
			});
			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(
					content: Text(errors.isNotEmpty
						? (errors.first['message'] ?? 'Failed to delete address').toString()
						: 'Failed to delete address. Please try again.')
				));
			}
			_getAddresses();
			return;
		}

		if (context.mounted) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
				content: Text('Address was successfully deleted!')
			));
		}

		_getAddresses();
	}

	Future<void> _setDefaultAddress(String addressId) async {
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
					mutation customerDefaultAddressUpdate($accessToken: String! $addressId: ID!) {
						customerDefaultAddressUpdate (customerAccessToken: $accessToken addressId: $addressId) {
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
					'addressId': addressId,
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
				List errors = result.data!['customerDefaultAddressUpdate']['customerUserErrors'];

				if (errors.isEmpty) {
					ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
						content: Text('Address was successfully set as default')
					));
				} else {
					ScaffoldMessenger.of(context).showSnackBar(SnackBar(
						content: Text('Error! Message: ${errors[0]['message']}')
					));
				}
			}
		}

		_getAddresses();
	}

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) async {
			_getAddresses();
		});
  	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: Colors.white,
			key: _scaffoldKey,
			appBar: AppBar(
				backgroundColor: Colors.white,
				elevation: 0,
				centerTitle: true,

				title: const Text(
					'Addresses',
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

				/// ADD ADDRESS ICON
				actions: [
					IconButton(
						padding: const EdgeInsets.only(right: 12),
						constraints: const BoxConstraints(),
						onPressed: () async {
							await Future.delayed(const Duration(milliseconds: 200));

							if (context.mounted) {
								await Navigator.of(context).push(
									MaterialPageRoute(
										builder: (context) => const CustomerAddressAdd(),
									),
								);

								_getAddresses();
							}
						},
						icon: const SizedBox(
							width: 22,
							height: 22,
							child: AppIcon(
								isActive: false,
								outlinePath: 'assets/icons/PlusOutline.svg',
								filledPath: 'assets/icons/PlusOutline.svg',
							),
						),
					),
				],
			),
			body: _addresses == null

				? const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading, please wait',))
				: _addresses!.isEmpty
					? Center(
						child: Column(

							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								const Icon(Icons.sentiment_dissatisfied, size: 28, color: Colors.grey,),
								const SizedBox(height: 12),
								const Text('No addresses yet!'),
								const SizedBox(height: 16),
								ElevatedButton(
									onPressed: () async {
										await Future.delayed(const Duration(milliseconds: 200));
										if (context.mounted) {
											await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CustomerAddressAdd()));
											_getAddresses();
										}
									},
									child: const Text('Add a new address'),
								)
							],
						)
					)
					: NotificationListener<ScrollEndNotification>(
						onNotification: (scrollEnd) {
							if (scrollEnd.metrics.atEdge) {
								bool isTop = scrollEnd.metrics.pixels == 0;
								
								if (isTop) { return false; }

								if (_paginationInfo != null && _paginationInfo!['hasNextPage']) {
									setState(() {
									  	_paginationLoading = true;
									});
									_getAddresses(after: _paginationInfo!['endCursor']);
								}
							}
							return false;
						},
						child: Column(
							children: [
								Expanded(
									child: ListView(
										controller: _listViewController,
										padding: const EdgeInsets.fromLTRB(6, 8, 6, 48),
										children: [
											for (dynamic edge in _addresses!)
												Card(
														color: edge['node']['id'] == _defaultAddressId
																? Color(0xFFFFEFF6)
																: Colors.white,
														margin: const EdgeInsets.all(6),
														shape: RoundedRectangleBorder(
															borderRadius: BorderRadius.circular(8),
															side: BorderSide(
																color: edge['node']['id'] == _defaultAddressId
																		? Color(0xFFFCA1D2)
																		: Colors.grey.shade300,
																width: 1,

															),
														),

													child: Padding(
														padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),

														child: Row(
															mainAxisAlignment: MainAxisAlignment.spaceBetween,
															children: [
																Flexible(
																	child: Column(
																		crossAxisAlignment: CrossAxisAlignment.start,
																		children: [

																			Container(

																				padding: const EdgeInsets.only(bottom: 4),
																				decoration: const BoxDecoration(
																					border: Border(
																						bottom: BorderSide(width: 1, color: Colors.black54)
																					)
																				),
																				child: Text(
																					edge['node']['id'] == _defaultAddressId ? 'Default Address' : 'Address', 
																					style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
																				),
																			),
																			const SizedBox(height: 8),
																			Text(edge['node']['name'],
																				style: TextStyle(
																					fontSize: 12,
																					fontWeight: FontWeight.bold// change size as needed
																				),
																			),
																			const SizedBox(height: 5),
																			Text(edge['node']['formatted'].join(', '),
																				style: TextStyle(
																						fontSize: 12,
																				),
																			),
																			const SizedBox(height: 8,),
																			Row(
																				children: [
																					OutlinedButton(
																							style: OutlinedButton.styleFrom(
																								foregroundColor: Colors.black, // text color
																								side: const BorderSide(color: Colors.grey), // border color
																								shape: RoundedRectangleBorder(
																									borderRadius: BorderRadius.circular(20), // round shape
																								),
																								minimumSize: const Size(0, 30),
																								padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
																							),																						onPressed: () async {
																							await Future.delayed(const Duration(milliseconds: 200));
																							if (context.mounted) {
																								await Navigator.of(context).push(MaterialPageRoute(builder: (context) => CustomerAddressEdit(
																									address: edge['node'],
																								)));
																								_getAddresses();
																							}
																						},
																						 child: const Text(
																							'Edit address',
																							style: TextStyle(
																								fontSize: 12, // change size as needed
																							),
																						),
																					),
																					const SizedBox(width: 8),
																					if (edge['node']['id'] != _defaultAddressId)
																						OutlinedButton(
																								style: OutlinedButton.styleFrom(
																									foregroundColor: Colors.black, // text color
																									side: const BorderSide(color: Colors.grey), // border color
																									shape: RoundedRectangleBorder(
																										borderRadius: BorderRadius.circular(20), // round shape
																									),
																									minimumSize: const Size(0, 30),
																									padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
																								),
																								onPressed: () {
																								_setDefaultAddress(edge['node']['id']);
																							},
																							child: const Text(
																								'Set as default',
																								style: TextStyle(
																									fontSize: 12, // change size as needed
																								),
																							),
																						),
																				],
																			)
																		]
																	),
																),
																const SizedBox(width: 12,),
																IconButton(
																	onPressed: () async {
																		await Future.delayed(const Duration(milliseconds: 200));
																		_deleteAddress(edge['node']['id']);
																	},
																	icon:AppIcon(
																		isActive: true,
																		outlinePath: 'assets/icons/DeleteOutline.svg',
																		filledPath: 'assets/icons/DeleteOutline.svg',
																	),
																	color: Colors.red.shade700,
																),
															],
														),
													)
												)
										],
									)
								),
								if (_paginationLoading)
									const LinearProgressIndicator(semanticsLabel: 'Loading',)
							]
						)
					),
		);
	}
}
