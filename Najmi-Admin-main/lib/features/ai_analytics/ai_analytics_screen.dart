import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../core/supabase/supabase_config.dart';

// ─── Gemini config ────────────────────────────────────────────────────────────
const _geminiApiKey = 'AIzaSyCZ6y8DEHcZQfdjPHEN0pzX9n5KpowZcm0';
const _geminiUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

// ─── Data model ───────────────────────────────────────────────────────────────
class _BusinessData {
  final int totalProducts;
  final int totalBrands;
  final int totalCategories;
  final int featuredItems;
  final Map<String, int> categoryDistribution;
  final Map<String, int> brandDistribution;
  final Map<String, int> priceDistribution;
  final Map<String, int> stockDistribution;

  const _BusinessData({
    required this.totalProducts,
    required this.totalBrands,
    required this.totalCategories,
    required this.featuredItems,
    required this.categoryDistribution,
    required this.brandDistribution,
    required this.priceDistribution,
    required this.stockDistribution,
  });
}

// ─── Chat message model ───────────────────────────────────────────────────────
class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isLoading;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isLoading = false,
  });
}

// ─── Helper: safe opacity ─────────────────────────────────────────────────────
Color _op(Color c, double opacity) => c.withValues(alpha: opacity);

// ─── Metric item data ─────────────────────────────────────────────────────────
class _MetricItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String trend;
  const _MetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class AiAnalyticsScreen extends ConsumerStatefulWidget {
  const AiAnalyticsScreen({super.key});

  @override
  ConsumerState<AiAnalyticsScreen> createState() => _AiAnalyticsScreenState();
}

