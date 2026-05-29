import 'dart:convert';
import 'dart:io';

const Map<String, Map<String, String>> testMetadata = {
  'renders home login screen': {
    'feature': 'Giao diện màn hình khởi động (Home Login Screen)',
    'inputs': 'Khởi chạy ứng dụng, render HomeLoginScreen',
    'expected': 'Hiển thị tiêu đề "Mox" và nút bấm "Đăng nhập"',
  },
  'ApiClient Tests GET request success': {
    'feature': 'ApiClient - Gửi yêu cầu GET thành công',
    'inputs': 'Path: "/test", Mock API trả về JSON {"success": true, "data": "hello"}',
    'expected': 'Trả về dữ liệu JSON đã giải mã thành công',
  },
  'ApiClient Tests POST request success': {
    'feature': 'ApiClient - Gửi yêu cầu POST thành công',
    'inputs': 'Path: "/test-post", Body: {"name": "quang"}, Mock API trả về {"created": true}',
    'expected': 'Trả về dữ liệu phản hồi từ POST request thành công',
  },
  'ApiClient Tests PUT request success': {
    'feature': 'ApiClient - Gửi yêu cầu PUT thành công',
    'inputs': 'Path: "/test-put", Body: {"id": "123"}, Mock API trả về {"updated": true}',
    'expected': 'Trả về dữ liệu phản hồi cập nhật thành công',
  },
  'ApiClient Tests DELETE request success': {
    'feature': 'ApiClient - Gửi yêu cầu DELETE thành công',
    'inputs': 'Path: "/test-delete", Mock API trả về {"deleted": true}',
    'expected': 'Trả về dữ liệu phản hồi xóa thành công',
  },
  'ApiClient Tests Request headers injection with Auth Token': {
    'feature': 'ApiClient - Chèn token vào headers',
    'inputs': 'Gửi request với tokenProvider trả về "my_secret_token"',
    'expected': 'Request headers tự động chứa "Authorization: Bearer my_secret_token"',
  },
  'ApiClient Tests Throws ApiException on error response status code': {
    'feature': 'ApiClient - Xử lý lỗi trạng thái (Exception)',
    'inputs': 'Nhận mã lỗi 401 từ máy chủ khi gọi api',
    'expected': 'Ném ra ApiException chứa statusCode = 401 và message tương ứng',
  },
  'AuthProvider Tests Load saved credentials from SharedPreferences on initialization': {
    'feature': 'AuthProvider - Khởi tạo từ bộ nhớ tạm',
    'inputs': 'SharedPreferences đã có sẵn token và user đã lưu trước đó',
    'expected': 'Tải thông tin thành công, đặt isAuthenticated = true',
  },
  'AuthProvider Tests Login success with stayLoggedIn = true': {
    'feature': 'AuthProvider - Đăng nhập thành công',
    'inputs': 'Số điện thoại "0123456789", mật khẩu "password123", stayLoggedIn = true',
    'expected': 'Lưu token/user vào SharedPreferences, cập nhật isAuthenticated = true',
  },
  'AuthProvider Tests Login failure returns error message': {
    'feature': 'AuthProvider - Đăng nhập thất bại',
    'inputs': 'Nhập sai mật khẩu hoặc số điện thoại, API phản hồi lỗi 401',
    'expected': 'Trả về thông báo lỗi chi tiết, giữ trạng thái chưa xác thực',
  },
  'AuthProvider Tests Register success returns null': {
    'feature': 'AuthProvider - Đăng ký tài khoản thành công',
    'inputs': 'Số điện thoại "0123456789", giới tính "Nam", mật khẩu "password123"',
    'expected': 'Đăng ký thành công và trả về null (không có lỗi)',
  },
  'AuthProvider Tests Register failure returns error message': {
    'feature': 'AuthProvider - Đăng ký tài khoản thất bại',
    'inputs': 'Đăng ký số điện thoại đã tồn tại trên hệ thống, API phản hồi lỗi 422',
    'expected': 'Trả về chuỗi thông báo lỗi đăng ký tương ứng từ server',
  },
  'AuthProvider Tests Logout clears credentials and preferences': {
    'feature': 'AuthProvider - Đăng xuất tài khoản',
    'inputs': 'Gọi hàm logout() khi đang ở trạng thái xác thực',
    'expected': 'Xóa sạch thông tin token/user khỏi bộ nhớ tạm và SharedPreferences',
  },
  'FriendProvider Tests bindApi binds the API service': {
    'feature': 'FriendProvider - Liên kết API service',
    'inputs': 'Gọi hàm bindApi(ApiServices api)',
    'expected': 'Lưu trữ đối tượng API thành công để sẵn sàng thực hiện các chức năng',
  },
  'FriendProvider Tests resolveByPhone success updates resolvedUser and clears error': {
    'feature': 'FriendProvider - Tra cứu bạn bè bằng số điện thoại thành công',
    'inputs': 'Số điện thoại "0987654321", Mock API trả về thông tin user',
    'expected': 'Cập nhật resolvedUser đúng thông tin của user và đặt errorMessage = null',
  },
  'FriendProvider Tests resolveByPhone failure sets error and clears user': {
    'feature': 'FriendProvider - Tra cứu bạn bè bằng số điện thoại thất bại',
    'inputs': 'Số điện thoại "0000000000" không tồn tại, Mock API trả về lỗi 404',
    'expected': 'Thiết lập thông tin errorMessage phù hợp và đặt resolvedUser = null',
  },
  'FriendProvider Tests sendFriendRequest success triggers fetchOutgoingRequests': {
    'feature': 'FriendProvider - Gửi lời mời kết bạn thành công',
    'inputs': 'receiverId = "user_id_123", thực hiện gửi yêu cầu',
    'expected': 'Trả về true, tự động làm mới danh sách gửi đi và chứa lời mời mới',
  },
  'FriendProvider Tests fetchIncomingRequests success updates incomingRequests list': {
    'feature': 'FriendProvider - Tải danh sách lời mời kết bạn nhận được',
    'inputs': 'Gọi fetchIncomingRequests(), API trả về danh sách lời mời',
    'expected': 'Cập nhật danh sách incomingRequests với các bản ghi từ API',
  },
  'FriendProvider Tests acceptRequest success and fetches incoming requests': {
    'feature': 'FriendProvider - Chấp nhận lời mời kết bạn',
    'inputs': 'requestId = "req_123", thực hiện chấp nhận',
    'expected': 'Chấp nhận thành công, trả về true và cập nhật lại danh sách lời mời đến',
  },
  'FriendProvider Tests rejectRequest success and fetches incoming requests': {
    'feature': 'FriendProvider - Từ chối lời mời kết bạn',
    'inputs': 'requestId = "req_123", thực hiện từ chối',
    'expected': 'Từ chối thành công, trả về true và cập nhật lại danh sách lời mời đến',
  },
  'FriendProvider Tests cancelRequest success and fetches outgoing requests': {
    'feature': 'FriendProvider - Hủy lời mời kết bạn đã gửi đi',
    'inputs': 'requestId = "req_123", thực hiện hủy',
    'expected': 'Hủy yêu cầu thành công, trả về true và cập nhật lại danh sách lời mời đi',
  },
  'FriendProvider Tests unfriend success': {
    'feature': 'FriendProvider - Hủy kết bạn (hủy liên kết bạn bè)',
    'inputs': 'userId = "user_xyz", gọi hàm unfriend()',
    'expected': 'Xóa quan hệ bạn bè thành công trên server, trả về true',
  },
};

