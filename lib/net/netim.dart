

import 'dart:async';
import 'dart:io';

import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import 'package:protobuf/protobuf.dart' as $pb;



class NetImAddress{
  String host;
  int port;
  NetImAddress(this.host, this.port);

}

abstract class INetAddressGenerator<Addr>{
  Addr next();
  void done(Addr addr, bool ok);
}

class NetAddressGenerator extends INetAddressGenerator<NetImAddress>{

  NetImAddress addr = NetImAddress("10.10.1.99", 19443);

  NetAddressGenerator([this.addr]);

  @override
  void done(NetImAddress addr, bool ok) {
    // TODO: implement done
  }

  @override
  NetImAddress next() {
    // TODO: implement next
    return addr;
  }
}


class Header{
  static const int PACKAGE = 4;
  //22
  //<<SZ:32,?IM_SESSION_SIGN:16, Ver:16, Tp:8, Res:8, Qid:32, Fid:32, Code:32, Body/binary>>).
  static const int SIZE = 22;

  int sign = 0x1615;
  int ver = 0; //uint32
  int tp = 0; //uint8
  int res = 0; //uint8
  int qid = 0; //uint32
  int fid = 0; //uint32
  int code = 0; //uint32
  Header({this.fid, this.qid});
  Header.fromByteData(ByteData data){
    sign    = data.getUint16(4);
    ver     = data.getUint16(6);
    tp      = data.getUint8(8);
    res     = data.getUint8(9);
    qid     = data.getUint32(10);
    fid     = data.getUint32(14);
    code    = data.getUint32(18);
  }


  Uint8List makePackage(Uint8List body){
    var header = ByteData(SIZE);

    header.setUint16(4, sign);
    header.setUint16(6, ver);
    header.setUint8(8, tp);
    header.setUint8(9, res);
    header.setUint32(10, qid);
    header.setUint32(14, fid);
    header.setUint32(18, code);
    if(body == null){
      header.setUint32(0, SIZE-PACKAGE);
      return header.buffer.asUint8List();
    }
    header.setUint32(0, SIZE-PACKAGE+body.length);
    return Uint8List.fromList(header.buffer.asUint8List() + body);
  }
}
class Package{
  Header header;
  //body
  Uint8List body;

  Package(this.header, this.body);

  bool isResponse(){
    return header.res == 1;
  }
}

class NetImConfig{
  int reconnectMax = 5;
  int reconnectDelay = 1000;

  Duration timeoutConnect;
  Duration timeout;

  NetImConfig({this.reconnectMax = 5, this.reconnectDelay = 1000, int timeout=60, int timeoutConnect=10}){
    this.timeout = Duration(seconds: timeout);
    this.timeoutConnect = Duration(seconds: timeoutConnect);
  }
}


class NetStatus extends ValueNotifier<int>{
  NetStatus(value) : super(value);
}

class NetIm{
//  static const int StatusNone       = 0x00;
  static const int StatusTimeout    = -1;
  static const int StatusExit       = 0x01;
  static const int StatusNone       = 0x02;
  static const int StatusDone       = 0x04;
  static const int StatusError      = 0x08; //reconnect failed
  static const int StatusFailed     = 0x10;
  static const int StatusConnecting = 0x20;
  static const int StatusConnected  = 0x40;
  static const int StatusLogin      = 0x80;

  INetAddressGenerator<NetImAddress> addrs = NetAddressGenerator();//default address maker
  NetStatus status = NetStatus(StatusNone);
  bool isLogin(){
    return status.value == StatusLogin;
  }
  bool isConnected(){
    return status.value == StatusLogin || status.value == StatusConnected;
  }

  static final NetIm _netWork = NetIm._internal();//1
  factory NetIm() {//2
    return _netWork;
  }
  NetIm._internal();
//  NetIm._internal({int reconnectCD = 5,int reconnectDelay = 1000}){
//    this._reconnectCD = reconnectCD;
//    this._reconnectDelay = reconnectDelay;
//    this.config = NetImConfig();
//  }//3

  void init([INetAddressGenerator<NetImAddress> addrs, NetImConfig config]){
    this.addrs = addrs;
    if(config!= null) {
      this.config = config;
    }
  }

//  void (Package pkg) onPacakge;
  NetImConfig config = NetImConfig();
  int _reconnectCD = 5;
  int _reconnectDelay = 1000;

//  NetIm(this.addrs, this.config);
  Socket _sock;
  void connect()async{
    if(status.value > StatusFailed){
      //already start
      return;
    }
    //use while to reconnect
    status.value = StatusConnecting;
    var addr = addrs.next();
    try {

      _sock = await SecureSocket.connect(addr.host, addr.port, onBadCertificate: onBadCertificate, timeout: config.timeoutConnect);
//      _sock = await Socket.connect(addr.host, addr.port, timeout: config.timeoutConnect);

      status.value = StatusConnected;
      addrs.done(addr, true);

      reconnectReset();
      //todo reconnectReset();
      //reset _status
      _cacheData = Uint8List(0);
      clearAllQueries();
      //start listen
      _sock.listen(onData, onDone:onDone, onError:onError);
    } catch (e) {
      debugPrint("failed to connect to server: ${addr.host},  $e");
      status.value = StatusFailed;
      addrs.done(addr, false);
      _reconnect();
    }
  }

