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
import 'package:screen_recorder/screen_recorder.dart'; /// For saving video
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'blinkingTimer.dart'; /// For blinking timer
import 'videoUtil.dart'; /// For video capture
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:gallery_saver/gallery_saver.dart'; /// For video saving to gallery

import 'package:intl/intl.dart';

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
        channel: IOWebSocketChannel.connect('ws://34.94.141.140:65080'),
      ),
    );
  }
}

class Home extends StatefulWidget {
  WebSocketChannel channel; /// Removed final
  Home({Key? key, required this.channel,}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  WebSocketChannel? commChannel; /// Testing

  final videoWidth = 640;
  final videoHeight = 480;

  double newVideoSizeWidth = 640;
  double newVideoSizeHeight = 480;

  String _timeString = "TIME DATA EMPTY"; /// String for time display on stream
  bool? isLandscape; /// Boolean to track orientation of the app
  bool? leftStimState; /// Boolean to track state of the left stimulus
  bool? rightStimState; /// Boolean to track state of the right stimulus

  var _globalKey = new GlobalKey(); /// Initialize global key

  ScreenRecorderController controller = ScreenRecorderController();

  int? frameNum; /// Counting variable
  Timer? _timer;
  bool? isRecording; /// Boolean variable for video recording
  final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();
  String? msg; /// Variable for loading message to be sent to the board
  String? dropdownValue; /// Initial frequency option
  List<String> freqOptions = []; /// Frequency options to be chosen from by user (1-25Hz)

  @override
  void initState() {
    commChannel = IOWebSocketChannel.connect('ws://34.94.141.140:65080'); /// Testing

    isLandscape = false; /// Assume initially the app is in portrait mode
    isRecording = false;
    leftStimState = false; /// Initially left stimulus is LOW so set boolean to FALSE
    rightStimState = false; /// Initially right stimulus is LOW so set boolean to FALSE
    super.initState();

    _timeString = _formatDateTime(DateTime.now()); /// Set time string value
    Timer.periodic(Duration(seconds:1), (Timer t) => _getTime());

    frameNum = 0;
    VideoUtil.workPath = 'images';
    VideoUtil.getAppTempDirectory();

    msg = ""; /// Initialize message as empty string
    for(int i = 1; i <= 25; i++) {
      freqOptions.add("$i Hz"); /// Add all frequency options to the list of spinner options
    }
    dropdownValue = '1 Hz'; /// Initial frequency option
  }

  /// Dispose method called when the object is removed from the tree permanently
  @override
  void dispose() {
    widget.channel.sink.close(); /// Close websocket
    commChannel!.sink.close(); /// Testing
    _timer!.cancel(); /// Cancel timer
    super.dispose();
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
          newVideoSizeWidth = screenWidth;
          newVideoSizeHeight = videoHeight * newVideoSizeWidth / videoWidth;
        } else {
          isLandscape = true;
          newVideoSizeHeight = screenHeight;
          newVideoSizeWidth = videoWidth * newVideoSizeHeight / videoHeight;
        }

        return Container(
          color: Colors.black,
          child: StreamBuilder(stream: widget.channel.stream,
            builder: (context, snapshot) {
              // Check if snapshot has data
              if (!snapshot.hasData) { // If snapshot does not have data, display loading circle
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),),
                );
              } else { // If the snapshot does have data
                if(isRecording!){
                  VideoUtil.saveImageFileToDirectory(snapshot.data as Uint8List, 'image_$frameNum.jpg');
                  frameNum = frameNum! + 1;
                }
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
                                Text('BVER Cam', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300, color: Colors.black),), /// App title
                                SizedBox(
                                  height: 4,
                                ),
                                Text('Live | $_timeString', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: Colors.black),), /// Live tag and time stamp display
                                SizedBox(height: 16,),
                                isRecording!? BlinkingTimer() : Container(),
                              ],
                            ), alignment: Alignment.topCenter, /** Align text at top center */
                            ))
                          ],
                        ),

                        /**
                         * Stimulus menu bar
                         * */
                        Expanded(flex: 1,
                            child: Container(color: Colors.black,
                                width: MediaQuery.of(context).size.width,
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 25),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly, /** Align all buttons on menu bar evenly*/
                                      children: [
                                        Material( /** wrap Icon button in Material to make splash color visible front of container */
                                          color: Colors.black,
                                          child: OutlinedButton(
                                            child: Text("Left stimulus", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300),),
                                            style: OutlinedButton.styleFrom(
                                              primary: Colors.orange,
                                              backgroundColor: Colors.black,
                                              side: BorderSide(color: Colors.orange, width: 1),
                                            ),
                                            onPressed: () {
                                              sendMsg("Left stimulus button activated"); /// Send string message
                                            },
                                          ),
                                        ),
                                        Material( /** wrap Icon button in Material to make splash color visible front of container */
                                          color: Colors.black,
                                          child: OutlinedButton(
                                            child: Text("Right stimulus", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300),),
                                            style: OutlinedButton.styleFrom(
                                              primary: Colors.orange,
                                              backgroundColor: Colors.black,
                                              side: BorderSide(color: Colors.orange, width: 1),
                                            ),
                                            onPressed: () {
                                              print("Right button pushed");
                                              sendMsg("Right stimulus button activated"); /// Send string message
                                              },
                                          ),
                                        ),
                                      ],
                                    )
                                ))),
                                /**
                                 * Capture & frequency menu bar
                                 * */
                                Expanded(flex: 5,
                                child: Container(color: Colors.black,
                                width: MediaQuery.of(context).size.width,
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 25),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Material( /** wrap Icon button in Material to make splash color visible front of container */
                                          color: Colors.black,
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.photo_camera,
                                            ),
                                            iconSize: 30,
                                            color: Colors.orange,
                                            splashColor: Colors.orange,
                                            onPressed: () { _saveScreen();},
                                          ),
                                        ),
                                        Material( /** wrap Icon button in Material to make splash color visible front of container */
                                          color: Colors.black,
                                          child: IconButton(
                                            icon: Icon(
                                              isRecording!? Icons.stop : Icons.videocam, /// Icon displayed is conditional on recording boolean
                                            ),
                                            iconSize: 30,
                                            color: Colors.orange,
                                            splashColor: Colors.orange,
                                            onPressed: () {videoRecording();}, /// When pressed, toggle the state of video recording
                                          ),
                                        ),
                                        Material( /** wrap Icon button in Material to make splash color visible front of container */
                                          color: Colors.black,
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 11),
                                            child: Text(
                                                "Frequency: ",
                                                style: TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.w300),
                                            ),
                                          )
                                        ),
                                        /// Spinner/drop down menu for choosing the frequency of the stimulus (1-25 Hz)
                                        Material( /** wrap Icon button in Material to make splash color visible front of container */
                                          color: Colors.black,
                                          /// Add some padding around the frequency menu
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 20),
                                            child: DropdownButton<String>(
                                              value: dropdownValue,
                                              icon: const Icon(Icons.arrow_drop_down),
                                              iconSize: 15,
                                              iconDisabledColor: Colors.orange,
                                              iconEnabledColor: Colors.orange,
                                              elevation: 16,
                                              style: const TextStyle(color: Colors.orange, fontSize: 18,fontWeight: FontWeight.w300),
                                              underline: Container(
                                                height: 2,
                                                color: Colors.orange,
                                              ),
                                              /// Setting new value once changed
                                              onChanged: (String? newValue) {
                                                setState(() {
                                                  dropdownValue = newValue!;
                                                  sendMsg(dropdownValue!); /// Send the dropdown value selected to the board
                                                });
                                              },
                                              /// Item list
                                              items: freqOptions
                                                  .map<DropdownMenuItem<String>>((String value) {
                                                return DropdownMenuItem<String>(
                                                  value: value,
                                                  child: Text(value),
                                                  // if(value == "")
                                                );
                                              }).toList(),
                                            ),
                                          )
                                        ),
                                      ],
                                    )
                                ))),
                                /**End of capture menu bar*/
                      ]
                    )
                  ]
                );
              }
            },),
        );
      }),
        floatingActionButton: _getFab(),
    );
  }

  /// Method as seen in https://pub.dev/packages/image_gallery_saver/example
  /// Captures and saves screenshot to gallery
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

  /// Formats date time string
  String _formatDateTime(DateTime dateTime){
    return DateFormat('MM/dd hh:mm:ss aaa').format(dateTime);
  }

  /// Updates the current time
  void _getTime(){
    final DateTime now = DateTime.now();
    setState(() {
      _timeString = _formatDateTime(now);
    });
  }

  /// Speed dial widget for landscape orientation
  Widget _getFab(){
    return SpeedDial(
      overlayOpacity: 0.1,
      animatedIcon: AnimatedIcons.menu_close,
      animatedIconTheme: IconThemeData(size: 22),
      visible: isLandscape!,
      curve: Curves.bounceIn,
      backgroundColor: Colors.orange,
      foregroundColor: Colors.black,
      children: [
        SpeedDialChild(
          backgroundColor: Colors.black,
          foregroundColor: Colors.orange,
          child: Icon(Icons.photo_camera),
          onTap: () => _saveScreen(),
        ),
        SpeedDialChild(
          backgroundColor: Colors.black,
          foregroundColor: Colors.orange,
          child: Icon(isRecording!? Icons.stop : Icons.videocam), /// Icon displayed is conditional on recording boolean),
          onTap: (){videoRecording();} /// When pressed, toggle the state of video recording
        )
      ]
    );
  }

  /**
   * Video capture functions
   * */

  /// Toggles the state of video recording boolean and initiates video creation
  videoRecording(){
    isRecording = !isRecording!;

    if(!isRecording! && frameNum! > 0){
      frameNum = 0;
      makeVideoWithFFMpeg();
    }
  }

  Future<int> execute(String command) async {
    return await _flutterFFmpeg.execute(command);
  }

  /// Creates video
  makeVideoWithFFMpeg(){
    String tempVideofileName = "${DateTime.now().millisecondsSinceEpoch}.mp4";
    execute(VideoUtil.generateEncodeVideoScript("mpeg4", tempVideofileName)).then((rc){
      if(rc == 0){ /// No issue making video
        print("Video complete");
        String outputPath = VideoUtil.appTempDir! + "/$tempVideofileName";
        _saveVideo(outputPath);
      }
    });
  }

  /// Saves video to gallery
  _saveVideo(String path) async {
    GallerySaver.saveVideo(path).then((result){
      print("Video Save result : $result");
      _toastInfo("Video saved in Gallery: $result"); /// Display debug message to app
      VideoUtil.deleteTempDirectory();
    });
  }

  /// Stimulus function
  /// Sends a message via communication channel to the camera module
  sendMsg(String msg) {
    print("sending msg");
    widget.channel.sink.close(); /// Disconnect video streaming channel
    commChannel!.sink.add(msg); /// Send message in communication channel
    widget.channel = IOWebSocketChannel.connect('ws://34.94.141.140:65080'); /// Reconnect the video streaming channel
  }
}