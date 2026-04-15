class HomeSection {
  final String id;
  final String title;
  final String type;
  final bool visible;
  final int order;
  final SectionSettings settings;
  final List<SectionItem> items;

  HomeSection({
    required this.id,
    required this.title,
    required this.type,
    required this.visible,
    required this.order,
    required this.settings,
    required this.items,
  });

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    return HomeSection(
      id: json['_id']?.toString() ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      visible: json['visible'] ?? true,
      order: json['order'] ?? 0,
      settings: SectionSettings.fromJson(
        json['settings'] ?? {},
      ),
      items: (json['items'] as List? ?? [])
          .map((e) =>
          SectionItem.fromJson(e ?? {}))
          .toList(),
    );
  }
}

class SectionSettings {
  final String layout;
  final int columns;

  final String backgroundColor;
  final String gradientStart;
  final String gradientEnd;
  final String backgroundImage;
  final double overlayOpacity;
  final String containerWidth;
  final int borderRadius;

  final int paddingTop;
  final int paddingBottom;
  final String sliderStyle;
  final String? layoutStyle;


  SectionSettings({
    required this.layout,
    required this.columns,
    required this.backgroundColor,
    required this.gradientStart,
    required this.gradientEnd,
    required this.backgroundImage,
    required this.overlayOpacity,
    required this.containerWidth,
    required this.borderRadius,
    required this.paddingTop,
    required this.paddingBottom,
    required this.sliderStyle,
    this.layoutStyle,

  });

  factory SectionSettings.fromJson(Map<String, dynamic> json) {
    return SectionSettings(
      layout: json['layout'] ?? 'column',
      columns: json['columns'] ?? 2,

      backgroundColor: json['backgroundColor'] ?? "#ffffff",
      gradientStart: json['gradientStart'] ?? "",
      gradientEnd: json['gradientEnd'] ?? "",
      backgroundImage: json['backgroundImage'] ?? "",
      overlayOpacity:
      (json['overlayOpacity'] ?? 0).toDouble(),
      containerWidth: json['containerWidth'] ?? "full",
      borderRadius: json['borderRadius'] ?? 0,

      paddingTop: json['paddingTop'] ?? 16,
      paddingBottom: json['paddingBottom'] ?? 16,

      sliderStyle: json['sliderStyle'] ?? "small",
      layoutStyle: json['layoutStyle'] ?? "grid",

    );
  }
}
class SectionItem {

  final String title;

  final String? image;
  final String? collectionId;
  final String? collectionHandle;
  final String? productId;

  /// NEW IMAGE FALLBACKS
  final String? productImage;
  final String? collectionImage;

  /// VIDEO / REEL
  final String? video;
  final String? thumbnail;

  final int views;
  final List<String> products;

  final bool visible;

  SectionItem({
    required this.title,
    this.image,
    this.collectionId,
    this.collectionHandle,
    this.productId,

    /// NEW
    this.productImage,
    this.collectionImage,

    this.video,
    this.thumbnail,
    this.views = 0,
    this.products = const [],

    required this.visible,
  });

  factory SectionItem.fromJson(Map<String, dynamic> json) {

    String? handle = json['collectionHandle']?.toString();

    /// AUTO GENERATE HANDLE IF MISSING
    if (handle == null || handle.isEmpty) {
      final title = json['title']?.toString() ?? "";
      handle = title
          .toLowerCase()
          .replaceAll("&", "")
          .replaceAll(" ", "-")
          .replaceAll(RegExp(r'[^a-z0-9\-]'), "");
    }

    return SectionItem(
      title: json['title'] ?? "",

      image: json['image']?.toString(),
      collectionId: json['collectionId']?.toString(),
      collectionHandle: handle,
      productId: json['productId']?.toString(),

      productImage: json['productImage']?.toString(),
      collectionImage: json['collectionImage']?.toString(),

      video: json['video']?.toString(),
      thumbnail: json['thumbnail']?.toString(),

      views: json['views'] != null ? json['views'] as int : 0,

      products: json['products'] != null
          ? List<String>.from(json['products'])
          : [],

      visible: json['visible'] ?? true,


    );
  }
}