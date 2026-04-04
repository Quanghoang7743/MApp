import '../api_client.dart';

class AttachmentsApi {
  AttachmentsApi(this._client);

  final ApiClient _client;

  Future<dynamic> addAttachment(
    String messageId,
    Map<String, dynamic> payload,
  ) {
    return _client.post('/messages/$messageId/attachments', body: payload);
  }

  Future<dynamic> deleteAttachment(String attachmentId) {
    return _client.delete('/attachments/$attachmentId');
  }
}
