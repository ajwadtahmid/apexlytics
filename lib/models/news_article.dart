import '../utils/formatting/json_utils.dart';

class NewsArticle {
  final String title;
  final String description;
  final String link;
  final String imageUrl;

  const NewsArticle({
    required this.title,
    required this.description,
    required this.link,
    required this.imageUrl,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: asString(json['title']) ?? 'No Title',
      description: asString(json['description']) ?? '',
      link: asString(json['link']) ?? '',
      imageUrl: asString(json['img']) ?? '',
    );
  }
}
