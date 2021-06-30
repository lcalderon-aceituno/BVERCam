import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart'; /// For saving video
import 'package:dio/dio.dart'; /// For saving video

import 'package:intl/intl.dart';

// import 'package:flutter_speed_dial/flutter_speed_dial.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:save_in_gallery/save_in_gallery.dart';
// import 'package:web_socket_channel/io.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context){
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      title: "ESP32-CAM Surveillance Camera",
      home: Home(
        channel: IOWebSocketChannel.connect('ws://34.94.141.140:65080')
      ),
    );
  }
}

class Home extends StatefulWidget {

  final WebSocketChannel channel;
  Home({Key? key, required this.channel}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {

  final videoWidth = 640;
  final videoHeight = 480;

  double newVideoSizeWidth = 640;
  double newVideoSizeHeight = 480;

  String _timeString = "TIME DATA EMPTY"; /// String for time display on stream
  bool? isLandscape; /// Boolean to track orientation of the app

  var _globalKey = new GlobalKey(); /// Initialize global key

  @override
  void initState() {
    isLandscape = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(builder: (context, orientation) {
        var screenWidth = MediaQuery.of(context).size.width;
        var screenHeight = MediaQuery.of(context).size.height;

        if (orientation == Orientation.portrait) {
          // screen width < screen height
          isLandscape = false;
          newVideoSizeWidth =
          (screenWidth > videoWidth ? videoWidth : screenWidth) as double;
          newVideoSizeHeight = videoHeight * newVideoSizeWidth / videoWidth;
        } else {
          isLandscape = true;
          newVideoSizeHeight =
          (screenHeight > videoHeight ? videoHeight : screenHeight) as double;
          newVideoSizeWidth = videoWidth * newVideoSizeHeight / videoHeight;
        }

        return Container(
          color: Colors.black,
          child: StreamBuilder(stream: widget.channel.stream,
            builder: (context, snapshot) {
              // Check if snapshot has data
              if (!snapshot
                  .hasData) { // If snapshot does not have data, display loading circle
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),),
                );
              } else { // If the snapshot does have data
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        SizedBox(
                          height: isLandscape! ? 0:30,
                        ),
                        Stack(
                          children: [
                            RepaintBoundary(
                              key: _globalKey,
                              child: Image.memory(
                                  snapshot.data as Uint8List,
                                  gaplessPlayback: true,
                                  width: newVideoSizeWidth,
                                  height: newVideoSizeHeight,
                                ),
                            ),

                            Positioned.fill(child: Align(child:
                            Column(
                              children: [
                                SizedBox(
                                  height: 16,
                                ),
                                Text('BVER Cam', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300),), // App title
                                SizedBox(
                                  height: 4,
                                ),
                                Text('Live | $_timeString', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300),), // Live tag and time stamp display
                              ],
                            ), alignment: Alignment.topCenter, /** Align text at top center */
                            ))
                          ],
                        ),

                        /** Create menu bar below image widget */
                        Expanded(flex: 1,
                        child: Container(color: Colors.black,
                        width: MediaQuery.of(context).size.width,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly, /** Align all buttons on menu bar evenly*/
                              children: [
                                Material( /** wrap Icon button in Material to make splash color visible front of container */
                                  color: Colors.black,
                                  child: IconButton(
                                      icon: Icon(
                                        Icons.videocam,
                                      ),
                                    iconSize: 24,
                                    color: Colors.orange,
                                    splashColor: Colors.orange,
                                    onPressed: () {},
                                  ),
                                ),
                                Material( /** wrap Icon button in Material to make splash color visible front of container */
                                  color: Colors.black,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.photo_camera,
                                    ),
                                    iconSize: 24,
                                    color: Colors.orange,
                                    splashColor: Colors.orange,
                                    onPressed: () { _saveScreen();},
                                  ),
                                ),
                              ],
                            )
                        )))
                        /**End of menu bar*/
                      ]
                    )
                  ]
                );
              }
            },),
        );
      }),
    );
  }

  /// Method as seen in https://pub.dev/packages/image_gallery_saver/example
  _saveScreen() async {
    RenderRepaintBoundary boundary =
    _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage();
    ByteData? byteData = await (image.toByteData(format: ui.ImageByteFormat.png));
    if (byteData != null) {
      final result =
      await ImageGallerySaver.saveImage(byteData.buffer.asUint8List());
      print(result);
      _toastInfo(result.toString());
    }
  }

  _toastInfo(String info) {
    Fluttertoast.showToast(msg: info, toastLength: Toast.LENGTH_LONG);
  }
}