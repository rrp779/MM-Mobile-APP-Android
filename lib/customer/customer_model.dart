import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../services/notification_service.dart';

class CustomerModel with ChangeNotifier {
	Map? _customer;

	Map? get customer => _customer;

	/// ✅ Loyalty Data
	int loyaltyPoints = 0;
	String vipTier = "";
	int redeemedRewards = 0;

	/// ✅ Login state
	bool get isLoggedIn => _customer != null;

	Future<void> logout(BuildContext context) async {
		final prefs = await SharedPreferences.getInstance();

		await prefs.remove('customer');

		NotificationService().unregisterOnLogout();

		_customer = null;

		loyaltyPoints = 0;
		vipTier = "";
		redeemedRewards = 0;

		try {
			context.read<CartProvider>().resetCartState();
		} catch (e) {
			debugPrint("Error resetting cart on logout: $e");
		}

		notifyListeners();

		if (context.mounted) {
			Navigator.pushNamedAndRemoveUntil(
				context,
				'/home',
						(route) => false,
			);
		}
	}

	Future<void> getCustomer(BuildContext context) async {
		final client = GraphQLProvider.of(context).value;

		final prefs = await SharedPreferences.getInstance();
		String? customerEncoded = prefs.getString('customer');

		if (customerEncoded == null) {
			_customer = null;
			notifyListeners();
			return;
		}

		Map customer = jsonDecode(customerEncoded);

		DateTime expiresAt = DateTime.parse(customer['expiresAt']);

		/// 🔄 Refresh token
		if (expiresAt.isAfter(DateTime.now())) {
			final result = await client.mutate(
				MutationOptions(
					document: gql(r'''
            mutation customerAccessTokenRenew ($accessToken: String!) {
              customerAccessTokenRenew(customerAccessToken: $accessToken)  {
                customerAccessToken {
                  accessToken
                  expiresAt
                }
                userErrors {
                  field
                  message
                }
              }
            }
          '''),
					variables: {
						'accessToken': customer['accessToken']
					},
				),
			);

			List errors = result.data!['customerAccessTokenRenew']['userErrors'];

			if (errors.isNotEmpty) {
				if (context.mounted) {
					ScaffoldMessenger.of(context).showSnackBar(
						SnackBar(content: Text(errors[0]['message'])),
					);
				}
				return;
			}

			Map accessToken =
			result.data!['customerAccessTokenRenew']['customerAccessToken'];

			await prefs.setString(
				'customer',
				jsonEncode({
					'accessToken': accessToken['accessToken'],
					'expiresAt': accessToken['expiresAt'],
				}),
			);

			customerEncoded = prefs.getString('customer');
			customer = jsonDecode(customerEncoded!);
		} else {
			await prefs.remove('customer');

			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text(
								'Your session expired. Please login again.'),
					),
				);
			}
			return;
		}

		/// 🔥 UPDATED QUERY WITH LOYALTY DATA
		final result = await client.query(
			QueryOptions(
				document: gql(r'''
          query customer($accessToken: String!) {
            customer(customerAccessToken: $accessToken) {
              id
              firstName
              lastName
              email
              phone

              # ⭐ LOYALTY FIELDS
              points: metafield(namespace: "app--168671248385", key: "points") {
                value
              }

              vipTier: metafield(namespace: "app--168671248385", key: "vip_tier") {
                value
              }

              redeemed: metafield(namespace: "app--168671248385", key: "redeemed_rewards") {
                value
              }

              orders(first: 10) {
                edges {
                  node {
                    id
                    name
                    processedAt

                    totalPrice {
                      amount
                      currencyCode
                    }

                    lineItems(first: 5) {
                      edges {
                        node {
                          title
                          quantity

                          variant {
                            image {
                              url
                            }
                            price {
                              amount
                            }
                            compareAtPrice {
                              amount
                            }
                            product {
                              featuredImage {
                                url
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        '''),
				variables: {
					'accessToken': customer['accessToken']
				},
			),
		);

		if (kDebugMode) {
			print(result.data);

		}

		final data = result.data!['customer'];
		_customer = data;

		if (data != null) {
			NotificationService().syncTokenWithBackend(
				customerId: data['id']?.toString(),
				email: data['email']?.toString(),
				phone: data['phone']?.toString(),
			);
		}
		/// ✅ PARSE LOYALTY DATA
		loyaltyPoints =
				int.tryParse(data['points']?['value'] ?? "0") ?? 0;
		vipTier = data['vipTier']?['value'] ?? "";
		redeemedRewards =
				int.tryParse(data['redeemed']?['value'] ?? "0") ?? 0;
		notifyListeners();


	}
}