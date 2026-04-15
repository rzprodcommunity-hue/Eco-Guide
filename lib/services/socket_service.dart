import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants/api_constants.dart';

class SocketService {
  static IO.Socket? _socket;

  static void init() {
    if (_socket != null) return;

    // Use baseUrl without /api
    final socketUrl = ApiConstants.baseUrl.replaceAll('/api', '');

    _socket = IO.io(socketUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build()
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      print('WebSocket connected to backend');
    });

    _socket!.onDisconnect((_) {
      print('WebSocket disconnected from backend');
    });

    _socket!.onConnectError((err) {
      print('WebSocket Connect Error: $err');
    });

    _socket!.onError((err) {
      print('WebSocket Error: $err');
    });
  }

  static void on(String event, Function(dynamic) callback) {
    if (_socket == null) init();
    _socket!.on(event, callback);
  }

  static void off(String event) {
    if (_socket == null) return;
    _socket!.off(event);
  }
}
