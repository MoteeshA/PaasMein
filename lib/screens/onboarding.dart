import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../openai_api_key.dart';

class PaytmColors {
  static const deepNavy = Color(0xFF002970);
  static const paytmBlue = Color(0xFF00BAF2);
  static const skyBlue = Color(0xFF4DD0E1);
  static const iceBlue = Color(0xFFE8F7FC);
  static const paperBlue = Color(0xFFF4FAFD);
  static const gold = Color(0xFFFFC969);
  static const goldDeep = Color(0xFFF5A623);
  static const inkTop = Color(0xFF04152B);
  static const inkBottom = Color(0xFF0A2A4D);
  static const logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [paytmBlue, Color(0xFF0288D1)],
  );
  static const ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [gold, goldDeep],
  );
  static const surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [iceBlue, Colors.white],
  );
}

class _PaytmLogo extends StatelessWidget {
  final double size;
  const _PaytmLogo({this.size = 34});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        'Pay',
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
          color: PaytmColors.deepNavy,
          height: 1,
        ),
      ),
      Text(
        'tm',
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
          color: PaytmColors.paytmBlue,
          height: 1,
        ),
      ),
    ],
  );
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paytm Buddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: PaytmColors.iceBlue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: PaytmColors.paytmBlue,
          primary: PaytmColors.deepNavy,
          secondary: PaytmColors.paytmBlue,
          tertiary: PaytmColors.gold,
          surface: PaytmColors.paperBlue,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: PaytmColors.deepNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      home: const OnboardingScreen(),
    );
  }
}

// ============================================================
//           LANGUAGE MODEL
// ============================================================
enum AppLanguage {
  english('en', 'English', '🇬🇧', 'English'),
  hindi('hi', 'हिन्दी', '🇮🇳', 'Hindi'),
  tamil('ta', 'தமிழ்', '🇮🇳', 'Tamil'),
  telugu('te', 'తెలుగు', '🇮🇳', 'Telugu'),
  bengali('bn', 'বাংলা', '🇮🇳', 'Bengali'),
  marathi('mr', 'मराठी', '🇮🇳', 'Marathi'),
  kannada('kn', 'ಕನ್ನಡ', '🇮🇳', 'Kannada'),
  malayalam('ml', 'മലയാളം', '🇮🇳', 'Malayalam');

  const AppLanguage(this.code, this.nativeName, this.flag, this.englishName);
  final String code;
  final String nativeName;
  final String flag;
  final String englishName;

  String get ttsLocale => switch (this) {
    AppLanguage.english => 'en-IN',
    AppLanguage.hindi => 'hi-IN',
    AppLanguage.tamil => 'ta-IN',
    AppLanguage.telugu => 'te-IN',
    AppLanguage.bengali => 'bn-IN',
    AppLanguage.marathi => 'mr-IN',
    AppLanguage.kannada => 'kn-IN',
    AppLanguage.malayalam => 'ml-IN',
  };

  String get pointAtQr => switch (this) {
    AppLanguage.english => 'Point at a QR code.',
    AppLanguage.hindi => 'क्यूआर कोड की ओर इंगित करें।',
    AppLanguage.tamil => 'QR குறியீட்டை நோக்கி காட்டு.',
    AppLanguage.telugu => 'QR కోడ్ వైపు చూపించండి.',
    AppLanguage.bengali => 'একটি QR কোডে নির্দেশ করুন।',
    AppLanguage.marathi => 'QR कोडकडे निर्देश करा.',
    AppLanguage.kannada => 'QR ಕೋಡ್ ಕಡೆಗೆ ತೋರಿಸಿ.',
    AppLanguage.malayalam => 'QR കോഡിലേക്ക് ചൂണ്ടുക.',
  };

  String get gotIt => switch (this) {
    AppLanguage.english => 'Got it!',
    AppLanguage.hindi => 'मिल गया!',
    AppLanguage.tamil => 'கிடைத்தது!',
    AppLanguage.telugu => 'దొరికింది!',
    AppLanguage.bengali => 'পেয়েছি!',
    AppLanguage.marathi => 'मिळाले!',
    AppLanguage.kannada => 'ಸಿಕ್ಕಿತು!',
    AppLanguage.malayalam => 'കിട്ടി!',
  };

  String get scannerHint => switch (this) {
    AppLanguage.english => 'Align the QR code within the frame',
    AppLanguage.hindi => 'क्यूआर कोड को फ्रेम में रखें',
    AppLanguage.tamil => 'QR குறியீட்டை சட்டகத்திற்குள் வைக்கவும்',
    AppLanguage.telugu => 'QR కోడ్‌ను ఫ్రేమ్‌లో సరిపోల్చండి',
    AppLanguage.bengali => 'QR কোডটি ফ্রেমের মধ্যে রাখুন',
    AppLanguage.marathi => 'QR कोड फ्रेममध्ये ठेवा',
    AppLanguage.kannada => 'QR ಕೋಡ್ ಅನ್ನು ಫ್ರೇಮ್‌ನಲ್ಲಿ ಇರಿಸಿ',
    AppLanguage.malayalam => 'QR കോഡ് ഫ്രെയിമിൽ വയ്ക്കുക',
  };

  String get scanning => switch (this) {
    AppLanguage.english => 'Scanning…',
    AppLanguage.hindi => 'स्कैन हो रहा है…',
    AppLanguage.tamil => 'ஸ்கேன் ஆகிறது…',
    AppLanguage.telugu => 'స్కాన్ అవుతోంది…',
    AppLanguage.bengali => 'স্ক্যান হচ্ছে…',
    AppLanguage.marathi => 'स्कॅन होत आहे…',
    AppLanguage.kannada => 'ಸ್ಕ್ಯಾನ್ ಆಗುತ್ತಿದೆ…',
    AppLanguage.malayalam => 'സ്കാൻ ചെയ്യുന്നു…',
  };

  String get languageQuestion => switch (this) {
    AppLanguage.english => 'Hold the mic and say a language, or tap it!',
    AppLanguage.hindi => '"हिन्दी" बोलिए या टच करें!',
    AppLanguage.tamil => '"தமிழ்" சொல்லுங்க அல்லது தொடுங்க!',
    AppLanguage.telugu => '"తెలుగు" చెప్పండి లేదా తాకండి!',
    AppLanguage.bengali => '"বাংলা" বলুন বা স্পর্শ করুন!',
    AppLanguage.marathi => '"मराठी" म्हणा किंवा टच करा!',
    AppLanguage.kannada => '"ಕನ್ನಡ" ಹೇಳಿ ಅಥವಾ ಸ್ಪರ್ಶಿಸಿ!',
    AppLanguage.malayalam => '"മലയാളം" പറയുക അല്ലെങ്കിൽ തൊടുക!',
  };

  String get ttsName => englishName;

  String get chatGreeting => switch (this) {
    AppLanguage.english => 'Hi! I scanned your QR. What do you sell?',
    AppLanguage.hindi => 'नमस्ते! आपका QR स्कैन हो गया। आप क्या बेचते हैं?',
    AppLanguage.tamil =>
      'வணக்கம்! உங்கள் QR ஸ்கேன் செய்துவிட்டேன். நீங்கள் என்ன விற்கிறீர்கள்?',
    AppLanguage.telugu => 'హాయ్! మీ QR స్కాన్ చేశాను. మీరు ఏమి అమ్ముతారు?',
    AppLanguage.bengali =>
      'হ্যালো! আপনার QR স্ক্যান করেছি। আপনি কী বিক্রি করেন?',
    AppLanguage.marathi => 'नमस्कार! तुमचा QR स्कॅन केला. तुम्ही काय विकता?',
    AppLanguage.kannada =>
      'ನಮಸ್ಕಾರ! ನಿಮ್ಮ QR ಕೋಡ್ ಸ್ಕ್ಯಾನ್ ಆಗಿದೆ. ನೀವು ಏನು ಮಾರುತ್ತೀರಿ?',
    AppLanguage.malayalam =>
      'ഹായ്! നിങ്ങളുടെ QR സ്കാൻ ചെയ്തു. നിങ്ങൾ എന്താണ് വിൽക്കുന്നത്?',
  };
}

// ============================================================
//  VOICE SERVICE
//  - Warm, playful voice with clear, natural pacing
//  - Cheap: caching (same phrase → instant replay, no API hit)
//  - Reports isSpeaking so robot mouth can flap
// ============================================================
class VoiceService {
  static final AudioRecorder _recorder = AudioRecorder();
  static final FlutterTts _deviceTts = FlutterTts();
  static final AudioPlayer _cloudPlayer = AudioPlayer();
  static final Map<String, Uint8List> _speechCache = {};
  static String _voiceFor(AppLanguage language) => switch (language) {
    AppLanguage.kannada => 'marin',
    AppLanguage.hindi => 'nova',
    _ => 'sage',
  };
  static final SpeechToText _speechToText = SpeechToText();
  static bool _speechReady = false;

  static final ValueNotifier<bool> _speaking = ValueNotifier(false);
  static Listenable get speakingListenable => _speaking;
  static bool get isSpeaking => _speaking.value;
  static int _speechGeneration = 0;
  static Future<void> _speechQueue = Future<void>.value();

  static void _setSpeaking(bool value) {
    if (_speaking.value != value) _speaking.value = value;
  }

  /// Play one utterance at a time. A newer screen/request cancels stale speech.
  static Future<void> speak(
    String text, {
    AppLanguage language = AppLanguage.english,
    double speed = 0.78,
    bool cacheToDisk = false,
  }) async {
    final generation = ++_speechGeneration;
    _setSpeaking(false);
    final interrupted = Future.wait([
      _deviceTts.stop().catchError((_) {}),
      _cloudPlayer.stop().catchError((_) {}),
    ]);
    final request = _speechQueue.then((_) async {
      await interrupted;
      if (generation != _speechGeneration) return;
      final cloudPlayed = await _speakWithOpenAi(
        text,
        language,
        generation,
        cacheToDisk: cacheToDisk,
      );
      if (!cloudPlayed && generation == _speechGeneration) {
        await _speakInDeviceLanguage(text, language, generation, speed);
      }
    });
    _speechQueue = request.catchError((Object error) {
      debugPrint('TTS error: $error');
    });
    return request;
  }

  static Future<void> stop() async {
    ++_speechGeneration;
    _setSpeaking(false);
    try {
      await _deviceTts.stop();
    } catch (_) {}
    try {
      await _cloudPlayer.stop();
    } catch (_) {}
    try {
      if (_speechToText.isListening) await _speechToText.stop();
    } catch (_) {}
  }

  static Future<bool> _speakWithOpenAi(
    String text,
    AppLanguage language,
    int generation, {
    required bool cacheToDisk,
  }) async {
    if (kOpenAiKey.isEmpty) return false;
    try {
      final voice = _voiceFor(language);
      final cacheKey = 'gpt-4o-mini-tts:$voice:${language.code}:$text';
      var bytes = _speechCache[cacheKey];
      File? cacheFile;
      if (bytes == null && cacheToDisk) {
        cacheFile = await _speechCacheFile(cacheKey);
        if (await cacheFile.exists()) {
          final saved = await cacheFile.readAsBytes();
          if (saved.isNotEmpty) {
            bytes = saved;
            _speechCache[cacheKey] = saved;
          }
        }
      }
      if (bytes == null) {
        final response = await http
            .post(
              Uri.parse('https://api.openai.com/v1/audio/speech'),
              headers: {
                'Authorization': 'Bearer $kOpenAiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': 'gpt-4o-mini-tts',
                'voice': voice,
                'input': text,
                'instructions':
                    'Speak warmly, naturally, and clearly at a relaxed pace. '
                    'Pronounce the words naturally in the language of the text.',
                'response_format': 'mp3',
              }),
            )
            .timeout(const Duration(seconds: 25));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          debugPrint('OpenAI speech request failed: ${response.statusCode}');
          return false;
        }
        bytes = response.bodyBytes;
        if (cacheToDisk) {
          try {
            cacheFile ??= await _speechCacheFile(cacheKey);
            await cacheFile.writeAsBytes(bytes, flush: true);
          } catch (error) {
            debugPrint('Could not save local speech cache: $error');
          }
        }
        if (_speechCache.length >= 32)
          _speechCache.remove(_speechCache.keys.first);
        _speechCache[cacheKey] = bytes;
      }
      if (generation != _speechGeneration) return false;
      await _cloudPlayer.stop();
      _setSpeaking(true);
      final completed = _cloudPlayer.onPlayerStateChanged.firstWhere(
        (state) =>
            state == PlayerState.completed || state == PlayerState.stopped,
      );
      await _cloudPlayer.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
      await completed.timeout(const Duration(seconds: 45));
      if (generation == _speechGeneration) _setSpeaking(false);
      return generation == _speechGeneration;
    } catch (error) {
      if (generation == _speechGeneration) _setSpeaking(false);
      debugPrint('OpenAI speech error: $error');
      return false;
    }
  }

  static Future<File> _speechCacheFile(String cacheKey) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final cacheDirectory = Directory('${supportDirectory.path}/piku_speech');
    await cacheDirectory.create(recursive: true);
    var hash = 0xcbf29ce484222325;
    for (final unit in cacheKey.codeUnits) {
      hash = ((hash ^ unit) * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return File('${cacheDirectory.path}/${hash.toRadixString(16)}.mp3');
  }

  static Future<String?> startLanguageRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted || !await _recorder.hasPermission()) return null;
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/language_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      return path;
    } catch (error) {
      debugPrint('Language recording start error: $error');
      return null;
    }
  }

  static Future<String?> finishLanguageRecording(String? path) async {
    if (path == null) return null;
    File? file;
    try {
      final stopped = await _recorder.stop();
      if (stopped == null) return null;
      file = File(stopped);
      if (!await file.exists() || await file.length() < 2000) return null;
      return await _transcribeFile(file, null);
    } catch (error) {
      debugPrint('Language recording/transcription error: $error');
      return null;
    } finally {
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  /// Use partial phone-recognition results so we can select the language as
  /// soon as the short phrase is understood instead of waiting for a cloud
  /// transcription round trip.
  static Future<String?> listenForLanguageChoice({
    required bool Function(String) isLanguageMatch,
  }) async {
    try {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) return null;
      if (!_speechReady) {
        _speechReady = await _speechToText.initialize();
      }
      if (!_speechReady) return null;

      final result = Completer<String?>();
      var latestWords = '';
      Timer? safetyTimer;

      void finish(String? words) {
        if (result.isCompleted) return;
        safetyTimer?.cancel();
        result.complete(words);
      }

      safetyTimer = Timer(const Duration(seconds: 7), () {
        if (_speechToText.isListening) unawaited(_speechToText.stop());
        finish(latestWords);
      });

      await _speechToText.listen(
        onResult: (recognition) {
          latestWords = recognition.recognizedWords.trim();
          for (final alternate in recognition.alternates) {
            final words = alternate.recognizedWords.trim();
            if (words.isNotEmpty && isLanguageMatch(words)) {
              finish(words);
              unawaited(_speechToText.stop());
              return;
            }
          }
          if (recognition.finalResult) finish(latestWords);
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 6),
          pauseFor: const Duration(milliseconds: 1100),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
          contextualPhrases: AppLanguage.values
              .expand((language) => [language.englishName, language.nativeName])
              .toList(),
        ),
      );

      return await result.future;
    } catch (error) {
      debugPrint('On-device language recognition error: $error');
      return null;
    }
  }

  static Future<bool> _speakInDeviceLanguage(
    String text,
    AppLanguage language,
    int generation,
    double speed,
  ) async {
    try {
      var selectedLocale = '';
      for (final locale in [language.ttsLocale, language.code]) {
        final available = await _deviceTts.isLanguageAvailable(locale);
        if (generation != _speechGeneration) return false;
        if (available == true) {
          selectedLocale = locale;
          break;
        }
      }
      if (selectedLocale.isEmpty) {
        debugPrint('Device TTS locale unavailable: ${language.ttsLocale}');
        return false;
      }

      final selected = await _deviceTts.setLanguage(selectedLocale);
      if (generation != _speechGeneration || selected != 1) return false;

      final voiceData = await _deviceTts.getVoices;
      if (generation != _speechGeneration) return false;
      if (voiceData is List) {
        final candidates = voiceData
            .whereType<Map>()
            .map((voice) => Map<String, dynamic>.from(voice))
            .where(
              (voice) =>
                  voice['locale']?.toString().toLowerCase().startsWith(
                    language.code.toLowerCase(),
                  ) ??
                  false,
            )
            .toList();
        candidates.sort((a, b) => _voiceQuality(b).compareTo(_voiceQuality(a)));
        if (candidates.isNotEmpty) {
          final selectedVoice = Map<String, String>.fromEntries(
            candidates.first.entries.map(
              (entry) => MapEntry(entry.key, entry.value.toString()),
            ),
          );
          await _deviceTts.setVoice(selectedVoice);
          if (generation != _speechGeneration) return false;
        }
      }

      await _deviceTts.setSpeechRate(speed.clamp(0.5, 1.0).toDouble());
      if (generation != _speechGeneration) return false;
      // Keep the native voice at its natural pitch. Artificial pitch changes
      // can make language-specific pronunciation sound thin or distorted.
      await _deviceTts.setPitch(1.0);
      if (generation != _speechGeneration) return false;
      await _deviceTts.awaitSpeakCompletion(true);
      if (generation != _speechGeneration) return false;
      _setSpeaking(true);
      final result = await _deviceTts.speak(text);
      if (generation == _speechGeneration) _setSpeaking(false);
      return generation == _speechGeneration && (result == true || result == 1);
    } catch (e) {
      if (generation == _speechGeneration) _setSpeaking(false);
      debugPrint('Device TTS error: $e');
      return false;
    }
  }

  static int _voiceQuality(Map<String, dynamic> voice) {
    final rawQuality = voice['quality']?.toString().toLowerCase();
    final quality = switch (rawQuality) {
      'very high' => 5,
      'high' => 4,
      'normal' => 3,
      'low' => 2,
      _ => (int.tryParse(rawQuality ?? '') ?? 0) ~/ 100,
    };
    final networkRequired = voice['network_required']?.toString();
    final networkPenalty = networkRequired == '1' || networkRequired == 'true'
        ? 1
        : 0;
    return quality * 2 - networkPenalty;
  }

  /// Record + Whisper. WAV for reliability on OPPO/ColorOS.
  static Future<String?> recordAndTranscribe({
    int seconds = 4,
    AppLanguage? language,
  }) async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return null;
    if (!await _recorder.hasPermission()) return null;

    await Future.delayed(const Duration(milliseconds: 120));
    return _recordOnce(seconds, language);
  }

  static Future<String?> _recordOnce(int seconds, AppLanguage? language) async {
    File? file;
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: path,
      );

      await Future.delayed(const Duration(milliseconds: 200));
      await Future.delayed(Duration(seconds: seconds));

      final stopped = await _recorder.stop();
      if (stopped == null) return null;

      file = File(stopped);
      if (!await file.exists()) return null;

      final size = await file.length();
      debugPrint('STT: recorded ${size}B');
      if (size < 2000) {
        try {
          await file.delete();
        } catch (_) {}
        return null;
      }

      return await _transcribeFile(file, language);
    } catch (e) {
      debugPrint('STT error: $e');
      return null;
    } finally {
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  static Future<String?> _transcribeFile(
    File file,
    AppLanguage? language,
  ) async {
    try {
      if (kOpenAiKey.isEmpty) return null;
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
      );
      req.headers['Authorization'] = 'Bearer $kOpenAiKey';
      req.fields['model'] = 'whisper-1';
      if (language != null) req.fields['language'] = language.code;
      req.fields['prompt'] = language == null
          ? 'The speaker says one app language name. Candidate names: English, '
                'Hindi, Tamil, Telugu, Bengali, Marathi, Kannada, or Malayalam. '
                'Transcribe only the spoken name.'
          : 'A merchant is speaking ${language.ttsName}. Transcribe their words in that language.';
      req.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return (json['text'] as String?)?.trim();
    } catch (e) {
      debugPrint('STT error: $e');
      return null;
    }
  }

  static Future<String> chat({
    required List<Map<String, String>> messages,
    String systemPrompt = '',
  }) async {
    try {
      if (kOpenAiKey.isEmpty) return '';
      final full = <Map<String, String>>[
        if (systemPrompt.isNotEmpty)
          {'role': 'system', 'content': systemPrompt},
        ...messages,
      ];

      final res = await http
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $kOpenAiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'gpt-4o-mini',
              'messages': full,
              'temperature': 0.8,
              'max_tokens': 200,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode != 200) return '';
      final json = jsonDecode(res.body);
      return (json['choices']?[0]?['message']?['content'] as String?)?.trim() ??
          '';
    } catch (e) {
      debugPrint('Chat error: $e');
      return '';
    }
  }
}