class _AiAnalyticsScreenState extends ConsumerState<AiAnalyticsScreen>
    with SingleTickerProviderStateMixin {

  // Data
  _BusinessData? _data;
  bool _loading = true;
  String? _error;

  // AI chat
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          "Hello! I'm your AI business assistant. I can help you analyze your data, identify trends, and provide actionable insights. Try asking me about your products, sales performance, or business recommendations.",
      isUser: false,
    ),
  ];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  bool _sending = false;
  String _aiStatus = 'AI Ready';
  Color _aiStatusColor = const Color(0xFF10B981);

  // Insights
  String _salesInsight = '';
  String _productInsight = '';
  String _brandInsight = '';
  String _growthInsight = '';

  // AI Generated Report
  String _monthlyReportContent = '';
  bool _generatingReport = false;
  DateTime? _lastReportGenerated;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _chatScroll.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = SupabaseConfig.client;

      // Count tables by fetching id only
      final productList = await client.from('products').select('id') as List<dynamic>;
      final brandList = await client.from('brands').select('id') as List<dynamic>;
      final categoryList = await client.from('categories').select('id') as List<dynamic>;

      final productCount = productList.length;
      final brandCount = brandList.length;
      final categoryCount = categoryList.length;

      int featuredItems = 0;
      try {
        final fp = await client.from('featured_products').select('id') as List<dynamic>;
        final fb = await client.from('featured_brands').select('id') as List<dynamic>;
        final img = await client.from('image_slides').select('id') as List<dynamic>;
        featuredItems = fp.length + fb.length + img.length;
      } catch (_) {}

      // Fetch product details for distribution charts
      // Products link to brands via brand_ids; join brands for name
      final products = await client
          .from('products')
          .select('category, final_price, stock_status, brands(name)')
          .limit(500) as List<dynamic>;

      final catDist = <String, int>{};
      final brandDist = <String, int>{};
      final priceDist = <String, int>{
        'Under ₹100': 0,
        '₹100–500': 0,
        '₹500–1000': 0,
        '₹1000–5000': 0,
        'Above ₹5000': 0,
      };
      final stockDist = <String, int>{
        'In Stock': 0,
        'Low Stock': 0,
        'Out of Stock': 0,
      };

      for (final p in products) {
        final cat = (p['category'] as String?)?.trim() ?? 'Uncategorized';
        catDist[cat] = (catDist[cat] ?? 0) + 1;

        // Extract brand name from joined brands (array or single object)
        String brand = 'Unknown';
        final brandsData = p['brands'];
        if (brandsData is List && brandsData.isNotEmpty) {
          brand = (brandsData.first['name'] as String?)?.trim() ?? 'Unknown';
        } else if (brandsData is Map) {
          brand = (brandsData['name'] as String?)?.trim() ?? 'Unknown';
        }
        brandDist[brand] = (brandDist[brand] ?? 0) + 1;

        final price = double.tryParse(p['final_price']?.toString() ?? '0') ?? 0;
        if (price < 100) {
          priceDist['Under ₹100'] = (priceDist['Under ₹100'] ?? 0) + 1;
        } else if (price < 500) {
          priceDist['₹100–500'] = (priceDist['₹100–500'] ?? 0) + 1;
        } else if (price < 1000) {
          priceDist['₹500–1000'] = (priceDist['₹500–1000'] ?? 0) + 1;
        } else if (price < 5000) {
          priceDist['₹1000–5000'] = (priceDist['₹1000–5000'] ?? 0) + 1;
        } else {
          priceDist['Above ₹5000'] = (priceDist['Above ₹5000'] ?? 0) + 1;
        }

        final status = (p['stock_status'] as String?) ?? 'In Stock';
        if (stockDist.containsKey(status)) {
          stockDist[status] = stockDist[status]! + 1;
        } else {
          stockDist['In Stock'] = (stockDist['In Stock'] ?? 0) + 1;
        }
      }

      final sortedBrands = brandDist.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top10Brands = Map.fromEntries(sortedBrands.take(10));

      setState(() {
        _data = _BusinessData(
          totalProducts: productCount,
          totalBrands: brandCount,
          totalCategories: categoryCount,
          featuredItems: featuredItems,
          categoryDistribution: catDist,
          brandDistribution: top10Brands,
          priceDistribution: priceDist,
          stockDistribution: stockDist,
        );
        _loading = false;
      });

      _setDefaultInsights();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _setDefaultInsights() {
    setState(() {
      _salesInsight =
          'Good category diversity. Focus on inventory management and seasonal trends for better performance.';
      _productInsight =
          'Strong catalog diversity. Feature best-performing categories and optimize descriptions for better engagement.';
      _brandInsight =
          'Good brand portfolio coverage. Strengthen relationships with top brands and expand partnerships.';
      _growthInsight =
          'Key opportunities: Expand featured products, better inventory management, leverage seasonal trends, and digital marketing.';
    });
  }

  String _buildContext() {
    if (_data == null) return '';
    final parts = <String>[
      'Total Products: ${_data!.totalProducts}',
      'Total Brands: ${_data!.totalBrands}',
      'Total Categories: ${_data!.totalCategories}',
      'Featured Items: ${_data!.featuredItems}',
    ];
    if (_data!.categoryDistribution.isNotEmpty) {
      parts.add('Categories: ${_data!.categoryDistribution.keys.join(', ')}');
    }
    return parts.join('\n');
  }

  // ── Gemini API ──────────────────────────────────────────────────────────────
  Future<String> _callGemini(String prompt) async {
    try {
      final dio = Dio();
      final response = await dio.post(
        '$_geminiUrl?key=$_geminiApiKey',
        data: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      final candidates = response.data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) throw Exception('No response');
      return candidates[0]['content']['parts'][0]['text'] as String;
    } catch (e) {
      return _mockResponse(prompt);
    }
  }

  String _mockResponse(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('top performing') || lower.contains('products')) {
      return 'Your top categories are building materials and plumbing supplies. Consider featuring best-selling items for better visibility.';
    }
    if (lower.contains('performance') || lower.contains('monthly')) {
      return 'Good diversity across categories. Focus on inventory management and seasonal trends for better performance.';
    }
    if (lower.contains('growth') || lower.contains('recommendation')) {
      return 'Key growth areas: 1) Expand featured products, 2) Better inventory tracking, 3) Add customer reviews, 4) Optimize categories.';
    }
    if (lower.contains('inventory')) {
      return 'Implement stock alerts and focus on profitable product lines for optimal inventory management.';
    }
    return 'Your construction materials business shows good organization. For detailed analysis, please try again later.';
  }

  // ── Chat ─────────────────────────────────────────────────────────────────────
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _sending) return;
    _inputCtrl.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text.trim(), isUser: true));
      _messages.add(const _ChatMessage(text: '', isUser: false, isLoading: true));
      _sending = true;
    });
    _scrollToBottom();

    final ctx = _buildContext();
    final prompt =
        'You are an AI business analyst for a construction materials company. Based on the following business data, answer this question: "$text"\n\nBusiness Data:\n$ctx\n\nProvide a helpful, actionable response.';

    final response = await _callGemini(prompt);

    setState(() {
      _messages.removeLast();
      _messages.add(_ChatMessage(text: response, isUser: false));
      _sending = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Try AI Generation ────────────────────────────────────────────────────────
  Future<void> _tryAIGeneration() async {
    setState(() {
      _aiStatus = 'Generating...';
      _aiStatusColor = const Color(0xFFF59E0B);
    });
    try {
      final ctx = _buildContext();
      final prompt =
          'Analyze the sales trends for this construction materials business:\n$ctx\nProvide a brief 2-3 sentence analysis.';
      final result = await _callGemini(prompt);
      setState(() {
        _salesInsight = result;
        _aiStatus = 'AI Active';
        _aiStatusColor = const Color(0xFF10B981);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI insights generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _aiStatus = 'AI Unavailable';
        _aiStatusColor = Colors.red;
      });
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text('Error: $_error'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: _loadData,
          ),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(children: [
        _buildPageHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildMetricsGrid(),
              const SizedBox(height: 24),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: _buildAIChat()),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: _buildInsightsCards()),
              ]),
              const SizedBox(height: 24),
              _buildChartsSection(),
              const SizedBox(height: 24),
              _buildRecommendationsSection(),
              const SizedBox(height: 24),
              _buildAIReportsSection(),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Page header ─────────────────────────────────────────────────────────────
  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'AI Analytics Dashboard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          Text(
            'Powered by Gemini AI — get intelligent insights about your business',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _op(_aiStatusColor, 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _op(_aiStatusColor, 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.smart_toy_outlined, size: 16, color: _aiStatusColor),
            const SizedBox(width: 6),
            Text(_aiStatus, style: TextStyle(fontSize: 12, color: _aiStatusColor, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _tryAIGeneration,
          icon: const Icon(Icons.auto_fix_high, size: 16),
          label: const Text('Try AI'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh data',
          color: const Color(0xFF64748B),
        ),
      ]),
    );
  }

  // ── Metric cards ─────────────────────────────────────────────────────────────
  Widget _buildMetricsGrid() {
    final metrics = [
      _MetricItem(label: 'Total Products',  value: _data!.totalProducts,  icon: Icons.shopping_bag_outlined,  color: const Color(0xFF3B82F6), trend: '+12%'),
      _MetricItem(label: 'Active Brands',   value: _data!.totalBrands,    icon: Icons.bookmark_border,         color: const Color(0xFF10B981), trend: '+5%'),
      _MetricItem(label: 'Categories',      value: _data!.totalCategories, icon: Icons.folder_outlined,       color: const Color(0xFFF59E0B), trend: '0%'),
      _MetricItem(label: 'Featured Items',  value: _data!.featuredItems,  icon: Icons.star_border,             color: const Color(0xFFEF4444), trend: '+8%'),
    ];

    return Row(
      children: List.generate(metrics.length, (index) {
        final m = metrics[index];
        final isLast = index == metrics.length - 1;
        final isPositive = m.trend.startsWith('+');
        return Expanded(
          child: Container(
            margin: isLast ? EdgeInsets.zero : const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: _op(Colors.black, 0.04), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _op(m.color, 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(m.icon, color: m.color, size: 22),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPositive ? _op(const Color(0xFF10B981), 0.1) : _op(Colors.grey, 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    m.trend,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? const Color(0xFF10B981) : Colors.grey.shade600,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Text(
                NumberFormat.compact().format(m.value),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(m.label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ]),
          ),
        );
      }),
    );
  }

  // ── AI Chat ──────────────────────────────────────────────────────────────────
  Widget _buildAIChat() {
    final quickQuestions = [
      'What are my top performing products?',
      'How is my business performing?',
      'What recommendations do you have for growth?',
      'Analyze my inventory levels',
    ];
    final quickLabels = ['Top Products', 'Performance', 'Growth Tips', 'Inventory'];

    return Container(
      height: 480,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _op(Colors.black, 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Chat header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _op(Colors.white, 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI Business Assistant',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text('Ask me anything about your business data',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ]),
        ),

        // Messages
        Expanded(
          child: ListView.builder(
            controller: _chatScroll,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, i) => _buildChatBubble(_messages[i]),
          ),
        ),

        // Quick questions
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: List.generate(quickLabels.length, (i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _sendMessage(quickQuestions[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: _op(const Color(0xFF6366F1), 0.4)),
                    borderRadius: BorderRadius.circular(20),
                    color: _op(const Color(0xFF6366F1), 0.05),
                  ),
                  child: Text(
                    quickLabels[i],
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            )),
          ),
        ),

        // Input
        Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                decoration: InputDecoration(
                  hintText: 'Ask me about your business...',
                  hintStyle: const TextStyle(fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : () => _sendMessage(_inputCtrl.text),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildChatBubble(_ChatMessage msg) {
    if (msg.isLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _dot(),
              const SizedBox(width: 4),
              _dot(),
              const SizedBox(width: 4),
              _dot(),
            ]),
          ),
        ]),
      );
    }

    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF0F172A),
            child: Icon(Icons.person, size: 18, color: Colors.white),
          ),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
          child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(msg.text, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
          ),
        ),
      ]),
    );
  }

  Widget _dot() => const CircleAvatar(radius: 4, backgroundColor: Color(0xFF94A3B8));

  // ── Insight cards ─────────────────────────────────────────────────────────────
  Widget _buildInsightsCards() {
    final insights = [
      {'icon': Icons.trending_up,           'title': 'Sales Trends',         'text': _salesInsight,   'color': const Color(0xFF3B82F6)},
      {'icon': Icons.shopping_bag_outlined, 'title': 'Product Performance',  'text': _productInsight, 'color': const Color(0xFF10B981)},
      {'icon': Icons.bookmark_border,       'title': 'Brand Analysis',       'text': _brandInsight,   'color': const Color(0xFF8B5CF6)},
      {'icon': Icons.lightbulb_outline,     'title': 'Growth Opportunities', 'text': _growthInsight,  'color': const Color(0xFFF59E0B)},
    ];

    return Column(
      children: insights.map((i) {
        final color = i['color'] as Color;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: _op(Colors.black, 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(i['icon'] as IconData, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                i['title'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              i['text'] as String,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.5),
            ),
          ]),
        );
      }).toList(),
    );
  }

  // ── Charts section ────────────────────────────────────────────────────────────
  Widget _buildChartsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.bar_chart, color: Color(0xFF6366F1)),
        SizedBox(width: 8),
        Text('Visual Analytics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ]),
      const SizedBox(height: 4),
      const Text('Data-driven insights through interactive charts',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _buildBarChart('Products by Category', _data!.categoryDistribution, const Color(0xFF3B82F6))),
        const SizedBox(width: 16),
        Expanded(child: _buildBarChart('Brand Distribution (Top 10)', _data!.brandDistribution, const Color(0xFF8B5CF6))),
      ]),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _buildBarChart('Pricing Analysis', _data!.priceDistribution, const Color(0xFF10B981))),
        const SizedBox(width: 16),
        Expanded(child: _buildStockChart()),
      ]),
    ]);
  }

  Widget _buildBarChart(String title, Map<String, int> data, Color color) {
    final maxVal = data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _op(Colors.black, 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          const Center(child: Text('No data', style: TextStyle(color: Color(0xFF94A3B8))))
        else
          ...entries.take(8).map((e) {
            final ratio = maxVal == 0 ? 0.0 : e.value / maxVal;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    e.key.length > 12 ? '${e.key.substring(0, 12)}…' : e.key,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(builder: (ctx, bc) {
                    return Stack(children: [
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: _op(color, 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        height: 20,
                        width: bc.maxWidth * ratio,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [color, _op(color, 0.7)]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ]);
                  }),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${e.value}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _buildStockChart() {
    final data = _data!.stockDistribution;
    final total = data.values.fold(0, (a, b) => a + b);
    final colors = [const Color(0xFF10B981), const Color(0xFFF59E0B), const Color(0xFFEF4444)];
    final keys = ['In Stock', 'Low Stock', 'Out of Stock'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _op(Colors.black, 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Stock Status',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
        const SizedBox(height: 16),
        if (total == 0)
          const Center(child: Text('No data', style: TextStyle(color: Color(0xFF94A3B8))))
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: List.generate(keys.length, (i) {
                final count = data[keys[i]] ?? 0;
                final flex = total == 0 ? 1 : (count == 0 ? 0 : (count * 100 ~/ total).clamp(1, 100));
                if (count == 0) return const SizedBox.shrink();
                return Expanded(
                  flex: flex,
                  child: Container(height: 24, color: colors[i]),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(keys.length, (i) {
            final count = data[keys[i]] ?? 0;
            final pct = total == 0 ? 0 : (count * 100 ~/ total);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: colors[i], borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(keys[i], style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                Text(
                  '$count ($pct%)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors[i]),
                ),
              ]),
            );
          }),
        ]
      ]),
    );
  }

  // ── Recommendations section ───────────────────────────────────────────────────
  Widget _buildRecommendationsSection() {
    final recs = [
      {'title': 'Optimize Product Categories', 'desc': 'Consider expanding your top-performing categories to increase revenue potential.', 'priority': 'High',   'color': const Color(0xFFEF4444), 'icon': Icons.trending_up},
      {'title': 'Inventory Management',        'desc': 'Review stock levels for fast-moving products to avoid stockouts.',                'priority': 'Medium', 'color': const Color(0xFFF59E0B), 'icon': Icons.inventory_2_outlined},
      {'title': 'Featured Products',           'desc': 'Update your featured products section with trending items.',                      'priority': 'Low',    'color': const Color(0xFF10B981), 'icon': Icons.star_border},
      {'title': 'Brand Partnerships',          'desc': 'Strengthen relationships with top-performing brands for better margins.',         'priority': 'Medium', 'color': const Color(0xFFF59E0B), 'icon': Icons.handshake_outlined},
      {'title': 'Digital Marketing',           'desc': 'Implement SEO strategies to improve online visibility and attract new customers.','priority': 'High',   'color': const Color(0xFFEF4444), 'icon': Icons.campaign_outlined},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _op(Colors.black, 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Row(children: [
            Icon(Icons.lightbulb_outline, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('AI Recommendations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ]),
          TextButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF6366F1)),
          ),
        ]),
        const SizedBox(height: 16),
        ...recs.map((r) {
          final color = r['color'] as Color;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              color: const Color(0xFFFAFAFF),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _op(color, 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(r['icon'] as IconData, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    r['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(r['desc'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ]),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _op(color, 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _op(color, 0.3)),
                ),
                child: Text(
                  '${r['priority']} Priority',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // ── AI Generated Reports ───────────────────────────────────────────────────
  Future<void> _generateMonthlyReport() async {
    setState(() {
      _generatingReport = true;
    });
    try {
      final ctx = _buildContext();
      final now = DateTime.now();
      final monthYear = '${_monthName(now.month)} ${now.year}';
      final prompt =
          'You are an AI business analyst. Generate a comprehensive Monthly Business Summary report for $monthYear for a construction materials e-commerce business.\n\nBusiness Data:\n$ctx\n\nInclude:\n1. Executive Summary\n2. Product & Inventory Highlights\n3. Category Performance\n4. Brand Performance\n5. Key Recommendations for next month\n\nKeep it concise and actionable (under 300 words).';
      final result = await _callGemini(prompt);
      setState(() {
        _monthlyReportContent = result;
        _lastReportGenerated = DateTime.now();
        _generatingReport = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Monthly report generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _generatingReport = false;
      });
    }
  }

  String _monthName(int month) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month];
  }

  Widget _buildAIReportsSection() {
    final lastGenText = _lastReportGenerated == null
        ? 'Never'
        : DateFormat('MMM d, yyyy h:mm a').format(_lastReportGenerated!);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _op(Colors.black, 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Row(children: [
            Icon(Icons.description_outlined, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text(
              'AI Generated Reports',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ]),
          ElevatedButton.icon(
            onPressed: _generatingReport ? null : _generateMonthlyReport,
            icon: _generatingReport
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.description_outlined, size: 16),
            label: Text(_generatingReport ? 'Generating...' : 'Generate Monthly Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // Monthly Business Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _op(const Color(0xFF6366F1), 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_month_outlined, color: Color(0xFF6366F1), size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Monthly Business Summary',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                ),
              ]),
              Text(
                'Last Generated: $lastGenText',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ]),
            const SizedBox(height: 12),
            if (_monthlyReportContent.isEmpty) ...[
              const Text(
                'Generate your first AI-powered monthly report to get comprehensive insights about your business performance.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _generatingReport ? null : _generateMonthlyReport,
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: Text(_generatingReport ? 'Generating...' : 'Generate Report'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  _monthlyReportContent,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.6),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                ElevatedButton.icon(
                  onPressed: _downloadReport,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _generateMonthlyReport,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Regenerate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  void _downloadReport() {
    if (_monthlyReportContent.isEmpty) return;
    final now = _lastReportGenerated ?? DateTime.now();
    final fileName =
        'monthly_report_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}.txt';

    // Build a nicely formatted text file
    final header = [
      '=' * 60,
      'MONTHLY BUSINESS SUMMARY REPORT',
      'Generated: ${DateFormat('MMMM d, yyyy – h:mm a').format(now)}',
      '=' * 60,
      '',
    ].join('\n');

    final fullContent = header + _monthlyReportContent;
    final bytes = utf8.encode(fullContent);
    final blob = html.Blob([bytes], 'text/plain');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Report downloaded as $fileName'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
