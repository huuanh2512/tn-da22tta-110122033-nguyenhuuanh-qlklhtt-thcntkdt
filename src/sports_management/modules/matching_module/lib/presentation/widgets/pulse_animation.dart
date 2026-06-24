import 'package:flutter/material.dart';

class PulsingRadarWidget extends StatefulWidget {
  final double size;
  final Color color;

  const PulsingRadarWidget({
    super.key,
    this.size = 200.0,
    this.color = const Color(0xFFFF5600),
  });

  @override
  State<PulsingRadarWidget> createState() => _PulsingRadarWidgetState();
}

class _PulsingRadarWidgetState extends State<PulsingRadarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              _buildPulse(0.0),
              _buildPulse(0.33),
              _buildPulse(0.66),
              // Inner Core Circle
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: const Icon(
                  Icons.online_prediction,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPulse(double delay) {
    final progress = (_controller.value + delay) % 1.0;
    final scale = 1.0 + (progress * 2.5);
    final opacity = 1.0 - progress;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: widget.size / 3.5,
          height: widget.size / 3.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color,
              width: 2.0,
            ),
          ),
        ),
      ),
    );
  }
}
