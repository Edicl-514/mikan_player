import 'package:mikan_player/src/rust/api/bangumi.dart';

class BangumiUserCollection {
  final String date;
  final String comment;
  final List<dynamic> tags;
  final BangumiUserCollectionSubject subject;
  final int subjectId;
  final int
  type; // 1->Want to Watch, 2->Watched, 3->Watching, 4->On Hold, 5->Dropped
  final int rate;
  final bool private;

  BangumiUserCollection({
    required this.date,
    required this.comment,
    required this.tags,
    required this.subject,
    required this.subjectId,
    required this.type,
    required this.rate,
    required this.private,
  });

  factory BangumiUserCollection.fromJson(Map<String, dynamic> json) {
    return BangumiUserCollection(
      date: json['updated_at'] ?? '',
      comment: json['comment'] ?? '',
      tags: json['tags'] ?? [],
      subject: BangumiUserCollectionSubject.fromJson(json['subject']),
      subjectId: json['subject_id'] ?? 0,
      type: json['type'] ?? 0,
      rate: json['rate'] ?? 0,
      private: json['private'] ?? false,
    );
  }
}

class BangumiUserCollectionSubject {
  final int id;
  final String name;
  final String nameCn;
  final String shortSummary;
  final double score;
  final BangumiImages images;
  final int eps;
  final int collectionTotal;

  BangumiUserCollectionSubject({
    required this.id,
    required this.name,
    required this.nameCn,
    required this.shortSummary,
    required this.score,
    required this.images,
    required this.eps,
    required this.collectionTotal,
  });

  factory BangumiUserCollectionSubject.fromJson(Map<String, dynamic> json) {
    return BangumiUserCollectionSubject(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      nameCn: json['name_cn'] ?? '',
      shortSummary: json['short_summary'] ?? '',
      score: (json['score'] ?? 0).toDouble(),
      images: BangumiImages(
        small: json['images']?['small'] ?? '',
        grid: json['images']?['grid'] ?? '',
        large: json['images']?['large'] ?? '',
        medium: json['images']?['medium'] ?? '',
        common: json['images']?['common'] ?? '',
      ),
      eps: json['eps'] ?? 0,
      collectionTotal: json['collection_total'] ?? 0,
    );
  }
}
