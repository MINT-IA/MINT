import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:mint_mobile/services/api_service.dart';

/// Privacy-first analytics service for MINT
///
/// Features:
/// - Anonymous session ID (UUID) stored locally
/// - Event queuing and batching
/// - Graceful fallback if backend is unreachable
/// - Consent-based tracking (opt-in)
/// - No PII, no device fingerprinting
///
/// LPD (Swiss Privacy Law) Compliant
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static const String _sessionIdKey = 'analytics_session_id';
  static const String _consentKey = 'analytics_consent';
  static const String _eventsQueueKey = 'analytics_events_queue';
  static const int _maxQueueSize = 50;
  static const int _flushThreshold = 10;

  String? _sessionId;
  bool _isEnabled = false;
  final List<Map<String, dynamic>> _eventQueue = [];
  bool _isInitialized = false;

  /// Initialize the analytics service
  /// Loads session ID and consent status from SharedPreferences
  Future<void> init() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();

    // Load or create anonymous session ID
    _sessionId = prefs.getString(_sessionIdKey);
    if (_sessionId == null) {
      _sessionId = const Uuid().v4();
      await prefs.setString(_sessionIdKey, _sessionId!);
    }

    // Load consent status (defaults to false - opt-in required)
    _isEnabled = prefs.getBool(_consentKey) ?? false;

    // Load persisted event queue
    final queueJson = prefs.getString(_eventsQueueKey);
    if (queueJson != null) {
      try {
        final List<dynamic> decodedQueue = jsonDecode(queueJson);
        _eventQueue.addAll(decodedQueue.cast<Map<String, dynamic>>());
      } catch (e) {
        // Ignore corrupted queue
        await prefs.remove(_eventsQueueKey);
      }
    }

    _isInitialized = true;

    // Auto-flush persisted events on init if consent is given
    if (_isEnabled && _eventQueue.isNotEmpty) {
      flush();
    }
  }

  /// Get current session ID
  String? get sessionId => _sessionId;

  /// Check if analytics is enabled
  bool get isEnabled => _isEnabled;

  /// Set user consent for analytics
  Future<void> setConsent(bool consent) async {
    _isEnabled = consent;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, consent);

    if (consent) {
      // Track consent event
      trackEvent('analytics_consent_granted', category: 'system');
      // Flush any queued events
      if (_eventQueue.isNotEmpty) {
        flush();
      }
    } else {
      // Clear queue if consent revoked
      _eventQueue.clear();
      await prefs.remove(_eventsQueueKey);
      trackEvent('analytics_consent_revoked', category: 'system');
      flush(); // Send the revocation event
    }
  }

  /// Track an event
  ///
  /// [name] Event name (e.g., 'onboarding_completed')
  /// [category] Event category (e.g., 'engagement', 'navigation', 'conversion')
  /// [data] Additional event data (no PII!)
  /// [screenName] Screen name for navigation events
  void trackEvent(
    String name, {
    String category = 'engagement',
    Map<String, dynamic>? data,
    String? screenName,
  }) {
    if (!_isInitialized) {
      // Queue event for tracking after initialization
      return;
    }

    if (!_isEnabled && name != 'analytics_consent_granted' && name != 'analytics_consent_revoked') {
      // Don't track if consent not given (except consent events)
      return;
    }

    final event = {
      'name': name,
      'category': category,
      'timestamp': DateTime.now().toIso8601String(),
      'session_id': _sessionId,
      if (data != null) 'data': data,
      if (screenName != null) 'screen_name': screenName,
    };

    _eventQueue.add(event);

    // Persist queue to SharedPreferences
    _persistQueue();

    // Auto-flush if threshold reached
    if (_eventQueue.length >= _flushThreshold) {
      flush();
    }
  }

  /// Track a screen view
  void trackScreenView(String screenName) {
    trackEvent(
      'screen_view',
      category: 'navigation',
      screenName: screenName,
    );
  }

  /// Track onboarding progress
  void trackOnboardingStep(int step, String stepName, {int? totalSteps}) {
    trackEvent(
      'onboarding_step_completed',
      category: 'engagement',
      data: {
        'step': step,
        'step_name': stepName,
        if (totalSteps != null) 'total_steps': totalSteps,
      },
    );
  }

  /// Track onboarding start
  void trackOnboardingStarted() {
    trackEvent('onboarding_started', category: 'engagement');
  }

  /// Track onboarding completion with time spent
  void trackOnboardingCompleted({int? timeSpentSeconds}) {
    trackEvent(
      'onboarding_completed',
      category: 'conversion',
      data: {
        if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
      },
    );
  }

  /// Track CTA click
  void trackCTAClick(String ctaName, {String? screenName}) {
    trackEvent(
      'cta_clicked',
      category: 'engagement',
      data: {'cta_name': ctaName},
      screenName: screenName,
    );
  }

  /// Track tab switch
  void trackTabSwitch(String fromTab, String toTab) {
    trackEvent(
      'tab_switched',
      category: 'navigation',
      data: {
        'from': fromTab,
        'to': toTab,
      },
    );
  }

  /// Flush event queue to backend
  /// Sends all queued events in a batch and clears the queue
  Future<void> flush() async {
    if (_eventQueue.isEmpty) return;

    // Create a copy of events to send
    final eventsToSend = List<Map<String, dynamic>>.from(_eventQueue);

    try {
      // Send to backend
      await ApiService.post('/analytics/events', {
        'events': eventsToSend,
        'session_id': _sessionId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Clear queue on success
      _eventQueue.clear();
      await _persistQueue();
    } catch (e) {
      // Graceful fallback: log locally but don't throw
      // Events remain in queue for next flush attempt
      if (kDebugMode) {
        debugPrint('Analytics flush failed (graceful): $e');
      }

      // Prevent queue from growing indefinitely
      if (_eventQueue.length > _maxQueueSize) {
        // Remove oldest events
        _eventQueue.removeRange(0, _eventQueue.length - _maxQueueSize);
        await _persistQueue();
      }
    }
  }

  /// Persist event queue to SharedPreferences
  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_eventQueue);
      await prefs.setString(_eventsQueueKey, queueJson);
    } catch (e) {
      // Ignore persistence errors
      if (kDebugMode) {
        debugPrint('Failed to persist analytics queue: $e');
      }
    }
  }

  /// Check if user has given consent
  static Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }

  /// Check if consent has been asked
  static Future<bool> hasAskedForConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_consentKey);
  }
}