  //===============================================
  bool onBadCertificate(X509Certificate certificate){
    debugPrint("onBadCertificate: ${certificate.issuer}, ${certificate.toString()}");
    return true;
  }

  //===============================================
  void _reset(){
    status.value = StatusDone;
    //call all waiting query error
    clearAllQueries();
    _reconnect();
  }
  void reconnectReset(){
    _reconnectCD = config.reconnectMax;
    _reconnectDelay = config.reconnectDelay;
  }
  void _reconnect()async{
    if(status.value > StatusFailed){
      //already start
      return;
    }
    if (_reconnectCD < 1){
      status.value = StatusError;
      return;
    }
    _reconnectCD--;
    _reconnectDelay = _reconnectDelay*2;
    await Future.delayed(Duration(milliseconds:_reconnectDelay));
    debugPrint("_reconnect: $_reconnectCD, $_reconnectDelay");
    connect();
  }
  //===============================================
  //sock callbacks

  //todo convert this to onPackage(Package)
  Uint8List _cacheData = Uint8List(0);
  void onData(newData){
//    debugPrint("onData");
    if(newData == null)return;
    //todo parse header or body and on and on
    _cacheData = Uint8List.fromList(_cacheData + newData);
    //
    while(true){
      if(_cacheData.length < Header.PACKAGE){
        return;
      }
      var packdata = _cacheData.buffer.asByteData();
      var plen = packdata.getUint32(0)+Header.PACKAGE;
      if(_cacheData.length < plen){
        return;
      }
      var body = _cacheData.sublist(Header.SIZE, plen);
      //next package
      _cacheData = _cacheData.sublist(plen);

      var header = Header.fromByteData(packdata);
      //this is a package, so let's make it
//    <<SZ:32,?IM_SESSION_SIGN:16, Ver:16, Tp:8, Res:8, Qid:32, Fid:32, Code:32, Body/binary>>).
      var pkg = Package(header, body);

      if(pkg.isResponse()){
        onQuery(pkg);
      }else{
        onEvent(pkg);
      }
    }
  }

  void onError(error, StackTrace trace){
    debugPrint("onError: $error");
    _sock.close();
    _reset();
    print(error);
  }

  void onDone(){
    debugPrint("onDone");
    _sock.destroy();
    _reset();
  }
  //===============================================
  Map _queries = new Map();
  int _queryId = 1;
  int _nextQueryId(){return _queryId++;}

  Future query(int fid, {$pb.GeneratedMessage msg, int timeout})async{
    if(!isConnected()){
      var comp = Completer<Package>();
      Future.microtask((){comp.completeError(status.value);});
      return comp.future;
    }
    if(msg != null) {
      var body = msg.writeToBuffer();
      return _queryBinary(fid, body: body, timeout: timeout);
    }
    return _queryBinary(fid, timeout: timeout);
  }

  Future queryBinary(int fid, {Uint8List body, int timeout})async{
    if(!isConnected()){
      var comp = Completer<Package>();
      Future.microtask((){comp.completeError(status.value);});
      return comp.future;
    }
    return _queryBinary(fid, body: body, timeout: timeout);
  }

  Future _queryBinary(int fid, {Uint8List body, int timeout})async{
    var comp = Completer<Package>();
    int qid = _nextQueryId();
    _queries[qid] = comp;
    var header = Header(fid: fid, qid: qid);

    try{
      _sock.add(header.makePackage(body));
      if(timeout>0){
        Future.delayed(Duration(milliseconds:timeout), ()=>_onQueryTimeout(qid));
      }
      return comp.future;
    }catch(e){
      var comp = Completer<Package>();
      Future.microtask((){comp.completeError(e);});
      return comp.future;
    }
  }

  void _onQueryTimeout(int qid){
    Completer<Package> comp = _queries.remove(qid);
    if(comp == null){return;}
    comp.completeError(StatusTimeout);
  }

  bool send(int fid, [$pb.GeneratedMessage msg]){
    if(!isConnected()){
      return false;
    }
    if(msg != null) {
      var body = msg.writeToBuffer();
      return _sendBinary(fid, body);
    }
    return _sendBinary(fid);
  }
  bool sendBinary(int fid, [Uint8List body]){
    if(!isConnected()){
      return false;
    }
    return _sendBinary(fid, body);
  }
  bool _sendBinary(int fid, [Uint8List body]){
    int qid = _nextQueryId();
    var header = Header(fid: fid, qid: qid);
    try{
      _sock.add(header.makePackage(body));
      return true;
    }catch(e){
      return false;
    }
  }

  void onQuery(Package pkg){
    Completer<Package> comp = _queries.remove(pkg.header.qid);
    if(comp == null){return;}
    comp.complete(pkg);
  }
  void clearAllQueries(){
    //connection closed
    Map queries = _queries;
    _queryId = 1;
    _queries = new Map();
    queries.forEach((qid, comp){comp.completeError(status);});
  }
//  void _onQueriesError(int qid, Completer<Package> comp){
//    comp.completeError(_status);
//  }
  //=================================================
  Map _events = new Map();
  void handleEvent(int fid, void handler(Package pkg)){
    _events[fid] = handler;
  }
  void onEvent(Package pkg){
    var handler = _events[pkg.header.fid];
    if(handler == null){
      debugPrint("unknown package: $pkg");
      return;
    }
    debugPrint("handle package: $pkg");
    handler(pkg);
  }
  //===============================================
}