// ============================================================
//           ONBOARDING
// ============================================================
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _jumpController;
  late Animation<double> _jumpOffsetY;
  late Animation<double> _squashX;
  late Animation<double> _squashY;

  late AnimationController _bubbleController;
  late Animation<double> _bubbleScale;
  late Animation<double> _bubbleOpacity;

  late AnimationController _bgController;
  late Animation<double> _bgFade;

  late AnimationController _blinkController;
  late AnimationController _breatheController;
  late AnimationController _bobController;
  late AnimationController _tiltController;
  late AnimationController _waveController;
  late AnimationController _mouthController;
  late AnimationController _antennaController;
  late AnimationController _pupilController;

  late AnimationController _dustController;
  late AnimationController _tapController;
  late AnimationController _auroraController;
  late AnimationController _confettiController;

  String _bubbleText = "Hey! I'm Piku!";
  _RobotExpression _expression = _RobotExpression.happy;
  bool _voicePlayed = false;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _bgFade = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);

    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _jumpOffsetY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 460.0,
          end: -30.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -30.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 45,
      ),
    ]).animate(_jumpController);

    _squashX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 25),
    ]).animate(_jumpController);

    _squashY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 25),
    ]).animate(_jumpController);

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bubbleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bubbleController, curve: Curves.elasticOut),
    );
    _bubbleOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bubbleController, curve: Curves.easeIn));

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scheduleBlink();

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _tiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _mouthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _antennaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pupilController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _dustController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _jumpController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _confettiController.forward(from: 0);
      }
    });

    _runSequence();
    _startExpressionCycle();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 600));
    _jumpController.forward();
    if (!_voicePlayed) {
      _voicePlayed = true;
      unawaited(
        VoiceService.speak(
          "Hey! I'm Piku. Welcome, Paytm merchant!",
          cacheToDisk: true,
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 950));
    _dustController.forward();
    _waveController.repeat(reverse: true);
    if (mounted) setState(() => _expression = _RobotExpression.excited);

    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _expression = _RobotExpression.happy);

    await Future.delayed(const Duration(milliseconds: 200));
    _bgController.forward();
    _bubbleController.forward();
  }

  void _startExpressionCycle() async {
    final moods = [
      _RobotExpression.happy,
      _RobotExpression.thinking,
      _RobotExpression.listening,
      _RobotExpression.happy,
      _RobotExpression.confused,
      _RobotExpression.excited,
      _RobotExpression.surprised,
      _RobotExpression.sleepy,
    ];
    int i = 0;
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 3400));
      if (!mounted) return;
      if (_jumpController.value < 0.95) continue;
      if (VoiceService.isSpeaking) continue;
      i = (i + 1) % moods.length;
      setState(() => _expression = moods[i]);
    }
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future.delayed(
        Duration(milliseconds: 2200 + math.Random().nextInt(2200)),
      );
      if (!mounted) return;
      await _blinkController.forward();
      await _blinkController.reverse();
    }
  }

  Future<void> _onRobotTap() async {
    if (_jumpController.value < 0.95) return;
    _tapController.forward(from: 0);
    await VoiceService.stop();

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const LanguageSelectionScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _jumpController.dispose();
    _bubbleController.dispose();
    _bgController.dispose();
    _blinkController.dispose();
    _breatheController.dispose();
    _bobController.dispose();
    _tiltController.dispose();
    _waveController.dispose();
    _mouthController.dispose();
    _antennaController.dispose();
    _pupilController.dispose();
    _dustController.dispose();
    _tapController.dispose();
    _auroraController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _bgFade,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(Colors.black, PaytmColors.iceBlue, _bgFade.value)!,
                  Color.lerp(
                    Colors.black,
                    PaytmColors.paperBlue,
                    _bgFade.value,
                  )!,
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _auroraController,
                      builder: (context, _) => CustomPaint(
                        painter: _AuroraMeshPainter(t: _auroraController.value),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _auroraController,
                        builder: (context, _) => CustomPaint(
                          painter: _FloatingParticlesPainter(
                            t: _auroraController.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Opacity(
                      opacity: _bgFade.value,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: const Center(child: _PaytmLogo(size: 32)),
                      ),
                    ),
                  ),
                  Center(
                    child: SizedBox(
                      height: 480,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _jumpController,
                          _tapController,
                        ]),
                        builder: (context, child) {
                          final tapT = _tapController.value;
                          final tapHop = math.sin(tapT * math.pi) * -22;
                          final tapSquashX =
                              1 + math.sin(tapT * math.pi) * 0.06;
                          final tapSquashY =
                              1 - math.sin(tapT * math.pi) * 0.06;

                          return Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: 10,
                                child: AnimatedBuilder(
                                  animation: _bubbleController,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _bubbleScale.value,
                                      alignment: Alignment.bottomCenter,
                                      child: Opacity(
                                        opacity: _bubbleOpacity.value,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _SpeechBubble(text: _bubbleText),
                                ),
                              ),
                              Positioned(
                                bottom: 6,
                                child: AnimatedBuilder(
                                  animation: _dustController,
                                  builder: (context, _) {
                                    return _DustPuff(
                                      progress: _dustController.value,
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                child: AnimatedBuilder(
                                  animation: _jumpController,
                                  builder: (context, _) {
                                    final grow =
                                        (1 -
                                        (_jumpOffsetY.value / 460).clamp(0, 1));
                                    return Opacity(
                                      opacity: 0.22 * grow,
                                      child: Container(
                                        width: 150 * grow + 40,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius: BorderRadius.circular(
                                            50,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                bottom: 20,
                                child: GestureDetector(
                                  onTap: _onRobotTap,
                                  behavior: HitTestBehavior.opaque,
                                  child: AnimatedBuilder(
                                    animation: Listenable.merge([
                                      _jumpController,
                                      VoiceService.speakingListenable,
                                      _breatheController,
                                      _bobController,
                                      _tiltController,
                                      _blinkController,
                                      _waveController,
                                      _mouthController,
                                      _antennaController,
                                      _pupilController,
                                    ]),
                                    builder: (context, _) {
                                      final onGround =
                                          _jumpController.value >= 0.95;
                                      final bob = onGround
                                          ? math.sin(
                                                  _bobController.value *
                                                      math.pi *
                                                      2,
                                                ) *
                                                4
                                          : 0.0;
                                      final tilt = onGround
                                          ? math.sin(
                                                  _tiltController.value *
                                                      math.pi *
                                                      2,
                                                ) *
                                                0.05
                                          : 0.0;
                                      final breathe =
                                          1 +
                                          math.sin(
                                                _breatheController.value *
                                                    math.pi *
                                                    2,
                                              ) *
                                              0.02;
                                      final isSpeaking =
                                          VoiceService.isSpeaking;
                                      final liveExpression = isSpeaking
                                          ? _RobotExpression.speaking
                                          : _expression;
                                      final mouthFlap = isSpeaking
                                          ? _speechMouthOpening(
                                              _mouthController.value,
                                            )
                                          : 0.0;

                                      return Transform.translate(
                                        offset: Offset(
                                          0,
                                          _jumpOffsetY.value + bob + tapHop,
                                        ),
                                        child: Transform.scale(
                                          scaleX:
                                              _squashX.value *
                                              tapSquashX *
                                              breathe,
                                          scaleY:
                                              _squashY.value *
                                              tapSquashY *
                                              breathe,
                                          alignment: Alignment.bottomCenter,
                                          child: Transform.rotate(
                                            angle: tilt,
                                            alignment: Alignment.bottomCenter,
                                            child: _PremiumRobot(
                                              blink: _blinkController.value,
                                              wave: _waveController.value,
                                              showWave: onGround,
                                              antennaPulse:
                                                  _antennaController.value,
                                              pupil: _pupilController.value,
                                              expression: liveExpression,
                                              mouthFlap: mouthFlap,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _confettiController,
                        builder: (context, _) => CustomPaint(
                          painter: _ConfettiBurstPainter(
                            progress: _confettiController.value,
                            origin: Offset(
                              MediaQuery.sizeOf(context).width / 2,
                              MediaQuery.sizeOf(context).height * 0.72,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
//   ONBOARDING UPGRADE HELPERS — aurora, particles, confetti
// ============================================================
class _AuroraMeshPainter extends CustomPainter {
  final double t;
  const _AuroraMeshPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final blobs = [
      (
        PaytmColors.paytmBlue,
        0.25 + 0.08 * math.sin(t * math.pi * 2),
        0.28 + 0.06 * math.cos(t * math.pi * 2 + 1.1),
        0.55,
        0.20,
      ),
      (
        PaytmColors.gold,
        0.78 + 0.07 * math.cos(t * math.pi * 2 + 2.3),
        0.36 + 0.08 * math.sin(t * math.pi * 2 + 0.4),
        0.48,
        0.16,
      ),
      (
        PaytmColors.skyBlue,
        0.5 + 0.10 * math.sin(t * math.pi * 2 + 1.7),
        0.72 + 0.06 * math.cos(t * math.pi * 2 + 3.0),
        0.62,
        0.18,
      ),
    ];
    for (final blob in blobs) {
      final center = Offset(blob.$2 * size.width, blob.$3 * size.height);
      final radius = blob.$4 * math.min(size.width, size.height);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [blob.$1.withOpacity(blob.$5), blob.$1.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraMeshPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _FloatingParticlesPainter extends CustomPainter {
  final double t;
  const _FloatingParticlesPainter({required this.t});
  static const int _count = 18;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _count; i++) {
      final seed = i / _count;
      final phase = (t + seed) % 1.0;
      final y = size.height * (1 - phase);
      final sway =
          math.sin(phase * math.pi * 2 + seed * 6.28) * 26 +
          (i.isEven ? 18.0 : -18.0);
      final x = size.width * (0.08 + 0.84 * _hash(i)) + sway;
      final opacity =
          math.sin(phase * math.pi).clamp(0.0, 1.0) *
          (0.25 + 0.45 * _hash(i + 7));
      final radius = 1.5 + 2.8 * _hash(i + 3);
      final color = switch (i % 3) {
        0 => const Color(0xFFFFD17A),
        1 => const Color(0xFF00BAF2),
        _ => const Color(0xFF7FE7F5),
      };
      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  double _hash(int n) {
    final value = math.sin(n * 12.9898) * 43758.5453;
    return value - value.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _FloatingParticlesPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _ConfettiBurstPainter extends CustomPainter {
  final double progress;
  final Offset origin;
  const _ConfettiBurstPainter({required this.progress, required this.origin});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);
    const colors = [
      Color(0xFF00BAF2),
      Color(0xFFFFD17A),
      Color(0xFF7FE7F5),
      Color(0xFFFF9DB0),
    ];
    for (var i = 0; i < 22; i++) {
      final angle = (i / 22) * math.pi * 2 + (i.isEven ? 0.15 : 0);
      final distance = eased * (90 + (i % 5) * 14);
      final position =
          origin + Offset(math.cos(angle), math.sin(angle)) * distance;
      final paint = Paint()
        ..color = colors[i % colors.length].withOpacity(0.9 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(
        position,
        (3.5 - progress * 1.5).clamp(1.5, 3.5).toDouble(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiBurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.origin != origin;
}

// ============================================================
//           LANGUAGE SELECTION — animated robot + auto loop
// ============================================================
class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _breatheController;
  late AnimationController _bobController;
  late AnimationController _tiltController;
  late AnimationController _blinkController;
  late AnimationController _waveController;
  late AnimationController _antennaController;
  late AnimationController _pupilController;
  late AnimationController _scanLookController;
  late AnimationController _mouthController;
  late AnimationController _entranceController;
  late AnimationController _micPulseController;
  late AnimationController _transitionOutController;

  _RobotExpression _expression = _RobotExpression.listening;
  AppLanguage _selected = AppLanguage.english;
  String _statusText = 'Selected: English';
  bool _busy = false;
  bool _recordingLanguage = false;
  String? _languageRecordingPath;
  Future<String?>? _languageRecordingStart;
  bool _languageHoldActive = false;
  int _failedAttempts = 0;
  bool _loopActive = false;
  bool _transitioning = false;
  final GlobalKey _languageStackKey = GlobalKey();
  final Map<AppLanguage, GlobalKey> _languageKeys = {
    for (final language in AppLanguage.values) language: GlobalKey(),
  };
  Offset? _transitionOrigin;
  bool _isTransitioningOut = false;

  @override
  void initState() {
    super.initState();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scheduleBlink();

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _tiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _antennaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pupilController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _scanLookController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // NEW: fast mouth flap (tied to voice.isSpeaking below)
    _mouthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _transitionOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // NEW: expression cycle so robot animates even when idle
    _startExpressionCycle();

    _statusText = 'Hold the mic and say a language';
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) {
        unawaited(
          VoiceService.speak(
            AppLanguage.english.languageQuestion,
            cacheToDisk: true,
          ),
        );
      }
    });
  }

  Future<void> _beginLanguageCapture() async {
    if (_busy || !mounted) return;
    _languageHoldActive = true;
    setState(() {
      _busy = true;
      _recordingLanguage = true;
      _statusText = 'Listening… release when you finish';
      _expression = _RobotExpression.listening;
    });
    _languageRecordingStart = VoiceService.startLanguageRecording();
    _languageRecordingPath = await _languageRecordingStart;
    if (!mounted) return;
    if (!_languageHoldActive && _languageRecordingPath != null) {
      await _endLanguageCapture();
      return;
    }
    if (_languageRecordingPath == null) {
      setState(() {
        _busy = false;
        _recordingLanguage = false;
        _statusText = 'Microphone unavailable — tap a language below';
        _expression = _RobotExpression.confused;
      });
    }
  }

  Future<void> _endLanguageCapture() async {
    if (!_recordingLanguage) return;
    _languageHoldActive = false;
    setState(() {
      _recordingLanguage = false;
      _statusText = 'Recognizing language…';
    });
    final path = await (_languageRecordingStart ?? Future.value(null));
    _languageRecordingPath = path;
    final text = await VoiceService.finishLanguageRecording(path);
    _languageRecordingPath = null;
    _languageRecordingStart = null;
    if (!mounted) return;
    final language = text == null ? null : _matchLanguage(text);
    if (language == null) {
      setState(() {
        _busy = false;
        _statusText = text == null
            ? 'Couldn’t recognize that — hold the mic and try again'
            : 'Heard “$text”. Try again or tap a language below.';
        _expression = _RobotExpression.confused;
      });
      return;
    }
    setState(() {
      _selected = language;
      _statusText = 'Selected: ${language.nativeName}';
      _expression = _RobotExpression.excited;
    });
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) _continueToScanner(language);
  }

  void _startExpressionCycle() async {
    final moods = [
      _RobotExpression.listening,
      _RobotExpression.thinking,
      _RobotExpression.listening,
      _RobotExpression.happy,
      _RobotExpression.listening,
    ];
    int i = 0;
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 2400));
      if (!mounted) return;
      // Only change expression when we're NOT listening to a phrase
      if (!VoiceService.isSpeaking) {
        i = (i + 1) % moods.length;
        setState(() => _expression = moods[i]);
      }
    }
  }

  Future<void> _startLoop() async {
    if (!mounted || _loopActive) return;
    _loopActive = true;
    await _loopStep();
    _loopActive = false;
  }

  Future<void> _loopStep() async {
    if (!mounted) return;

    setState(() {
      _statusText = 'Listening… Say one language name';
      _expression = _RobotExpression.listening;
    });
    final text = await VoiceService.listenForLanguageChoice(
      isLanguageMatch: (words) => _matchLanguage(words) != null,
    );
    if (!mounted) return;

    if (text == null || text.isEmpty) {
      _failedAttempts++;
      if (_failedAttempts >= 2) {
        setState(() {
          _statusText = 'Tap a language below';
          _expression = _RobotExpression.confused;
        });
        return;
      }
      setState(() {
        _statusText = 'Couldn\'t hear — try again';
        _expression = _RobotExpression.confused;
      });
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) await _loopStep();
      return;
    }

    final matched = _matchLanguage(text);
    if (matched != null) {
      _failedAttempts = 0;
      setState(() {
        _selected = matched;
        _statusText = 'Selected: ${matched.nativeName}';
        _expression = _RobotExpression.excited;
      });
      await VoiceService.stop();
      await Future.delayed(const Duration(milliseconds: 120));
      if (mounted) _continueToScanner(matched);
      return;
    }

    _failedAttempts++;
    if (_failedAttempts >= 2) {
      setState(() {
        _statusText = 'Heard "$text". Tap your language below.';
        _expression = _RobotExpression.confused;
      });
      return;
    }

    setState(() {
      _statusText = 'Heard "$text". Say it once more, or tap below.';
      _expression = _RobotExpression.confused;
    });
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) await _loopStep();
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future.delayed(
        Duration(milliseconds: 2200 + math.Random().nextInt(2200)),
      );
      if (!mounted) return;
      await _blinkController.forward();
      await _blinkController.reverse();
    }
  }

  AppLanguage? _matchLanguage(String raw) {
    String normalize(String value) {
      final result = StringBuffer();
      for (final rune in value.toLowerCase().runes) {
        final isAsciiLetter = rune >= 0x61 && rune <= 0x7a;
        final isDigit = rune >= 0x30 && rune <= 0x39;
        final isIndianScript = rune >= 0x0900 && rune <= 0x0d7f;
        if (isAsciiLetter || isDigit || isIndianScript) {
          result.writeCharCode(rune);
        }
      }
      return result.toString();
    }

    final t = normalize(raw);
    const aliases = <AppLanguage, List<String>>{
      AppLanguage.english: ['english', 'ಇಂಗ್ಲಿಷ್'],
      AppLanguage.hindi: [
        'hindi',
        'hindee',
        'hindhi',
        'हिंदी',
        'हिन्दी',
        'ಹಿಂದಿ',
      ],
      AppLanguage.tamil: ['tamil', 'thamizh', 'tamizh', 'தமிழ்', 'ತಮಿಳು'],
      AppLanguage.telugu: ['telugu', 'తెలుగు', 'ತೆಲುಗು'],
      AppLanguage.bengali: [
        'bengali',
        'bangla',
        'বাংলা',
        'বাঙালি',
        'ಬೆಂಗಾಲಿ',
        'ಬಾಂಗ್ಲಾ',
      ],
      AppLanguage.marathi: ['marathi', 'मराठी', 'ಮರಾಠಿ'],
      AppLanguage.kannada: [
        'kannada',
        'kanada',
        'kannad',
        'ಕನ್ನಡ',
        'ಕನ್ನಡಾ',
        'कन्नड़',
        'कन्नडा',
        'కన్నడ',
        'కన్నడా',
        'கன்னடா',
        'கன்னட',
        'கன்னடம்',
      ],
      AppLanguage.malayalam: ['malayalam', 'malayāḷam', 'മലയാളം', 'ಮಲಯಾಳಂ'],
    };
    for (final lang in AppLanguage.values) {
      final names = <String>[
        lang.englishName,
        lang.nativeName,
        ...?aliases[lang],
      ];
      final normalizedNames = names
          .map(normalize)
          .where((name) => name.isNotEmpty);
      if (normalizedNames.any((name) => t == name || t.contains(name))) {
        return lang;
      }
    }
    return null;
  }

  Future<void> _continueToScanner(AppLanguage lang) async {
    if (!mounted || _transitioning) return;
    _transitioning = true;
    final tile =
        _languageKeys[lang]?.currentContext?.findRenderObject() as RenderBox?;
    final stack =
        _languageStackKey.currentContext?.findRenderObject() as RenderBox?;
    setState(() => _isTransitioningOut = true);
    if (tile != null && stack != null) {
      _transitionOrigin = stack.globalToLocal(
        tile.localToGlobal(tile.size.center(Offset.zero)),
      );
    } else {
      _transitionOrigin = Offset(
        MediaQuery.sizeOf(context).width / 2,
        MediaQuery.sizeOf(context).height / 2,
      );
    }
    await _transitionOutController.forward(from: 0);
    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => RoleSelectionScreen(language: lang),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _transitionOutController.reset();
        setState(() => _isTransitioningOut = false);
        _transitioning = false;
      }
    });
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _bobController.dispose();
    _tiltController.dispose();
    _blinkController.dispose();
    _waveController.dispose();
    _antennaController.dispose();
    _pupilController.dispose();
    _scanLookController.dispose();
    _mouthController.dispose();
    _entranceController.dispose();
    _micPulseController.dispose();
    _transitionOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 650;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final entranceScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );

    return Scaffold(
      backgroundColor: PaytmColors.inkTop,
      body: Stack(
        key: _languageStackKey,
        children: [
          const Positioned.fill(child: _TreacleBackdrop()),
          Positioned(
            top: MediaQuery.viewPaddingOf(context).top + 10,
            left: 16,
            child: _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 70, 20, 0),
              child: Column(
                children: [
                  FadeTransition(
                    opacity: _entranceController,
                    child: const Text(
                      'Choose your language',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!compact)
                    SizedBox(
                      height: 170,
                      child: FadeTransition(
                        opacity: _entranceController,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _breatheController,
                            _bobController,
                            _tiltController,
                            _blinkController,
                            _waveController,
                            _antennaController,
                            _pupilController,
                            _scanLookController,
                            _mouthController,
                            VoiceService.speakingListenable,
                          ]),
                          builder: (context, _) {
                            final bob =
                                math.sin(_bobController.value * math.pi * 2) *
                                4;
                            final tilt =
                                math.sin(_tiltController.value * math.pi * 2) *
                                0.04;
                            final breathe =
                                1 +
                                math.sin(
                                      _breatheController.value * math.pi * 2,
                                    ) *
                                    0.02;
                            final isSpeaking = VoiceService.isSpeaking;
                            final liveExpr = isSpeaking
                                ? _RobotExpression.speaking
                                : _expression;
                            final mouthFlap = isSpeaking
                                ? _speechMouthOpening(_mouthController.value)
                                : 0.0;
                            return Transform.translate(
                              offset: Offset(0, bob),
                              child: Transform.scale(
                                scale: breathe * 0.65,
                                alignment: Alignment.topCenter,
                                child: Transform.rotate(
                                  angle: tilt,
                                  child: _PremiumRobot(
                                    blink: _blinkController.value,
                                    wave: _waveController.value,
                                    showWave: true,
                                    antennaPulse: _antennaController.value,
                                    pupil: _pupilController.value,
                                    expression: liveExpr,
                                    mouthFlap: mouthFlap,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: Colors.white.withOpacity(0.05)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'LANGUAGES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withOpacity(0.3),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: Colors.white.withOpacity(0.05)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.only(bottom: 190),
                      physics: const BouncingScrollPhysics(),
                      itemCount: AppLanguage.values.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: compact ? 2.8 : 2.4,
                      ),
                      itemBuilder: (context, index) {
                        final lang = AppLanguage.values[index];
                        final delay = index * 0.05;
                        final animation = CurvedAnimation(
                          parent: _entranceController,
                          curve: Interval(delay, 1, curve: Curves.easeOutCubic),
                        );
                        return Container(
                          key: _languageKeys[lang],
                          child: FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.3),
                                end: Offset.zero,
                              ).animate(animation),
                              child: _LanguageTile(
                                lang: lang,
                                selected: _selected == lang,
                                compact: compact,
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _selected = lang;
                                    _statusText =
                                        'Selected: ${lang.nativeName}';
                                    _expression = _RobotExpression.happy;
                                  });
                                },
                                onDoubleTap: () => _continueToScanner(lang),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24 + bottomInset,
            child: Center(
              child: ScaleTransition(
                scale: entranceScale,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C2340).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                      BoxShadow(
                        color: PaytmColors.paytmBlue.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: _statusText.startsWith('Selected:')
                            ? Padding(
                                padding: const EdgeInsets.only(
                                  top: 2,
                                  bottom: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: PaytmColors.paytmBlue,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_selected.nativeName} selected',
                                      style: const TextStyle(
                                        color: PaytmColors.paytmBlue,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onLongPressStart: (_) => _beginLanguageCapture(),
                            onLongPressEnd: (_) => _endLanguageCapture(),
                            child: AnimatedBuilder(
                              animation: _micPulseController,
                              builder: (context, child) {
                                final pulse =
                                    1 + _micPulseController.value * 0.05;
                                return Transform.scale(
                                  scale: _recordingLanguage ? pulse : 1,
                                  child: child,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 140,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: _recordingLanguage
                                      ? PaytmColors.gold
                                      : Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: _recordingLanguage
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.1),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _recordingLanguage
                                          ? Icons.mic_rounded
                                          : Icons.mic_none_rounded,
                                      color: _recordingLanguage
                                          ? PaytmColors.deepNavy
                                          : PaytmColors.paytmBlue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _recordingLanguage
                                          ? 'Listening…'
                                          : 'Say it',
                                      style: TextStyle(
                                        color: _recordingLanguage
                                            ? PaytmColors.deepNavy
                                            : Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _transitioning
                                ? null
                                : () => _continueToScanner(_selected),
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                gradient: PaytmColors.ctaGradient,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: PaytmColors.gold.withOpacity(0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Scan',
                                    style: TextStyle(
                                      color: PaytmColors.deepNavy,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: PaytmColors.deepNavy,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isTransitioningOut && _transitionOrigin != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _transitionOutController,
                  builder: (context, _) {
                    final t = Curves.easeInOutCubic.transform(
                      _transitionOutController.value,
                    );
                    final scale = 0.1 + t * 30.0;
                    final opacity = 1.0 - t;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            color: PaytmColors.inkTop.withOpacity(t * 0.7),
                          ),
                        ),
                        Positioned(
                          left: _transitionOrigin!.dx,
                          top: _transitionOrigin!.dy,
                          child: Transform.translate(
                            offset: const Offset(-150, -150),
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 300,
                                height: 300,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      PaytmColors.paytmBlue.withOpacity(
                                        opacity,
                                      ),
                                      PaytmColors.gold.withOpacity(
                                        opacity * 0.8,
                                      ),
                                      Colors.transparent,
                                    ],
                                    stops: const [0, 0.4, 1],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: _transitionOrigin!.dx,
                          top: _transitionOrigin!.dy,
                          child: Transform.translate(
                            offset: const Offset(-150, -150),
                            child: Transform.scale(
                              scale: scale * 1.2,
                              child: Container(
                                width: 300,
                                height: 300,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: PaytmColors.gold.withOpacity(
                                      opacity * 0.5,
                                    ),
                                    width: 8 * (1 - t) + 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: PaytmColors.gold.withOpacity(
                                        opacity * 0.6,
                                      ),
                                      blurRadius: 40,
                                      spreadRadius: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TreacleBackdrop extends StatelessWidget {
  const _TreacleBackdrop();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PaytmColors.inkTop,
              PaytmColors.inkBottom,
              PaytmColors.inkTop,
            ],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SizedBox.expand(),
      ),
      Positioned(
        top: -140,
        right: -90,
        child: _AmbientOrb(
          size: 320,
          color: PaytmColors.paytmBlue.withOpacity(0.28),
        ),
      ),
      Positioned(
        bottom: -120,
        left: -100,
        child: _AmbientOrb(
          size: 300,
          color: PaytmColors.gold.withOpacity(0.16),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  Colors.transparent,
                  PaytmColors.inkTop.withOpacity(0.55),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ],
  );
}

class _AmbientOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _AmbientOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
    ),
  );
}

class _LanguageTile extends StatelessWidget {
  final AppLanguage lang;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final bool compact;

  const _LanguageTile({
    required this.lang,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1FC8EF), Color(0xFF0078B8)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.03),
                  ],
                ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? PaytmColors.gold : Colors.white.withOpacity(0.08),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: PaytmColors.paytmBlue.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: compact ? 32 : 36,
              height: compact ? 32 : 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Colors.white : const Color(0xFFFFE8C8),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.4),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
              ),
              child: Text(
                lang.flag,
                style: TextStyle(fontSize: compact ? 16 : 18),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.nativeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 14 : 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang.englishName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white.withOpacity(0.85)
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: selected
                  ? const Icon(
                      Icons.check_circle_rounded,
                      key: ValueKey('check'),
                      color: PaytmColors.gold,
                      size: 20,
                    )
                  : const SizedBox(width: 20, key: ValueKey('empty')),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//           QR SCANNER — MODERN PREMIUM UPGRADE
// ============================================================
class QrScannerScreen extends StatefulWidget {
  final AppLanguage language;
  const QrScannerScreen({super.key, required this.language});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with TickerProviderStateMixin {
  final MobileScannerController _scanController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  late AnimationController _breatheController;
  late AnimationController _blinkController;
  late AnimationController _antennaController;
  late AnimationController _pupilController;

  late AnimationController _scanPulseController;
  late AnimationController _scanMouthController;

  // NEW: modern scan-line + shimmer + fade-in entrance
  late AnimationController _scanLineController;
  late AnimationController _shimmerController;
  late AnimationController _entranceController;
  late AnimationController _successController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  _RobotExpression _expression = _RobotExpression.listening;
  bool _handled = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scheduleBlink();

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _antennaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pupilController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _scanPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scanMouthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // NEW: laser scan line sweeps up/down inside the frame
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // NEW: shimmer sweep across the glass panel
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    // NEW: entrance fade + slide
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entranceFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    _entranceController.forward();

    VoiceService.speak(
      widget.language.pointAtQr,
      language: widget.language,
      cacheToDisk: true,
    );
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future.delayed(
        Duration(milliseconds: 2200 + math.Random().nextInt(2200)),
      );
      if (!mounted) return;
      await _blinkController.forward();
      await _blinkController.reverse();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _handled = true;
    HapticFeedback.heavyImpact();

    final publishedCard = _tryParsePublishedCard(raw);
    if (publishedCard != null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => MerchantLoginScreen(
            language: widget.language,
            pendingShopData: publishedCard,
            rawQr: raw,
          ),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
            child: child,
          ),
        ),
      );
      return;
    }

    _scanPulseController.stop();
    _scanLineController.stop();
    setState(() => _expression = _RobotExpression.excited);

    await _successController.forward(from: 0);

    await VoiceService.speak(
      widget.language.gotIt,
      language: widget.language,
      cacheToDisk: true,
    );
    if (!mounted) return;

    final merchantName = _extractMerchantName(raw);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => MerchantCardFlow(
          language: widget.language,
          merchantName: merchantName,
          rawQr: raw,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  Map<String, String>? _tryParsePublishedCard(String raw) {
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is! Map || decoded['type'] != 'piku_store') return null;
      return {
        'id': (decoded['id'] ?? '').toString(),
        'business_name': (decoded['name'] ?? '').toString(),
        'business_type': (decoded['category'] ?? '').toString(),
        'items': (decoded['items'] ?? '').toString(),
        'specialty': (decoded['specialty'] ?? '').toString(),
        'hours': (decoded['hours'] ?? '').toString(),
        'location': (decoded['location'] ?? '').toString(),
        'phone': (decoded['phone'] ?? '').toString(),
        'extras': (decoded['extras'] ?? '').toString(),
      };
    } catch (_) {
      return null;
    }
  }

  String _extractMerchantName(String raw) {
    try {
      final lower = raw.toLowerCase();
      if (lower.startsWith('upi://')) {
        final q = Uri.tryParse(raw)?.queryParameters ?? {};
        final pn = q['pn'];
        if (pn != null && pn.isNotEmpty) return Uri.decodeComponent(pn);
        final pa = q['pa'];
        if (pa != null && pa.isNotEmpty) return pa.split('@').first;
      }
      if (raw.trim().startsWith('{')) {
        final json = jsonDecode(raw);
        final name = json['name'] ?? json['merchant'] ?? json['pn'];
        if (name is String && name.isNotEmpty) return name;
      }
      if (lower.startsWith('paasmein://')) {
        final u = Uri.tryParse(raw);
        if (u != null && u.pathSegments.isNotEmpty) {
          return u.pathSegments.last;
        }
      }
    } catch (_) {}
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 40) return cleaned;
    return cleaned.substring(0, 40);
  }

  @override
  void dispose() {
    _scanController.dispose();
    _breatheController.dispose();
    _blinkController.dispose();
    _antennaController.dispose();
    _pupilController.dispose();
    _scanPulseController.dispose();
    _scanMouthController.dispose();
    _scanLineController.dispose();
    _shimmerController.dispose();
    _entranceController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeSize = Size(
      MediaQuery.sizeOf(context).width,
      MediaQuery.sizeOf(context).height -
          MediaQuery.viewPaddingOf(context).vertical,
    );
    final frame = _ModernScannerOverlayPainter.frameFor(safeSize);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FadeTransition(
          opacity: _entranceFade,
          child: SlideTransition(
            position: _entranceSlide,
            child: Stack(
              children: [
                // ── Camera feed ──────────────────────────────────
                Positioned.fill(
                  child: MobileScanner(
                    controller: _scanController,
                    onDetect: _onDetect,
                  ),
                ),

                // ── Dark vignette + gradient frame + scan line ───
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _scanLineController,
                        _scanPulseController,
                        _successController,
                      ]),
                      builder: (context, _) => CustomPaint(
                        painter: _ModernScannerOverlayPainter(
                          scanLineProgress: _scanLineController.value,
                          pulse: _scanPulseController.value,
                          successProgress: _successController.value,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Top bar (back / torch / flip) ────────────────
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () {
                          _scanPulseController.stop();
                          _scanMouthController.stop();
                          _scanLineController.stop();
                          VoiceService.stop();
                          Navigator.of(context).pop();
                        },
                      ),
                      Row(
                        children: [
                          _GlassIconButton(
                            icon: _torchOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            active: _torchOn,
                            onTap: () {
                              _scanController.toggleTorch();
                              setState(() => _torchOn = !_torchOn);
                            },
                          ),
                          const SizedBox(width: 10),
                          _GlassIconButton(
                            icon: Icons.flip_camera_ios_rounded,
                            onTap: () => _scanController.switchCamera(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Robot mascot ─────────────────────────────────
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _breatheController,
                        _blinkController,
                        _antennaController,
                        _pupilController,
                        _scanMouthController,
                        VoiceService.speakingListenable,
                      ]),
                      builder: (context, _) {
                        final isSpeaking = VoiceService.isSpeaking;
                        final mouthFlap = isSpeaking
                            ? _speechMouthOpening(_scanMouthController.value)
                            : 0.0;
                        final breathe =
                            1 +
                            math.sin(_breatheController.value * math.pi * 2) *
                                0.02;
                        return Transform.scale(
                          scale: breathe * 0.58,
                          alignment: Alignment.topCenter,
                          child: _PremiumRobot(
                            blink: _blinkController.value,
                            wave: 0,
                            showWave: false,
                            antennaPulse: _antennaController.value,
                            pupil: _pupilController.value,
                            expression: isSpeaking
                                ? _RobotExpression.speaking
                                : _expression,
                            mouthFlap: mouthFlap,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── Scanning / success status chip ───────────
                Positioned(
                  top: math.max(8.0, frame.top - 40),
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _scanMouthController,
                          _successController,
                        ]),
                        builder: (context, _) {
                          final isSuccess = _successController.value > 0;
                          final pulse =
                              0.6 +
                              0.4 *
                                  math
                                      .sin(
                                        _scanMouthController.value *
                                            math.pi *
                                            2,
                                      )
                                      .abs();
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSuccess
                                  ? PaytmColors.gold.withOpacity(0.9)
                                  : Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: isSuccess
                                    ? Colors.white
                                    : PaytmColors.paytmBlue.withOpacity(pulse),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isSuccess
                                              ? PaytmColors.gold
                                              : PaytmColors.paytmBlue)
                                          .withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSuccess)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: PaytmColors.deepNavy,
                                    size: 18,
                                  )
                                else
                                  _PulsingDot(pulse: pulse),
                                const SizedBox(width: 9),
                                Text(
                                  isSuccess
                                      ? 'QR Detected!'
                                      : widget.language.scanning,
                                  style: TextStyle(
                                    color: isSuccess
                                        ? PaytmColors.deepNavy
                                        : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // ── Minimal floating scan hint ────────────────────
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 32,
                  child: IgnorePointer(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width - 36,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.52),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: PaytmColors.paytmBlue,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  widget.language.scannerHint,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  NEW WIDGETS
// ────────────────────────────────────────────────────────────

/// A frosted-glass circular icon button.
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF00BAF2).withOpacity(0.9)
                : Colors.white.withOpacity(0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? const Color(0xFFFFD17A)
                  : Colors.white.withOpacity(0.28),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: active
                    ? const Color(0xFF00BAF2).withOpacity(0.45)
                    : Colors.black.withOpacity(0.22),
                blurRadius: active ? 16 : 10,
                spreadRadius: active ? 2 : 0,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// A small pulsing dot used inside the scanning chip.
class _PulsingDot extends StatelessWidget {
  final double pulse;
  const _PulsingDot({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withOpacity(pulse),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.9 * pulse),
            blurRadius: 8,
            spreadRadius: 1.5,
          ),
        ],
      ),
    );
  }
}

/// Wraps a child with a moving diagonal shimmer highlight.
class _ShimmerCard extends StatelessWidget {
  final double progress;
  final Widget child;
  const _ShimmerCard({required this.progress, required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) {
        final dx = -rect.width + progress * rect.width * 2.4;
        return LinearGradient(
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.16),
            Colors.white.withOpacity(0.0),
          ],
          stops: const [0.35, 0.5, 0.65],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          transform: _SlideGradientTransform(dx),
        ).createShader(rect);
      },
      child: child,
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double dx;
  const _SlideGradientTransform(this.dx);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0, 0);
  }
}

// ────────────────────────────────────────────────────────────
//  MODERN OVERLAY PAINTER (frame, corners, scan line, vignette)
// ────────────────────────────────────────────────────────────
class _ModernScannerOverlayPainter extends CustomPainter {
  final double scanLineProgress;
  final double pulse;
  final double successProgress;

  const _ModernScannerOverlayPainter({
    required this.scanLineProgress,
    required this.pulse,
    required this.successProgress,
  });

  static Rect frameFor(Size size) => Rect.fromCenter(
    center: Offset(size.width / 2, size.height * 0.52),
    width: 280,
    height: 280,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = frameFor(size);
    final frame = RRect.fromRectAndRadius(rect, const Radius.circular(36));
    final overlay = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(frame)
      ..fillType = PathFillType.evenOdd;
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1,
        colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.85)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(overlay, vignette);

    final isSuccess = successProgress > 0;
    final color = isSuccess ? PaytmColors.gold : PaytmColors.paytmBlue;
    final aura = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawRRect(frame, aura);

    _paintDashedBorder(canvas, rect);
    _paintModernCorners(canvas, rect, color);
    if (isSuccess) {
      _paintSuccessBurst(canvas, rect);
    } else {
      _paintScanLine(canvas, rect);
    }
  }

  void _paintDashedBorder(Canvas canvas, Rect rect) {
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(36)));
    final metric = outline.computeMetrics().first;
    final dashPaint = Paint()
      ..color = PaytmColors.paytmBlue.withOpacity(0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    const dashLength = 9.0;
    const gap = 8.0;
    final phase = pulse * gap;
    for (double d = -phase; d < metric.length; d += dashLength + gap) {
      final start = d.clamp(0.0, metric.length);
      final end = (d + dashLength).clamp(0.0, metric.length);
      if (end > start) {
        canvas.drawPath(metric.extractPath(start, end), dashPaint);
      }
    }
  }

  void _paintModernCorners(Canvas canvas, Rect rect, Color color) {
    const len = 50.0;
    const radius = 36.0;
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(radius));
    final path = Path()
      ..moveTo(r.left, r.top + len)
      ..lineTo(r.left, r.top + radius)
      ..quadraticBezierTo(r.left, r.top, r.left + radius, r.top)
      ..lineTo(r.left + len, r.top)
      ..moveTo(r.right - len, r.top)
      ..lineTo(r.right - radius, r.top)
      ..quadraticBezierTo(r.right, r.top, r.right, r.top + radius)
      ..lineTo(r.right, r.top + len)
      ..moveTo(r.right, r.bottom - len)
      ..lineTo(r.right, r.bottom - radius)
      ..quadraticBezierTo(r.right, r.bottom, r.right - radius, r.bottom)
      ..lineTo(r.right - len, r.bottom)
      ..moveTo(r.left + len, r.bottom)
      ..lineTo(r.left + radius, r.bottom)
      ..quadraticBezierTo(r.left, r.bottom, r.left, r.bottom - radius)
      ..lineTo(r.left, r.bottom - len);
    final glow = Paint()
      ..color = color.withOpacity(0.5 + 0.3 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    final core = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, color, color.withOpacity(0.8)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glow);
    canvas.drawPath(path, core);
  }

  void _paintScanLine(Canvas canvas, Rect rect) {
    final y = rect.top + rect.height * scanLineProgress;
    final line = Rect.fromLTWH(rect.left + 20, y, rect.width - 40, 2);
    final core = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          PaytmColors.paytmBlue,
          Colors.white,
          PaytmColors.paytmBlue,
          Colors.transparent,
        ],
      ).createShader(line);
    canvas.drawRect(line, core);
    final trail = Rect.fromLTWH(rect.left + 20, y - 10, rect.width - 40, 22);
    final glow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          PaytmColors.paytmBlue.withOpacity(0.4),
          Colors.transparent,
        ],
      ).createShader(trail);
    canvas.drawRect(trail, glow);
    final nodes = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(rect.left + 20, y + 1), 3, nodes);
    canvas.drawCircle(Offset(rect.right - 20, y + 1), 3, nodes);
  }

  void _paintSuccessBurst(Canvas canvas, Rect rect) {
    final t = Curves.easeOutCubic.transform(successProgress.clamp(0.0, 1.0));
    final center = rect.center;
    final radius = rect.width * t * 1.2;
    final ripple = Paint()
      ..shader = RadialGradient(
        colors: [
          PaytmColors.gold.withOpacity((1 - t).clamp(0.0, 1.0) * 0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, ripple);

    if (t <= 0.2) return;
    final check = Path()
      ..moveTo(center.dx - 35, center.dy)
      ..lineTo(center.dx - 10, center.dy + 25)
      ..lineTo(center.dx + 45, center.dy - 35);
    final metric = check.computeMetrics().first;
    final progress = ((t - 0.2) / 0.8).clamp(0.0, 1.0);
    final partial = metric.extractPath(0, metric.length * progress);
    final shadow = Paint()
      ..color = PaytmColors.gold.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final mark = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(partial, shadow);
    canvas.drawPath(partial, mark);
  }

  @override
  bool shouldRepaint(covariant _ModernScannerOverlayPainter old) =>
      old.scanLineProgress != scanLineProgress ||
      old.pulse != pulse ||
      old.successProgress != successProgress;
}

// ============================================================
//           CHAT SCREEN — animated robot + mouth-flap on TTS
// ============================================================
class ChatScreen extends StatefulWidget {
  final AppLanguage language;
  final String merchantName;
  final String rawQr;

  const ChatScreen({
    super.key,
    required this.language,
    required this.merchantName,
    required this.rawQr,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  final List<Map<String, String>> _messages = [];
  bool _busy = false;
  bool _voiceCapture = false;

  late AnimationController _breatheController;
  late AnimationController _bobController;
  late AnimationController _tiltController;
  late AnimationController _blinkController;
  late AnimationController _waveController;
  late AnimationController _antennaController;
  late AnimationController _pupilController;
  late AnimationController _mouthController;

  _RobotExpression _expression = _RobotExpression.happy;

  @override
  void initState() {
    super.initState();

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _tiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scheduleBlink();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _antennaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pupilController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _mouthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _startExpressionCycle();
    _startConversation();
  }

  void _startExpressionCycle() async {
    final moods = [
      _RobotExpression.happy,
      _RobotExpression.listening,
      _RobotExpression.thinking,
      _RobotExpression.happy,
    ];
    int i = 0;
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 2600));
      if (!mounted) return;
      if (!VoiceService.isSpeaking) {
        i = (i + 1) % moods.length;
        setState(() => _expression = moods[i]);
      }
    }
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future.delayed(
        Duration(milliseconds: 2200 + math.Random().nextInt(2200)),
      );
      if (!mounted) return;
      await _blinkController.forward();
      await _blinkController.reverse();
    }
  }

  Future<void> _startConversation() async {
    final greeting = widget.language.chatGreeting;
    _messages.add({'role': 'assistant', 'content': greeting});
    setState(() {});
    _scrollToBottom();
    await VoiceService.speak(
      greeting,
      language: widget.language,
      cacheToDisk: true,
    );
  }

  Future<void> _sendUserMessage(String text) async {
    if (text.trim().isEmpty || _busy) return;
    final userMsg = text.trim();
    _textController.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': userMsg});
      _busy = true;
      _expression = _RobotExpression.thinking;
    });
    _scrollToBottom();

    final systemPrompt =
        '''
You are "Paytm Buddy", a cute friendly robot helping a merchant set up their digital store after scanning their QR code.
Reply only in ${widget.language.englishName} (${widget.language.nativeName}), using its normal script. Keep each answer very short: one sentence and one question at most.
Collect from the merchant, one question at a time:
1. What do they sell?
2. What is the price?
3. Anything else to add (delivery, timing, offers)?
Once all three are collected, summarize back, then say "Great! Your store is ready!".
Do not ask more than one question at a time.
''';

    final reply = await VoiceService.chat(
      messages: _messages
          .map((m) => {'role': m['role']!, 'content': m['content']!})
          .toList(),
      systemPrompt: systemPrompt,
    );

    if (!mounted) return;
    if (reply.isEmpty) {
      setState(() {
        _busy = false;
        _expression = _RobotExpression.confused;
      });
      return;
    }

    setState(() {
      _messages.add({'role': 'assistant', 'content': reply});
      _busy = false;
      _expression = _RobotExpression.speaking;
    });
    _scrollToBottom();
    await VoiceService.speak(reply, language: widget.language);
  }

  Future<void> _onMicTap() async {
    if (_busy) return;
    setState(() {
      _voiceCapture = true;
      _expression = _RobotExpression.listening;
    });

    final text = await VoiceService.recordAndTranscribe(
      seconds: 3,
      language: widget.language,
    );
    if (!mounted) return;
    setState(() => _voiceCapture = false);

    if (text != null && text.isNotEmpty) {
      _sendUserMessage(text);
    } else {
      setState(() => _expression = _RobotExpression.confused);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _breatheController.dispose();
    _bobController.dispose();
    _tiltController.dispose();
    _blinkController.dispose();
    _waveController.dispose();
    _antennaController.dispose();
    _pupilController.dispose();
    _mouthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F7FC),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              decoration: BoxDecoration(
                gradient: PaytmColors.logoGradient,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                height: 170,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _breatheController,
                    _bobController,
                    _tiltController,
                    _blinkController,
                    _waveController,
                    _antennaController,
                    _pupilController,
                    _mouthController,
                    VoiceService.speakingListenable,
                  ]),
                  builder: (context, _) {
                    final bob =
                        math.sin(_bobController.value * math.pi * 2) * 3;
                    final tilt =
                        math.sin(_tiltController.value * math.pi * 2) * 0.04;
                    final breathe =
                        1 +
                        math.sin(_breatheController.value * math.pi * 2) * 0.02;
                    // Mouth flap ONLY while TTS is playing
                    final isSpeaking = VoiceService.isSpeaking;
                    final liveExpr = isSpeaking
                        ? _RobotExpression.speaking
                        : _expression;
                    final mouthFlap = isSpeaking
                        ? _speechMouthOpening(_mouthController.value)
                        : 0.0;

                    return Transform.translate(
                      offset: Offset(0, bob),
                      child: Transform.scale(
                        scale: breathe * 0.55,
                        alignment: Alignment.topCenter,
                        child: Transform.rotate(
                          angle: tilt,
                          alignment: Alignment.topCenter,
                          child: _PremiumRobot(
                            blink: _blinkController.value,
                            wave: _waveController.value,
                            showWave: true,
                            antennaPulse: _antennaController.value,
                            pupil: _pupilController.value,
                            expression: liveExpr,
                            mouthFlap: mouthFlap,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _PaytmLogo(size: 20),
                const SizedBox(width: 10),
                Container(
                  width: 1,
                  height: 16,
                  color: PaytmColors.deepNavy.withOpacity(0.3),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Merchant: ${widget.merchantName}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PaytmColors.deepNavy,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: _messages.length + (_busy ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _busy) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: _TypingBubble(),
                    );
                  }
                  final m = _messages[index];
                  final isUser = m['role'] == 'user';
                  return _ChatBubble(text: m['content'] ?? '', isUser: isUser);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _onMicTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _voiceCapture
                            ? const Color(0xFFFF7043)
                            : const Color(0xFF00BAF2),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_voiceCapture
                                        ? const Color(0xFFFF7043)
                                        : const Color(0xFF00BAF2))
                                    .withOpacity(0.35),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        _voiceCapture ? Icons.mic : Icons.mic_none_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) _sendUserMessage(v);
                      },
                      decoration: InputDecoration(
                        hintText: 'Type or tap mic…',
                        filled: true,
                        fillColor: const Color(0xFFF2F7FA),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (_textController.text.trim().isNotEmpty) {
                        _sendUserMessage(_textController.text);
                      }
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: PaytmColors.logoGradient,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x6600BAF2),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  const _ChatBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? PaytmColors.paytmBlue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: PaytmColors.deepNavy.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: isUser ? Colors.white : PaytmColors.deepNavy,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF00BAF2),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: const Color(0xFF002970), size: 22),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double guideProgress;
  final double pointingAngle;

  const _ScannerOverlayPainter({
    required this.guideProgress,
    required this.pointingAngle,
  });

  static Rect frameFor(Size size) => Rect.fromCenter(
    center: Offset(size.width / 2, size.height * 0.58),
    width: 260,
    height: 260,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = frameFor(size);

    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(28)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(overlay, Paint()..color = Colors.black.withOpacity(0.55));

    final corner = Paint()
      ..color = const Color(0xFF00BAF2)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 34.0;
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(28));
    final path = Path();

    path.moveTo(r.left, r.top + len);
    path.lineTo(r.left, r.top + 24);
    path.quadraticBezierTo(r.left, r.top, r.left + 24, r.top);
    path.lineTo(r.left + len, r.top);

    path.moveTo(r.right - len, r.top);
    path.lineTo(r.right - 24, r.top);
    path.quadraticBezierTo(r.right, r.top, r.right, r.top + 24);
    path.lineTo(r.right, r.top + len);

    path.moveTo(r.right, r.bottom - len);
    path.lineTo(r.right, r.bottom - 24);
    path.quadraticBezierTo(r.right, r.bottom, r.right - 24, r.bottom);
    path.lineTo(r.right - len, r.bottom);

    path.moveTo(r.left + len, r.bottom);
    path.lineTo(r.left + 24, r.bottom);
    path.quadraticBezierTo(r.left, r.bottom, r.left, r.bottom - 24);
    path.lineTo(r.left, r.bottom - len);

    canvas.drawPath(path, corner);

    _paintGuideArrow(canvas, size, rect);
  }

  void _paintGuideArrow(Canvas canvas, Size size, Rect frame) {
    final p = guideProgress;
    final isPhoneScanning = p >= 0.22 && p < 0.55;
    final isPointing = p >= 0.68;
    if (!isPhoneScanning && !isPointing) return;

    const scale = 0.62;
    const robotCenterX = 140.0;
    const robotTop = 36.0;
    final shoulder = isPhoneScanning
        ? const Offset(89, 204)
        : const Offset(212, 204);
    final angle = isPhoneScanning ? _phoneArmAngle(p) : pointingAngle;
    final handReach = isPhoneScanning ? 79.0 : 108.0;
    final handLocal =
        shoulder +
        Offset(math.sin(angle) * handReach, math.cos(angle) * handReach);
    final phoneOffset = isPhoneScanning ? const Offset(0, -14) : Offset.zero;
    final start = Offset(
      size.width / 2 + (handLocal.dx - robotCenterX) * scale + phoneOffset.dx,
      robotTop + handLocal.dy * scale + phoneOffset.dy,
    );
    final end = frame.center;
    final bend = (end.dy - start.dy) * 0.42;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx,
        start.dy + bend,
        end.dx,
        end.dy - bend,
        end.dx,
        end.dy,
      );
    final pulse = 0.5 + 0.5 * math.sin(p * math.pi * 2);
    final opacity = isPhoneScanning ? 0.22 : 0.34 + pulse * 0.24;
    final glow = Paint()
      ..color = const Color(0xFF35D8FF).withOpacity(opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final stroke = Paint()
      ..color = const Color(0xFF8DEBFF).withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, glow);
    canvas.drawPath(path, stroke);

    final tangent = Offset(end.dx - start.dx, end.dy - start.dy);
    final angleToEnd = math.atan2(tangent.dy, tangent.dx);
    const arrowLength = 12.0;
    final arrow = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowLength * math.cos(angleToEnd - math.pi / 6),
        end.dy - arrowLength * math.sin(angleToEnd - math.pi / 6),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowLength * math.cos(angleToEnd + math.pi / 6),
        end.dy - arrowLength * math.sin(angleToEnd + math.pi / 6),
      );
    canvas.drawPath(arrow, stroke);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.guideProgress != guideProgress ||
      oldDelegate.pointingAngle != pointingAngle;
}

// ============================================================
//           EXPRESSIONS + PREMIUM ROBOT
// ============================================================
enum _RobotExpression {
  happy,
  thinking,
  listening,
  speaking,
  confused,
  excited,
  sleepy,
  surprised,
}

enum _Reaction {
  idle,
  newQuestion,
  heardAnswer,
  correct,
  thinking,
  categoryPicked,
  finish,
  unsure,
}

class _RobotReactionPose {
  final double jump;
  final double squash;
  final double headTilt;
  final double armAngle;
  final double antennaFlash;
  final double pupilLook;
  final _RobotExpression? expressionOverride;
  final double mouthOpen;
  const _RobotReactionPose({
    this.jump = 0,
    this.squash = 1,
    this.headTilt = 0,
    this.armAngle = -2.30,
    this.antennaFlash = 0,
    this.pupilLook = 0,
    this.expressionOverride,
    this.mouthOpen = 0,
  });
}

_RobotReactionPose _poseFor(_Reaction kind, double t) {
  final bell = math.sin(t * math.pi);
  final squashBell = math.sin(t * math.pi * 2).abs();
  switch (kind) {
    case _Reaction.newQuestion:
      return _RobotReactionPose(
        jump: -10 * bell,
        squash: 1 + .03 * bell,
        headTilt: -.12 * bell,
        armAngle: -2.30 + 1.3 * bell,
        antennaFlash: bell,
        pupilLook: .5 * bell,
        expressionOverride: _RobotExpression.listening,
        mouthOpen: .2 * bell,
      );
    case _Reaction.heardAnswer:
      return _RobotReactionPose(
        jump: -6 * bell,
        squash: 1 + .02 * bell,
        headTilt: math.sin(t * math.pi * 2) * .05,
        armAngle: -2.30 + .6 * bell,
        expressionOverride: _RobotExpression.happy,
        pupilLook: .2 * bell,
      );
    case _Reaction.correct:
      return _RobotReactionPose(
        jump: -18 * bell,
        squash: 1 + .06 * squashBell,
        antennaFlash: 1 - t,
        expressionOverride: _RobotExpression.excited,
        mouthOpen: .5 * bell,
      );
    case _Reaction.thinking:
      return _RobotReactionPose(
        headTilt: -.14 * bell,
        armAngle: -1.6 * bell - .6,
        pupilLook: -.4 * bell,
        expressionOverride: _RobotExpression.thinking,
      );
    case _Reaction.categoryPicked:
      return _RobotReactionPose(
        jump: -22 * bell,
        squash: 1 + .08 * squashBell,
        headTilt: .06 * math.sin(t * math.pi * 6) * bell,
        armAngle: -2.30 + 2 * bell,
        antennaFlash: bell,
        expressionOverride: _RobotExpression.excited,
        mouthOpen: .6 * bell,
      );
    case _Reaction.finish:
      final sway = math.sin(t * math.pi * 8);
      return _RobotReactionPose(
        jump: -12 * bell,
        squash: 1 + .05 * squashBell,
        headTilt: .1 * sway,
        armAngle: -2.30 + 2.2 * bell + .2 * sway,
        antennaFlash: 1 - t,
        expressionOverride: _RobotExpression.excited,
        mouthOpen: .7,
      );
    case _Reaction.unsure:
      return _RobotReactionPose(
        headTilt: .12 * bell,
        armAngle: -2.30 + .15 * bell,
        expressionOverride: _RobotExpression.confused,
        pupilLook: -.6 * bell,
      );
    case _Reaction.idle:
      return const _RobotReactionPose();
  }
}

double _phoneArmAngle(double progress) {
  if (progress < 0.12) return 0.12;
  if (progress < 0.22) {
    final t = Curves.easeInOutCubic.transform((progress - 0.12) / 0.10);
    return 0.12 + 0.40 * t;
  }
  if (progress < 0.55) {
    final scan = (progress - 0.22) / 0.33;
    return 0.52 + math.sin(scan * math.pi * 4) * 0.035;
  }
  if (progress < 0.68) {
    final t = Curves.easeInOutCubic.transform((progress - 0.55) / 0.13);
    return 0.52 - 0.40 * t;
  }
  return 0.12;
}

class _RobotScanPhone extends StatelessWidget {
  final bool scanning;
  final double pulse;

  const _RobotScanPhone({required this.scanning, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final linePosition = 7 + ((pulse * 3) % 1) * 24;
    return Container(
      width: 24,
      height: 42,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF002970),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFB8F5FF), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BAF2).withOpacity(scanning ? 0.8 : 0.35),
            blurRadius: scanning ? 10 : 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            Container(color: const Color(0xFF75E5F8)),
            Positioned(
              top: 3,
              left: 6,
              right: 6,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFF002970).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (scanning)
              Positioned(
                top: linePosition,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00BAF2).withOpacity(0.9),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PremiumRobot extends StatelessWidget {
  final double blink;
  final double wave;
  final bool showWave;
  final bool pointAtCamera;
  final double scannerGuidePhase;
  final double pointingAngle;
  final double antennaPulse;
  final double pupil;
  final _RobotExpression expression;
  final double extraHeadTilt;
  final double mouthFlap;
  final double? rightArmOverride;
  final double pupilLook;

  const _PremiumRobot({
    required this.blink,
    required this.wave,
    required this.showWave,
    this.pointAtCamera = false,
    this.scannerGuidePhase = 0,
    this.pointingAngle = -0.58,
    required this.antennaPulse,
    required this.pupil,
    required this.expression,
    this.extraHeadTilt = 0,
    this.mouthFlap = 0,
    this.rightArmOverride,
    this.pupilLook = 0,
  });

  @override
  Widget build(BuildContext context) {
    double extraTilt = 0;
    if (expression == _RobotExpression.thinking) extraTilt = -0.10;
    if (expression == _RobotExpression.confused) extraTilt = 0.08;

    const double bodyLeft = 74;
    const double bodyWidth = 132;
    const double bodyRight = bodyLeft + bodyWidth;
    const double bodyTop = 195;
    const double shoulderY = bodyTop + 14;

    const double armW = 52;

    final double leftArmAngle = pointAtCamera
        ? _phoneArmAngle(scannerGuidePhase)
        : 0.18;

    const double rightArmBaseRotate = -2.30;
    final double waveSwing = showWave ? (-0.14 + wave * 0.28) : 0.0;
    final double rightArmAngle =
        rightArmOverride ??
        (pointAtCamera ? pointingAngle : rightArmBaseRotate + waveSwing);

    const double leftSocketCx = bodyLeft + 4 + 11;
    const double rightSocketCx = bodyRight + 6;

    return SizedBox(
      width: 280,
      height: 300,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 15,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00BAF2).withOpacity(0.22),
                    const Color(0xFF00BAF2).withOpacity(0.0),
                  ],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
          ),
          ..._buildParticles(pupil),
          Positioned(top: 0, child: _GlowAntenna(pulse: antennaPulse)),
          Positioned(
            top: bodyTop,
            child: Transform.rotate(
              angle: extraTilt,
              alignment: Alignment.topCenter,
              child: const _CuteBody(),
            ),
          ),
          Positioned(
            top: shoulderY - 11,
            left: leftSocketCx - 11,
            child: const _ShoulderSocket(),
          ),
          Positioned(
            top: shoulderY - 11,
            left: rightSocketCx - 11,
            child: const _ShoulderSocket(),
          ),
          Positioned(
            left: leftSocketCx - armW / 2,
            top: shoulderY - 5,
            child: Transform.rotate(
              angle: leftArmAngle,
              alignment: Alignment.topCenter,
              child: _ArmPiece(flip: false),
            ),
          ),
          Positioned(
            top: 30,
            child: Transform.rotate(
              angle: extraTilt + extraHeadTilt,
              alignment: Alignment.bottomCenter,
              child: _CuteHead(
                blink: blink,
                expression: expression,
                pupil: pupil,
                mouthFlap: mouthFlap,
                lookOffset: pupilLook,
              ),
            ),
          ),
          Positioned(
            left: rightSocketCx - armW / 2,
            top: shoulderY - 5,
            child: Transform.rotate(
              angle: rightArmAngle,
              alignment: Alignment.topCenter,
              child: _ArmPiece(flip: true, pointing: pointAtCamera),
            ),
          ),
          if (pointAtCamera &&
              scannerGuidePhase >= 0.12 &&
              scannerGuidePhase < 0.68)
            Positioned(
              left: leftSocketCx + math.sin(leftArmAngle) * 79 - 12,
              top: shoulderY - 5 + math.cos(leftArmAngle) * 79 - 34,
              child: Transform.rotate(
                angle: leftArmAngle * 0.65,
                child: _RobotScanPhone(
                  scanning:
                      scannerGuidePhase >= 0.22 && scannerGuidePhase < 0.55,
                  pulse: scannerGuidePhase,
                ),
              ),
            ),
          const Positioned(top: 262, left: 100, child: _CuteFoot()),
          const Positioned(top: 262, right: 100, child: _CuteFoot()),
        ],
      ),
    );
  }

  List<Widget> _buildParticles(double t) {
    final particles = <Widget>[];
    for (int i = 0; i < 3; i++) {
      final phase = (t + i * 0.33) % 1.0;
      final angle = phase * math.pi * 2;
      final radius = 110.0 + i * 8;
      final x = 140 + math.cos(angle) * radius;
      final y = 160 + math.sin(angle) * radius * 0.6;
      final opacity = (math.sin(phase * math.pi)).clamp(0.0, 1.0) * 0.7;
      final size = 4.0 + i * 1.5;
      particles.add(
        Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: i.isEven
                    ? const Color(0xFFFFE44D)
                    : const Color(0xFF9DEEFB),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        (i.isEven
                                ? const Color(0xFFFFE44D)
                                : const Color(0xFF9DEEFB))
                            .withOpacity(0.9),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return particles;
  }
}

// --------- Robot parts unchanged ---------
class _ShoulderSocket extends StatelessWidget {
  const _ShoulderSocket();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PaytmColors.gold, PaytmColors.goldDeep],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: PaytmColors.deepNavy, width: 2.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.55),
            blurRadius: 8,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: const Color(0xFF002970).withOpacity(0.45),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _ArmPiece extends StatelessWidget {
  final bool flip;
  final bool pointing;
  const _ArmPiece({required this.flip, this.pointing = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: pointing ? 112 : 100,
      child: CustomPaint(
        painter: _ArmPainter(flip: flip, pointing: pointing),
      ),
    );
  }
}

class _ArmPainter extends CustomPainter {
  final bool flip;
  final bool pointing;
  _ArmPainter({required this.flip, this.pointing = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = pointing ? size.height - 12 : size.height;

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9DEEFB), Color(0xFF4DD0E1), Color(0xFF00BAF2)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final stroke = Paint()
      ..color = const Color(0xFF002970)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final cx = w / 2;

    final body = Path()
      ..moveTo(cx - 9, h * 0.05)
      ..lineTo(cx + 9, h * 0.05)
      ..lineTo(cx + 9, h * 0.44)
      ..lineTo(cx + 10, h * 0.50)
      ..lineTo(cx + 16, h * 0.55)
      ..cubicTo(cx + 24, h * 0.56, cx + 26, h * 0.66, cx + 20, h * 0.72)
      ..cubicTo(cx + 26, h * 0.74, cx + 24, h * 0.86, cx + 14, h * 0.90)
      ..cubicTo(cx + 12, h * 0.94, cx + 2, h * 0.96, cx - 2, h * 0.92)
      ..cubicTo(cx - 10, h * 0.94, cx - 16, h * 0.88, cx - 16, h * 0.80)
      ..cubicTo(cx - 24, h * 0.78, cx - 24, h * 0.62, cx - 12, h * 0.58)
      ..lineTo(cx - 10, h * 0.50)
      ..lineTo(cx - 9, h * 0.44)
      ..close();

    if (flip) {
      canvas.save();
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }

    canvas.drawPath(body, fill);
    canvas.drawPath(body, stroke);

    if (pointing) {
      final finger = Path()
        ..moveTo(cx - 5, h * 0.79)
        ..cubicTo(cx - 4, h * 0.88, cx - 3, h * 0.96, cx - 2, h + 5)
        ..quadraticBezierTo(cx, h + 11, cx + 4, h + 9)
        ..quadraticBezierTo(cx + 8, h + 7, cx + 6, h + 1)
        ..lineTo(cx + 8, h * 0.79)
        ..close();
      canvas.drawPath(finger, fill);
      canvas.drawPath(finger, stroke);
    }

    final cuff = Paint()
      ..color = const Color(0xFF002970).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 8, h * 0.52), Offset(cx + 9, h * 0.52), cuff);

    final groove = Paint()
      ..color = const Color(0xFF002970).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + 18, h * 0.70),
      Offset(cx + 20, h * 0.78),
      groove,
    );
    canvas.drawLine(
      Offset(cx + 10, h * 0.80),
      Offset(cx + 12, h * 0.88),
      groove,
    );

    canvas.drawCircle(
      Offset(cx - 2, h * 0.66),
      3.6,
      Paint()..color = Colors.white.withOpacity(0.7),
    );
    canvas.drawCircle(
      Offset(cx + 4, h * 0.62),
      1.8,
      Paint()..color = Colors.white.withOpacity(0.45),
    );

    if (flip) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArmPainter old) =>
      old.flip != flip || old.pointing != pointing;
}

class _SparklyEye extends StatelessWidget {
  final double blink;
  final _RobotExpression expression;
  final double pupil;
  final bool isLeft;
  final double lookOffset;

  const _SparklyEye({
    required this.blink,
    required this.expression,
    required this.pupil,
    required this.isLeft,
    this.lookOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (expression == _RobotExpression.sleepy) {
      return SizedBox(
        width: 34,
        height: 20,
        child: CustomPaint(painter: _SleepyEyePainter()),
      );
    }

    double open = 1 - blink * 0.9;
    if (expression == _RobotExpression.excited) open = 1.08;
    if (expression == _RobotExpression.surprised) open = 1.15;
    final h = 34.0 * open;

    final drift = math.sin(pupil * math.pi * 2) * 3;
    final px = (isLeft ? drift : -drift * 0.8) + lookOffset * 4.0;

    return SizedBox(
      width: 34,
      height: h.clamp(3.0, 40.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF002970), width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BAF2).withOpacity(0.35),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Transform.translate(
                offset: Offset(px, 0),
                child: Container(
                  width: 20 * (1 - blink),
                  height: 20 * (1 - blink),
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0xFF0050A0), Color(0xFF002970)],
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            if (blink < 0.5)
              Positioned(
                top: 6,
                left: 8 + (isLeft ? px : -px),
                child: const CircleAvatar(
                  radius: 4.5,
                  backgroundColor: Colors.white,
                ),
              ),
            if (blink < 0.5)
              Positioned(
                bottom: 7,
                right: 7 + (isLeft ? -px : px),
                child: CircleAvatar(
                  radius: 2.2,
                  backgroundColor: Colors.white.withOpacity(0.9),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SleepyEyePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF002970)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width / 2,
        -size.height * 0.4,
        size.width,
        size.height * 0.7,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlowAntenna extends StatelessWidget {
  final double pulse;
  const _GlowAntenna({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final glow = 0.5 + pulse * 0.5;
    final scale = 1 + pulse * 0.10;
    return SizedBox(
      width: 60,
      height: 76,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFD700).withOpacity(0.55 * glow),
                    const Color(0xFFFFD700).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFF176), Color(0xFFFFB300)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF002970),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.8),
                      blurRadius: 12 * glow,
                      spreadRadius: 2 * glow,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 30,
            child: Container(
              width: 4,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF90A4AE),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CuteHead extends StatelessWidget {
  final double blink;
  final _RobotExpression expression;
  final double pupil;
  final double mouthFlap;
  final double lookOffset;
  const _CuteHead({
    required this.blink,
    required this.expression,
    required this.pupil,
    required this.mouthFlap,
    this.lookOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 190,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 200,
              height: 172,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF9DEEFB),
                    Color(0xFF4DD0E1),
                    Color(0xFF00BAF2),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(98),
                border: Border.all(color: const Color(0xFF002970), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BAF2).withOpacity(0.35),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 12,
                    left: 30,
                    child: Container(
                      width: 70,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    left: 118,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const Positioned(top: 128, left: 18, child: _Blush()),
                  const Positioned(top: 128, right: 18, child: _Blush()),
                  Positioned(
                    top: 62,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SparklyEye(
                          blink: blink,
                          expression: expression,
                          pupil: pupil,
                          isLeft: true,
                          lookOffset: lookOffset,
                        ),
                        const SizedBox(width: 24),
                        _SparklyEye(
                          blink: blink,
                          expression: expression,
                          pupil: pupil,
                          isLeft: false,
                          lookOffset: lookOffset,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 138,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: CustomPaint(
                        size: const Size(36, 24),
                        painter: _ExpressionMouthPainter(expression, mouthFlap),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(top: 100, left: -2, child: _SideAccent()),
          const Positioned(top: 100, right: -2, child: _SideAccent()),
        ],
      ),
    );
  }
}

double _speechMouthOpening(double progress) {
  const syllables = <double>[
    0.02,
    0.04,
    0.42,
    0.12,
    0.03,
    0.05,
    0.30,
    0.08,
    0.02,
    0.06,
    0.54,
    0.16,
  ];
  final position = (progress % 1.0) * syllables.length;
  final index = position.floor();
  final from = syllables[index];
  final to = syllables[(index + 1) % syllables.length];
  final t = position - index;
  final eased = t * t * (3 - 2 * t);
  return from + (to - from) * eased;
}

class _ExpressionMouthPainter extends CustomPainter {
  final _RobotExpression expression;
  final double mouthFlap;
  _ExpressionMouthPainter(this.expression, this.mouthFlap);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF002970)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = const Color(0xFFFF8A80);
    final w = size.width;
    final h = size.height;

    if (expression == _RobotExpression.speaking) {
      final opening = mouthFlap.clamp(0.0, 0.58);
      if (opening < 0.10) {
        final smile = Path()
          ..moveTo(w * 0.22, h * 0.46)
          ..quadraticBezierTo(w * 0.5, h * 0.64, w * 0.78, h * 0.46);
        canvas.drawPath(smile, stroke);
        return;
      }

      final mouthHeight = h * (0.08 + opening * 0.42);
      final mouth = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w / 2, h * 0.49),
          width: w * (0.62 + opening * 0.18),
          height: mouthHeight,
        ),
        Radius.circular(mouthHeight / 2),
      );
      canvas.drawRRect(mouth, Paint()..color = const Color(0xFF18243A));
      canvas.drawRRect(mouth, stroke);
      return;
    }

    switch (expression) {
      case _RobotExpression.excited:
        final path = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(w / 2, h * 1.8, w, 0)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        break;
      case _RobotExpression.surprised:
        final rect = Rect.fromCenter(
          center: Offset(w / 2, h / 2),
          width: w * 0.6,
          height: h * 1.2,
        );
        canvas.drawOval(rect, fill);
        canvas.drawOval(rect, stroke);
        break;
      case _RobotExpression.thinking:
        canvas.drawLine(
          Offset(w * 0.3, h * 0.5),
          Offset(w * 0.7, h * 0.5),
          stroke,
        );
        break;
      case _RobotExpression.confused:
        final path = Path()
          ..moveTo(0, h * 0.4)
          ..quadraticBezierTo(w * 0.25, h * 0.9, w * 0.5, h * 0.4)
          ..quadraticBezierTo(w * 0.75, -h * 0.1, w, h * 0.4);
        canvas.drawPath(path, stroke);
        break;
      case _RobotExpression.sleepy:
        canvas.drawLine(
          Offset(w * 0.35, h * 0.5),
          Offset(w * 0.65, h * 0.5),
          stroke,
        );
        break;
      case _RobotExpression.listening:
        final rect = Rect.fromCenter(
          center: Offset(w / 2, h / 2),
          width: w * 0.35,
          height: h * 0.9,
        );
        canvas.drawOval(rect, stroke);
        break;
      case _RobotExpression.speaking:
        final path = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(w / 2, h * 1.5, w, 0)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        break;
      case _RobotExpression.happy:
      default:
        final path = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(w / 2, h * 1.4, w, 0);
        canvas.drawPath(path, stroke);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ExpressionMouthPainter old) =>
      old.expression != expression || old.mouthFlap != mouthFlap;
}

class _Blush extends StatelessWidget {
  const _Blush();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 13,
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          colors: [Color(0xFFFFB4AB), Color(0xFFFF8A80)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8A80).withOpacity(0.35),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

class _SideAccent extends StatelessWidget {
  const _SideAccent();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PaytmColors.gold, PaytmColors.goldDeep],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: PaytmColors.deepNavy, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _CuteBody extends StatelessWidget {
  const _CuteBody();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 78,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9DEEFB), Color(0xFF4DD0E1), Color(0xFF00BAF2)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(42),
        border: Border.all(color: const Color(0xFF002970), width: 4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BAF2).withOpacity(0.30),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 60,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF002970),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ChestLight(color: PaytmColors.gold),
                  SizedBox(width: 6),
                  _ChestLight(color: PaytmColors.paytmBlue),
                  SizedBox(width: 6),
                  _ChestLight(color: PaytmColors.skyBlue),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: PaytmColors.paytmBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'tm',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChestLight extends StatelessWidget {
  final Color color;
  const _ChestLight({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.9), blurRadius: 6)],
      ),
    );
  }
}

class _CuteFoot extends StatelessWidget {
  const _CuteFoot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7FE7F5), Color(0xFF00BAF2)],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(12),
          top: Radius.circular(6),
        ),
        border: Border.all(color: const Color(0xFF002970), width: 3),
      ),
    );
  }
}

