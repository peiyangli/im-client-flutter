import 'dart:async';
import 'dart:io';
import 'dart:collection';

// see https://github.com/dart-lang/sdk/blob/master/tests/standalone_2/io/raw_socket_test.dart

class NetWork{
  Socket _socket;
  var _host;
  int _port;

  bool _logining;

  final Queue _queue = new Queue<List<int>>();

  NetWork(this._host, this._port);

  void connect(){
    if(_logining)return;
    _logining = true;
    Socket.connect(_host, _port).then((Socket sock) {
      _socket = sock;
      _connected();
      _socket.listen(_onData,
          onError: _onError,
          onDone: _onDone,
          cancelOnError: false);
    }).catchError((AsyncError e) {
      _connectFailed();
    });
  }
  void _connectFailed(){
  }
  void _connected(){
  }
  void _onData(data){
    print(new String.fromCharCodes(data).trim());
  }
  void _onError(error, StackTrace trace){
    print(error);

    Future.delayed(const Duration(seconds:5));
    //reconnect
    connect();
  }
  void _onDone(){
    _socket.destroy();
  }
}