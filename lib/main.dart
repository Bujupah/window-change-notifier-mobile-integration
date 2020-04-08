import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sweetalert/sweetalert.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.dark(),
      home: MyHomePage(),
    );
  }
}
class NotifyData {
  final int id;
  final String title;
  final String body; 
  final String image;

  NotifyData(this.id, this.title, this.body, this.image);

  Uint8List get imageFile => Base64Decoder().convert(image);

  @override
  String toString(){
    return '$this{#}$title{#}$body{#}$image';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'image': image,
    };
  }

  static NotifyData fromMap(Map<String, dynamic> map) {
    if (map == null) return null;
  
    return NotifyData(
      map['id'],
      map['title'],
      map['body'],
      map['image'],
    );
  }

  String toJson() => json.encode(toMap());

  static NotifyData fromJson(String source) => fromMap(json.decode(source));
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  final String channelName = 'window_change_notifier';
  final int port = 8080;

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  HttpServer httpServer;
  StreamSubscription<HttpRequest> streamSubscription;
  
  openServer() async {
    print('Trying to create server...');
    httpServer = await HttpServer
      .bind(InternetAddress.anyIPv4, port).whenComplete((){
        print('Listening on $port');
      });
    streamSubscription = httpServer.listen((HttpRequest req) async {
      if (req.uri.path == '/webhook') {
        var id = int.tryParse(req.headers.value('id'));
        var title = req.headers.value('title');
        var body = req.headers.value('body');
        var image = req.headers.value('image');
        _notify(id, title, body, image);
      }
      req.response.close();
    });
    setState(() {});
  }

  _notify(id, title, body, image){
    _showNotificationWithDefaultSound(NotifyData(id, title, body, image));
  }
  
  @override
  void initState() {
    super.initState();
    openServer();
    var initAndroidSettings = AndroidInitializationSettings('app_icon');
    var initIOSSettings = IOSInitializationSettings();

    var initSettings = InitializationSettings(initAndroidSettings, initIOSSettings);

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    flutterLocalNotificationsPlugin.initialize(initSettings, onSelectNotification: onSelectNotification);
    
  }

  Image image;

  Future onSelectNotification(String payload){
    NotifyData data = NotifyData.fromJson(payload);
    SweetAlert.show(context,
      title: data.title,
      subtitle: data.body,
      onPress: (value){
        setState(() => image = Image.memory(data.imageFile));

        return true;
      }
    );
  }

  Future _showNotificationWithDefaultSound(NotifyData data) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'channelId', 
      'channelName', 
      'channelDescription',
      importance: Importance.Max, 
      priority: Priority.High
    );

    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      data.id,
      data.title,
      data.body,
      platformChannelSpecifics,
      payload: data.toJson(),
    );

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        alignment: Alignment.center,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: image,
      )
    );
  }
}
