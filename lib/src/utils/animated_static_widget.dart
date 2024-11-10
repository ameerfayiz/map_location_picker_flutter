import 'package:flutter/material.dart';

class AnimatedStaticWidget extends StatefulWidget {
  final Widget child;

  const AnimatedStaticWidget({super.key, required this.child});

  @override
  State<StatefulWidget> createState() => AnimatedStaticWidgetState(child);
}

class AnimatedStaticWidgetState extends State<AnimatedStaticWidget> with SingleTickerProviderStateMixin {
  AnimatedStaticWidgetState(this.child);

  final Widget child;
  late final AnimationController _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..repeat(reverse: true);
  late final Animation<double> _animation = Tween<double>(
    begin: 0.9,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ),
  );

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _animationController.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0.0, -43),
      child: Transform.scale(
        //alignment: Alignment.bottomCenter,
        origin: const Offset(0.0, 45),
        scale: _animation.value,
        child: child,
      ),
    );
  }
}
