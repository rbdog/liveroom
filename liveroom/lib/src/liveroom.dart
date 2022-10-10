// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum _BodyType {
  join(0),
  message(1),
  exit(2);

  final int rawValue;
  const _BodyType(this.rawValue);
  factory _BodyType.from({required int rawValue}) {
    final value = _BodyType.values.firstWhere((e) => e.rawValue == rawValue);
    return value;
  }
}

// ライブイベント
class _LiveEvent {
  // シートID
  final String seatId;
  // join | message | exit
  final _BodyType bodyType;
  // メッセージ本文
  final String body;
  _LiveEvent({
    required this.seatId,
    required this.bodyType,
    required this.body,
  });
  // JSON 変換
  _LiveEvent.fromJson(Map<String, dynamic> json)
      : seatId = json['seat_id'],
        bodyType = _BodyType.from(rawValue: json['body_type']),
        body = json['body'];
  Map<String, dynamic> toJson() => {
        'seat_id': seatId,
        'body_type': bodyType,
        'body': body,
      };
}

enum Scheme {
  ws('ws');

  final String rawValue;
  const Scheme(this.rawValue);
}

class LiveroomConfig {
  final Scheme scheme;
  final String host;
  final String rootPath;
  final int port;
  String? roomId;
  String? seatId;

  LiveroomConfig({
    required this.scheme,
    required this.host,
    required this.rootPath,
    required this.port,
  });
}

// ライブルーム
class Liveroom {
  // WebSocket
  WebSocketChannel? _channel;
  var _sendCtrl = StreamController<_LiveEvent>.broadcast();
  var _joinCtrl = StreamController<String>.broadcast();
  var _exitCtrl = StreamController<String>.broadcast();
  var _errCtrl = StreamController<String>.broadcast();
  final LiveroomConfig config;
  final void Function(String log)? logger;

  Liveroom({
    Scheme scheme = Scheme.ws,
    String host = '0.0.0.0',
    String rootPath = '/liveroom',
    int port = 5000,
    this.logger,
  }) : config = LiveroomConfig(
          scheme: scheme,
          host: host,
          rootPath: rootPath,
          port: port,
        );

  // WebSocket接続
  void _connect(
    String apiPath,
    String roomId, {
    required String? optSeatId,
    required void Function(Object error) onError,
  }) {
    logger?.call('_connect called');
    final seatId = optSeatId ?? const Uuid().v4();
    final url = Uri(
      scheme: config.scheme.rawValue,
      host: config.host,
      path: config.rootPath + apiPath,
      port: config.port,
      queryParameters: {
        'room_id': roomId,
        'seat_id': seatId,
      },
    );
    logger?.call('Connecting: ${url.toString()}');
    _channel = WebSocketChannel.connect(url);

    // save roomId, seatId
    config.roomId = roomId;
    config.seatId = seatId;
    // WebSocket 受信
    _channel?.stream.listen(
      (event) {
        final json = jsonDecode(event);
        final liveEvent = _LiveEvent.fromJson(json);
        switch (liveEvent.bodyType) {
          case _BodyType.join:
            _joinCtrl.sink.add(liveEvent.seatId);
            break;
          case _BodyType.message:
            _sendCtrl.sink.add(liveEvent);
            break;
          case _BodyType.exit:
            _exitCtrl.sink.add(liveEvent.seatId);
            break;
          default:
            break;
        }
      },
      cancelOnError: true,
      onError: (Object error) {
        logger?.call('ConnectingError: ${error.toString()}');
        onError(error);
      },
      onDone: () {
        // 自分が disconnected
        _exitCtrl.sink.add(seatId);
      },
    );
  }

  // 既にルームに参加中かどうか
  bool get isJoined {
    return _channel != null;
  }

  // 自分のシートID
  String? get mySeatId {
    return config.seatId;
  }

  // ルームを作成
  Future<void> create({required String roomId, String? seatId}) async {
    logger?.call('create called');
    if (isJoined) {
      logger?.call('exiting old room ...');
      await exit();
      logger?.call('exited old room');
    }
    _connect(
      '/create',
      roomId,
      optSeatId: seatId,
      onError: (Object error) {
        _errCtrl.sink.add(error.toString());
      },
    );
  }

  // ルームに参加
  Future<void> join({required String roomId, String? seatId}) async {
    logger?.call('join called');
    if (isJoined) {
      logger?.call('exiting old room ...');
      await exit();
      logger?.call('exited old room');
    }
    _connect(
      '/join',
      roomId,
      optSeatId: seatId,
      onError: (Object error) {
        _errCtrl.sink.add(error.toString());
      },
    );
  }

  // 誰かが入室した時
  StreamSubscription onJoin(void Function(String seatId) process) {
    logger?.call('onJoin called');
    final subs = _joinCtrl.stream.listen((body) {
      process(body);
    });
    return subs;
  }

  // メッセージをルーム内全員に送信
  void send({required String message}) {
    logger?.call('send called');
    if (!isJoined) {
      logger?.call('Not joined Room');
      return;
    }
    _channel?.sink.add(message);
  }

  // メッセージを受け取った時の処理
  StreamSubscription receive(
    void Function(String seatId, String message) process,
  ) {
    logger?.call('receive called');
    final subs = _sendCtrl.stream.listen((liveEvent) {
      process(liveEvent.seatId, liveEvent.body);
    });
    return subs;
  }

  // ルームを退出
  Future<void> exit() async {
    logger?.call('exit called');
    _channel?.sink.close();
    _channel = null;
    config.roomId = null;
  }

  // 誰かが退出した時
  StreamSubscription onExit(void Function(String seatId) process) {
    logger?.call('onExit called');
    final subs = _exitCtrl.stream.listen((body) {
      process(body);
    });
    return subs;
  }

  // エラーがあった時
  StreamSubscription onError(void Function(String errorMessage) process) {
    logger?.call('onError called');
    final subs = _errCtrl.stream.listen((errString) {
      process(errString);
    });
    return subs;
  }

  /// * RESET ALL Liveroom state
  Future<void> reset() async {
    logger?.call('reset called');
    _sendCtrl.sink.close();
    _joinCtrl.sink.close();
    _exitCtrl.sink.close();
    _errCtrl.sink.close();
    _sendCtrl = StreamController<_LiveEvent>.broadcast();
    _joinCtrl = StreamController<String>.broadcast();
    _exitCtrl = StreamController<String>.broadcast();
    _errCtrl = StreamController<String>.broadcast();
    _channel?.sink.close();
    _channel = null;
    config.roomId = null;
  }
}
