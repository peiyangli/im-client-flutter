####支持protobuffer的dart库

1. 在pubspec.yaml中添加protobuf: ^1.0.0
dependencies:
  flutter:
    sdk: flutter

  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^0.1.2
  protobuf: ^1.0.0

2. 项目引用

import 'package:protobuf/protobuf.dart';


####配置dart的protobuffer编译插件

1. git clone https://github.com/dart-lang/protobuf.git

2. cd protoc_plugin

3. flutter与pub需要在path下： PATH=%PAT%;C:\flutter\bin;C:\flutter\bin\cache\dart-sdk\bin;

4. pub install

5. 添加到PATH下 PATH=%PAT%;D:\works\flutter\protobuf\protoc_plugin\bin


#### 生成pb文件

protoc --dart_out=. test.proto