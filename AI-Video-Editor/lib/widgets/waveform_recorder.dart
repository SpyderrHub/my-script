// waveform_recorder.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

/// WaveformRecorder widget: shows live waveform while recording using a provided RecorderController.
/// - start/stop handled by parent; this widget just attaches to the controller to render waveform.
class WaveformRecorder extends StatefulWidget {
  final RecorderController controller;
  final bool isRecording;
  final VoidCallback? onStopPressed;
  final VoidCallback? onStartPressed;

  const WaveformRecorder({
    Key? key,
    required this.controller,
    this.isRecording = false,
    this.onStopPressed,
    this.onStartPressed,
  }) : super(key: key);

  @override
  State<WaveformRecorder> createState() => _WaveformRecorderState();
}

class _WaveformRecorderState extends State<WaveformRecorder> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 140,
          color: Colors.black87,
          child: AudioWaveforms(
            enableGesture: false,
            size: Size(MediaQuery.of(context).size.width, 140),
            recorderController: widget.controller,
            waveStyle: const WaveStyle(
              waveColor: Colors.blueAccent,
              extendWaveform: true,
              showMiddleLine: false,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: widget.isRecording ? null : widget.onStartPressed,
              icon: const Icon(Icons.mic),
              label: const Text('Record'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: widget.isRecording ? widget.onStopPressed : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
              style: ElevatedButton.styleFrom(primary: Colors.redAccent),
            ),
          ],
        ),
      ],
    );
  }
}
