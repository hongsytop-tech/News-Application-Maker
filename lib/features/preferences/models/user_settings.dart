import 'package:news_application_maker/features/news_feed/models/news_category.dart';

/// User-controlled app settings. Currently the set of categories the user
/// wants to see in their feed.
class UserSettings {
  const UserSettings({required this.enabledCategoryIds});

  /// Ids of [NewsCategory] the user has enabled. Empty means "all".
  final Set<String> enabledCategoryIds;

  /// Default: every category enabled.
  factory UserSettings.initial() => UserSettings(
        enabledCategoryIds: {for (final c in NewsCategory.all) c.id},
      );

  /// Resolves to the ordered list of enabled categories (falls back to all).
  List<NewsCategory> get enabledCategories {
    final list = [
      for (final c in NewsCategory.all)
        if (enabledCategoryIds.isEmpty || enabledCategoryIds.contains(c.id)) c,
    ];
    return list.isEmpty ? NewsCategory.all : list;
  }

  bool isEnabled(String categoryId) =>
      enabledCategoryIds.isEmpty || enabledCategoryIds.contains(categoryId);

  UserSettings toggle(String categoryId) {
    final next = Set<String>.from(
      enabledCategoryIds.isEmpty
          ? {for (final c in NewsCategory.all) c.id}
          : enabledCategoryIds,
    );
    if (next.contains(categoryId)) {
      next.remove(categoryId);
    } else {
      next.add(categoryId);
    }
    return UserSettings(enabledCategoryIds: next);
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    final list = (json['enabled_categories'] as List?) ?? const [];
    return UserSettings(
      enabledCategoryIds: list.map((e) => e.toString()).toSet(),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled_categories': enabledCategoryIds.toList(),
      };
}
