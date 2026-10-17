import 'package:flutter/material.dart';
import 'package:kalasathi_mobile/theme/app_theme.dart';

class ImageComparisonSlider extends StatefulWidget {
  final ImageProvider beforeImage;
  final ImageProvider afterImage;

  const ImageComparisonSlider({
    super.key,
    required this.beforeImage,
    required this.afterImage,
  });

  @override
  State<ImageComparisonSlider> createState() => _ImageComparisonSliderState();
}

class _ImageComparisonSliderState extends State<ImageComparisonSlider> {
  double _splitPosition = 0.5; // 0.0 to 1.0

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // After Image (Studio White Background)
                Positioned.fill(
                  child: Image(
                    image: widget.afterImage,
                    fit: BoxFit.cover,
                  ),
                ),
                // Before Image (Clipped)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: width * _splitPosition,
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: width,
                      maxHeight: height,
                      alignment: Alignment.centerLeft,
                      child: Image(
                        image: widget.beforeImage,
                        fit: BoxFit.cover,
                        width: width,
                        height: height,
                      ),
                    ),
                  ),
                ),
                // Divider Line
                Positioned(
                  left: (width * _splitPosition) - 2,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    color: Colors.white,
                  ),
                ),
                // Interactive Handle Knob
                Positioned(
                  left: (width * _splitPosition) - 20,
                  top: (height / 2) - 20,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _splitPosition += details.delta.dx / width;
                        _splitPosition = _splitPosition.clamp(0.05, 0.95);
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.terracotta,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.compare_arrows_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                // Labels
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "BEFORE (मूल फोटो)",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.terracotta,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "AFTER (एआई स्टुडिओ)",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
