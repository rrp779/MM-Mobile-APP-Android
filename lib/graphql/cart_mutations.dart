const String cartCreateMutation = r'''
mutation cartCreate {
  cartCreate {
    cart {
      id
      checkoutUrl
    }
  }
}
''';

const String cartLinesAddMutation = r'''
mutation cartLinesAdd($cartId: ID!, $lines: [CartLineInput!]!) {
  cartLinesAdd(cartId: $cartId, lines: $lines) {
    cart {
      id
      checkoutUrl
      lines(first: 50) {
        edges {
          node {
            id
            quantity
            merchandise {
              ... on ProductVariant {
                id
                title
                product {
                  title
                }
                 price {
      amount
    }
    compareAtPrice {
      amount
    }
                image {
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
''';
