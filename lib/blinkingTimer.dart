import 'package:flutter/material.dart';
import 'dart:async';

class BlinkingTimer extends StatefulWidget {
  const BlinkingTimer({Key? key}) : super(key: key);

  @override
  _BlinkingTimerState createState() => _BlinkingTimerState();
}

class _BlinkingTimerState extends State<BlinkingTimer> with SingleTickerProviderStateMixin{
  AnimationController? _animationController;
  DateTime? currentTime;
  String? _timeString;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: Duration(seconds: 1));
    _animationController!.repeat();

    _timeString = "00:00";
    currentTime = DateTime.now();
    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) => _getTimer());
  }

  @override
  void dispose() {
    _animationController!.dispose();
    _timer!.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeTransition(opacity: _animationController!,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
        ),),
        SizedBox(width: 10,),
        Text(_timeString!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: Colors.black),)
      ],
    );
  }

  _getTimer() {
    final DateTime now = DateTime.now();
    Duration d = now.difference(currentTime!);
    setState(() {
      _timeString = "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
    });
  }

  /// Format time string
  String twoDigits(int n){
    if(n>= 10){
      return "$n";
    }else{
      return "0"+"$n";
    }
  }
}
