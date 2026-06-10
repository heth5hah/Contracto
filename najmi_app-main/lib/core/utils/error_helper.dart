class ErrorHelper {
  /// Converts technical database errors to human-readable messages
  static String getHumanReadableError(dynamic error) {
    if (error == null) return 'An unknown error occurred';

    final errorString = error.toString().toLowerCase();

    // Database constraint errors
    if (errorString.contains('duplicate key') ||
        errorString.contains('already exists')) {
      if (errorString.contains('email')) {
        return 'An account with this email already exists. Please try logging in instead.';
      }
      if (errorString.contains('mobile')) {
        return 'A mobile number is already registered with this account.';
      }
      if (errorString.contains('pan')) {
        return 'This PAN number is already registered with another account.';
      }
      if (errorString.contains('gst')) {
        return 'This GST number is already registered with another account.';
      }
      return 'This information is already registered with another account.';
    }

    // Authentication errors
    if (errorString.contains('user not authenticated') ||
        errorString.contains('not authenticated')) {
      return 'Please log in to continue.';
    }

    if (errorString.contains('user not found')) {
      return 'User account not found. Please try logging in again.';
    }

    // Network errors
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network connection issue. Please check your internet connection and try again.';
    }

    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    // Permission errors
    if (errorString.contains('permission') ||
        errorString.contains('unauthorized')) {
      return 'You don\'t have permission to perform this action.';
    }

    if (errorString.contains('row-level security') ||
        errorString.contains('rls')) {
      return 'Access denied due to security restrictions. Please contact support.';
    }

    // Validation errors
    if (errorString.contains('invalid') || errorString.contains('validation')) {
      return 'Please check your input and try again.';
    }

    // Generic database errors
    if (errorString.contains('database') || errorString.contains('postgres')) {
      return 'A database error occurred. Please try again or contact support.';
    }

    // Default fallback
    return 'Something went wrong. Please try again.';
  }

  /// Gets a user-friendly title for the error
  static String getErrorTitle(dynamic error) {
    if (error == null) return 'Error';

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('duplicate') ||
        errorString.contains('already exists')) {
      return 'Already Exists';
    }

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Connection Error';
    }

    if (errorString.contains('permission') ||
        errorString.contains('unauthorized')) {
      return 'Access Denied';
    }

    if (errorString.contains('validation') || errorString.contains('invalid')) {
      return 'Invalid Input';
    }

    return 'Error';
  }

  /// Checks if the error is retryable
  static bool isRetryable(dynamic error) {
    if (error == null) return false;

    final errorString = error.toString().toLowerCase();

    // Network errors are usually retryable
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return true;
    }

    // Server errors might be retryable
    if (errorString.contains('server') || errorString.contains('internal')) {
      return true;
    }

    // Constraint violations are not retryable
    if (errorString.contains('duplicate') ||
        errorString.contains('constraint') ||
        errorString.contains('validation')) {
      return false;
    }

    return false;
  }
}
