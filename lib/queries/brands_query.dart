const String collectionsQuery = r'''
query GetCollections($cursor: String) {
  collections(first: 250, after: $cursor) {
    pageInfo {
      hasNextPage
      endCursor
    }
    edges {
      node {
        id
        title
        handle

        image {
          url
        }
        
       
        metafield(namespace: "custom", key: "mobile_app_setting_from_website") {
          reference {
            ... on Metaobject {
              fields {
                key
                value
                reference {
                  ... on MediaImage {
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
  }
}
''';