class _DustPuff extends StatelessWidget {
  final double progress;
  const _DustPuff({required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress == 0) return const SizedBox.shrink();
    final p = progress;
    return SizedBox(
      width: 220,
      height: 80,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          for (int i = 0; i < 6; i++)
            Positioned(
              left: 20.0 + i * 30 + (i.isEven ? -p * 30 : p * 30),
              bottom: 10.0 + (i % 2) * 6 - p * 12,
              child: Opacity(
                opacity: (1 - p).clamp(0.0, 1.0) * 0.8,
                child: Container(
                  width: 20.0 + i * 2,
                  height: 20.0 + i * 2,
                  decoration: const BoxDecoration(
                    color: Color(0xFFB3E5FC),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;
  const _SpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: PaytmColors.paytmBlue, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: PaytmColors.paytmBlue.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: PaytmColors.deepNavy,
              letterSpacing: -0.3,
            ),
          ),
        ),
        CustomPaint(size: const Size(26, 16), painter: _BubbleTailPainter()),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = Colors.white;
    final border = Paint()
      ..color = PaytmColors.paytmBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
//           MERCHANT CARD FLOW — "Piku hands you cards"
// ============================================================

/// One question on a card. Some are optional (skippable).
class _CardQuestion {
  final String id;
  final String prompt; // what Piku says + shows
  final String hint; // small grey helper text
  final IconData icon;
  final bool optional;
  final _AnswerKind kind;
  final List<String> quickPicks; // one-tap chips (empty = none)

  const _CardQuestion({
    required this.id,
    required this.prompt,
    required this.hint,
    required this.icon,
    required this.kind,
    this.optional = false,
    this.quickPicks = const [],
  });
}

enum MerchantCategory {
  food('Food / Tella', '🍜'),
  tea('Tea / Coffee', '☕'),
  snacks('Chaat / Snacks', '🥟'),
  salon('Salon / Barber', '💈'),
  tailoring('Tailoring', '🧵'),
  repair('Repair / Service', '🔧'),
  grocery('Grocery / Kirana', '🛒'),
  other('Other', '📦');

  const MerchantCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

enum _AnswerKind { text, price, list, location, phone, category, menuBuilder }

class _MenuItem {
  String name;
  String price = '';

  _MenuItem({required this.name});

  String get display => price.isEmpty ? name : '$name — $price';
}

const List<_CardQuestion> kCommonQuestions = [
  _CardQuestion(
    id: 'business_name',
    prompt: 'What is your shop called?',
    hint: 'The name people know you by',
    icon: Icons.storefront_rounded,
    kind: _AnswerKind.text,
  ),
  _CardQuestion(
    id: 'business_type',
    prompt: 'What kind of business do you run?',
    hint: 'Choose a category to continue',
    icon: Icons.category_rounded,
    kind: _AnswerKind.category,
  ),
];

const List<_CardQuestion> kClosingQuestions = [
  _CardQuestion(
    id: 'location',
    prompt: 'Where is your shop located?',
    hint: 'Tell us a street, area, or nearby landmark',
    icon: Icons.location_on_rounded,
    kind: _AnswerKind.location,
  ),
  _CardQuestion(
    id: 'phone',
    prompt: 'A phone number customers can reach?',
    hint: 'Optional — you can skip',
    icon: Icons.phone_rounded,
    kind: _AnswerKind.phone,
    optional: true,
  ),
];

final Map<MerchantCategory, List<_CardQuestion>> kCategoryQuestions = {
  MerchantCategory.food: const [
    _CardQuestion(
      id: 'items',
      prompt: 'Let’s build your menu one item at a time.',
      hint: 'Add one item, then set its price',
      icon: Icons.receipt_long_rounded,
      kind: _AnswerKind.menuBuilder,
    ),
    _CardQuestion(
      id: 'specialty',
      prompt: 'What is your most famous dish?',
      hint: 'Customers keep coming back for this',
      icon: Icons.local_fire_department_rounded,
      kind: _AnswerKind.text,
      optional: true,
    ),
    _CardQuestion(
      id: 'hours',
      prompt: 'When are you open?',
      hint: 'Example: 5pm to 11pm',
      icon: Icons.schedule_rounded,
      kind: _AnswerKind.text,
      optional: true,
      quickPicks: ['Morning', 'Evening', 'All day', 'Late night'],
    ),
  ],
  MerchantCategory.tea: const [
    _CardQuestion(
      id: 'items',
      prompt: 'Let’s build your menu one item at a time.',
      hint: 'Add one item, then set its price',
      icon: Icons.receipt_long_rounded,
      kind: _AnswerKind.menuBuilder,
    ),
    _CardQuestion(
      id: 'specialty',
      prompt: 'What is your signature brew?',
      hint: 'Your best-selling drink',
      icon: Icons.local_fire_department_rounded,
      kind: _AnswerKind.text,
      optional: true,
    ),
    _CardQuestion(
      id: 'hours',
      prompt: 'When do you open?',
      hint: 'Example: 6am to 10am',
      icon: Icons.schedule_rounded,
      kind: _AnswerKind.text,
      optional: true,
      quickPicks: ['Early morning', 'Evening', 'All day'],
    ),
  ],
  MerchantCategory.snacks: const [
    _CardQuestion(
      id: 'items',
      prompt: 'Let’s build your menu one item at a time.',
      hint: 'Add one item, then set its price',
      icon: Icons.receipt_long_rounded,
      kind: _AnswerKind.menuBuilder,
    ),
    _CardQuestion(
      id: 'hours',
      prompt: 'When are you open?',
      hint: 'Example: 4pm to 10pm',
      icon: Icons.schedule_rounded,
      kind: _AnswerKind.text,
      optional: true,
      quickPicks: ['Afternoon', 'Evening', 'All day'],
    ),
  ],
  MerchantCategory.salon: const [
    _CardQuestion(
      id: 'items',
      prompt: 'Let’s add your services one at a time.',
      hint: 'Add one service, then set its price',
      icon: Icons.receipt_long_rounded,
      kind: _AnswerKind.menuBuilder,
    ),
    _CardQuestion(
      id: 'hours',
      prompt: 'What are your working hours?',
      hint: 'Example: 10am to 8pm',
      icon: Icons.schedule_rounded,
      kind: _AnswerKind.text,
      optional: true,
      quickPicks: ['10am–8pm', 'All day', 'By appointment'],
    ),
  ],
  MerchantCategory.tailoring: const [
    _CardQuestion(
      id: 'items',
      prompt: 'Let’s add your services one at a time.',
      hint: 'Add one service, then set its price',
      icon: Icons.receipt_long_rounded,
      kind: _AnswerKind.menuBuilder,
    ),
    _CardQuestion(
      id: 'hours',
      prompt: 'How long does an order usually take?',
      hint: 'Example: 3 days, 1 week',
      icon: Icons.schedule_rounded,
      kind: _AnswerKind.text,
      optional: true,
      quickPicks: ['1 day', '3 days', '1 week'],
    ),
  ],
  MerchantCategory.repair: const [
    _CardQuestion(
      id: 'items',
      prompt: 'Let’s add your services one at a time.',
      hint: 'Add one service, then set its price',
      icon: Icons.receipt_long_rounded,
      kind: _AnswerKind.menuBuilder,
    ),
    _CardQuestion(
      id: 'hours',
      prompt: 'When can people reach you?',
      hint: 'Example: 9am to 7pm',
      icon: Icons.schedule_rounded,
      kind: _AnswerKind.text,
      optional: true,
      quickPicks: ['9am–7pm', 'Weekends only', 'All day'],
    ),
  ],
  MerchantCategory.grocery: const [
    _CardQuestion(
      id: 'items',
      prompt: 'Let’s build your list one item at a time.',
      hint: 'Add one item, then set its price',
      icon: Icons.receipt_long_rounded,
      kind: _AnswerKind.menuBuilder,
    ),
    _CardQuestion(
      id: 'hours',
      prompt: 'When is your shop open?',
      hint: 'Example: 7am to 10pm',
      icon: Icons.schedule_rounded,
      kind: _AnswerKind.text,
      optional: true,
      quickPicks: ['Morning–night', 'All day', 'Closed Sunday'],
    ),
  ],
  MerchantCategory.other: const [
    _CardQuestion(
      id: 'items',
      prompt: 'Let’s build your list one item at a time.',
      hint: 'Add one item, then set its price',
      icon: Icons.receipt_long_rounded,
      kind: _AnswerKind.menuBuilder,
    ),
    _CardQuestion(
      id: 'hours',
      prompt: 'When are you open?',
      hint: 'Example: 10am to 8pm',
      icon: Icons.schedule_rounded,
      kind: _AnswerKind.text,
      optional: true,
    ),
  ],
};

class MerchantCardFlow extends StatefulWidget {
  final AppLanguage language;
  final String merchantName;
  final String rawQr;
  final Map<String, String>? initialData;

  const MerchantCardFlow({
    super.key,
    required this.language,
    required this.merchantName,
    required this.rawQr,
    this.initialData,
  });

  @override
  State<MerchantCardFlow> createState() => _MerchantCardFlowState();
}

class _MerchantCardFlowState extends State<MerchantCardFlow>
    with TickerProviderStateMixin {
  final Map<String, String> _answers = {};
  final List<_MenuItem> _menuItems = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  MerchantCategory? _category;
  List<_CardQuestion> _questionBank = List.of(kCommonQuestions);
  bool _aiThinking = false;
  final Map<String, String> _translationCache = {};
  final Map<String, String> _naturalLineCache = {};
  bool _localizing = false;
  late final AnimationController _brandIn;
  late final AnimationController _aiPulse;

  int _index = 0;
  bool _busy = false;
  bool _listening = false;
  bool _finished = false;
  bool _menuAwaitingPrice = false;
  _MenuItem? _menuDraft;
  String? _transientHint; // "Couldn't hear you — try again"
  String? _currentSpokenLine;
  double? _gpsLatitude;
  double? _gpsLongitude;

  // animations
  late final AnimationController _cardIn;
  late final AnimationController _cardOut;
  late final AnimationController _bob;
  late final AnimationController _blink;
  late final AnimationController _mouth;
  late final AnimationController _antenna;
  late final AnimationController _pupil;
  late final AnimationController _reaction;
  _Reaction _reactionKind = _Reaction.idle;
  static const Map<_Reaction, Duration> _reactionDurations = {
    _Reaction.newQuestion: Duration(milliseconds: 900),
    _Reaction.heardAnswer: Duration(milliseconds: 700),
    _Reaction.correct: Duration(milliseconds: 520),
    _Reaction.thinking: Duration(milliseconds: 1200),
    _Reaction.categoryPicked: Duration(milliseconds: 1400),
    _Reaction.finish: Duration(milliseconds: 1400),
    _Reaction.unsure: Duration(milliseconds: 700),
  };

  _RobotExpression _expression = _RobotExpression.happy;

  _CardQuestion get _q => _questionBank[_index];
  int get _total => _questionBank.length;
  double get _progress =>
      _finished ? 1 : (_index + (_aiThinking ? .5 : 0)) / _total;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _answers.addAll(widget.initialData!);
      _finished = true;
    }
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scheduleBlink();
    _mouth = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _antenna = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pupil = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    _cardIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _cardOut = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _brandIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _aiPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _reaction = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Piku greets + speaks first card
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _brandIn.forward();
      unawaited(_prewarmCategoryLabels());
      if (_finished) {
        _cardIn.forward(from: 0);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 350));
      unawaited(_playReaction(_Reaction.newQuestion));
      if (mounted) _speakCurrent();
      _cardIn.forward(from: 0);
    });
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future.delayed(
        Duration(milliseconds: 2200 + math.Random().nextInt(2200)),
      );
      if (!mounted) return;
      await _blink.forward();
      await _blink.reverse();
    }
  }

  Future<void> _speakCurrent() async {
    if (!mounted) return;
    if (_q.kind == _AnswerKind.menuBuilder) {
      await _beginMenuBuilder();
      return;
    }
    setState(() => _localizing = true);
    if (widget.language != AppLanguage.english) {
      await _translateBatch([_q.prompt, _q.hint, ..._q.quickPicks]);
    }
    if (!mounted) return;
    final line = await _naturalQuestionLine(_q);
    if (!mounted) return;
    setState(() {
      _currentSpokenLine = line;
      _localizing = false;
    });
    await VoiceService.speak(
      line,
      language: widget.language,
      cacheToDisk: true,
    );
  }

  Future<void> _beginMenuBuilder() async {
    if (_menuItems.isNotEmpty || _menuAwaitingPrice) return;
    const opening = 'Let’s build your menu. What is the first item?';
    setState(() {
      _localizing = true;
      _currentSpokenLine = null;
      _transientHint = null;
    });
    await _translateBatch([
      opening,
      'Add an item',
      'Price for',
      'Price varies',
      'What else would you like to include?',
      'That’s all',
      'Add at least one item, or skip this step.',
      'Skip this step',
      'Done — that’s my menu',
      'Type an item name…',
      'Price (e.g. 40, Varies)…',
      'item',
      'items',
      'item added',
      'items added',
      'Edit item',
      'Item name',
      'Price (blank means varies)',
      'Cancel',
      'Save',
    ]);
    if (!mounted) return;
    setState(() {
      _localizing = false;
      _currentSpokenLine = _localized(opening);
    });
    await VoiceService.speak(
      _localized(opening),
      language: widget.language,
      cacheToDisk: true,
    );
  }

  Future<void> _speakMenuLine(String line) async {
    await _translateBatch([line]);
    if (!mounted) return;
    await VoiceService.speak(
      _localized(line),
      language: widget.language,
      cacheToDisk: true,
    );
  }

  Future<void> _handleMenuInput(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[.!?,]+$'), '')
        .trim();
    const finishPhrases = {
      "that's all",
      'that is all',
      'thats all',
      'done',
      'no more',
      'nothing else',
      'finish',
      'finished',
      'बस',
      'बस इतना',
      'और नहीं',
      'ಸಾಕು',
      'ಇಷ್ಟೇ',
      'చాలు',
      'ఇంతే',
      'മതി',
      'ഇത്ര മതി',
      'போதும்',
      'அவ்வளவுதான்',
    };
    final saysDone = finishPhrases.contains(normalized);
    if (!_menuAwaitingPrice && saysDone) {
      await _finishMenu();
      return;
    }
    if (_menuAwaitingPrice && saysDone && _menuDraft != null) {
      setState(() {
        _menuDraft!.price = 'Varies';
        _menuItems.add(_menuDraft!);
        _menuDraft = null;
        _menuAwaitingPrice = false;
        _input.clear();
      });
      HapticFeedback.mediumImpact();
      await _finishMenu();
      return;
    }

    setState(() {
      _busy = true;
      _transientHint = null;
    });
    try {
      if (_menuAwaitingPrice && _menuDraft != null) {
        final item = _menuDraft!;
        final price = _extractPrice(text);
        setState(() {
          item.price = price;
          _menuItems.add(item);
          _menuDraft = null;
          _menuAwaitingPrice = false;
          _input.clear();
        });
        HapticFeedback.mediumImpact();
        unawaited(_playReaction(_Reaction.correct));
        await _speakMenuLine(
          'Added ${item.name} for ${item.price}. What else?',
        );
      } else {
        setState(() {
          _menuDraft = _MenuItem(name: text);
          _menuAwaitingPrice = true;
          _input.clear();
        });
        await _speakMenuLine('How much for one $text?');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _extractPrice(String input) {
    final match = RegExp(r'(\d[\d,.]*)').firstMatch(input);
    if (match != null) {
      final number = match
          .group(1)!
          .replaceAll(',', '')
          .replaceAll(RegExp(r'\.$'), '');
      return '₹$number';
    }
    final value = input.trim();
    if (value.toLowerCase().contains('var')) return 'Varies';
    if (value.toLowerCase().contains('free')) return 'Free';
    return value.isEmpty ? 'Varies' : value;
  }

  Future<void> _finishMenu() async {
    if (_menuAwaitingPrice) return;
    if (_menuItems.isEmpty) {
      setState(
        () => _transientHint = _localized(
          'Add at least one item, or skip this step.',
        ),
      );
      return;
    }
    HapticFeedback.selectionClick();
    unawaited(_playReaction(_Reaction.correct));
    final joined = _menuItems
        .map(
          (item) =>
              item.price.isEmpty ? item.name : '${item.name} ${item.price}',
        )
        .join(', ');
    await _advance(answer: joined);
  }

  Future<void> _editMenuItem(_MenuItem item) async {
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price);
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Edit item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (blank means varies)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (saved == true && mounted && nameController.text.trim().isNotEmpty) {
        setState(() {
          item.name = nameController.text.trim();
          item.price = priceController.text.trim();
        });
      }
    } finally {
      nameController.dispose();
      priceController.dispose();
    }
  }

  String _previousAnswerSummary() {
    if (_index == 0) return '';
    final previousQuestion = _questionBank[_index - 1];
    final answer = _answers[previousQuestion.id]?.trim() ?? '';
    return answer.isEmpty ? '' : '${previousQuestion.id}: $answer';
  }

  String _englishPromptFor(_CardQuestion question) => switch (question.id) {
    'business_name' => 'ask what people call their shop',
    'business_type' => 'ask what kind of business they run',
    'items' => 'ask what they sell and the prices',
    'specialty' => 'ask what item or dish customers come back for',
    'hours' => 'ask when the shop is open',
    'location' => 'ask where the shop is and for a nearby landmark',
    'phone' => 'ask for a phone number customers can use to reach them',
    _ => question.prompt,
  };

  Future<String> _naturalQuestionLine(_CardQuestion question) async {
    final previous = _previousAnswerSummary();
    final cacheKey = '${widget.language.code}|${question.id}|$previous';
    final cached = _naturalLineCache[cacheKey];
    if (cached != null) return cached;

    final firstLine = _index == 0
        ? 'Open with a warm, brief introduction: “Hi, I’m Piku.” Then ask the question.'
        : '';
    final context = _category == null
        ? ''
        : 'Their business category is ${_localized(_category!.label)}.';
    final prior = previous.isEmpty
        ? ''
        : 'They just answered: $previous. Acknowledge that answer naturally before asking the next question.';
    final reply = await VoiceService.chat(
      systemPrompt:
          '''
You are Piku, a friendly voice assistant helping an Indian street merchant set up a simple store.
Speak only in ${widget.language.englishName} (${widget.language.nativeName}), using its normal script.
Sound casual, kind and conversational. In one short spoken line (no more than about 18 words), ask for this information: ${_englishPromptFor(question)}.
$firstLine
$context
$prior
Do not ask for any other information. Do not mention forms, fields, AI, or instructions. No emoji, labels, or quotation marks. Return only the exact line to say.
''',
      messages: const [
        {'role': 'user', 'content': 'Say the next line to the merchant.'},
      ],
    ).timeout(const Duration(seconds: 9), onTimeout: () => '');

    final line = reply.trim().replaceAll(RegExp(r'^[“”"\s]+|[“”"\s]+$'), '');
    final result = line.isEmpty ? _localized(question.prompt) : line;
    _naturalLineCache[cacheKey] = result;
    return result;
  }

  String _translationKey(String text) => '${widget.language.code}|$text';

  String _localized(String text) =>
      _translationCache[_translationKey(text)] ?? text;

  Future<void> _translateBatch(Iterable<String> sourceTexts) async {
    if (widget.language == AppLanguage.english) return;
    final texts = sourceTexts
        .toSet()
        .where(
          (text) =>
              text.trim().isNotEmpty &&
              !_translationCache.containsKey(_translationKey(text)),
        )
        .toList();
    if (texts.isEmpty) return;
    for (var start = 0; start < texts.length; start += 8) {
      final end = math.min(start + 8, texts.length);
      await _translateChunk(texts.sublist(start, end));
    }
  }

  Future<void> _translateChunk(List<String> texts) async {
    final indexed = {for (var i = 0; i < texts.length; i++) '$i': texts[i]};
    final response = await VoiceService.chat(
      systemPrompt:
          'Translate every value in the JSON object into ${widget.language.englishName}. '
          'Return only a valid JSON object with the same keys and translated string values. '
          'Preserve numbers, prices, punctuation, and names. Do not explain.',
      messages: [
        {'role': 'user', 'content': jsonEncode(indexed)},
      ],
    );
    if (response.isEmpty) return;
    try {
      var jsonResponse = response.trim();
      if (jsonResponse.startsWith('```')) {
        jsonResponse = jsonResponse
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '');
      }
      final decoded = jsonDecode(jsonResponse) as Map<String, dynamic>;
      for (var i = 0; i < texts.length; i++) {
        final translated = decoded['$i'];
        if (translated is String && translated.trim().isNotEmpty) {
          _translationCache[_translationKey(texts[i])] = translated.trim();
        }
      }
    } catch (_) {
      // Keep source text when the translation service doesn't return valid JSON.
    }
  }

  Future<void> _prewarmCategoryLabels() async {
    await _translateBatch([
      ...MerchantCategory.values.map((category) => category.label),
      'Preparing your language…',
      'Type or speak…',
      'Say your area',
      'Skip this question',
      "Couldn't hear you — try again or type it",
      'Let me prepare the right questions.',
      'All done! Here is your menu card.',
      'Type your area or use GPS',
      'Use my current location',
      'Locating…',
      'Location permission denied. Enable it in settings.',
      'Could not get your location',
      'Retry',
      'Save location',
      'Piku is thinking…',
      'MENU CARD',
      'No items captured yet.',
      'Famous for:',
      'Start over',
      'Publish',
      'Powered by Paytm Buddy',
      'Piku is preparing your questions…',
      'A few tailored to your business',
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _playReaction(_Reaction kind) async {
    if (!mounted) return;
    _reaction.stop(canceled: false);
    _reactionKind = kind;
    _reaction.duration =
        _reactionDurations[kind] ?? const Duration(milliseconds: 800);
    await _reaction.forward(from: 0);
    if (!mounted || _reactionKind != kind) return;
    _reactionKind = _Reaction.idle;
    _reaction.value = 0;
    setState(() => _expression = _RobotExpression.happy);
  }

  Future<void> _advance({String? answer}) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (answer != null && answer.trim().isNotEmpty) {
      _answers[_q.id] = answer.trim();
    }
    await _cardOut.forward(from: 0);
    if (!mounted) return;

    if (_index >= _questionBank.length - 1) {
      await _playReaction(_Reaction.finish);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _finished = true;
      });
      _cardIn.forward(from: 0);
      _speakFinish();
      return;
    }
    setState(() {
      _index += 1;
      _busy = false;
      _expression = _RobotExpression.happy;
      _transientHint = null;
    });
    _input.clear();
    _cardIn.forward(from: 0);
    unawaited(_playReaction(_Reaction.newQuestion));
    await _speakCurrent();
  }

  Future<void> _pickCategory(MerchantCategory category) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _aiThinking = true;
      _category = category;
      _answers['business_type'] = category.label;
      _expression = _RobotExpression.thinking;
    });
    unawaited(_playReaction(_Reaction.categoryPicked));
    const confirmation = 'Let me prepare the right questions.';
    await _translateBatch([category.label, confirmation]);
    final localizedCategory = _localized(category.label);
    final localizedConfirmation = _localized(confirmation);
    _answers['business_type'] = localizedCategory;
    await VoiceService.speak(
      '$localizedCategory. $localizedConfirmation',
      language: widget.language,
      cacheToDisk: true,
    );
    unawaited(_playReaction(_Reaction.thinking));
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _questionBank = [
        ...kCommonQuestions,
        ...(kCategoryQuestions[category] ?? const <_CardQuestion>[]),
        ...kClosingQuestions,
      ];
      _busy = false;
      _aiThinking = false;
      _expression = _RobotExpression.excited;
    });
    await _advance();
  }

  Future<void> _skip() async {
    if (!_q.optional) return;
    await _advance();
  }

  Future<void> _onMic() async {
    if (_busy || _listening) return;
    setState(() {
      _listening = true;
      _expression = _RobotExpression.listening;
      _transientHint = null;
    });
    final text = await VoiceService.recordAndTranscribe(
      seconds: 3,
      language: widget.language,
    );
    if (!mounted) return;
    setState(() => _listening = false);
    if (text == null || text.isEmpty) {
      setState(() {
        _expression = _RobotExpression.confused;
        _transientHint = _localized("Couldn't hear you — try again or type it");
      });
      unawaited(_playReaction(_Reaction.unsure));
      return;
    }
    if (_q.kind == _AnswerKind.menuBuilder) {
      await _handleMenuInput(text);
    } else {
      await _submit(text);
    }
  }

  Future<void> _submit(String raw) async {
    if (_busy) return;
    final text = raw.trim();
    if (text.isEmpty) return;
    if (_q.kind == _AnswerKind.menuBuilder) {
      await _handleMenuInput(text);
      return;
    }
    setState(() {
      _expression = _RobotExpression.thinking;
      _busy = true;
    });
    unawaited(_playReaction(_Reaction.thinking));
    // Give an AI-shaped response per kind so the user feels understood
    final polished = await _formatForCard(_q, text);
    if (!mounted) return;
    await _playReaction(_Reaction.correct);
    if (!mounted) return;
    setState(() => _busy = false);
    await _advance(answer: polished);
  }

  Future<String> _formatForCard(_CardQuestion q, String raw) async {
    // For prices/lists, let GPT structure them once; for simple text, pass through
    if (q.kind != _AnswerKind.list && q.kind != _AnswerKind.price) {
      return raw;
    }
    if (!raw.contains(',') && !raw.contains('\n')) return raw;
    final reply = await VoiceService.chat(
      systemPrompt:
          'Format a merchant answer as a clean comma-separated list. '
          'Preserve the original language (${widget.language.englishName}), '
          'item names and numbers exactly. Do not add items. '
          'Reply only with the formatted list.',
      messages: [
        {'role': 'user', 'content': raw},
      ],
    );
    return reply.isEmpty ? raw : reply;
  }

  Future<void> _speakFinish() async {
    const finishText = 'All done! Here is your menu card.';
    await _translateBatch([finishText]);
    await VoiceService.speak(
      _localized(finishText),
      language: widget.language,
      cacheToDisk: true,
    );
  }

  void _restart() {
    setState(() {
      _answers.clear();
      _menuItems.clear();
      _menuDraft = null;
      _menuAwaitingPrice = false;
      _category = null;
      _questionBank = List.of(kCommonQuestions);
      _index = 0;
      _finished = false;
      _input.clear();
      _transientHint = null;
      _expression = _RobotExpression.happy;
    });
    _cardIn.forward(from: 0);
    unawaited(_playReaction(_Reaction.newQuestion));
    _speakCurrent();
  }

  @override
  void dispose() {
    _bob.dispose();
    _blink.dispose();
    _mouth.dispose();
    _antenna.dispose();
    _pupil.dispose();
    _cardIn.dispose();
    _cardOut.dispose();
    _input.dispose();
    _scroll.dispose();
    _brandIn.dispose();
    _aiPulse.dispose();
    _reaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaytmColors.inkTop,
      body: Stack(
        children: [
          const Positioned.fill(child: _TreacleBackdrop()),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _bob,
                builder: (context, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.3),
                      radius: 1.5,
                      colors: [
                        PaytmColors.paytmBlue.withOpacity(
                          0.15 + _bob.value * 0.05,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _reaction,
                builder: (context, _) => _reactionKind == _Reaction.finish
                    ? CustomPaint(
                        painter: _FinishConfettiPainter(_reaction.value),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _BrandBar(
                  merchantName: widget.merchantName,
                  progress: _progress,
                  anim: _brandIn,
                  onBack: () => Navigator.of(context).pop(),
                ),
                if (!_finished)
                  Expanded(
                    child: Stack(
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.none,
                      children: [
                        if (_aiThinking || _localizing)
                          Positioned(
                            top: 20,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _ThinkingRadar(animation: _aiPulse),
                            ),
                          ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 215,
                          child: AnimatedBuilder(
                            animation: Listenable.merge([
                              _bob,
                              _blink,
                              _mouth,
                              _antenna,
                              _pupil,
                              _cardIn,
                              _reaction,
                              VoiceService.speakingListenable,
                            ]),
                            builder: (context, _) {
                              final speaking = VoiceService.isSpeaking;
                              final pose = _poseFor(
                                _reactionKind,
                                _reaction.value,
                              );
                              final bob =
                                  math.sin(_bob.value * math.pi * 2) * 6;
                              final lean =
                                  math.sin(_cardIn.value * math.pi) * .1;
                              final expression =
                                  pose.expressionOverride ??
                                  (speaking
                                      ? _RobotExpression.speaking
                                      : _expression);
                              final mouth = pose.mouthOpen > 0
                                  ? pose.mouthOpen
                                  : (speaking
                                        ? _speechMouthOpening(_mouth.value)
                                        : 0.0);
                              return Center(
                                child: Transform.translate(
                                  offset: Offset(0, bob + pose.jump),
                                  child: Transform.scale(
                                    scale: .65,
                                    alignment: Alignment.topCenter,
                                    child: Transform.scale(
                                      scaleX: 1 + (pose.squash - 1) * .45,
                                      scaleY: 1 - (pose.squash - 1),
                                      child: Transform.rotate(
                                        angle: lean + pose.headTilt,
                                        alignment: Alignment.bottomCenter,
                                        child: _PremiumRobot(
                                          blink: _blink.value,
                                          wave: 0,
                                          showWave: false,
                                          antennaPulse: pose.antennaFlash > 0
                                              ? pose.antennaFlash
                                              : _antenna.value,
                                          pupil: _pupil.value,
                                          expression: expression,
                                          mouthFlap: mouth,
                                          extraHeadTilt: pose.headTilt,
                                          rightArmOverride: pose.armAngle,
                                          pupilLook: pose.pupilLook,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (!_aiThinking)
                          Positioned(
                            top: 210,
                            left: 20,
                            right: 20,
                            bottom: 0,
                            child: AnimatedBuilder(
                              animation: _cardIn,
                              builder: (context, child) {
                                final t = Curves.easeOutBack
                                    .transform(_cardIn.value.clamp(0.0, 1.0))
                                    .clamp(0.0, 1.0);
                                return Transform.translate(
                                  offset: Offset(0, (1 - t) * 36),
                                  child: Opacity(opacity: t, child: child),
                                );
                              },
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(
                                  top: 12,
                                  bottom: 8,
                                ),
                                child: _buildSpeechBubble(),
                              ),
                            ),
                          ),
                        if (_aiThinking)
                          Positioned(
                            bottom: 36,
                            child: _buildThinkingIndicator(),
                          ),
                      ],
                    ),
                  ),
                if (_aiThinking) const SizedBox(height: 12),
                if (!_finished && !_aiThinking && !_localizing)
                  _buildInputDock(),
                if (_finished) Expanded(child: _buildMenuCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechBubble() {
    final q = _q;
    if (q.kind == _AnswerKind.menuBuilder && !_localizing) {
      return _buildMenuBuilderBubble();
    }
    final isCategory = q.kind == _AnswerKind.category;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.95),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: PaytmColors.paytmBlue.withOpacity(.2),
                blurRadius: 30,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: _localizing
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PaytmColors.paytmBlue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _localized('Piku is thinking…'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PaytmColors.deepNavy.withOpacity(.75),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentSpokenLine ?? _localized(q.prompt),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        height: 1.32,
                        fontWeight: FontWeight.w900,
                        color: PaytmColors.deepNavy,
                        letterSpacing: -.3,
                      ),
                    ),
                    if (_localized(q.hint).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _localized(q.hint),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: PaytmColors.deepNavy.withOpacity(.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (!isCategory && q.quickPicks.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: q.quickPicks
                            .map(
                              (pick) => GestureDetector(
                                onTap: _busy ? null : () => _submit(pick),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PaytmColors.iceBlue,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: PaytmColors.paytmBlue.withOpacity(
                                        .3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _localized(pick),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: PaytmColors.deepNavy,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (isCategory) ...[
                      const SizedBox(height: 14),
                      _buildCategoryGrid(),
                    ],
                  ],
                ),
        ),
        Positioned(
          top: -12,
          child: CustomPaint(
            size: const Size(24, 14),
            painter: _BubbleTailUpPainter(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuBuilderBubble() {
    final hasItems = _menuItems.isNotEmpty;
    final header = _menuAwaitingPrice
        ? '${_localized('Price for')} ${_menuDraft?.name ?? ''}?'
        : hasItems
        ? '${_menuItems.length} ${_localized(_menuItems.length == 1 ? 'item added' : 'items added')}'
        : _localized('Add an item');
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.97),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: PaytmColors.paytmBlue.withOpacity(.22),
                blurRadius: 26,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PaytmColors.iceBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      color: PaytmColors.deepNavy,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      header,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: PaytmColors.deepNavy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (hasItems)
                ..._menuItems.map(
                  (item) => _MenuItemRow(
                    item: item,
                    onEdit: () => _editMenuItem(item),
                    onRemove: () {
                      HapticFeedback.selectionClick();
                      setState(() => _menuItems.remove(item));
                    },
                  ),
                ),
              if (_menuAwaitingPrice)
                _buildPricePrompt()
              else
                _buildAddItemRow(),
              if (_menuAwaitingPrice)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => unawaited(_handleMenuInput('Varies')),
                    child: Text(_localized('Price varies')),
                  ),
                ),
              const SizedBox(height: 10),
              if (hasItems && !_menuAwaitingPrice)
                ElevatedButton.icon(
                  onPressed: _busy ? null : _finishMenu,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(_localized('Done — that’s my menu')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PaytmColors.gold,
                    foregroundColor: PaytmColors.deepNavy,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                )
              else if (!hasItems)
                TextButton(
                  onPressed: _busy ? null : () => _advance(),
                  child: Text(_localized('Skip this step')),
                ),
              if (_transientHint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _transientHint!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          top: -12,
          child: CustomPaint(
            size: const Size(24, 14),
            painter: _BubbleTailUpPainter(),
          ),
        ),
      ],
    );
  }

  Widget _buildAddItemRow() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: PaytmColors.iceBlue,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: PaytmColors.paytmBlue.withOpacity(.35)),
    ),
    child: Row(
      children: [
        const Icon(Icons.add_rounded, color: PaytmColors.paytmBlue, size: 20),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _input,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => unawaited(_handleMenuInput(value)),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: PaytmColors.deepNavy,
            ),
            decoration: InputDecoration(
              hintText: _localized('Type an item name…'),
              hintStyle: const TextStyle(
                color: PaytmColors.deepNavy,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        _MicBubble(listening: _listening, onTap: _onMic, compact: true),
      ],
    ),
  );

  Widget _buildPricePrompt() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: PaytmColors.gold.withOpacity(.18),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: PaytmColors.goldDeep.withOpacity(.45)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.currency_rupee_rounded,
          color: PaytmColors.goldDeep,
          size: 20,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _input,
            enabled: !_busy,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onTap: HapticFeedback.selectionClick,
            onSubmitted: (value) => unawaited(_handleMenuInput(value)),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: PaytmColors.deepNavy,
            ),
            decoration: InputDecoration(
              hintText: _localized('Price (e.g. 40, Varies)…'),
              hintStyle: const TextStyle(
                color: PaytmColors.deepNavy,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        _MicBubble(listening: _listening, onTap: _onMic, compact: true),
      ],
    ),
  );

  Widget _buildThinkingIndicator() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.95),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(color: PaytmColors.paytmBlue.withOpacity(.2), blurRadius: 20),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: PaytmColors.paytmBlue,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _localized('Piku is thinking…'),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: PaytmColors.deepNavy.withOpacity(.8),
          ),
        ),
      ],
    ),
  );

  Widget _buildInputDock() {
    final q = _q;
    if (q.kind == _AnswerKind.category) return const SizedBox.shrink();
    if (q.kind == _AnswerKind.menuBuilder) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(.1))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_transientHint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _transientHint!,
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (q.kind == _AnswerKind.location)
            _LocationField(
              key: const ValueKey('location_field'),
              busy: _busy,
              hintText: _localized('Type your area or use GPS'),
              useCurrentLabel: _localized('Use my current location'),
              locatingLabel: _localized('Locating…'),
              permissionDeniedLabel: _localized(
                'Location permission denied. Enable it in settings.',
              ),
              unavailableLabel: _localized('Could not get your location'),
              retryLabel: _localized('Retry'),
              saveLabel: _localized('Save location'),
              onSubmit: (value) => unawaited(_submit(value)),
              onPosition: (position) => setState(() {
                _gpsLatitude = position.latitude;
                _gpsLongitude = position.longitude;
              }),
            )
          else
            Row(
              children: [
                _MicBubble(listening: _listening, onTap: _onMic),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(_input.text),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: PaytmColors.deepNavy,
                      ),
                      decoration: InputDecoration(
                        hintText: _localized('Type or speak…'),
                        hintStyle: TextStyle(
                          color: PaytmColors.deepNavy.withOpacity(.3),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 17,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _busy ? null : () => _submit(_input.text),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: PaytmColors.ctaGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: PaytmColors.gold.withOpacity(.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: PaytmColors.deepNavy,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_upward_rounded,
                              color: PaytmColors.deepNavy,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          if (q.optional) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _skip,
              child: Text(
                _localized('Skip this question'),
                style: TextStyle(
                  color: Colors.white.withOpacity(.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: MerchantCategory.values.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (context, index) {
        final category = MerchantCategory.values[index];
        final label = _localized(category.label);
        return GestureDetector(
          onTap: _busy ? null : () => _pickCategory(category),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: PaytmColors.iceBlue,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PaytmColors.paytmBlue.withOpacity(.2)),
            ),
            child: Row(
              children: [
                Text(category.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: PaytmColors.deepNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThinkingCard() => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _aiPulse,
          builder: (context, _) => Transform.scale(
            scale: 1 + _aiPulse.value * .08,
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                gradient: PaytmColors.logoGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _localized('Piku is preparing your questions…'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: PaytmColors.deepNavy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _localized('A few tailored to your business'),
          style: TextStyle(
            fontSize: 12,
            color: PaytmColors.deepNavy.withOpacity(.5),
          ),
        ),
      ],
    ),
  );

  // ---------- MENU CARD ----------
  Widget _buildMenuCard() {
    final name = _answers['business_name'] ?? widget.merchantName;
    final type = _answers['business_type'] ?? _category?.label ?? 'Business';
    final itemsRaw = _answers['items'] ?? '';
    final specialty = _answers['specialty'] ?? '';
    final hours = _answers['hours'] ?? '';
    final location = _answers['location'] ?? '';
    final phone = _answers['phone'] ?? '';
    final extras = _answers['extras'] ?? '';

    final items = _parseItems(itemsRaw);

    return Container(
      key: const ValueKey('menu'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [PaytmColors.deepNavy, Color(0xFF003B8E)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: PaytmColors.gold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _localized('MENU CARD'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: PaytmColors.deepNavy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Items
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                child: Column(
                  children: items.isEmpty
                      ? [
                          Text(
                            _localized('No items captured yet.'),
                            style: TextStyle(
                              color: PaytmColors.deepNavy.withOpacity(0.5),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ]
                      : items.map((it) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: PaytmColors.paytmBlue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    it.$1,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: PaytmColors.deepNavy,
                                    ),
                                  ),
                                ),
                                if (it.$2.isNotEmpty)
                                  Text(
                                    it.$2,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: PaytmColors.goldDeep,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                ),
              ),

              if (specialty.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                  child: Text(
                    '${_localized('Famous for:')} $specialty',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: PaytmColors.deepNavy,
                    ),
                  ),
                ),

              // Meta chips
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hours.isNotEmpty)
                      _MetaChip(icon: Icons.schedule_rounded, label: hours),
                    if (location.isNotEmpty)
                      _MetaChip(
                        icon: Icons.location_on_rounded,
                        label: location,
                      ),
                    if (phone.isNotEmpty)
                      _MetaChip(icon: Icons.phone_rounded, label: phone),
                    if (extras.isNotEmpty)
                      _MetaChip(icon: Icons.local_offer_rounded, label: extras),
                  ],
                ),
              ),

              // Divider + actions
              Divider(color: PaytmColors.deepNavy.withOpacity(0.08)),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _restart,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(_localized('Start over')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PaytmColors.deepNavy,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _onPublish,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Text(_localized('Publish')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PaytmColors.paytmBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onPublish() async {
    if (_busy) return;
    setState(() => _busy = true);
    unawaited(_playReaction(_Reaction.finish));
    final published = <String, String>{
      if ((widget.initialData?['id'] ?? widget.initialData?['_id']) != null)
        '_id': (widget.initialData?['id'] ?? widget.initialData?['_id'])!,
      'business_name': _answers['business_name'] ?? widget.merchantName,
      'business_type': _answers['business_type'] ?? (_category?.label ?? ''),
      'items': _answers['items'] ?? '',
      'specialty': _answers['specialty'] ?? '',
      'hours': _answers['hours'] ?? '',
      'location': _answers['location'] ?? '',
      'phone': _answers['phone'] ?? '',
      'extras': _answers['extras'] ?? '',
    };
    final menuPrices = _menuItems
        .map(
          (item) =>
              double.tryParse(item.price.replaceAll(RegExp(r'[^0-9.]'), '')),
        )
        .whereType<double>()
        .where((price) => price.isFinite && price >= 0)
        .toList();
    if (menuPrices.isNotEmpty) {
      published['minPrice'] = menuPrices
          .reduce((left, right) => left < right ? left : right)
          .toString();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (widget.initialData == null || widget.initialData!.isEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SetPasswordScreen(
            language: widget.language,
            answers: published,
            latitude: _gpsLatitude,
            longitude: _gpsLongitude,
          ),
        ),
      );
      return;
    }
    try {
      final storeId = await StoreRepository.saveStore(
        published,
        latitude: _gpsLatitude,
        longitude: _gpsLongitude,
      );
      published['_id'] = storeId;
    } catch (error) {
      debugPrint('Could not update merchant locally: $error');
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => PublishedCardScreen(
          language: widget.language,
          answers: published,
          merchantAccountName: published['business_name'],
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          ),
          child: child,
        ),
      ),
    );
  }

  List<(String, String)> _parseItems(String raw) {
    // Tries to split "Gobi 40, Noodles 50" → [("Gobi","₹40"), ("Noodles","₹50")]
    if (raw.trim().isEmpty) return const [];
    final pieces = raw.split(RegExp(r'[,;\n]'));
    final result = <(String, String)>[];
    final priceRegex = RegExp(r'(\d+)');
    for (var piece in pieces) {
      final p = piece.trim();
      if (p.isEmpty) continue;
      final match = priceRegex.firstMatch(p);
      if (match != null) {
        final price = match.group(1)!;
        var namePart = p.replaceFirst(match.group(0)!, '').trim();
        namePart = namePart
            .replaceAll(
              RegExp(r'^(rs\.?|rupees?|₹)\s*', caseSensitive: false),
              '',
            )
            .replaceAll(RegExp(r'[\-–:]+$'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (namePart.isEmpty) namePart = p;
        result.add((namePart, '₹$price'));
      } else {
        result.add((p, ''));
      }
    }
    return result;
  }
}

class _BubbleTailUpPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = Colors.white.withOpacity(.95);
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ThinkingRadar extends StatelessWidget {
  final Animation<double> animation;

  const _ThinkingRadar({required this.animation});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) => SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 3; i++) _buildRing((animation.value + i / 3) % 1),
        ],
      ),
    ),
  );

  Widget _buildRing(double progress) {
    final diameter = 58 + 122 * progress;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: PaytmColors.paytmBlue.withOpacity(1 - progress),
          width: 2.5,
        ),
      ),
    );
  }
}

class _FinishConfettiPainter extends CustomPainter {
  final double progress;
  const _FinishConfettiPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final fade = (1 - progress).clamp(0.0, 1.0);
    const colors = [
      PaytmColors.paytmBlue,
      PaytmColors.gold,
      Color(0xFF7FE7F5),
      Color(0xFFFF9DB0),
    ];
    for (var i = 0; i < 28; i++) {
      final angle = (i / 28) * math.pi * 2;
      final distance = t * (90 + (i % 6) * 18);
      final center =
          Offset(size.width / 2, size.height * .42) +
          Offset(math.cos(angle), math.sin(angle)) * distance;
      final paint = Paint()
        ..color = colors[i % colors.length].withOpacity(.85 * fade);
      if (i.isEven) {
        canvas.drawCircle(center, 3 + (i % 3).toDouble(), paint);
      } else {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle + progress * math.pi * 4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-2, -5, 4, 10),
            const Radius.circular(1),
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FinishConfettiPainter old) =>
      old.progress != progress;
}

// ---------- Small shared widgets ----------

class _BrandBar extends StatelessWidget {
  final String merchantName;
  final double progress;
  final Animation<double> anim;
  final VoidCallback onBack;
  const _BrandBar({
    required this.merchantName,
    required this.progress,
    required this.anim,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              _CircleIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
              const SizedBox(width: 14),
              Expanded(
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, -.4),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: anim,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                    child: Row(
                      children: [
                        const _PaytmLogo(size: 18),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 14,
                          color: Colors.white.withOpacity(.3),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            merchantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(height: 6, color: Colors.white.withOpacity(.1)),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 400),
                  widthFactor: progress.clamp(.02, 1),
                  child: Container(
                    height: 6,
                    decoration: const BoxDecoration(
                      gradient: PaytmColors.ctaGradient,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final double progress;
  final VoidCallback onBack;
  const _TopBar({required this.progress, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          _CircleIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Container(height: 8, color: Colors.white.withOpacity(0.1)),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 400),
                    widthFactor: progress.clamp(0.05, 1.0),
                    child: Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        gradient: PaytmColors.ctaGradient,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MicBubble extends StatelessWidget {
  final bool listening;
  final VoidCallback onTap;
  final bool compact;
  const _MicBubble({
    required this.listening,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 38.0 : 52.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: listening ? const Color(0xFFFF7043) : PaytmColors.paytmBlue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color:
                  (listening ? const Color(0xFFFF7043) : PaytmColors.paytmBlue)
                      .withOpacity(0.4),
              blurRadius: listening ? 20 : 10,
              spreadRadius: listening ? 3 : 0,
            ),
          ],
        ),
        child: Icon(
          listening ? Icons.mic : Icons.mic_none_rounded,
          color: Colors.white,
          size: compact ? 19 : 24,
        ),
      ),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final _MenuItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _MenuItemRow({
    required this.item,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: PaytmColors.iceBlue,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: PaytmColors.paytmBlue.withOpacity(.22)),
    ),
    child: Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: PaytmColors.paytmBlue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: PaytmColors.deepNavy,
            ),
          ),
        ),
        if (item.price.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              item.price,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: PaytmColors.goldDeep,
              ),
            ),
          ),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          icon: const Icon(
            Icons.edit_rounded,
            size: 16,
            color: PaytmColors.paytmBlue,
          ),
          onPressed: onEdit,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          icon: Icon(Icons.close_rounded, size: 16, color: Colors.red.shade300),
          onPressed: onRemove,
        ),
      ],
    ),
  );
}

