import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tax_config_provider.dart';

class TaxSettingsScreen extends ConsumerStatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  ConsumerState<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends ConsumerState<TaxSettingsScreen> {
  late TextEditingController defaultGstController;
  final Map<String, TextEditingController> categoryControllers = {};
  
  bool requirePan = false;
  bool requireGst = false;
  bool validatePanFormat = true;
  bool validateGstFormat = true;

  @override
  void initState() {
    super.initState();
    defaultGstController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final gstRates = await ref.read(gstRatesProvider.future);
    final businessRules = await ref.read(businessTaxRulesProvider.future);

    setState(() {
      defaultGstController.text = gstRates['default'].toString();
      
      if (gstRates['categories'] != null) {
        final categories = gstRates['categories'] as Map<String, dynamic>;
        categories.forEach((key, value) {
          categoryControllers[key] = TextEditingController(text: value.toString());
        });
      }

      requirePan = businessRules['require_pan'] ?? false;
      requireGst = businessRules['require_gst'] ?? false;
      validatePanFormat = businessRules['validate_pan_format'] ?? true;
      validateGstFormat = businessRules['validate_gst_format'] ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Tax Configuration',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // GST Rates Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GST Rates',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: defaultGstController,
                          decoration: const InputDecoration(
                            labelText: 'Default GST Rate (%)',
                            hintText: 'e.g., 18',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Category-Specific Rates',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...categoryControllers.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    entry.key.toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: entry.value,
                                    decoration: InputDecoration(
                                      labelText: 'GST %',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.delete, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            categoryControllers.remove(entry.key);
                                          });
                                        },
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _addCategoryRate,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Category Rate'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Business Tax Rules Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Business Account Rules',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Require PAN for Business Accounts'),
                          subtitle: const Text('Make PAN number mandatory for business users'),
                          value: requirePan,
                          onChanged: (value) => setState(() => requirePan = value),
                        ),
                        SwitchListTile(
                          title: const Text('Require GST for Business Accounts'),
                          subtitle: const Text('Make GST number mandatory for business users'),
                          value: requireGst,
                          onChanged: (value) => setState(() => requireGst = value),
                        ),
                        const Divider(height: 32),
                        const Text(
                          'Validation Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Validate PAN Format'),
                          subtitle: const Text('Check if PAN follows AAAAA9999A format'),
                          value: validatePanFormat,
                          onChanged: (value) => setState(() => validatePanFormat = value),
                        ),
                        SwitchListTile(
                          title: const Text('Validate GST Format'),
                          subtitle: const Text('Check if GST follows 99AAAAA9999A9Z9 format'),
                          value: validateGstFormat,
                          onChanged: (value) => setState(() => validateGstFormat = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Save Configuration',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addCategoryRate() {
    showDialog(
      context: context,
      builder: (context) {
        final categoryController = TextEditingController();
        final rateController = TextEditingController();

        return AlertDialog(
          title: const Text('Add Category GST Rate'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g., cement, steel',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(
                  labelText: 'GST Rate (%)',
                  hintText: 'e.g., 28',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  categoryControllers[categoryController.text.toLowerCase()] =
                      TextEditingController(text: rateController.text);
                });
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveSettings() async {
    // Save GST rates
    final categories = <String, dynamic>{};
    categoryControllers.forEach((key, controller) {
      categories[key] = double.parse(controller.text);
    });

    final gstRates = {
      'default': double.parse(defaultGstController.text),
      'categories': categories,
    };

    await ref.read(taxConfigManagementProvider).updateGstRates(gstRates);

    // Save business tax rules
    final businessRules = {
      'require_pan': requirePan,
      'require_gst': requireGst,
      'validate_pan_format': validatePanFormat,
      'validate_gst_format': validateGstFormat,
    };

    await ref.read(taxConfigManagementProvider).updateBusinessTaxRules(businessRules);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tax configuration saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    defaultGstController.dispose();
    categoryControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }
}
