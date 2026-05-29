import '../api_client.dart';

class AttachmentsApi {
  AttachmentsApi(this._client);

  final ApiClient _client;

  Future<dynamic> addAttachment(
    String messageId, {
    required String filePath,
    String type = 'image',
  }) {
    return _client.postMultipart(
      '/messages/$messageId/attachments',
      fields: {'type': type},
      files: [
        ApiMultipartFile(
          field: 'file',
          filePath: filePath,
        ),
      ],
    );
  }

  Future<dynamic> deleteAttachment(String attachmentId) {
    return _client.delete('/attachments/$attachmentId');
  }
}
