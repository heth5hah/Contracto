import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:contracto_app/features/orders/data/models/order_model.dart';
import 'package:contracto_app/core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderTrackingScreen extends StatelessWidget {
  final OrderModel order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 30,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Orders and Tracking',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 24),
            _buildTrackingCard(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showHelpAndSupportDialog(context);
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.phone_outlined, color: Color(0xFF1F2937)),
      ),
    );
  }

  Widget _buildTrackingCard() {
    final statusIndex = order.trackingStepIndex;
    final dateFormat = DateFormat('dd MMM yyyy');
    final dayFormat = DateFormat('EEE, d MMM');

    // Milestones logic
    final confirmedDate = order.trackingMilestones?['confirmed'] ?? order.createdAt;
    final transportDate = order.trackingMilestones?['transport'];
    final deliveredDate = order.trackingMilestones?['delivered'];
    final estDate = order.estimatedDelivery ?? order.createdAt.add(const Duration(days: 7));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ID: ${order.id.replaceAll('-', '').substring(0, 12).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order date: ${dateFormat.format(order.createdAt)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              const Icon(Icons.info_outline, color: Colors.black),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: Color(0xFF10B981), size: 24),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Estimated delivery: ${dateFormat.format(estDate)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _buildTimeline(statusIndex, dayFormat, confirmedDate, transportDate, deliveredDate, estDate),
          
          if (order.statusNotes?.isNotEmpty == true) ...[
            const SizedBox(height: 40),
            const Divider(height: 1),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.note_alt_outlined, size: 20, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                const Text(
                  'Status Notes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                if (order.updatedAt != null)
                  Text(
                    'Updated: ${DateFormat('dd MMM, hh:mm a').format(order.updatedAt!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                order.statusNotes!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildTimeline(
    int currentIndex,
    DateFormat dayFormat,
    DateTime confirmedDate,
    DateTime? transportDate,
    DateTime? deliveredDate,
    DateTime estDate,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStepLabel('Order Confirmed', currentIndex >= 0),
            _buildStepLabel('In Transport', currentIndex >= 1),
            _buildStepLabel('Delivered', currentIndex >= 2),
            if (currentIndex >= 3) _buildStepLabel('Returned', currentIndex >= 3),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildDot(currentIndex >= 0),
            Expanded(child: _buildLine(currentIndex >= 1)),
            _buildDot(currentIndex >= 1),
            Expanded(child: _buildLine(currentIndex >= 2)),
            _buildDot(currentIndex >= 2),
            if (currentIndex >= 3) Expanded(child: _buildLine(currentIndex >= 3)),
            if (currentIndex >= 3) _buildDot(currentIndex >= 3),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildDateLabel(dayFormat.format(confirmedDate)),
            _buildDateLabel(transportDate != null ? dayFormat.format(transportDate) : dayFormat.format(confirmedDate)),
            _buildDateLabel(deliveredDate != null ? dayFormat.format(deliveredDate) : 'Expected by, ${DateFormat('EEE d').format(estDate)}th'),
            if (currentIndex >= 3) _buildDateLabel(dayFormat.format(order.updatedAt ?? DateTime.now())),
          ],
        ),
      ],
    );
  }

  Widget _buildStepLabel(String label, bool isReached) {
    return SizedBox(
      width: 80,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isReached ? const Color(0xFF10B981) : const Color(0xFF9CA3AF).withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildDateLabel(String label) {
    return SizedBox(
      width: 80,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildLine(bool isActive) {
    return Container(
      height: 1.5,
      color: isActive ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
    );
  }

  void _showHelpAndSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.headset_mic,
                      color: Color(0xFF3B82F6),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Help & Support',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Contact Options
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Phone Support
                      _buildSupportOption(
                        icon: Icons.phone,
                        title: 'Call Support',
                        subtitle: AppConfig.contactPhoneDisplay,
                        color: const Color(0xFF10B981),
                        onTap: () async {
                          final Uri phoneUri = Uri.parse('tel:${AppConfig.contactPhone}');
                          if (await canLaunchUrl(phoneUri)) {
                            await launchUrl(phoneUri);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Unable to make phone call'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Email Support
                      _buildSupportOption(
                        icon: Icons.email_outlined,
                        title: 'Email Support',
                        subtitle: AppConfig.contactEmail,
                        color: const Color(0xFF3B82F6),
                        onTap: () async {
                          final Uri emailUri = Uri.parse('mailto:${AppConfig.contactEmail}?subject=Order Support Request');
                          if (await canLaunchUrl(emailUri)) {
                            await launchUrl(emailUri);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Unable to open email'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // WhatsApp Support
                      _buildSupportOption(
                        icon: Icons.chat_outlined,
                        title: 'Chat Support',
                        subtitle: 'Get instant help via WhatsApp',
                        color: const Color(0xFF25D366),
                        onTap: () async {
                          // WhatsApp support with pre-filled message
                          final orderId = order.id.replaceAll('-', '').substring(0, 12).toUpperCase();
                          final message = 'Hi! I need help with my order.\n\nOrder ID: $orderId\nStatus: ${order.status}\n\nPlease assist me.';
                          
                          final whatsappUrl = 'https://wa.me/${AppConfig.contactWhatsApp}?text=${Uri.encodeComponent(message)}';
                          final uri = Uri.parse(whatsappUrl);
                          
                          try {
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Unable to open WhatsApp. Please install WhatsApp or contact us via phone/email.'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error opening WhatsApp: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Order Information
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline, size: 20, color: Color(0xFF6B7280)),
                                SizedBox(width: 8),
                                Text(
                                  'Order Information',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Order ID: ${order.id.replaceAll('-', '').substring(0, 12).toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Status: ${order.status.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
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
      ),
    );
  }

  Widget _buildSupportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
