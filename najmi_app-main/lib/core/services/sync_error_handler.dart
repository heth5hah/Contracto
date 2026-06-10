import 'dart:async';

/// Error handler for sync operations
/// Provides graceful error handling and retry logic
class SyncErrorHandler {
  static final SyncErrorHandler _instance = SyncErrorHandler._internal();
  factory SyncErrorHandler() => _instance;
  SyncErrorHandler._internal();

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 1);
  static const Duration maxRetryDelay = Duration(seconds: 30);

  /// Execute an operation with retry logic
  Future<T> executeWithRetry<T>({
    required Future<T> Function() operation,
    String? operationName,
    int maxAttempts = maxRetries,
  }) async {
    int attempt = 0;
    Duration delay = initialRetryDelay;

    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        if (attempt >= maxAttempts) {
          print('${operationName ?? 'Operation'} failed after $maxAttempts attempts: $e');
          rethrow;
        }

        print('${operationName ?? 'Operation'} failed (attempt $attempt/$maxAttempts): $e');
        print('Retrying in ${delay.inSeconds} seconds...');

        await Future.delayed(delay);
        
        // Exponential backoff with max cap
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 2).clamp(
            initialRetryDelay.inMilliseconds,
            maxRetryDelay.inMilliseconds,
          ),
        );
      }
    }

    throw Exception('${operationName ?? 'Operation'} failed after $maxAttempts attempts');
  }

  /// Handle network errors gracefully
  String getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || 
        errorString.contains('socket') ||
        errorString.contains('connection')) {
      return 'Network connection issue. Please check your internet connection.';
    }

    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (errorString.contains('unauthorized') || 
        errorString.contains('authentication')) {
      return 'Authentication error. Please log in again.';
    }

    if (errorString.contains('permission') || 
        errorString.contains('forbidden')) {
      return 'You don\'t have permission to perform this action.';
    }

    if (errorString.contains('not found')) {
      return 'The requested resource was not found.';
    }

    // Generic error message
    return 'An error occurred. Please try again later.';
  }

  /// Check if error is recoverable
  bool isRecoverableError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network errors are recoverable
    if (errorString.contains('network') || 
        errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return true;
    }

    // Server errors (5xx) are recoverable
    if (errorString.contains('500') || 
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504')) {
      return true;
    }

    // Auth and permission errors are not recoverable
    if (errorString.contains('unauthorized') || 
        errorString.contains('forbidden') ||
        errorString.contains('authentication')) {
      return false;
    }

    // Default to recoverable for unknown errors
    return true;
  }

  /// Log error for debugging
  void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    print('=== ERROR in $context ===');
    print('Error: $error');
    if (stackTrace != null) {
      print('Stack trace: $stackTrace');
    }
    print('========================');
  }
}
