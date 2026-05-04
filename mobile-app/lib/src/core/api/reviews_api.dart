import 'api_client.dart';

class ReviewResult {
  const ReviewResult({
    required this.id,
    required this.rating,
    required this.comment,
    required this.reviewerName,
    required this.createdAt,
  });

  final String id;
  final double rating;
  final String comment;
  final String reviewerName;
  final DateTime createdAt;

  factory ReviewResult.fromJson(Map<String, dynamic> json) {
    final customer = json['user'] ?? json['customerId'];
    String name = 'Anonymous';
    if (customer is Map<String, dynamic>) {
      name = (customer['name'] as String?) ?? 'Anonymous';
    }
    return ReviewResult(
      id: (json['_id'] as String?) ?? '',
      rating: ((json['rating'] as num?) ?? 0).toDouble(),
      comment: (json['comment'] as String?) ?? '',
      reviewerName: name,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class ReviewsApi {
  ReviewsApi(this._client);

  final ApiClient _client;

  Future<List<ReviewResult>> getWorkerReviews(String workerId) async {
    final data =
        _client.unwrapData(await _client.get('/reviews/worker/$workerId'));
    final list = (data['reviews'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ReviewResult.fromJson)
        .toList();
  }

  Future<void> submitReview({
    required String bookingId,
    required int rating,
    required String comment,
  }) async {
    await _client.post('/reviews', <String, dynamic>{
      'bookingId': bookingId,
      'rating': rating,
      'comment': comment,
    });
  }
}
