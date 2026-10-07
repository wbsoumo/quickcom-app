import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceSearchSheet extends StatefulWidget {
  final Function(String query) onResult;

  const VoiceSearchSheet({Key? key, required this.onResult}) : super(key: key);

  static void show(BuildContext context, {required Function(String query) onResult}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceSearchSheet(onResult: onResult),
    );
  }

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isAvailable = false;
  String _text = 'Listening for your search...';
  String _spokenQuery = '';
  AnimationController? _animController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (mounted) {
            if (status == 'done' || status == 'notListening') {
              setState(() {
                _isListening = false;
              });
              if (_spokenQuery.trim().isNotEmpty) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    Navigator.pop(context);
                    widget.onResult(_spokenQuery.trim());
                  }
                });
              }
            }
          }
        },
        onError: (errorNotification) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _text = 'Could not catch that. Please try again.';
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isAvailable = available;
        });
        if (available) {
          _startListening();
        } else {
          setState(() {
            _text = 'Voice recognition not available on this device';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _text = 'Microphone permission denied or unavailable';
        });
      }
    }
  }

  void _startListening() async {
    if (!_isAvailable) return;
    setState(() {
      _isListening = true;
      _text = 'Say something like "Milk", "Ice Cream", "Biscuits"...';
      _spokenQuery = '';
    });
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _spokenQuery = result.recognizedWords;
            if (_spokenQuery.isNotEmpty) {
              _text = _spokenQuery;
            }
          });
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'en_IN',
      cancelOnError: true,
      listenMode: stt.ListenMode.search,
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  @override
  void dispose() {
    _animController?.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isListening ? 'Listening...' : (_spokenQuery.isNotEmpty ? 'Result' : 'Tap mic to speak'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0XFF0C831F),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _spokenQuery.isNotEmpty ? 22 : 16,
                fontWeight: _spokenQuery.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                color: _spokenQuery.isNotEmpty ? Colors.black87 : Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 36),
          GestureDetector(
            onTap: () {
              if (_isListening) {
                _stopListening();
              } else {
                _startListening();
              }
            },
            child: AnimatedBuilder(
              animation: _animController!,
              builder: (context, child) {
                final double scale = _isListening ? 1.0 + (_animController!.value * 0.15) : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? const Color(0XFF0C831F) : Colors.grey.shade200,
                      boxShadow: _isListening
                          ? [
                              BoxShadow(
                                color: const Color(0XFF0C831F).withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 4,
                              )
                            ]
                          : [],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.white : Colors.black87,
                      size: 36,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          if (_spokenQuery.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0XFF0C831F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onResult(_spokenQuery.trim());
                },
                child: Text(
                  'Search "$_spokenQuery"',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
