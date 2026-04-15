class CollectionModel {
  final String handle;
  final String title;
  final String image;


  final String? mobileBanner;
  final String? mobileTitle;
  final String? mobileDescription;
  final bool showInMobile;
  final String? collectiontype;
  final String? parentCategory;

  CollectionModel({
    required this.handle,
    required this.title,
    required this.image,
    this.mobileBanner,
    this.mobileTitle,
    this.mobileDescription,
    this.showInMobile = false,
    this.collectiontype,
    this.parentCategory,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    final metafield = json['metafield'];

    String? banner;
    String? title;
    String? description;
    bool show = false;
    String? collectiontype;
    String? parentCategory;

    if (metafield != null &&
        metafield['reference'] != null &&
        metafield['reference']['fields'] != null) {

      final fields = metafield['reference']['fields'] as List;

      for (var field in fields) {
        final key = field['key'];
        final value = field['value'];

        switch (key) {

          case 'app_banner':
            banner = field['reference']?['image']?['url'];
            break;

          case 'app_banner_title':
            title = value;
            break;

          case 'app_banner_description':
            description = value;
            break;

          case 'show_in_mobile_app':
            if (value is bool) {
              show = value;
            } else if (value is String) {
              show = value.toLowerCase() == 'true' || value == '1';
            } else if (value is int) {
              show = value == 1;
            }
            break;

          case 'collection_type':
            collectiontype = value;
            break;

          case 'parent_category':
            parentCategory = value;
            break;
        }
      }
    }

    return CollectionModel(
      handle: json['handle'] ?? '',
      title: json['title'] ?? '',
      image: json['image']?['url'] ?? '',
      mobileBanner: banner,
      mobileTitle: title,
      mobileDescription: description,
      showInMobile: show,
      collectiontype: collectiontype,
      parentCategory: parentCategory,

    );
  }
}