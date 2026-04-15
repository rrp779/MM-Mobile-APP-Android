const String productDetailQuery = r'''
query ProductDetail($id: ID!) {
  product(id: $id) {
    id
    title
    descriptionHtml
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
    images(first: 200) {
      edges {
        node {
          url
        }
      }
    }
variants(first: 20) {
  edges {
    node {
      id
      title
      availableForSale
      quantityAvailable
      price {
        amount
      }
      compareAtPrice {
        amount
      }
      image {
        url
      }
         selectedOptions {
        name
        value
      }
    }
  }
}
  }
}
''';