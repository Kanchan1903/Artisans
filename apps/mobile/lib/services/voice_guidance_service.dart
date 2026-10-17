import 'package:flutter/material.dart';

class VoiceGuidanceService {
  static void speakPrompt(BuildContext context, String message) {
    // Show accessible high-contrast voice guidance sheet with audio waveform indicator
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF262220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE09F3E).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volume_up_rounded,
                    color: Color(0xFFE09F3E),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    "आवाज मार्गदर्शन / Audio Guide",
                    style: TextStyle(
                      color: Color(0xFFE09F3E),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(ctx),
                )
              ],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            // Animated audio wave representation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                9,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 4,
                  height: 12 + ((i * 7) % 24).toDouble(),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE09F3E),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