Future<void> main() async {
  print('=== KHỞI CHẠY KIỂM THỬ TỰ ĐỘNG (FLUTTER TEST) ===');
  
  final process = await Process.start('flutter', ['test', '--reporter', 'json']);
  
  final Map<int, Map<String, dynamic>> runningTests = {};
  final List<Map<String, dynamic>> resultsList = [];
  
  await for (final line in process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    try {
      final event = jsonDecode(line) as Map<String, dynamic>;
      final eventType = event['type'] ?? event['event'];
      
      if (eventType == 'testStart') {
        final testData = event['test'] as Map<String, dynamic>;
        final id = testData['id'] as int;
        final name = testData['name'] as String;
        
        // Skip suite load events which have metadata but no real code test representation
        if (!name.startsWith('loading ') && name != '(setUpAll)' && name != '(tearDownAll)') {
          runningTests[id] = {
            'name': name,
            'error': '',
            'status': 'skipped',
          };
        }
      } else if (eventType == 'error') {
        final testId = event['testID'] as int;
        final errorText = event['error'] as String;
        if (runningTests.containsKey(testId)) {
          runningTests[testId]!['error'] = (runningTests[testId]!['error'] + '\n' + errorText).trim();
        }
      } else if (eventType == 'testDone') {
        final testId = event['testID'] as int;
        final result = event['result'] as String;
        final wasSkipped = event['skipped'] as bool? ?? false;
        
        if (runningTests.containsKey(testId)) {
          final test = runningTests[testId]!;
          test['status'] = wasSkipped ? 'skipped' : result;
          
          resultsList.add({
            'name': test['name'],
            'status': test['status'],
            'error': test['error'],
          });
          
          final statusSymbol = test['status'] == 'success' ? '✓' : '✗';
          print('[$statusSymbol] ${test['name']} - ${test['status']}');
        }
      }
    } catch (_) {
      // Ignore parse errors from non-json output lines if any
    }
  }
  
  final exitCode = await process.exitCode;
  print('\n=== KIỂM THỬ HOÀN THÀNH. MÃ THOÁT: $exitCode ===');
  
  // Generate the report markdown table
  final StringBuffer buffer = StringBuffer();
  buffer.writeln('# BÁO CÁO KẾT QUẢ KIỂM THỬ TỰ ĐỘNG (AUTOMATION TEST REPORT)');
  buffer.writeln();
  buffer.writeln('Thời gian chạy kiểm thử: ${DateTime.now().toLocal()}');
  buffer.writeln();
  buffer.writeln('| STT | Chức năng kiểm thử | Dữ liệu đầu vào | Kết quả mong đợi | Kết quả thực tế | Trạng thái |');
  buffer.writeln('| :--- | :--- | :--- | :--- | :--- | :--- |');
  
  int stt = 1;
  for (final res in resultsList) {
    final name = res['name'] as String;
    final status = res['status'] as String;
    final error = res['error'] as String;
    
    // Look up in metadata
    final metadata = testMetadata[name];
    
    final String feature = metadata != null ? metadata['feature']! : name;
    final String inputs = metadata != null ? metadata['inputs']! : 'N/A';
    final String expected = metadata != null ? metadata['expected']! : 'Thực thi thành công';
    
    String actual = '';
    String statusText = '';
    
    if (status == 'success') {
      actual = 'Đạt kết quả mong đợi, xử lý không xảy ra lỗi.';
      statusText = '<span style="color:green; font-weight:bold;">Đạt</span>';
    } else if (status == 'skipped') {
      actual = 'Bị bỏ qua.';
      statusText = '<span style="color:orange; font-weight:bold;">Bỏ qua</span>';
    } else {
      actual = error.isNotEmpty 
          ? 'Thất bại. Lỗi chi tiết: ${error.replaceAll('\n', '<br>')}'
          : 'Thất bại không rõ nguyên nhân.';
      statusText = '<span style="color:red; font-weight:bold;">Không đạt</span>';
    }
    
    buffer.writeln('| $stt | $feature | $inputs | $expected | $actual | $statusText |');
    stt++;
  }
  
  final reportFile = File('test_report.md');
  await reportFile.writeAsString(buffer.toString());
  print('Đã xuất báo cáo ra file: ${reportFile.absolute.path}');
}
