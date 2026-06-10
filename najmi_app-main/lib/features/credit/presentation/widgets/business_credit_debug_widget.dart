import 'package:flutter/material.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/credit/data/services/business_credit_service.dart';
import 'package:contracto_app/features/auth/data/services/user_service.dart';

/// Debug widget to check Business Credit visibility
class BusinessCreditDebugWidget extends StatelessWidget {
  const BusinessCreditDebugWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _checkStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Checking Business Credit status...'),
            ),
          );
        }

        final status = snapshot.data ?? {};
        final shouldShow = status['shouldShow'] as bool? ?? false;

        return Card(
          margin: const EdgeInsets.all(16),
          color: shouldShow ? Colors.green.shade50 : Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business Credit Debug Info',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: shouldShow ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                _buildStatusRow('Is Logged In', status['isLoggedIn']?.toString() ?? 'unknown'),
                _buildStatusRow('User Type', status['userType']?.toString() ?? 'unknown'),
                _buildStatusRow('Is Business Account', status['isBusiness']?.toString() ?? 'unknown'),
                _buildStatusRow('Credit Account Exists', status['creditAccountExists']?.toString() ?? 'unknown'),
                _buildStatusRow('Credit Limit', status['creditLimit']?.toString() ?? 'unknown'),
                _buildStatusRow('KYC Status', status['kycStatus']?.toString() ?? 'unknown'),
                const SizedBox(height: 12),
                Text(
                  shouldShow
                      ? '✅ Widget SHOULD be visible'
                      : '❌ Widget will NOT be visible',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: shouldShow ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                if (!shouldShow) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Reason: ${status['reason'] ?? 'Unknown'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _checkStatus() async {
    final status = <String, dynamic>{};

    try {
      // Check if logged in
      final user = SupabaseService.instance.currentUser;
      status['isLoggedIn'] = user != null;

      if (user == null) {
        status['shouldShow'] = false;
        status['reason'] = 'User not logged in';
        return status;
      }

      // Get user data
      final userService = UserService();
      final userData = await userService.getCurrentUserData();
      final userType = userData?['user_type'] as String?;
      status['userType'] = userType;
      status['isBusiness'] = userType == 'company';

      if (userType != 'company') {
        status['shouldShow'] = false;
        status['reason'] = 'User is not a business account (user_type: $userType)';
        return status;
      }

      // Check credit account
      final creditService = BusinessCreditService();
      final creditAccount = await creditService.getCreditAccount();
      status['creditAccountExists'] = creditAccount != null;

      if (creditAccount == null) {
        status['shouldShow'] = false;
        status['reason'] = 'Credit account does not exist. Run create_credit_accounts_for_existing_business_users.sql';
        return status;
      }

      final creditLimit = (creditAccount['credit_limit'] ?? 0.0).toDouble();
      final kycStatus = creditAccount['kyc_status'] as String?;
      status['creditLimit'] = creditLimit;
      status['kycStatus'] = kycStatus;

      if (creditLimit == 0) {
        status['shouldShow'] = false;
        status['reason'] = 'Credit limit is 0';
        return status;
      }

      status['shouldShow'] = true;
      status['reason'] = 'All conditions met';
    } catch (e) {
      status['shouldShow'] = false;
      status['reason'] = 'Error: $e';
    }

    return status;
  }
}

