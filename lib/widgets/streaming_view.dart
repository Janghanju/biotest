import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';

class StreamingView extends StatelessWidget {
  final ChewieController? chewieController;

  const StreamingView({Key? key, required this.chewieController}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (chewieController == null) {
      return Center(child: CircularProgressIndicator());
    } else {
      return Container(
        height: 200,
        child: Chewie(controller: chewieController!),
      );
    }
  }
}