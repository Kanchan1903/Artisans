import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalasathi_mobile/providers/product_wizard_provider.dart';

final kTransparentImage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  group('WhatsApp-like AI Photo Studio Provider Logic', () {
    test('Initial studio state is clean and ready', () {
      final wizard = ProductWizardProvider();
      expect(wizard.hasRemovedBackground, isFalse);
      expect(wizard.isRemovingBackground, isFalse);
      expect(wizard.isComposingBackground, isFalse);
      expect(wizard.cutoutBase64, isNull);
      expect(wizard.currentStudioImageBase64, isNull);
      expect(wizard.selectedBackgroundId, 'transparent');
      expect(wizard.canUndo, isFalse);
      expect(wizard.canRedo, isFalse);
      expect(wizard.showOriginal, isFalse);
    });

    test('Undo, Redo, and Reset operations maintain history accurately', () async {
      final wizard = ProductWizardProvider();
      wizard.addPhoto(kTransparentImage);

      // Simulate background removal result
      await wizard.removeBackground();

      expect(wizard.hasRemovedBackground, isTrue);
      expect(wizard.selectedBackgroundId, 'transparent');
      expect(wizard.canUndo, isFalse);
      expect(wizard.canRedo, isFalse);

      // Select a background
      await wizard.selectBackground('pastel_pink');
      expect(wizard.selectedBackgroundId, 'pastel_pink');
      expect(wizard.canUndo, isTrue);
      expect(wizard.canRedo, isFalse);

      // Select another background
      await wizard.selectBackground('wooden_texture');
      expect(wizard.selectedBackgroundId, 'wooden_texture');
      expect(wizard.canUndo, isTrue);

      // Test Undo
      wizard.undo();
      expect(wizard.canRedo, isTrue);

      // Test Redo
      wizard.redo();
      expect(wizard.canRedo, isFalse);
      expect(wizard.canUndo, isTrue);

      // Test Reset
      wizard.resetStudio();
      expect(wizard.selectedBackgroundId, 'transparent');
      expect(wizard.canUndo, isFalse);
      expect(wizard.canRedo, isFalse);
    });

    test('Original / Edited toggle updates showOriginal state', () {
      final wizard = ProductWizardProvider();
      expect(wizard.showOriginal, isFalse);

      wizard.toggleShowOriginal();
      expect(wizard.showOriginal, isTrue);

      wizard.toggleShowOriginal();
      expect(wizard.showOriginal, isFalse);
    });

    test('Custom background color updates customColor correctly', () async {
      final wizard = ProductWizardProvider();
      wizard.addPhoto(kTransparentImage);
      await wizard.removeBackground();

      const testColor = Color(0xFFE91E63);
      await wizard.selectBackground('custom', customColor: testColor);
      expect(wizard.selectedBackgroundId, 'custom');
      expect(wizard.customColor, testColor);
    });
  });
}
