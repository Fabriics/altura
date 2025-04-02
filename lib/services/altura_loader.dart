
import 'package:flutter/material.dart';

class AlturaLoader extends StatefulWidget {
  const AlturaLoader({Key? key}) : super(key: key);

  @override
  State<AlturaLoader> createState() => _AlturaLoaderState();
}

class _AlturaLoaderState extends State<AlturaLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RotationTransition(
        turns: _controller,
        child: Image.asset(
          'assets/logo/altura_logo_loader.png',
          width: 80,
        ),
      ),
    );
  }
}
