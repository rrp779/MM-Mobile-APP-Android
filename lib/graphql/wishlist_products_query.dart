const String wishlistProductsQuery = r'''
query GetWishlistProducts($ids: [ID!]!) {
  nodes(ids: $ids) {
    ... on Product {
      id
      title
      images(first: 1) {
        edges {
          node { url }
        }
      }
      collections(first: 10) {
            edges {
              node {
                title
                metafield(namespace: "custom", key: "mobile_app_setting_from_website") {
                  reference {
                    ... on Metaobject {
                      fields {
                        key
                        value
                      }
                    }
                  }
                }
              }
            }
          }
      variants(first: 1) {
        edges {
          node {
            id
            price { amount }
            compareAtPrice { amount }
             selectedOptions {
          name
          value
        }
          }
        }
      }
    }
  }
}
''';
