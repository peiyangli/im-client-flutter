import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:one/net/netim.dart' as $nm;

import 'proto/build/dart/pb_sys.pb.dart' as $pbsys;
import 'proto/build/dart/pb_user.pb.dart' as $pbuser;
import 'proto/build/dart/pb_ids.pbenum.dart';

import 'package:fixnum/fixnum.dart';


void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    var netim  = $nm.NetIm();
    netim.init($nm.NetAddressGenerator($nm.NetImAddress("10.10.1.99", 19443)));

    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  int once = 0;
  var netim  = $nm.NetIm();

  int _status;
  int _sysTime;

  void init(){
    netim.status.addListener(onNetImStatusChanged);
  }
  void onNetImStatusChanged(){
    debugPrint("onNetImStatusChanged: ${netim.status}");
    if(!netim.isLogin()){
      //todo login? if presented
    }
    setState(() {_status = netim.status.value;});
  }

  void _connect() async {
    if(!netim.isConnected()){
      netim.connect();
      return;
    }

    var query = $pbsys.SysTimeQuery();
    query.tt = $pbsys.SysTimeTypes.STT_MilliSecond;
    netim.query(Fids.SysTimeQuery.value, msg:query, timeout: 3000)
        .then((pkg){
//          $nm.Package resp;
          var resp = $pbsys.SysTimeQueryResponse.fromBuffer(pkg.body);
          setState(() {_sysTime = resp.v.toInt();});
        })
        .catchError((err){
            debugPrint("not connected? $err");
        });
//    $nm.Package resp = await netim.query(Fids.SysTimeQuery.value, body: query.writeToBuffer(), timeout: 3000);
//    if(resp == null){
//      debugPrint("not connected?");
//    }
  }

  @override
  Widget build(BuildContext context) {
    init();
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_status',
              style: Theme.of(context).textTheme.display1,
            ),
            Text(
              'SystemTime: '+'$_sysTime',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _connect,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  var _response;
  _request() async{

    var ui = $pbuser.UserInfo();
    ui.birthday = Int64(1024);
    var uis = ui.writeToBuffer();
    var ui2 = $pbuser.UserInfo.fromBuffer(uis);

    debugPrint("ui2: $ui2");


    //建立连接
    var socket=await Socket.connect("baidu.com", 80);
    //根据http协议，发送请求头
    socket.writeln("GET / HTTP/1.1");
    socket.writeln("Host:baidu.com");
    socket.writeln("Connection:close");
    socket.writeln();
    await socket.flush(); //发送
    //读取返回内容
//    _response = await socket.transform(utf8.Decoder).join();

    await socket.close().then((response){
      response.cast<List<int>>().transform(utf8.decoder).listen((content) {

        setState(() {
          // This call to setState tells the Flutter framework that something has
          // changed in this State, which causes it to rerun the build method below
          // so that the display can reflect the updated values. If we changed
          // _counter without calling setState(), then the build method would not be
          // called again, and so nothing would appear to happen.
          _response = content;
        });
      });
    });


//    await socket.close();
  }
}
