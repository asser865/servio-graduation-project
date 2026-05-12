import '../models/saved_card_model.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class SavedCardsApi {
  SavedCardsApi(this._client);

  final ApiClient _client;

  Future<List<SavedCardModel>> getSavedCards() async {
    final data = _client.unwrapData(await _client.get(ApiEndpoints.savedCards));
    final list = data['data'] is List<dynamic>
        ? data['data'] as List<dynamic>
        : (data['cards'] as List<dynamic>?) ?? <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(SavedCardModel.fromJson)
        .toList();
  }

  Future<SavedCardModel> addCard({
    required String last4,
    required String expiry,
    required String cardType,
    String label = '',
  }) async {
    final data = _client.unwrapData(
      await _client.post(ApiEndpoints.savedCards, <String, dynamic>{
        'last4': last4,
        'expiry': expiry,
        'cardType': cardType,
        if (label.trim().isNotEmpty) 'label': label.trim(),
      }),
    );
    return SavedCardModel.fromJson(data);
  }

  Future<void> deleteCard(String id) async {
    await _client.delete(ApiEndpoints.savedCard(id));
  }

  Future<SavedCardModel> setDefault(String id) async {
    final data = _client.unwrapData(
      await _client
          .patch(ApiEndpoints.defaultSavedCard(id), <String, dynamic>{}),
    );
    return SavedCardModel.fromJson(data);
  }
}