class _SoftButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SoftButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: PaytmColors.iceBlue,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: PaytmColors.paytmBlue.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: PaytmColors.deepNavy, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: PaytmColors.deepNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: PaytmColors.iceBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: PaytmColors.deepNavy),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PaytmColors.deepNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationField extends StatefulWidget {
  final String? initialText;
  final String hintText;
  final String useCurrentLabel;
  final String locatingLabel;
  final String permissionDeniedLabel;
  final String unavailableLabel;
  final String retryLabel;
  final String saveLabel;
  final bool busy;
  final ValueChanged<String> onSubmit;
  final ValueChanged<Position>? onPosition;

  const _LocationField({
    super.key,
    required this.hintText,
    required this.useCurrentLabel,
    required this.locatingLabel,
    required this.permissionDeniedLabel,
    required this.unavailableLabel,
    required this.retryLabel,
    required this.saveLabel,
    required this.busy,
    required this.onSubmit,
    this.onPosition,
    this.initialText,
  });

  @override
  State<_LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<_LocationField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText ?? '',
  );
  bool _fetching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    if (_fetching || widget.busy) return;
    setState(() {
      _fetching = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationFailure(_LocationFailureKind.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _LocationFailure(_LocationFailureKind.permissionDenied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      widget.onPosition?.call(position);

      var address = '';
      try {
        final marks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (marks.isNotEmpty) {
          final place = marks.first;
          final parts =
              <String?>[
                    place.name,
                    place.street,
                    place.subLocality,
                    place.locality,
                    place.administrativeArea,
                    place.postalCode,
                  ]
                  .where((part) => part != null && part.trim().isNotEmpty)
                  .map((part) => part!.trim())
                  .toSet()
                  .toList();
          address = parts.take(4).join(', ');
        }
      } catch (_) {
        // Use coordinates when the platform geocoder has no result.
      }
      if (address.isEmpty) {
        address =
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}';
      }

      if (!mounted) return;
      setState(() {
        _error = null;
        _controller.text = address;
      });
      HapticFeedback.lightImpact();
    } on _LocationFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = failure.kind == _LocationFailureKind.permissionDenied
            ? widget.permissionDeniedLabel
            : widget.unavailableLabel;
      });
    } catch (error) {
      debugPrint('Location lookup error: $error');
      if (mounted) setState(() => _error = widget.unavailableLabel);
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _retryOrOpenSettings() async {
    if (await Geolocator.checkPermission() ==
        LocationPermission.deniedForever) {
      await openAppSettings();
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return;
    }
    await _useMyLocation();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty && !widget.busy && !_fetching) {
      widget.onSubmit(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: widget.busy || _fetching ? null : _useMyLocation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56,
            decoration: BoxDecoration(
              gradient: PaytmColors.logoGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: PaytmColors.paytmBlue.withOpacity(.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_fetching)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    Icons.my_location_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Text(
                  _fetching ? widget.locatingLabel : widget.useCurrentLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFF8A80),
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF8A80),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.busy || _fetching
                    ? null
                    : _retryOrOpenSettings,
                style: TextButton.styleFrom(
                  foregroundColor: PaytmColors.gold,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(widget.retryLabel),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.done,
            maxLines: 2,
            minLines: 1,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: PaytmColors.deepNavy,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.location_on_rounded,
                color: PaytmColors.paytmBlue,
                size: 20,
              ),
              hintText: widget.hintText,
              hintStyle: TextStyle(color: PaytmColors.deepNavy.withOpacity(.3)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: widget.busy || _fetching || !hasText ? null : _submit,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: hasText ? 1 : .5,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: PaytmColors.ctaGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: PaytmColors.gold.withOpacity(.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_rounded,
                    color: PaytmColors.deepNavy,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.saveLabel,
                    style: const TextStyle(
                      color: PaytmColors.deepNavy,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _LocationFailureKind { permissionDenied, serviceDisabled }

class _LocationFailure implements Exception {
  final _LocationFailureKind kind;
  const _LocationFailure(this.kind);
}

class PublishedCardScreen extends StatefulWidget {
  final AppLanguage language;
  final Map<String, String> answers;
  final bool readOnly;
  final String? merchantAccountName;

  const PublishedCardScreen({
    super.key,
    required this.language,
    required this.answers,
    this.readOnly = false,
    this.merchantAccountName,
  });

  @override
  State<PublishedCardScreen> createState() => _PublishedCardScreenState();
}

class _PublishedCardScreenState extends State<PublishedCardScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  final Map<String, String> _copy = {};
  late final AnimationController _confetti;
  bool _exporting = false;

  String get _qrPayload => jsonEncode({
    'v': 1,
    'type': 'piku_store',
    'id': widget.answers['_id'] ?? '',
    'name': widget.answers['business_name'] ?? '',
    'category': widget.answers['business_type'] ?? '',
    'items': widget.answers['items'] ?? '',
    'specialty': widget.answers['specialty'] ?? '',
    'hours': widget.answers['hours'] ?? '',
    'location': widget.answers['location'] ?? '',
    'phone': widget.answers['phone'] ?? '',
    'extras': widget.answers['extras'] ?? '',
  });

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();
    unawaited(_translateCopy());
  }

  String _text(String source) => _copy[source] ?? source;

  Future<void> _translateCopy() async {
    if (widget.language == AppLanguage.english) return;
    const lines = [
      'Your menu card is ready',
      'Menu card',
      'Show QR',
      'Save',
      'Share',
      'Scan to view this menu',
      'This QR stores the menu details. Scan it with Piku to open the card.',
      'Close',
      'Menu image saved on this device.',
      'Could not export the menu card.',
      'MENU',
      'Ask us for today’s menu',
      'Famous for:',
      'Powered by Paytm Buddy',
    ];
    final indexed = {for (var i = 0; i < lines.length; i++) '$i': lines[i]};
    final response = await VoiceService.chat(
      systemPrompt:
          'Translate every value in this JSON object into ${widget.language.englishName} (${widget.language.nativeName}), using its normal script. Preserve brand names. Return only valid JSON with the same keys and translated string values.',
      messages: [
        {'role': 'user', 'content': jsonEncode(indexed)},
      ],
    ).timeout(const Duration(seconds: 8), onTimeout: () => '');
    if (!mounted || response.isEmpty) return;
    try {
      final decoded = jsonDecode(response) as Map<String, dynamic>;
      setState(() {
        for (var i = 0; i < lines.length; i++) {
          final translated = decoded['$i'];
          if (translated is String && translated.trim().isNotEmpty) {
            _copy[lines[i]] = translated.trim();
          }
        }
      });
    } catch (_) {
      // Keep the English labels if translation does not return valid JSON.
    }
  }

  Future<Uint8List?> _captureCard() async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = _cardKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return null;
      final image = await renderObject.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (error) {
      debugPrint('Menu card export failed: $error');
      return null;
    }
  }

  Future<void> _export({required bool share}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _captureCard();
      if (bytes == null) throw Exception('Could not render the menu card.');
      final directory = share
          ? await getTemporaryDirectory()
          : await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/piku_menu_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (share) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/png')],
          text:
              '${widget.answers['business_name'] ?? 'My Store'} — ${_text('Menu card')}',
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_text('Menu image saved on this device.'))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_text('Could not export the menu card.')}: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showQr() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _text('Scan to view this menu'),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: PaytmColors.deepNavy,
              ),
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: _qrPayload,
              version: QrVersions.auto,
              size: 240,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              _text(
                'This QR stores the menu details. Scan it with Piku to open the card.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: PaytmColors.deepNavy.withOpacity(.65)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_text('Close')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaytmColors.inkTop,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (_, __) => CustomPaint(
                  painter: _FinishConfettiPainter(_confetti.value),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      if (widget.readOnly) ...[
                        _CircleIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 12),
                      ] else ...[
                        const _PaytmLogo(size: 20),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          widget.readOnly
                              ? _text('Menu card')
                              : _text('Your menu card is ready'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (!widget.readOnly &&
                          widget.merchantAccountName != null) ...[
                        TextButton.icon(
                          onPressed: () => Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Log out'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(
                  height: 132,
                  child: Transform.scale(
                    scale: .48,
                    alignment: Alignment.topCenter,
                    child: const _PremiumRobot(
                      blink: 0,
                      wave: 0,
                      showWave: false,
                      antennaPulse: .5,
                      pupil: .5,
                      expression: _RobotExpression.excited,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Center(
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: _PublishedMenuCard(
                          answers: widget.answers,
                          qrPayload: _qrPayload,
                          menuLabel: _text('MENU'),
                          emptyItemsLabel: _text('Ask us for today’s menu'),
                          famousLabel: _text('Famous for:'),
                          poweredByLabel: _text('Powered by Paytm Buddy'),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _PublishedAction(
                              icon: Icons.qr_code_2_rounded,
                              label: _text('Show QR'),
                              onTap: _showQr,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _PublishedAction(
                              icon: Icons.download_rounded,
                              label: _text('Save'),
                              onTap: _exporting
                                  ? null
                                  : () => _export(share: false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _PublishedAction(
                              icon: Icons.ios_share_rounded,
                              label: _text('Share'),
                              onTap: _exporting
                                  ? null
                                  : () => _export(share: true),
                              highlighted: true,
                            ),
                          ),
                        ],
                      ),
                      if (!widget.readOnly &&
                          widget.merchantAccountName != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _confirmDeleteAccount,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text(
                            'Delete this local merchant profile',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_exporting)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(
                    color: PaytmColors.paytmBlue,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final shopName = widget.merchantAccountName;
    if (shopName == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete merchant profile?'),
        content: Text(
          'This removes $shopName from this device. It cannot be recovered here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await MerchantAuthRepository.deleteAccount(shopName);
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

class _PublishedMenuCard extends StatelessWidget {
  final Map<String, String> answers;
  final String qrPayload;
  final String menuLabel;
  final String emptyItemsLabel;
  final String famousLabel;
  final String poweredByLabel;
  const _PublishedMenuCard({
    required this.answers,
    required this.qrPayload,
    required this.menuLabel,
    required this.emptyItemsLabel,
    required this.famousLabel,
    required this.poweredByLabel,
  });

  List<(String, String)> get _items {
    final raw = answers['items'] ?? '';
    return raw.split(RegExp(r'[,;\n]')).where((s) => s.trim().isNotEmpty).map((
      part,
    ) {
      final match = RegExp(r'(\d+)').firstMatch(part);
      if (match == null) return (part.trim(), '');
      final item = part
          .replaceFirst(match.group(0)!, '')
          .replaceAll(RegExp(r'^[\s₹:–-]+|[\s:–-]+$'), '')
          .trim();
      return (item.isEmpty ? part.trim() : item, '₹${match.group(1)}');
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final name = answers['business_name']?.trim().isNotEmpty == true
        ? answers['business_name']!
        : 'My Store';
    final details = [
      if ((answers['hours'] ?? '').isNotEmpty)
        (Icons.schedule_rounded, answers['hours']!),
      if ((answers['location'] ?? '').isNotEmpty)
        (Icons.location_on_rounded, answers['location']!),
      if ((answers['phone'] ?? '').isNotEmpty)
        (Icons.phone_rounded, answers['phone']!),
    ];
    return SizedBox(
      width: math.min(MediaQuery.sizeOf(context).width - 32, 360),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.24),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [PaytmColors.deepNavy, Color(0xFF003B8E)],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (answers['business_type'] ?? menuLabel).toUpperCase(),
                          style: const TextStyle(
                            color: PaytmColors.deepNavy,
                            backgroundColor: PaytmColors.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if ((answers['specialty'] ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '$famousLabel ${answers['specialty']}',
                            style: const TextStyle(
                              color: PaytmColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 76,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 12),
              child: _items.isEmpty
                  ? Text(
                      emptyItemsLabel,
                      style: TextStyle(
                        color: PaytmColors.deepNavy.withOpacity(.65),
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : Column(
                      children: _items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 6,
                                color: PaytmColors.paytmBlue,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  item.$1,
                                  style: const TextStyle(
                                    color: PaytmColors.deepNavy,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (item.$2.isNotEmpty)
                                Text(
                                  item.$2,
                                  style: const TextStyle(
                                    color: PaytmColors.goldDeep,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            if (details.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: details.map((detail) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: PaytmColors.iceBlue,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            detail.$1,
                            size: 13,
                            color: PaytmColors.deepNavy,
                          ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 235),
                            child: Text(
                              detail.$2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: PaytmColors.deepNavy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            Container(
              color: PaytmColors.iceBlue,
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Center(
                child: Text(
                  poweredByLabel,
                  style: TextStyle(
                    color: PaytmColors.deepNavy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishedAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;
  const _PublishedAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: highlighted ? PaytmColors.gold : Colors.white.withOpacity(.12),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 54,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: highlighted ? PaytmColors.deepNavy : Colors.white,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: highlighted ? PaytmColors.deepNavy : Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CustomerItem {
  final String name;
  final double? quantity;
  final String? unit;

  const CustomerItem({required this.name, this.quantity, this.unit});

  Map<String, Object?> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
  };

  factory CustomerItem.fromJson(Map value) => CustomerItem(
    name: (value['name'] ?? '').toString(),
    quantity: (value['quantity'] as num?)?.toDouble(),
    unit: value['unit']?.toString(),
  );

  String get displayName => [
    if (quantity != null) quantity!.toStringAsFixed(quantity! % 1 == 0 ? 0 : 1),
    if (unit != null && unit!.isNotEmpty) unit,
    name,
  ].join(' ');
}

enum CustomerPriority { closest, cheapest, bestRated, fairSmallShops }

class CustomerOrderIntent {
  final List<CustomerItem> items;
  final double? radiusKm;
  final double? budgetInr;
  final CustomerPriority priority;
  final bool openNowOnly;
  final String originalText;

  const CustomerOrderIntent({
    required this.items,
    this.radiusKm,
    this.budgetInr,
    this.priority = CustomerPriority.closest,
    this.openNowOnly = false,
    this.originalText = '',
  });

  CustomerOrderIntent copyWith({
    List<CustomerItem>? items,
    double? radiusKm,
    double? budgetInr,
    CustomerPriority? priority,
    bool? openNowOnly,
    String? originalText,
  }) => CustomerOrderIntent(
    items: items ?? this.items,
    radiusKm: radiusKm ?? this.radiusKm,
    budgetInr: budgetInr ?? this.budgetInr,
    priority: priority ?? this.priority,
    openNowOnly: openNowOnly ?? this.openNowOnly,
    originalText: originalText ?? this.originalText,
  );

  static Future<CustomerOrderIntent> parse(String utterance) async {
    final reply = await VoiceService.chat(
      systemPrompt: '''
Extract the customer's shopping request as JSON only, with schema:
{"items":[{"name":string,"quantity":number|null,"unit":string|null}],"radius_km":number|null,"budget_inr":number|null}
Keep item names in the language and script spoken by the customer. Do not invent details. If the request is not about finding goods or services, return {"items":[]}.
''',
      messages: [
        {'role': 'user', 'content': utterance},
      ],
    ).timeout(const Duration(seconds: 9), onTimeout: () => '');
    try {
      var normalized = reply.trim();
      if (normalized.startsWith('```')) {
        normalized = normalized
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '');
      }
      final decoded = jsonDecode(normalized);
      if (decoded is Map) {
        final rawItems = decoded['items'];
        final items = rawItems is List
            ? rawItems
                  .whereType<Map>()
                  .map(CustomerItem.fromJson)
                  .where((item) => item.name.trim().isNotEmpty)
                  .toList()
            : <CustomerItem>[];
        return CustomerOrderIntent(
          items: items,
          radiusKm: (decoded['radius_km'] as num?)?.toDouble(),
          budgetInr: (decoded['budget_inr'] as num?)?.toDouble(),
          originalText: utterance,
        );
      }
    } catch (_) {
      // Fall back to the customer's own words below.
    }
    return CustomerOrderIntent(
      items: [CustomerItem(name: utterance.trim())],
      radiusKm: 3,
      originalText: utterance,
    );
  }
}

class StoreRepository {
  static const String _storesKey = 'piku_published_stores_v1';
  static const List<Map<String, Object>> demoStores = [
    {
      'id': 'demo_kirana',
      'business_name': 'Ramesh Kirana',
      'business_type': 'Grocery',
      'items': 'rice, dal, oil, spices',
      'location': 'Market Lane',
      'price_band': '₹₹',
      'emoji': '🛒',
      'distance_km': 0.8,
    },
    {
      'id': 'demo_vegetables',
      'business_name': 'Sunita Vegetables',
      'business_type': 'Fresh produce',
      'items': 'tomato, onion, potato, greens',
      'location': 'Green Market',
      'price_band': '₹',
      'emoji': '🥕',
      'distance_km': 1.2,
    },
    {
      'id': 'demo_chai',
      'business_name': 'Chai Corner',
      'business_type': 'Tea & snacks',
      'items': 'chai, coffee, bun, samosa',
      'location': 'Station Road',
      'price_band': '₹',
      'emoji': '☕',
      'distance_km': 1.7,
    },
    {
      'id': 'demo_tailors',
      'business_name': 'Ali Tailors',
      'business_type': 'Tailoring',
      'items': 'stitching, alterations, blouse',
      'location': 'Old Town',
      'price_band': '₹₹',
      'emoji': '🧵',
      'distance_km': 2.1,
    },
    {
      'id': 'demo_repairs',
      'business_name': 'Kumar Repairs',
      'business_type': 'Repairs',
      'items': 'fan, mixer, motor repair',
      'location': 'Temple Cross',
      'price_band': '₹₹',
      'emoji': '🔧',
      'distance_km': 2.5,
    },
  ];

  static Future<String> getOrCreateCustomerId() async {
    final preferences = await SharedPreferences.getInstance();
    var id = preferences.getString('piku_customer_id');
    if (id == null || id.isEmpty) {
      id = 'cust_${DateTime.now().microsecondsSinceEpoch}';
      await preferences.setString('piku_customer_id', id);
    }
    return id;
  }

  static Future<String> saveStore(
    Map<String, String> answers, {
    double? latitude,
    double? longitude,
    String? customPin,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final existing = _decodeStores(preferences.getString(_storesKey));
    final name = answers['business_name'] ?? 'My Store';
    final requestedId = (answers['_id'] ?? '').trim();
    final previous = existing.where((store) {
      final sameId =
          requestedId.isNotEmpty &&
          (store['id'] ?? '').toString().trim() == requestedId;
      final sameName =
          (store['business_name'] ?? '').toString().trim().toLowerCase() ==
          name.trim().toLowerCase();
      return sameId || sameName;
    }).toList();
    final previousPin = previous.isEmpty ? null : previous.first['pin'];
    final previousLatitude = previous.isEmpty
        ? null
        : (previous.first['latitude'] as num?)?.toDouble();
    final previousLongitude = previous.isEmpty
        ? null
        : (previous.first['longitude'] as num?)?.toDouble();
    final storeId = previous.isEmpty
        ? (requestedId.isNotEmpty
              ? requestedId
              : 'store_${DateTime.now().millisecondsSinceEpoch}')
        : (previous.first['id'] ?? requestedId).toString();
    existing.removeWhere(
      (store) => previous.any((match) => match['id'] == store['id']),
    );
    existing.insert(0, {
      'id': storeId,
      ...answers,
      'pin': customPin ?? previousPin ?? MerchantAuthRepository.defaultPin,
      'emoji': _emojiForCategory(answers['business_type'] ?? ''),
      if (latitude != null || previousLatitude != null)
        'latitude': latitude ?? previousLatitude,
      if (longitude != null || previousLongitude != null)
        'longitude': longitude ?? previousLongitude,
      'distance_km': 1.0,
    });
    await preferences.setString(_storesKey, jsonEncode(existing));
    return storeId;
  }

  static Future<List<Map<String, dynamic>>> loadStores() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = _decodeStores(preferences.getString(_storesKey));
    final savedNames = saved
        .map((store) => store['business_name'].toString().toLowerCase())
        .toSet();
    return [
      ...saved,
      ...demoStores.where(
        (store) => !savedNames.contains(
          store['business_name'].toString().toLowerCase(),
        ),
      ),
    ];
  }

  static Future<List<Map<String, dynamic>>> loadSavedStores() async {
    final preferences = await SharedPreferences.getInstance();
    return _decodeStores(preferences.getString(_storesKey));
  }

  static Future<void> saveResolvedCoordinates(
    String storeId,
    double latitude,
    double longitude,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final stores = _decodeStores(preferences.getString(_storesKey));
    final index = stores.indexWhere(
      (store) => (store['id'] ?? '').toString() == storeId,
    );
    if (index < 0) return;
    stores[index]['latitude'] = latitude;
    stores[index]['longitude'] = longitude;
    stores[index].remove('locationLookupAttemptedAt');
    await preferences.setString(_storesKey, jsonEncode(stores));
  }

  static Future<void> markLocationLookupAttempted(String storeId) async {
    final preferences = await SharedPreferences.getInstance();
    final stores = _decodeStores(preferences.getString(_storesKey));
    final index = stores.indexWhere(
      (store) => (store['id'] ?? '').toString() == storeId,
    );
    if (index < 0) return;
    stores[index]['locationLookupAttemptedAt'] =
        DateTime.now().millisecondsSinceEpoch;
    await preferences.setString(_storesKey, jsonEncode(stores));
  }

  static Future<void> deleteSavedStore(String shopName) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = _decodeStores(preferences.getString(_storesKey));
    saved.removeWhere(
      (store) =>
          (store['business_name'] ?? '').toString().toLowerCase() ==
          shopName.toLowerCase(),
    );
    await preferences.setString(_storesKey, jsonEncode(saved));
  }

  static List<Map<String, dynamic>> _decodeStores(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final value = jsonDecode(json);
      if (value is! List) return [];
      return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (_) {
      return [];
    }
  }

  static String _emojiForCategory(String category) {
    final value = category.toLowerCase();
    if (value.contains('food') || value.contains('tea')) return '🍲';
    if (value.contains('grocery') || value.contains('kirana')) return '🛒';
    if (value.contains('fruit') || value.contains('vegetable')) return '🥕';
    if (value.contains('tailor') || value.contains('cloth')) return '🧵';
    if (value.contains('repair')) return '🔧';
    return '🏪';
  }
}

class SetPasswordScreen extends StatefulWidget {
  final AppLanguage language;
  final Map<String, String> answers;
  final double? latitude;
  final double? longitude;

  const SetPasswordScreen({
    super.key,
    required this.language,
    required this.answers,
    this.latitude,
    this.longitude,
  });

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePin = true;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    final pin = _pinController.text.trim();
    if (!RegExp(r'^\d{4,}$').hasMatch(pin)) {
      setState(() => _error = 'PIN must contain at least 4 digits.');
      return;
    }
    if (pin != _confirmController.text.trim()) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final storeId = await StoreRepository.saveStore(
        widget.answers,
        latitude: widget.latitude,
        longitude: widget.longitude,
        customPin: pin,
      );
      widget.answers['_id'] = storeId;
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save this shop on the device. Please retry.';
        });
      }
      debugPrint('Could not save merchant PIN locally: $error');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PublishedCardScreen(
          language: widget.language,
          answers: widget.answers,
          merchantAccountName: widget.answers['business_name'],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaytmColors.inkTop,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_person_rounded,
                    size: 64,
                    color: PaytmColors.paytmBlue,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Secure your shop',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a PIN to reopen this shop on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _pinController,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    decoration: _pinDecoration('Create PIN'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmController,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    decoration: _pinDecoration(
                      'Confirm PIN',
                    ).copyWith(errorText: _error),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _obscurePin = !_obscurePin),
                      icon: Icon(
                        _obscurePin
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                      label: Text(_obscurePin ? 'Show PIN' : 'Hide PIN'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _busy ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PaytmColors.paytmBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save PIN & open shop',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _pinDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  );
}

// Device-local demo PIN authentication; it is not server-side account security.
class MerchantAuthRepository {
  static const String defaultPin = '1234';

  static Future<bool> login(
    String shopName,
    String pin, {
    String? shopId,
  }) async {
    final normalizedName = shopName.trim().toLowerCase();
    if (normalizedName.isEmpty || pin.isEmpty) return false;
    final stores = await StoreRepository.loadSavedStores();
    Map<String, dynamic>? store;
    if (shopId != null && shopId.trim().isNotEmpty) {
      store = stores.cast<Map<String, dynamic>?>().firstWhere(
        (candidate) =>
            (candidate?['id'] ?? '').toString().trim() == shopId.trim(),
        orElse: () => null,
      );
    }
    store ??= stores.cast<Map<String, dynamic>?>().firstWhere(
      (candidate) =>
          (candidate?['business_name'] ?? '').toString().trim().toLowerCase() ==
          normalizedName,
      orElse: () => null,
    );
    if (store == null) return false;
    return pin == (store['pin'] ?? defaultPin).toString();
  }

  static Future<void> deleteAccount(String shopName) =>
      StoreRepository.deleteSavedStore(shopName);
}

class MerchantLoginScreen extends StatefulWidget {
  final AppLanguage language;
  final Map<String, dynamic> pendingShopData;
  final String rawQr;

  const MerchantLoginScreen({
    super.key,
    required this.language,
    required this.pendingShopData,
    required this.rawQr,
  });

  @override
  State<MerchantLoginScreen> createState() => _MerchantLoginScreenState();
}

class _MerchantLoginScreenState extends State<MerchantLoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _busy = false;
  bool _obscurePin = true;
  bool _isExistingShop = false;
  bool _checking = true;
  String? _error;

  String get _shopName =>
      (widget.pendingShopData['business_name'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    _checkShopExistence();
  }

  Future<void> _checkShopExistence() async {
    try {
      final stores = await StoreRepository.loadSavedStores();
      final normalizedName = _shopName.toLowerCase();
      final qrId = (widget.pendingShopData['id'] ?? '').toString().trim();
      final exists = stores.any((store) {
        final storeId = (store['id'] ?? '').toString().trim();
        if (qrId.isNotEmpty && storeId == qrId) return true;
        return normalizedName.isNotEmpty &&
            (store['business_name'] ?? '').toString().trim().toLowerCase() ==
                normalizedName;
      });
      if (mounted) {
        setState(() {
          _isExistingShop = exists;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _startOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MerchantCardFlow(
          language: widget.language,
          merchantName: _shopName.isEmpty ? 'My Shop' : _shopName,
          rawQr: widget.rawQr,
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_busy || !_isExistingShop) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final success = await MerchantAuthRepository.login(
      _shopName,
      _pinController.text.trim(),
      shopId: (widget.pendingShopData['id'] ?? '').toString(),
    );
    if (!mounted) return;
    if (!success) {
      setState(() {
        _busy = false;
        _error = 'Incorrect PIN, or this shop is not saved on this device.';
      });
      return;
    }

    final initialData = widget.pendingShopData.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MerchantCardFlow(
          language: widget.language,
          merchantName: _shopName,
          rawQr: widget.rawQr,
          initialData: initialData,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: PaytmColors.inkTop,
        body: Center(
          child: CircularProgressIndicator(color: PaytmColors.paytmBlue),
        ),
      );
    }
    return Scaffold(
      backgroundColor: PaytmColors.inkTop,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    size: 64,
                    color: PaytmColors.paytmBlue,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isExistingShop
                        ? 'Welcome back,\n$_shopName'
                        : 'New Shop Found',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isExistingShop
                        ? 'Enter the PIN saved for this shop on this device.'
                        : 'This shop is not saved yet. Set it up now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 28),
                  if (_isExistingShop) ...[
                    TextField(
                      controller: _pinController,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter PIN',
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePin
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePin = !_obscurePin),
                        ),
                        errorText: _error,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _busy ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PaytmColors.paytmBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Open merchant card',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ] else
                    ElevatedButton(
                      onPressed: _busy ? null : _startOnboarding,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PaytmColors.gold,
                        foregroundColor: PaytmColors.deepNavy,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Set up my shop now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Back to scanner'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<Map<String, String>> _translateUiLines(
  AppLanguage language,
  List<String> lines,
) async {
  if (language == AppLanguage.english || kOpenAiKey.trim().isEmpty) {
    return const {};
  }
  try {
    final indexed = {for (var i = 0; i < lines.length; i++) '$i': lines[i]};
    final response = await VoiceService.chat(
      systemPrompt:
          'Translate JSON values into ${language.englishName} (${language.nativeName}), using its normal script. Preserve names and brand words. Return only valid JSON with the same keys.',
      messages: [
        {'role': 'user', 'content': jsonEncode(indexed)},
      ],
    ).timeout(const Duration(seconds: 8), onTimeout: () => '');
    if (response.trim().isEmpty) return const {};
    final decoded = jsonDecode(response) as Map<String, dynamic>;
    return {
      for (var i = 0; i < lines.length; i++)
        if (decoded['$i'] is String) lines[i]: (decoded['$i'] as String),
    };
  } catch (_) {
    return const {};
  }
}

class RoleSelectionScreen extends StatefulWidget {
  final AppLanguage language;
  const RoleSelectionScreen({super.key, required this.language});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;
  Map<String, String> _copy = {};
  String text(String source) => _copy[source] ?? source;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    unawaited(_loadCopy());
  }

  Future<void> _loadCopy() async {
    final copy = await _translateUiLines(widget.language, const [
      'Who are you?',
      'Piku will adapt to you.',
      'I sell things',
      'Make my shop card & QR',
      'I want to buy',
      'Tell Piku what you need',
    ]);
    if (mounted) setState(() => _copy = copy);
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: PaytmColors.inkTop,
    body: Stack(
      children: [
        const Positioned.fill(child: _TreacleBackdrop()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                SizedBox(
                  height: 190,
                  child: AnimatedBuilder(
                    animation: _wave,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(
                        0,
                        math.sin(_wave.value * math.pi * 2) * 5,
                      ),
                      child: Transform.scale(scale: .38, child: child),
                    ),
                    child: const _PremiumRobot(
                      blink: 0,
                      wave: .5,
                      showWave: true,
                      antennaPulse: .5,
                      pupil: .5,
                      expression: _RobotExpression.happy,
                    ),
                  ),
                ),
                Text(
                  text('Who are you?'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  text('Piku will adapt to you.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 26),
                _RoleChoiceCard(
                  emoji: '🛍️',
                  title: text('I sell things'),
                  subtitle: text('Make my shop card & QR'),
                  gradient: PaytmColors.ctaGradient,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          QrScannerScreen(language: widget.language),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _RoleChoiceCard(
                  emoji: '🛒',
                  title: text('I want to buy'),
                  subtitle: text('Tell Piku what you need'),
                  gradient: PaytmColors.logoGradient,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CustomerHomeScreen(language: widget.language),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _RoleChoiceCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _RoleChoiceCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        height: 94,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.2),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: PaytmColors.deepNavy,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: PaytmColors.deepNavy.withOpacity(.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: PaytmColors.deepNavy,
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    ),
  );
}

class CustomerHomeScreen extends StatefulWidget {
  final AppLanguage language;
  const CustomerHomeScreen({super.key, required this.language});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _input = TextEditingController();
  Map<String, String> _copy = {};
  String _customerId = '';
  String _greeting = 'What do you need today?';
  bool _busy = false;
  bool _listening = false;
  bool _locationRequesting = false;
  bool _locationUnavailable = false;
  Future<bool>? _locationFuture;
  Position? _userLocation;
  late final AnimationController _bob;
  late final AnimationController _blink;
  late final AnimationController _mouth;
  late final AnimationController _antenna;
  late final AnimationController _pupil;
  late final AnimationController _radar;
  _RobotExpression _expression = _RobotExpression.happy;

  String text(String source) => _copy[source] ?? source;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _mouth = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _antenna = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pupil = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    _radar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _scheduleBlink();
    unawaited(_initialize());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_ensureUserLocation(showMessage: false));
    });
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future.delayed(
        Duration(milliseconds: 2200 + math.Random().nextInt(2200)),
      );
      if (!mounted) return;
      await _blink.forward();
      await _blink.reverse();
    }
  }

  Future<void> _initialize() async {
    final result = await Future.wait([
      StoreRepository.getOrCreateCustomerId(),
      _translateUiLines(widget.language, const [
        'What do you need today?',
        'Tell Piku what you are looking for. You can type or speak.',
        'Type what you need…',
        'Piku is listening…',
        'Finding nearby shops…',
        'Could not hear that. Try typing instead.',
        'Find shops',
        'Speak',
        'No sign-up needed',
        'Please enable location to find nearby shops.',
        'Turn on location services to find nearby shops.',
        'Location is off. Enable it to find nearby shops.',
        'Retry',
      ]),
      VoiceService.chat(
        systemPrompt:
            'You are Piku, a warm local shopping helper. In ${widget.language.englishName} (${widget.language.nativeName}) and normal script, greet the customer in one short natural sentence and ask what they need today. Do not mention forms or AI. Return only the sentence.',
        messages: const [
          {'role': 'user', 'content': 'Say hello and ask what I need.'},
        ],
      ).timeout(const Duration(seconds: 8), onTimeout: () => ''),
    ]);
    _customerId = result[0] as String;
    _copy = result[1] as Map<String, String>;
    var greeting = result[2] as String;
    if (greeting.trim().isEmpty) {
      greeting = _copy['What do you need today?'] ?? 'What do you need today?';
    }
    if (!mounted) return;
    setState(() => _greeting = greeting.trim());
    await VoiceService.speak(
      _greeting,
      language: widget.language,
      cacheToDisk: true,
    );
  }

  Future<void> _listen() async {
    if (_busy || _listening) return;
    if (!await _ensureUserLocation()) return;
    setState(() {
      _listening = true;
      _expression = _RobotExpression.listening;
    });
    final words = await VoiceService.recordAndTranscribe(
      seconds: 6,
      language: widget.language,
    );
    if (!mounted) return;
    setState(() {
      _listening = false;
      _expression = _RobotExpression.happy;
    });
    if (words == null || words.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text('Could not hear that. Try typing instead.')),
        ),
      );
      return;
    }
    _input.text = words;
    await _search(words);
  }

  Future<void> _search(String raw) async {
    final request = raw.trim();
    if (request.isEmpty || _busy) return;
    if (!await _ensureUserLocation()) return;
    setState(() {
      _busy = true;
      _expression = _RobotExpression.thinking;
    });
    if (_customerId.isEmpty) {
      _customerId = await StoreRepository.getOrCreateCustomerId();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NeedBuilderScreen(
          language: widget.language,
          customerId: _customerId,
          userLocation: _userLocation!,
          initialText: request,
        ),
      ),
    );
  }

  Future<bool> _ensureUserLocation({bool showMessage = true}) async {
    if (_userLocation != null) return true;
    final pending = _locationFuture;
    if (pending != null) return pending;
    final request = _requestUserLocation(showMessage: showMessage);
    _locationFuture = request;
    try {
      return await request;
    } finally {
      if (identical(_locationFuture, request)) _locationFuture = null;
    }
  }

  Future<bool> _requestUserLocation({required bool showMessage}) async {
    if (_userLocation != null) return true;
    _locationRequesting = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _locationUnavailable = true);
        if (showMessage) {
          _showLocationMessage(
            text('Turn on location services to find nearby shops.'),
          );
        }
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationUnavailable = true);
        if (showMessage) {
          _showLocationMessage(
            text('Please enable location to find nearby shops.'),
          );
        }
        return false;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return false;
      setState(() {
        _userLocation = position;
        _locationUnavailable = false;
      });
      return true;
    } catch (error) {
      debugPrint('Could not get customer location: $error');
      if (mounted) {
        setState(() => _locationUnavailable = true);
        if (showMessage) {
          _showLocationMessage(
            text('Please enable location to find nearby shops.'),
          );
        }
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _locationRequesting = false);
      } else {
        _locationRequesting = false;
      }
    }
  }

  void _showLocationMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _bob.dispose();
    _blink.dispose();
    _mouth.dispose();
    _antenna.dispose();
    _pupil.dispose();
    _radar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: PaytmColors.inkTop,
    body: Stack(
      children: [
        const Positioned.fill(child: _TreacleBackdrop()),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _radar,
              builder: (context, _) =>
                  CustomPaint(painter: _HomeRadarPainter(_radar.value)),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    _CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    const _PaytmLogo(size: 19),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Piku Live',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 235,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _bob,
                            _blink,
                            _mouth,
                            _antenna,
                            _pupil,
                            VoiceService.speakingListenable,
                          ]),
                          builder: (context, child) {
                            final speaking = VoiceService.isSpeaking;
                            final mouth = speaking
                                ? _speechMouthOpening(_mouth.value)
                                : 0.0;
                            return Transform.translate(
                              offset: Offset(
                                0,
                                math.sin(_bob.value * math.pi * 2) * 7,
                              ),
                              child: Transform.scale(
                                scale: .43,
                                alignment: Alignment.bottomCenter,
                                child: _PremiumRobot(
                                  blink: _blink.value,
                                  wave: 0,
                                  showWave: false,
                                  antennaPulse: _antenna.value,
                                  pupil: _pupil.value,
                                  expression: speaking
                                      ? _RobotExpression.speaking
                                      : _expression,
                                  mouthFlap: mouth,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.95),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: PaytmColors.paytmBlue.withOpacity(.18),
                              blurRadius: 36,
                              spreadRadius: 3,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(.14),
                              blurRadius: 20,
                              offset: const Offset(0, 9),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              _greeting,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: PaytmColors.deepNavy,
                                fontSize: 22,
                                height: 1.3,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              text('Tell Piku what you are looking for.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: PaytmColors.deepNavy.withOpacity(.62),
                                fontSize: 13,
                              ),
                            ),
                            if (_locationUnavailable) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF4D8),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_off_rounded,
                                      color: PaytmColors.goldDeep,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        text(
                                          'Location is off. Enable it to find nearby shops.',
                                        ),
                                        style: const TextStyle(
                                          color: PaytmColors.deepNavy,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _locationRequesting
                                          ? null
                                          : () => unawaited(
                                              _ensureUserLocation(
                                                showMessage: true,
                                              ),
                                            ),
                                      child: Text(text('Retry')),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Container(
                              decoration: BoxDecoration(
                                color: PaytmColors.iceBlue,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: PaytmColors.paytmBlue.withOpacity(.3),
                                ),
                              ),
                              child: TextField(
                                controller: _input,
                                minLines: 1,
                                maxLines: 3,
                                textInputAction: TextInputAction.search,
                                onSubmitted: _search,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: text('Type what you need…'),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: PaytmColors.paytmBlue,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _busy || _listening
                                        ? null
                                        : _listen,
                                    icon: Icon(
                                      _listening
                                          ? Icons.graphic_eq
                                          : Icons.mic_rounded,
                                    ),
                                    label: Text(
                                      _listening
                                          ? text('Piku is listening…')
                                          : text('Speak'),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: PaytmColors.deepNavy,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _search(_input.text),
                                    icon: _busy
                                        ? const SizedBox.square(
                                            dimension: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.map_rounded),
                                    label: Text(text('Find shops')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: PaytmColors.gold,
                                      foregroundColor: PaytmColors.deepNavy,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              text('No sign-up needed'),
                              style: TextStyle(
                                color: PaytmColors.deepNavy.withOpacity(.46),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HomeRadarPainter extends CustomPainter {
  final double progress;
  const _HomeRadarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .4);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 4; i++) {
      final t = (progress + i / 4) % 1;
      paint.color = PaytmColors.paytmBlue.withOpacity((1 - t) * .14);
      canvas.drawCircle(center, t * size.width * .8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HomeRadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class NeedBuilderScreen extends StatefulWidget {
  final AppLanguage language;
  final String customerId;
  final Position userLocation;
  final String initialText;

  const NeedBuilderScreen({
    super.key,
    required this.language,
    required this.customerId,
    required this.userLocation,
    required this.initialText,
  });

  @override
  State<NeedBuilderScreen> createState() => _NeedBuilderScreenState();
}

class _NeedBuilderScreenState extends State<NeedBuilderScreen>
    with TickerProviderStateMixin {
  final TextEditingController _input = TextEditingController();
  int _step = 0;
  bool _busy = false;
  bool _listening = false;
  bool _openNowOnly = false;
  List<CustomerItem> _items = [];
  double? _budgetInr;
  double _radiusKm = 2;
  CustomerPriority _priority = CustomerPriority.closest;
  late final AnimationController _bob;
  late final AnimationController _blink;
  late final AnimationController _mouth;
  late final AnimationController _antenna;
  late final AnimationController _pupil;
  late final AnimationController _cardIn;

  static const _titles = [
    'What do you need?',
    'Any budget in mind?',
    'How far will you travel?',
    'How should I rank shops?',
  ];

  @override
  void initState() {
    super.initState();
    _input.text = widget.initialText;
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _mouth = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _antenna = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pupil = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    _cardIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..forward();
    _scheduleBlink();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakStep());
  }

  void _scheduleBlink() async {
    while (mounted) {
      await Future.delayed(
        Duration(milliseconds: 2200 + math.Random().nextInt(2200)),
      );
      if (!mounted) return;
      await _blink.forward();
      await _blink.reverse();
    }
  }

  Future<void> _speakStep() async {
    await VoiceService.speak(
      _titles[_step],
      language: widget.language,
      cacheToDisk: true,
    );
  }

  Future<void> _listen() async {
    if (_busy || _listening) return;
    setState(() => _listening = true);
    final words = await VoiceService.recordAndTranscribe(
      seconds: 6,
      language: widget.language,
    );
    if (!mounted) return;
    setState(() => _listening = false);
    if (words == null || words.trim().isEmpty) return;
    _input.text = words.trim();
    if (_step == 3) _choosePriorityFromSpeech(words);
  }

  void _choosePriorityFromSpeech(String words) {
    final lower = words.toLowerCase();
    final priority = lower.contains('cheap') || lower.contains('budget')
        ? CustomerPriority.cheapest
        : lower.contains('rating') || lower.contains('best')
        ? CustomerPriority.bestRated
        : lower.contains('small') || lower.contains('fair')
        ? CustomerPriority.fairSmallShops
        : CustomerPriority.closest;
    setState(() => _priority = priority);
  }

  Future<void> _continue() async {
    if (_busy) return;
    if (_step == 0) {
      final request = _input.text.trim();
      if (request.isEmpty) {
        _notice('Tell Piku what you need first.');
        return;
      }
      setState(() => _busy = true);
      final parsed = await CustomerOrderIntent.parse(request);
      if (!mounted) return;
      setState(() {
        _items = parsed.items.isEmpty
            ? [CustomerItem(name: request)]
            : parsed.items;
        _budgetInr = parsed.budgetInr;
        if (parsed.radiusKm != null && parsed.radiusKm! > 0) {
          _radiusKm = parsed.radiusKm!.clamp(.2, 25).toDouble();
        }
        _busy = false;
        _step = 1;
        _input.clear();
      });
      _cardIn.forward(from: 0);
      unawaited(_speakStep());
      return;
    }
    if (_step == 1) {
      final raw = _input.text.trim().replaceAll(',', '');
      final amount = double.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (raw.isNotEmpty && amount == null) {
        _notice('Enter a number, or choose No budget.');
        return;
      }
      if (raw.isNotEmpty) _budgetInr = amount;
    } else if (_step == 2 && _input.text.trim().isNotEmpty) {
      final value = double.tryParse(
        _input.text.trim().replaceAll(RegExp(r'[^0-9.]'), ''),
      );
      if (value == null || value <= 0) {
        _notice('Enter a distance in kilometres.');
        return;
      }
      _radiusKm = value.clamp(.2, 25).toDouble();
    }
    if (_step == 3) {
      _finish();
      return;
    }
    setState(() {
      _step++;
      _input.clear();
    });
    _cardIn.forward(from: 0);
    unawaited(_speakStep());
  }

  void _finish() {
    final intent = CustomerOrderIntent(
      items: _items,
      budgetInr: _budgetInr,
      radiusKm: _radiusKm,
      priority: _priority,
      openNowOnly: _openNowOnly,
      originalText: _items.map((item) => item.displayName).join(', '),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MarketMapScreen(
          language: widget.language,
          intent: intent,
          customerId: widget.customerId,
          userLocation: widget.userLocation,
        ),
      ),
    );
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: PaytmColors.gold,
    backgroundColor: PaytmColors.iceBlue,
    labelStyle: TextStyle(
      color: PaytmColors.deepNavy,
      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  Widget _questionContent() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _input,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _continue(),
              decoration: const InputDecoration(
                labelText: 'Items or service',
                hintText: 'For example: rice and cooking oil',
                prefixIcon: Icon(Icons.shopping_basket_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _choice('Rice', false, () => _input.text = 'rice'),
                _choice('Vegetables', false, () => _input.text = 'vegetables'),
                _choice(
                  'Tea and snacks',
                  false,
                  () => _input.text = 'tea and snacks',
                ),
              ],
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _input,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Maximum budget (₹)',
                hintText: 'Optional',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _choice(
                  'No budget',
                  _budgetInr == null && _input.text.isEmpty,
                  () {
                    setState(() {
                      _budgetInr = null;
                      _input.clear();
                    });
                  },
                ),
                for (final amount in [100, 300, 500, 1000])
                  _choice('₹$amount', _budgetInr == amount, () {
                    setState(() {
                      _budgetInr = amount.toDouble();
                      _input.text = '$amount';
                    });
                  }),
              ],
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _input,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Maximum distance (km)',
                hintText: 'Choose a radius or enter one',
                prefixIcon: Icon(Icons.near_me_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final radius in [0.5, 1.0, 2.0, 5.0])
                  _choice(
                    '${radius.toStringAsFixed(radius % 1 == 0 ? 0 : 1)} km',
                    _radiusKm == radius,
                    () {
                      setState(() {
                        _radiusKm = radius;
                        _input.text = '$radius';
                      });
                    },
                  ),
              ],
            ),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _choice(
                  'Closest',
                  _priority == CustomerPriority.closest,
                  () => setState(() => _priority = CustomerPriority.closest),
                ),
                _choice(
                  'Cheapest',
                  _priority == CustomerPriority.cheapest,
                  () => setState(() => _priority = CustomerPriority.cheapest),
                ),
                _choice(
                  'Best rated',
                  _priority == CustomerPriority.bestRated,
                  () => setState(() => _priority = CustomerPriority.bestRated),
                ),
                _choice(
                  'Support small shops',
                  _priority == CustomerPriority.fairSmallShops,
                  () => setState(
                    () => _priority = CustomerPriority.fairSmallShops,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Only show shops open now'),
              value: _openNowOnly,
              onChanged: (value) => setState(() => _openNowOnly = value),
            ),
          ],
        );
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _bob.dispose();
    _blink.dispose();
    _mouth.dispose();
    _antenna.dispose();
    _pupil.dispose();
    _cardIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: PaytmColors.inkTop,
    body: Stack(
      children: [
        const Positioned.fill(child: _TreacleBackdrop()),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    _CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    Text(
                      '${_step + 1} of 4',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ...List.generate(
                      4,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: index == _step ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: index <= _step
                              ? PaytmColors.gold
                              : Colors.white30,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 165,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _bob,
                    _blink,
                    _mouth,
                    _antenna,
                    _pupil,
                    VoiceService.speakingListenable,
                  ]),
                  builder: (context, _) => Transform.translate(
                    offset: Offset(0, math.sin(_bob.value * math.pi * 2) * 5),
                    child: Transform.scale(
                      scale: .34,
                      alignment: Alignment.topCenter,
                      child: _PremiumRobot(
                        blink: _blink.value,
                        wave: 0,
                        showWave: false,
                        antennaPulse: _antenna.value,
                        pupil: _pupil.value,
                        expression: VoiceService.isSpeaking
                            ? _RobotExpression.speaking
                            : _RobotExpression.happy,
                        mouthFlap: VoiceService.isSpeaking
                            ? _speechMouthOpening(_mouth.value)
                            : 0,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _cardIn,
                  builder: (context, child) => Opacity(
                    opacity: _cardIn.value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - _cardIn.value) * 14),
                      child: child,
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.97),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _titles[_step],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: PaytmColors.deepNavy,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _step == 0
                                ? 'Tell Piku what you are shopping for.'
                                : 'A quick preference helps Piku find a better match.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: PaytmColors.deepNavy.withOpacity(.64),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _questionContent(),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _busy || _listening ? null : _listen,
                            icon: Icon(
                              _listening ? Icons.graphic_eq : Icons.mic_rounded,
                            ),
                            label: Text(
                              _listening ? 'Listening…' : 'Answer by voice',
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _busy ? null : _continue,
                            icon: _busy
                                ? const SizedBox.square(
                                    dimension: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _step == 3
                                        ? Icons.map_rounded
                                        : Icons.arrow_forward_rounded,
                                  ),
                            label: Text(
                              _step == 3 ? 'Show nearby shops' : 'Continue',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: PaytmColors.paytmBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class MarketMapScreen extends StatefulWidget {
  final AppLanguage language;
  final CustomerOrderIntent intent;
  final String customerId;
  final Position userLocation;

  const MarketMapScreen({
    super.key,
    required this.language,
    required this.intent,
    required this.customerId,
    required this.userLocation,
  });

  @override
  State<MarketMapScreen> createState() => _MarketMapScreenState();
}

class _MarketMapScreenState extends State<MarketMapScreen>
    with TickerProviderStateMixin {
  final TextEditingController _search = TextEditingController();
  final MapController _mapController = MapController();
  late final AnimationController _bob;
  late final AnimationController _blink;
  late final AnimationController _mouth;
  late final AnimationController _antenna;
  late final AnimationController _pupil;
  List<Map<String, dynamic>> _stores = [];
  List<CustomerItem> _cart = [];
  Map<String, String> _copy = {};
  String? _cartShopId;
  bool _loading = true;
  bool _mapReady = false;
  Map<String, dynamic>? _priorityShop;
  Map<String, dynamic>? _pikuShop;
  late final AnimationController _pinMotion;
  late final AnimationController _pikuJump;
  _RobotExpression _expression = _RobotExpression.happy;

  String text(String source) => _copy[source] ?? source;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _mouth = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _antenna = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pupil = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    _pinMotion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _pikuJump = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scheduleBlink();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      // Map labels use their local English defaults; never wait on translation.
      // `loadStores()` includes `demoStores`, whose maps are const. Copy every
      // map before adding per-session metrics and calculated map coordinates.
      _stores = (await StoreRepository.loadStores())
          .map((shop) => Map<String, dynamic>.from(shop))
          .toList();
      if (!mounted) return;
      _copy = const {};

      const demoStats = <String, Map<String, num>>{
        'demo_kirana': {'rating': 4.1, 'ordersToday': 52},
        'demo_vegetables': {'rating': 4.5, 'ordersToday': 18},
        'demo_chai': {'rating': 4.9, 'ordersToday': 0},
        'demo_tailors': {'rating': 3.2, 'ordersToday': 3},
        'demo_repairs': {'rating': 4.7, 'ordersToday': 2},
      };
      for (final shop in _stores) {
        final stats = demoStats[(shop['id'] ?? '').toString()];
        if (stats == null) continue;
        shop['rating'] = stats['rating'];
        shop['ordersToday'] = stats['ordersToday'];
        shop['demoSampleMetrics'] = true;
        if (shop['id'] == 'demo_chai') shop['isSmallBusiness'] = true;
      }

      try {
        final preferences = await SharedPreferences.getInstance();
        if (!mounted) return;
        final savedCart = preferences.getString(
          'piku_cart_${widget.customerId}',
        );
        if (savedCart != null) {
          final json = jsonDecode(savedCart) as Map<String, dynamic>;
          _cartShopId = json['shopId']?.toString();
          _cart = (json['items'] as List? ?? const [])
              .whereType<Map>()
              .map(CustomerItem.fromJson)
              .toList();
        }
      } catch (error) {
        debugPrint('Could not restore market map cart: $error');
        _cart = [];
        _cartShopId = null;
      }

      _refreshMapPositions();
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerMapOnUser());
      unawaited(_translateUiLabels());
      unawaited(_resolveMissingShopLocations());
    } catch (error, stackTrace) {
      debugPrint('Market map load failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _stores = [];
        _copy = const {};
        _priorityShop = null;
        _pikuShop = null;
      });
    }
  }

  void _refreshMapPositions() {
    _processShopLocations();
    final locatedStores = _stores.where(_hasMapLocation).toList();
    final eligibleStores = locatedStores.where(_withinUserFilters).toList();
    final relevantStores = eligibleStores.where(_matchesNeed).toList();
    final fairPool = relevantStores.isNotEmpty
        ? relevantStores
        : widget.intent.items.isEmpty
        ? eligibleStores
        : const <Map<String, dynamic>>[];
    final fairMatch = fairPool
        .where((shop) => shop['isFairMatchCandidate'] == true)
        .firstOrNull;
    final proximityPool = fairPool.isNotEmpty ? fairPool : eligibleStores;
    final shopAtCurrentLocation = proximityPool
        .where(
          (shop) => shop['distanceIsDemo'] != true && _distanceTo(shop) <= .1,
        )
        .firstOrNull;
    final priority =
        shopAtCurrentLocation ??
        fairMatch ??
        (relevantStores.isNotEmpty
            ? relevantStores.first
            : (eligibleStores.isEmpty ? null : eligibleStores.first));
    for (final shop in _stores) {
      shop['isFairMatch'] =
          identical(shop, priority) &&
          shop['isFairMatchCandidate'] == true &&
          (widget.intent.items.isEmpty || _matchesNeed(shop));
    }
    if (!mounted) return;
    setState(() {
      _priorityShop = priority;
      _pikuShop = priority;
    });
    if (priority != null) _pikuJump.forward(from: 0);
  }

  Future<void> _resolveMissingShopLocations() async {
    final retryBefore = DateTime.now()
        .subtract(const Duration(days: 1))
        .millisecondsSinceEpoch;
    final shopsToResolve = _stores.where((shop) {
      final attemptedAt =
          (shop['locationLookupAttemptedAt'] as num?)?.toInt() ?? 0;
      final hasAddress = (shop['location'] ?? '').toString().trim().isNotEmpty;
      return !_hasMapLocation(shop) &&
          !(shop['id'] ?? '').toString().startsWith('demo_') &&
          hasAddress &&
          attemptedAt < retryBefore;
    }).toList();
    if (shopsToResolve.isEmpty) return;

    String? localityContext;
    try {
      final userPlaces = await placemarkFromCoordinates(
        widget.userLocation.latitude,
        widget.userLocation.longitude,
      ).timeout(const Duration(seconds: 3));
      if (userPlaces.isNotEmpty) {
        final place = userPlaces.first;
        localityContext =
            [place.locality, place.administrativeArea, place.country]
                .whereType<String>()
                .where((part) => part.trim().isNotEmpty)
                .toSet()
                .join(', ');
      }
    } catch (_) {
      // The saved address can still be resolved without the customer's area.
    }
    await Future.wait(
      shopsToResolve.map((shop) async {
        final address = (shop['location'] ?? '').toString().trim();
        final storeId = (shop['id'] ?? '').toString();
        if (address.isEmpty || storeId.isEmpty) return;
        try {
          // Recover coordinates for older profiles that saved an address but
          // predate GPS storage. Cache successful results for future map opens.
          final query = localityContext == null || localityContext.isEmpty
              ? address
              : '$address, $localityContext';
          final matches = await locationFromAddress(
            query,
          ).timeout(const Duration(seconds: 5));
          if (!mounted || matches.isEmpty) return;
          final match = matches.first;
          shop['latitude'] = match.latitude;
          shop['longitude'] = match.longitude;
          await StoreRepository.saveResolvedCoordinates(
            storeId,
            match.latitude,
            match.longitude,
          );
          _refreshMapPositions();
        } catch (error) {
          debugPrint(
            'Could not locate saved shop $storeId from address: $error',
          );
        } finally {
          if (mounted && !_hasMapLocation(shop)) {
            await StoreRepository.markLocationLookupAttempted(storeId);
          }
        }
      }),
    );
  }

  Future<void> _translateUiLabels() async {
    try {
      final copy = await _translateUiLines(widget.language, const [
        'Nearby shops',
        'Nearby map • sample sellers use demo locations',
        'Search shops or items…',
        'Your need:',
        'Cart',
        'Review order',
        'Send order on WhatsApp',
        'Call shop',
        'Add to cart',
        'Seller',
        'Items',
        'Location',
        'Phone number not added',
        'Seller contact is not available for this demo shop.',
        'Order preview',
        'Close',
        'Your order',
        'km away',
        'Open in Maps',
        'Distance unavailable',
        'Seller shops without saved GPS are not shown on this view.',
        'Fair match',
        'Top pick',
        'Low recent orders',
        'No ratings yet',
        'Your private rating',
        'Rating saved on this device; it is not shared yet.',
        'reviews',
        'orders today',
        'Sample data',
      ]);
      if (mounted && copy.isNotEmpty) setState(() => _copy = copy);
    } catch (error) {
      debugPrint('Background market map translation failed: $error');
    }
  }

  void _centerMapOnUser() {
    if (!mounted || !_mapReady) return;
    _mapController.move(
      LatLng(widget.userLocation.latitude, widget.userLocation.longitude),
      14.5,
    );
  }

  bool _hasMapLocation(Map<String, dynamic> shop) {
    final lat = (shop['latitude'] as num?)?.toDouble();
    final lng = (shop['longitude'] as num?)?.toDouble();
    return lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  bool _withinUserFilters(Map<String, dynamic> shop) =>
      _distanceTo(shop) <= (widget.intent.radiusKm ?? 2.0) &&
      (!widget.intent.openNowOnly || _isOpenNow(shop));

  LatLng _pointFor(Map<String, dynamic> shop) => LatLng(
    (shop['latitude'] as num).toDouble(),
    (shop['longitude'] as num).toDouble(),
  );

  void _scheduleBlink() async {
    while (mounted) {
      await Future.delayed(
        Duration(milliseconds: 2200 + math.Random().nextInt(2200)),
      );
      if (!mounted) return;
      await _blink.forward();
      await _blink.reverse();
    }
  }

  void _processShopLocations() {
    final userLat = widget.userLocation.latitude;
    final userLng = widget.userLocation.longitude;
    for (final shop in _stores) {
      if (!_hasMapLocation(shop) && shop['demoSampleMetrics'] == true) {
        // Sample merchants are shown near the real customer position so the
        // demo map has context. These are explicitly marked as sample locations.
        const sampleOffsetsMeters = <String, Offset>{
          'demo_kirana': Offset(45, 35),
          'demo_chai': Offset(-130, 115),
          'demo_vegetables': Offset(240, -80),
          'demo_tailors': Offset(280, 210),
          'demo_repairs': Offset(-240, -170),
        };
        final offset =
            sampleOffsetsMeters[shop['id']?.toString()] ??
            const Offset(100, 100);
        final longitudeScale = math.max(
          .1,
          math.cos(userLat * math.pi / 180).abs(),
        );
        shop['latitude'] = userLat + offset.dy / 111320;
        shop['longitude'] = userLng + offset.dx / (111320 * longitudeScale);
        shop['distanceIsDemo'] = true;
      }

      if (!_hasMapLocation(shop)) {
        shop['distanceKm'] = double.infinity;
        shop['priorityScore'] = 0.0;
        shop['isFairMatchCandidate'] = false;
        continue;
      }
      final lat = (shop['latitude'] as num).toDouble();
      final lng = (shop['longitude'] as num).toDouble();
      final distanceKm =
          Geolocator.distanceBetween(userLat, userLng, lat, lng) / 1000;
      shop['distanceIsDemo'] = shop['demoSampleMetrics'] == true;
      shop['distanceKm'] = distanceKm;
      shop['isFairMatchCandidate'] = _withinUserFilters(shop);
    }

    // Give a modest fairness nudge to a nearby small merchant competing with
    // a substantially busier shop in the same category.
    for (final shop in _stores) {
      shop['competitorNearby'] = false;
      if (!_hasMapLocation(shop)) continue;
      final category = (shop['business_type'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (category.isEmpty) continue;
      final shopOrders =
          ((shop['ordersToday'] ?? shop['orders_today']) as num?)?.toDouble() ??
          0;
      for (final competitor in _stores) {
        if (identical(shop, competitor) || !_hasMapLocation(competitor))
          continue;
        final competitorCategory = (competitor['business_type'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (category != competitorCategory) continue;
        final competitorOrders =
            ((competitor['ordersToday'] ?? competitor['orders_today']) as num?)
                ?.toDouble() ??
            0;
        if (competitorOrders < math.max(5, shopOrders * 1.5)) continue;
        final meters = Geolocator.distanceBetween(
          (shop['latitude'] as num).toDouble(),
          (shop['longitude'] as num).toDouble(),
          (competitor['latitude'] as num).toDouble(),
          (competitor['longitude'] as num).toDouble(),
        );
        if (meters <= 300) {
          shop['competitorNearby'] = true;
          break;
        }
      }
    }

    for (final shop in _stores) {
      if (!_hasMapLocation(shop)) continue;
      final distanceKm = _distanceTo(shop);
      final rating = (shop['rating'] as num?)?.toDouble();
      final ordersToday = (shop['ordersToday'] ?? shop['orders_today']) as num?;
      shop['priorityScore'] = _calculatePriorityScore(
        shop: shop,
        distanceKm: distanceKm,
        rating: rating,
        ordersToday: ordersToday?.toDouble(),
      );
    }

    _stores.sort((a, b) {
      final relevanceOrder = (_matchesNeed(b) ? 1 : 0).compareTo(
        _matchesNeed(a) ? 1 : 0,
      );
      if (relevanceOrder != 0) return relevanceOrder;
      final fairOrder = (b['isFairMatchCandidate'] == true ? 1 : 0).compareTo(
        a['isFairMatchCandidate'] == true ? 1 : 0,
      );
      if (fairOrder != 0) return fairOrder;
      final scoreOrder = (b['priorityScore'] as double).compareTo(
        a['priorityScore'] as double,
      );
      if (scoreOrder != 0) return scoreOrder;
      return (a['distanceKm'] as double).compareTo(b['distanceKm'] as double);
    });
  }

  double _calculatePriorityScore({
    required Map<String, dynamic> shop,
    required double distanceKm,
    required double? rating,
    required double? ordersToday,
  }) {
    final radiusKm = widget.intent.radiusKm ?? 2.0;
    if (distanceKm > radiusKm || radiusKm <= 0) return 0;
    final distanceScore = (1 - (distanceKm / radiusKm)).clamp(0.0, 1.0);
    // Missing reputation and order-volume data are neutral, never fabricated.
    final ratingScore = rating == null
        ? .6
        : (rating / 5).clamp(0.0, 1.0).toDouble();
    final lowBusinessScore = ordersToday == null
        ? .5
        : (1 - (ordersToday / 50)).clamp(0.0, 1.0).toDouble();
    final rawPrice = shop['minPrice'];
    final minPrice = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '');
    final budget = widget.intent.budgetInr;
    final cheapScore = minPrice == null
        ? .5
        : budget == null || budget <= 0
        ? (1 - (minPrice / 1000)).clamp(0.0, 1.0)
        : (1 - (minPrice / budget).clamp(0.0, 1.0));
    final weights = switch (widget.intent.priority) {
      CustomerPriority.closest => const [0.60, 0.20, 0.10, 0.10],
      CustomerPriority.cheapest => const [0.20, 0.20, 0.50, 0.10],
      CustomerPriority.bestRated => const [0.20, 0.60, 0.10, 0.10],
      CustomerPriority.fairSmallShops => const [0.25, 0.20, 0.10, 0.45],
    };
    var score =
        distanceScore * weights[0] +
        ratingScore * weights[1] +
        cheapScore * weights[2] +
        lowBusinessScore * weights[3];
    if (widget.intent.priority == CustomerPriority.fairSmallShops &&
        shop['competitorNearby'] == true) {
      score += .15;
    }
    final now = DateTime.now();
    score +=
        _dailyTieBreak(
          (shop['id'] ?? shop['business_name'] ?? '').toString(),
          now,
        ) *
        .03;
    return score.clamp(0.0, 1.0).toDouble();
  }

  double _dailyTieBreak(String shopId, DateTime date) {
    var hash = 0x811c9dc5;
    for (final codeUnit
        in '$shopId:${date.year}-${date.month}-${date.day}'.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0xffffffff;
    }
    return hash / 0xffffffff;
  }

  double _distanceTo(Map<String, dynamic> shop) {
    return (shop['distanceKm'] as num?)?.toDouble() ?? double.infinity;
  }

  String _fmtKm(double? km) {
    if (km == null || !km.isFinite) return '—';
    return km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
  }

  Widget _miniBadge(String icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.92),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      '$icon $label',
      style: const TextStyle(
        color: PaytmColors.deepNavy,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  List<Map<String, dynamic>> get _visibleStores {
    final query = _search.text.trim().toLowerCase();
    return _stores.where((shop) {
      if (_distanceTo(shop) > (widget.intent.radiusKm ?? 2.0)) return false;
      if (widget.intent.openNowOnly && !_isOpenNow(shop)) return false;
      if (query.isEmpty) return true;
      final searchable = [
        shop['business_name'],
        shop['business_type'],
        shop['items'],
        shop['location'],
      ].join(' ').toLowerCase();
      return searchable.contains(query) ||
          query.split(RegExp(r'\s+')).any(searchable.contains);
    }).toList();
  }

  bool _isOpenNow(Map<String, dynamic> shop) {
    final hours = (shop['hours'] ?? '').toString().toLowerCase();
    final match = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)\s*(?:to|–|-)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)',
    ).firstMatch(hours);
    // Unknown hours stay visible; we only hide a shop when saved hours clearly
    // describe a range that does not include the current local time.
    if (match == null) return true;
    int minutes(int hour, String? minute, String meridiem) {
      var normalizedHour = hour % 12;
      if (meridiem == 'pm') normalizedHour += 12;
      return normalizedHour * 60 + int.parse(minute ?? '0');
    }

    final start = minutes(
      int.parse(match.group(1)!),
      match.group(2),
      match.group(3)!,
    );
    final end = minutes(
      int.parse(match.group(4)!),
      match.group(5),
      match.group(6)!,
    );
    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    return end < start
        ? current >= start || current <= end
        : current >= start && current <= end;
  }

  bool _matchesNeed(Map<String, dynamic> shop) {
    if (widget.intent.items.isEmpty) return false;
    final inventory = '${shop['items'] ?? ''} ${shop['business_type'] ?? ''}'
        .toLowerCase();
    final inventoryWords = inventory
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty)
        .map(_normalizeEnglishPlural)
        .toSet();
    for (final item in widget.intent.items) {
      final itemName = item.name.toLowerCase().trim();
      if (itemName.isEmpty) continue;
      if (inventory.contains(itemName)) return true;
      for (final word in itemName.split(RegExp(r'[^a-z0-9]+'))) {
        final normalized = _normalizeEnglishPlural(word);
        if (normalized.length > 3 && inventoryWords.contains(normalized)) {
          return true;
        }
      }
    }
    return false;
  }

  String _normalizeEnglishPlural(String word) {
    if (word.length > 4 && word.endsWith('ies')) {
      return '${word.substring(0, word.length - 3)}y';
    }
    if (word.length > 4 && word.endsWith('oes')) {
      return word.substring(0, word.length - 2);
    }
    if (word.length > 3 && word.endsWith('s')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  Future<void> _showShop(Map<String, dynamic> shop) async {
    setState(() {
      _pikuShop = shop;
      _expression = _RobotExpression.excited;
    });
    if (_mapReady && _hasMapLocation(shop)) {
      _mapController.move(_pointFor(shop), 16);
    }
    _pikuJump.forward(from: 0);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _MarketShopSheet(
        shop: shop,
        copy: _copy,
        customerId: widget.customerId,
        distance: _distanceTo(shop),
        answers: _answersFor(shop),
        qrPayload: _qrPayloadFor(shop),
        onCall: () => _callShop(shop),
        onAdd: () {
          Navigator.of(sheetContext).pop();
          _addToCart(shop);
          setState(() => _expression = _RobotExpression.excited);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _expression = _RobotExpression.happy);
          });
        },
      ),
    );
    if (mounted) setState(() => _expression = _RobotExpression.happy);
  }

  Map<String, String> _answersFor(Map<String, dynamic> shop) => {
    'business_name': (shop['business_name'] ?? '').toString(),
    'business_type': (shop['business_type'] ?? '').toString(),
    'items': (shop['items'] ?? '').toString(),
    'specialty': (shop['specialty'] ?? '').toString(),
    'hours': (shop['hours'] ?? '').toString(),
    'location': (shop['location'] ?? '').toString(),
    'phone': (shop['phone'] ?? '').toString(),
    'extras': (shop['extras'] ?? '').toString(),
  };

  String _qrPayloadFor(Map<String, dynamic> shop) => jsonEncode({
    'v': 1,
    'type': 'piku_store',
    'id': (shop['id'] ?? '').toString(),
    'name': (shop['business_name'] ?? '').toString(),
    'category': (shop['business_type'] ?? '').toString(),
    'items': (shop['items'] ?? '').toString(),
    'specialty': (shop['specialty'] ?? '').toString(),
    'hours': (shop['hours'] ?? '').toString(),
    'location': (shop['location'] ?? '').toString(),
    'phone': (shop['phone'] ?? '').toString(),
    'extras': (shop['extras'] ?? '').toString(),
  });

  Future<void> _callShop(Map<String, dynamic> shop) async {
    final phone = (shop['phone'] ?? '').toString().trim();
    if (phone.isEmpty) {
      _snack(text('Phone number not added'));
      return;
    }
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    await launchUrl(Uri(scheme: 'tel', path: digits));
  }

  Future<void> _addToCart(Map<String, dynamic> shop) async {
    final candidates = widget.intent.items.isNotEmpty
        ? widget.intent.items
        : [
            CustomerItem(
              name: (shop['items'] ?? '').toString().split(',').first.trim(),
            ),
          ];
    setState(() {
      if (_cartShopId != shop['id']?.toString()) _cart.clear();
      _cartShopId = shop['id']?.toString();
      _cart.addAll(candidates);
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'piku_cart_${widget.customerId}',
      jsonEncode({
        'shopId': _cartShopId,
        'items': _cart.map((item) => item.toJson()).toList(),
      }),
    );
    _snack('${text('Cart')}: ${_cart.length}');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _reviewOrder() async {
    if (_cart.isEmpty) return;
    final shop = _stores.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id']?.toString() == _cartShopId,
      orElse: () => null,
    );
    if (shop == null) return;
    final phone = (shop['phone'] ?? '').toString().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    if (phone.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(text('Order preview')),
          content: Text(
            '${_cart.map((item) => '• ${item.displayName}').join('\n')}\n\n${text('Seller contact is not available for this demo shop.')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(text('Close')),
            ),
          ],
        ),
      );
      return;
    }
    final destination = phone.length == 10 ? '91$phone' : phone;
    final orderText = [
      'Hi ${shop['business_name']}, I would like to order:',
      ..._cart.map((item) => '• ${item.displayName}'),
    ].join('\n');
    final uri = Uri.parse(
      'https://wa.me/$destination?text=${Uri.encodeComponent(orderText)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack(text('Could not open WhatsApp'));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _mapController.dispose();
    _bob.dispose();
    _blink.dispose();
    _mouth.dispose();
    _antenna.dispose();
    _pupil.dispose();
    _pinMotion.dispose();
    _pikuJump.dispose();
    super.dispose();
  }

  List<Marker> _buildMapMarkers(List<Map<String, dynamic>> visibleStores) {
    final markers = <Marker>[
      Marker(
        point: LatLng(
          widget.userLocation.latitude,
          widget.userLocation.longitude,
        ),
        width: 54,
        height: 54,
        child: AnimatedBuilder(
          animation: _pinMotion,
          builder: (context, _) {
            final pulse = .72 + _pinMotion.value * .28;
            return Center(
              child: Transform.scale(
                scale: pulse,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: PaytmColors.paytmBlue.withOpacity(.16),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2878F0),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Color(0x552878F0), blurRadius: 9),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ];

    for (var index = 0; index < visibleStores.length; index++) {
      final shop = visibleStores[index];
      if (!_hasMapLocation(shop)) continue;
      final id = (shop['id'] ?? shop['business_name'] ?? '').toString();
      markers.add(
        Marker(
          key: ValueKey('shop_pin_$id'),
          point: _pointFor(shop),
          width: 165,
          height: 108,
          alignment: Alignment.bottomCenter,
          child: _AnimatedShopPin(
            shop: shop,
            phase: _pinMotion,
            index: index,
            isPriority: _priorityShop?['id'] == shop['id'],
            isFairMatch: shop['isFairMatch'] == true,
            fairMatchLabel: text('Fair match'),
            topPickLabel: text('Top pick'),
            highlighted: _matchesNeed(shop),
            onTap: () => _showShop(shop),
          ),
        ),
      );
    }

    final pikuShop = _pikuShop;
    if (pikuShop != null && _hasMapLocation(pikuShop)) {
      final lat = (pikuShop['latitude'] as num).toDouble();
      final lng = (pikuShop['longitude'] as num).toDouble();
      final longitudeOffset =
          .00025 / math.max(.15, math.cos(lat * math.pi / 180).abs());
      markers.add(
        Marker(
          key: const ValueKey('piku_map_marker'),
          point: LatLng(lat - .00015, lng + longitudeOffset),
          width: 100,
          height: 120,
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _pikuJump,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -math.sin(_pikuJump.value * math.pi) * 18),
              child: child,
            ),
            child: _MapPiku(
              scale: .38,
              bob: _bob,
              blink: _blink,
              mouth: _mouth,
              antenna: _antenna,
              pupil: _pupil,
              expression: _expression,
            ),
          ),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final stores = _visibleStores;
    return Scaffold(
      backgroundColor: PaytmColors.paperBlue,
      body: Stack(
        children: [
          if (!_loading)
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(
                    widget.userLocation.latitude,
                    widget.userLocation.longitude,
                  ),
                  initialZoom: 14.5,
                  minZoom: 3,
                  maxZoom: 19,
                  backgroundColor: PaytmColors.paperBlue,
                  onMapReady: () {
                    _mapReady = true;
                    _centerMapOnUser();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.paasmein',
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: LatLng(
                          widget.userLocation.latitude,
                          widget.userLocation.longitude,
                        ),
                        radius: 2000,
                        useRadiusInMeter: true,
                        color: PaytmColors.paytmBlue.withOpacity(.035),
                        borderColor: PaytmColors.paytmBlue.withOpacity(.28),
                        borderStrokeWidth: 1.2,
                      ),
                    ],
                  ),
                  MarkerLayer(markers: _buildMapMarkers(stores)),
                  RichAttributionWidget(
                    alignment: AttributionAlignment.bottomLeft,
                    showFlutterMapAttribution: false,
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: PaytmColors.paperBlue,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.96),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _CircleIconButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              text('Nearby shops'),
                              style: const TextStyle(
                                color: PaytmColors.deepNavy,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const _PaytmLogo(size: 18),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: text('Search shops or items…'),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: PaytmColors.iceBlue,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: PaytmColors.iceBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 14,
                                    color: PaytmColors.goldDeep,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${text('Your need:')} ${widget.intent.items.map((item) => item.displayName).join(', ')}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: PaytmColors.deepNavy,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _centerMapOnUser,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: PaytmColors.paytmBlue.withOpacity(.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.my_location_rounded,
                                size: 16,
                                color: PaytmColors.paytmBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.intent.budgetInr != null ||
                          widget.intent.priority != CustomerPriority.closest ||
                          widget.intent.radiusKm != null ||
                          widget.intent.openNowOnly) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (widget.intent.budgetInr != null)
                                _miniBadge(
                                  '💰',
                                  'Under ₹${widget.intent.budgetInr!.toInt()}',
                                ),
                              if (widget.intent.radiusKm != null)
                                _miniBadge(
                                  '📍',
                                  'Within ${_fmtKm(widget.intent.radiusKm)}',
                                ),
                              if (widget.intent.openNowOnly)
                                _miniBadge('🕒', 'Open now'),
                              if (widget.intent.priority !=
                                  CustomerPriority.closest)
                                _miniBadge(
                                  '🎯',
                                  switch (widget.intent.priority) {
                                    CustomerPriority.cheapest => 'Cheapest',
                                    CustomerPriority.bestRated => 'Best rated',
                                    CustomerPriority.fairSmallShops =>
                                      'Small shops',
                                    CustomerPriority.closest => 'Closest',
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (_stores.any((shop) => !_hasMapLocation(shop))) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                text('Needs a saved GPS location:'),
                                style: TextStyle(
                                  color: PaytmColors.deepNavy.withOpacity(.65),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              ..._stores
                                  .where((shop) => !_hasMapLocation(shop))
                                  .map(
                                    (shop) => ActionChip(
                                      avatar: const Icon(
                                        Icons.location_searching_rounded,
                                        size: 13,
                                      ),
                                      label: Text(
                                        (shop['business_name'] ?? 'Shop')
                                            .toString(),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onPressed: () => _showShop(shop),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                if (stores.isNotEmpty)
                  SizedBox(
                    height: 108,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      itemCount: stores.length,
                      itemBuilder: (context, index) {
                        final shop = stores[index];
                        final rating =
                            (shop['rating'] as num?)?.toDouble() ?? 0;
                        return GestureDetector(
                          onTap: () => _showShop(shop),
                          child: Container(
                            width: 200,
                            margin: const EdgeInsets.only(right: 9),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x18002970),
                                  blurRadius: 9,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 11,
                                      backgroundColor: PaytmColors.iceBlue,
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: PaytmColors.deepNavy,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        (shop['business_name'] ?? 'Shop')
                                            .toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: PaytmColors.deepNavy,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  (shop['business_type'] ?? '').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: PaytmColors.deepNavy.withOpacity(
                                      .62,
                                    ),
                                    fontSize: 10,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '⭐ ${rating.toStringAsFixed(1)}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      _fmtKm(_distanceTo(shop)),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (shop['isFairMatch'] == true) ...[
                                      const Spacer(),
                                      const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 14,
                                        color: PaytmColors.goldDeep,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (_cart.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 14,
                          offset: Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${text('Cart')} (${_cart.length}) · ${_cart.map((item) => item.name).join(', ')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PaytmColors.deepNavy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: _reviewOrder,
                          icon: const Icon(
                            Icons.shopping_bag_outlined,
                            size: 18,
                          ),
                          label: Text(text('Send order on WhatsApp')),
                          style: FilledButton.styleFrom(
                            backgroundColor: PaytmColors.deepNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPiku extends StatelessWidget {
  final double scale;
  final Animation<double> bob;
  final Animation<double> blink;
  final Animation<double> mouth;
  final Animation<double> antenna;
  final Animation<double> pupil;
  final _RobotExpression expression;

  const _MapPiku({
    this.scale = .45,
    required this.bob,
    required this.blink,
    required this.mouth,
    required this.antenna,
    required this.pupil,
    required this.expression,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      bob,
      blink,
      mouth,
      antenna,
      pupil,
      VoiceService.speakingListenable,
    ]),
    builder: (context, _) => Transform.translate(
      offset: Offset(0, math.sin(bob.value * math.pi * 2) * 3),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.bottomCenter,
        child: _PremiumRobot(
          blink: blink.value,
          wave: 0,
          showWave: false,
          antennaPulse: antenna.value,
          pupil: pupil.value,
          expression: VoiceService.isSpeaking
              ? _RobotExpression.speaking
              : expression,
          mouthFlap: VoiceService.isSpeaking
              ? _speechMouthOpening(mouth.value)
              : 0,
        ),
      ),
    ),
  );
}

class _AnimatedShopPin extends StatelessWidget {
  final Map<String, dynamic> shop;
  final Animation<double> phase;
  final int index;
  final bool isPriority;
  final bool isFairMatch;
  final String fairMatchLabel;
  final String topPickLabel;
  final bool highlighted;
  final VoidCallback onTap;

  const _AnimatedShopPin({
    required this.shop,
    required this.phase,
    required this.index,
    required this.isPriority,
    required this.isFairMatch,
    required this.fairMatchLabel,
    required this.topPickLabel,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rating = (shop['rating'] as num?)?.toDouble();
    final distance = (shop['distanceKm'] as num?)?.toDouble();
    final distanceLabel = distance == null || !distance.isFinite
        ? '—'
        : distance < 1
        ? '${(distance * 1000).round()}m'
        : '${distance.toStringAsFixed(1)}km';
    return AnimatedBuilder(
      animation: phase,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -math.sin((phase.value + index * .18) * math.pi) * 4),
        child: Transform.scale(
          scale: isPriority
              ? 1 + math.sin(phase.value * math.pi * 2) * .035
              : 1,
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPriority)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: PaytmColors.deepNavy,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: PaytmColors.deepNavy.withOpacity(.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  isFairMatch ? '🌟 $fairMatchLabel' : '📍 $topPickLabel',
                  style: const TextStyle(
                    color: PaytmColors.gold,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            Container(
              constraints: const BoxConstraints(maxWidth: 140),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isPriority ? PaytmColors.gold : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPriority
                      ? Colors.white
                      : highlighted
                      ? PaytmColors.goldDeep
                      : PaytmColors.paytmBlue.withOpacity(.4),
                  width: isPriority ? 2 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isPriority
                        ? PaytmColors.goldDeep.withOpacity(.4)
                        : Colors.black.withOpacity(.15),
                    blurRadius: isPriority ? 12 : 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (shop['emoji'] ?? '🏪').toString(),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      (shop['business_name'] ?? 'Shop').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PaytmColors.deepNavy,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isPriority)
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (rating != null) ...[
                      const Icon(
                        Icons.star_rounded,
                        color: PaytmColors.goldDeep,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      distanceLabel,
                      style: const TextStyle(
                        color: PaytmColors.deepNavy,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            CustomPaint(
              size: const Size(12, 8),
              painter: _MapPinTailPainter(isGold: isPriority),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPinTailPainter extends CustomPainter {
  final bool isGold;
  const _MapPinTailPainter({required this.isGold});
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = isGold ? PaytmColors.gold : Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPinTailPainter oldDelegate) =>
      oldDelegate.isGold != isGold;
}

class _ShopStatusBadge extends StatelessWidget {
  final String label;

  const _ShopStatusBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: PaytmColors.gold.withOpacity(.2),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: PaytmColors.gold),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: PaytmColors.deepNavy,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _MarketShopSheet extends StatefulWidget {
  final Map<String, dynamic> shop;
  final Map<String, String> copy;
  final String customerId;
  final Map<String, String> answers;
  final String qrPayload;
  final double distance;
  final VoidCallback onCall;
  final VoidCallback onAdd;

  const _MarketShopSheet({
    required this.shop,
    required this.copy,
    required this.customerId,
    required this.answers,
    required this.qrPayload,
    required this.distance,
    required this.onCall,
    required this.onAdd,
  });

  String text(String source) => copy[source] ?? source;

  @override
  State<_MarketShopSheet> createState() => _MarketShopSheetState();
}

class _MarketShopSheetState extends State<_MarketShopSheet> {
  int _myRating = 0;

  String text(String source) => widget.copy[source] ?? source;

  String get _ratingKey =>
      'piku_shop_rating_${widget.customerId}_${widget.shop['id'] ?? widget.shop['business_name']}';

  @override
  void initState() {
    super.initState();
    unawaited(_loadRating());
  }

  Future<void> _loadRating() async {
    final preferences = await SharedPreferences.getInstance();
    final rating = preferences.getInt(_ratingKey) ?? 0;
    if (mounted) setState(() => _myRating = rating);
  }

  Future<void> _saveRating(int rating) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_ratingKey, rating);
    if (!mounted) return;
    setState(() => _myRating = rating);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text('Rating saved on this device; it is not shared yet.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final name = (shop['business_name'] ?? 'Shop').toString();
    final distanceLabel = !widget.distance.isFinite
        ? text('Distance unavailable')
        : widget.distance < 1
        ? '${(widget.distance * 1000).round()} m away'
        : '${widget.distance.toStringAsFixed(1)} km away';
    final rating = (shop['rating'] as num?)?.toDouble();
    final reviewCount = (shop['ratingCount'] ?? shop['rating_count']) as num?;
    final ordersToday = (shop['ordersToday'] ?? shop['orders_today']) as num?;
    return DraggableScrollableSheet(
      initialChildSize: .72,
      minChildSize: .42,
      maxChildSize: .94,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Text(
                      (shop['emoji'] ?? '🏪').toString(),
                      style: const TextStyle(fontSize: 34),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: PaytmColors.deepNavy,
                            ),
                          ),
                          Text(
                            (shop['business_type'] ?? text('Seller'))
                                .toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: PaytmColors.deepNavy.withOpacity(.58),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      rating == null
                          ? Icons.star_border_rounded
                          : Icons.star_rounded,
                      color: PaytmColors.goldDeep,
                      size: 19,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating == null
                          ? text('No ratings yet')
                          : '${rating.toStringAsFixed(1)}${reviewCount == null ? '' : ' · ${reviewCount.toInt()} ${text('reviews')}'}',
                      style: const TextStyle(
                        color: PaytmColors.deepNavy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (shop['isFairMatch'] == true)
                      _ShopStatusBadge(label: text('Fair match')),
                    if (shop['isSmallBusiness'] == true)
                      _ShopStatusBadge(label: text('Small business')),
                    if (ordersToday != null)
                      _ShopStatusBadge(
                        label: '${ordersToday.toInt()} ${text('orders today')}',
                      ),
                    if (shop['demoSampleMetrics'] == true ||
                        shop['distanceIsDemo'] == true)
                      _ShopStatusBadge(label: text('Sample data')),
                  ],
                ),
                if (shop['isFairMatch'] == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PaytmColors.paytmBlue.withOpacity(.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: PaytmColors.paytmBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Fair match score: ${(((shop['priorityScore'] as num?)?.toDouble() ?? 0) * 100).round()}/100. Nearby shops with fewer orders and good ratings receive more visibility.',
                            style: const TextStyle(
                              color: PaytmColors.deepNavy,
                              fontSize: 11,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: PaytmColors.paytmBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        distanceLabel,
                        style: const TextStyle(
                          color: PaytmColors.deepNavy,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final lat = (shop['latitude'] as num?)?.toDouble();
                        final lng = (shop['longitude'] as num?)?.toDouble();
                        final query = lat != null && lng != null
                            ? '$lat,$lng'
                            : Uri.encodeComponent(
                                '${shop['business_name'] ?? ''} ${shop['location'] ?? ''}',
                              );
                        final uri = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=$query',
                        );
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.map_rounded, size: 16),
                      label: Text(text('Open in Maps')),
                      style: TextButton.styleFrom(
                        foregroundColor: PaytmColors.paytmBlue,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _PublishedMenuCard(
                  answers: widget.answers,
                  qrPayload: widget.qrPayload,
                  menuLabel: text('MENU'),
                  emptyItemsLabel: text('Ask us for today’s menu'),
                  famousLabel: text('Famous for:'),
                  poweredByLabel: text('Powered by Paytm Buddy'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PaytmColors.iceBlue,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: PaytmColors.paytmBlue.withOpacity(.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        text('Your private rating'),
                        style: const TextStyle(
                          color: PaytmColors.deepNavy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (index) => IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _saveRating(index + 1),
                            icon: Icon(
                              index < _myRating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: PaytmColors.goldDeep,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onCall,
                        icon: const Icon(Icons.call_rounded),
                        label: Text(text('Call shop')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PaytmColors.deepNavy,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: widget.onAdd,
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: Text(text('Add to cart')),
                        style: FilledButton.styleFrom(
                          backgroundColor: PaytmColors.deepNavy,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
