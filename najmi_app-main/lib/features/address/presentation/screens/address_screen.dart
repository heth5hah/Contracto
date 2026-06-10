import 'package:flutter/material.dart';
import 'package:contracto_app/features/address/data/models/address_model.dart';
import 'package:contracto_app/features/address/data/services/address_service.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/core/services/location_service.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _addressService = AddressService();
  final _locationService = LocationService();
  List<AddressModel> _addresses = [];
  bool _isLoading = true;
  bool _isDetectingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      setState(() => _isLoading = true);
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser != null) {
        final addresses = await _addressService.getAddresses();
        setState(() {
          _addresses = addresses;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _detectAndAddAddress() async {
    setState(() => _isDetectingLocation = true);
    try {
      final location = await _locationService.detectCurrentLocation();
      setState(() => _isDetectingLocation = false);

      if (!mounted) return;

      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AddressFormSheet(
          prefillStreet: [
            if (location.subLocality != null && location.subLocality!.isNotEmpty)
              location.subLocality!,
            if (location.street != null && location.street!.isNotEmpty)
              location.street!,
          ].join(', '),
          prefillCity: location.city ?? '',
          prefillState: location.state ?? '',
          prefillPincode: location.pincode ?? '',
        ),
      );

      if (result == true) _loadAddresses();
    } on LocationException catch (e) {
      setState(() => _isDetectingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isDetectingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not detect location: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _addNewAddress() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddressFormSheet(),
    );
    if (result == true) _loadAddresses();
  }

  Future<void> _editAddress(AddressModel address) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressFormSheet(address: address),
    );
    if (result == true) _loadAddresses();
  }

  Future<void> _deleteAddress(AddressModel address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Address',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupabaseService.client
            .from('addresses')
            .delete()
            .eq('id', address.id);
        _loadAddresses();
      } catch (_) {}
    }
  }

  Future<void> _setAsDefault(AddressModel address) async {
    try {
      await _addressService.setDefaultAddress(address.id);
      _loadAddresses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default address updated'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update default address'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  IconData _getLabelIcon(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'office':
        return Icons.business_rounded;
      case 'site':
        return Icons.construction_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Color(0xFF1E293B)),
          ),
        ),
        title: const Text(
          'My Addresses',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF4F46E5)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Use Current Location ──
                GestureDetector(
                  onTap: _isDetectingLocation ? null : _detectAndAddAddress,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _isDetectingLocation
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded,
                                  color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isDetectingLocation
                                    ? 'Detecting location...'
                                    : 'Use Current Location',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Auto-fill address from GPS',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Saved Addresses Header ──
                Row(
                  children: [
                    Text(
                      'Saved Addresses',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_addresses.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Address Cards ──
                if (_addresses.isEmpty)
                  _buildEmptyState()
                else
                  ..._addresses.map((address) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildAddressCard(address),
                      )),

                const SizedBox(height: 8),

                // ── Add New Address ──
                GestureDetector(
                  onTap: _addNewAddress,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_location_alt_rounded,
                            size: 18, color: Color(0xFF4F46E5)),
                        SizedBox(width: 8),
                        Text(
                          'Add New Address',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F46E5),
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.location_off_rounded,
                size: 32, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Saved Addresses',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your delivery addresses to get started',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(AddressModel address) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + label + badges + actions
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getLabelIcon(address.label),
                    size: 18,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  address.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (address.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Actions
                if (!address.isDefault)
                  GestureDetector(
                    onTap: () => _setAsDefault(address),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.star_border_rounded,
                          size: 20, color: Colors.grey[400]),
                    ),
                  ),
                GestureDetector(
                  onTap: () => _editAddress(address),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.edit_outlined,
                        size: 18, color: Colors.grey[400]),
                  ),
                ),
                GestureDetector(
                  onTap: () => _deleteAddress(address),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Address text
            if (address.buildingName != null &&
                address.buildingName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  address.buildingName!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            Text(
              address.streetAddress,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            if (address.landmark.isNotEmpty)
              Text(
                'Near ${address.landmark}',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                    height: 1.4),
              ),
            const SizedBox(height: 2),
            Text(
              '${address.city}, ${address.state} - ${address.pincode}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Address Form Bottom Sheet
// ═══════════════════════════════════════════════════════════

class AddressFormSheet extends StatefulWidget {
  final AddressModel? address;
  final String? prefillStreet;
  final String? prefillCity;
  final String? prefillState;
  final String? prefillPincode;

  const AddressFormSheet({
    super.key,
    this.address,
    this.prefillStreet,
    this.prefillCity,
    this.prefillState,
    this.prefillPincode,
  });

  @override
  State<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _buildingNameController = TextEditingController();
  final _flatNumberController = TextEditingController();
  final _floorNumberController = TextEditingController();
  final _streetAddressController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  String _selectedLabel = 'Home';
  bool _isDefault = false;
  bool _isCompany = false;
  bool _isLoadingUserType = true;
  bool _isDetectingLocation = false;
  final _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    if (widget.address != null) {
      _buildingNameController.text = widget.address!.buildingName ?? '';
      _flatNumberController.text = widget.address!.flatNumber ?? '';
      _floorNumberController.text = widget.address!.floorNumber ?? '';
      _streetAddressController.text = widget.address!.streetAddress;
      _landmarkController.text = widget.address!.landmark;
      _cityController.text = widget.address!.city;
      _stateController.text = widget.address!.state;
      _pincodeController.text = widget.address!.pincode;
      _selectedLabel = widget.address!.label;
      _isDefault = widget.address!.isDefault;
    } else {
      // Pre-fill from GPS if provided
      if (widget.prefillStreet != null) {
        _streetAddressController.text = widget.prefillStreet!;
      }
      if (widget.prefillCity != null) {
        _cityController.text = widget.prefillCity!;
      }
      if (widget.prefillState != null) {
        _stateController.text = widget.prefillState!;
      }
      if (widget.prefillPincode != null) {
        _pincodeController.text = widget.prefillPincode!;
      }
    }
    _checkUserType();
  }

  @override
  void dispose() {
    _buildingNameController.dispose();
    _flatNumberController.dispose();
    _floorNumberController.dispose();
    _streetAddressController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _checkUserType() async {
    try {
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser != null) {
        final userData =
            await SupabaseService.instance.getUserById(currentUser.id);
        if (mounted) {
          setState(() {
            if (userData != null) {
              _isCompany = userData['user_type'] == 'company';
              if (_isCompany && widget.address == null) {
                _selectedLabel = 'Site';
              }
            }
            _isLoadingUserType = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingUserType = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUserType = false);
    }
  }

  Future<void> _autoDetectLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final location = await _locationService.detectCurrentLocation();
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
          _streetAddressController.text = [
            if (location.subLocality != null &&
                location.subLocality!.isNotEmpty)
              location.subLocality!,
            if (location.street != null && location.street!.isNotEmpty)
              location.street!,
          ].join(', ');
          _cityController.text = location.city ?? '';
          _stateController.text = location.state ?? '';
          _pincodeController.text = location.pincode ?? '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location detected! Review and save.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on LocationException catch (e) {
      setState(() => _isDetectingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser == null) return;

      final fullAddress = [
        if (_buildingNameController.text.isNotEmpty)
          _buildingNameController.text,
        if (_flatNumberController.text.isNotEmpty)
          'Flat ${_flatNumberController.text}',
        if (_floorNumberController.text.isNotEmpty)
          'Floor ${_floorNumberController.text}',
        _streetAddressController.text,
        if (_landmarkController.text.isNotEmpty)
          'Near ${_landmarkController.text}',
        _cityController.text,
        _stateController.text,
        _pincodeController.text,
      ].join(', ');

      final newAddress = AddressModel(
        id: widget.address?.id ?? '',
        userId: currentUser.id,
        fullAddress: fullAddress,
        label: _selectedLabel,
        streetAddress: _streetAddressController.text,
        landmark: _landmarkController.text,
        city: _cityController.text,
        state: _stateController.text,
        pincode: _pincodeController.text,
        buildingName: _buildingNameController.text.isNotEmpty
            ? _buildingNameController.text
            : null,
        flatNumber: _flatNumberController.text.isNotEmpty
            ? _flatNumberController.text
            : null,
        floorNumber: _floorNumberController.text.isNotEmpty
            ? _floorNumberController.text
            : null,
        isDefault: _isDefault,
        createdAt: DateTime.now(),
      );

      final addressService = AddressService();
      if (widget.address != null) {
        await addressService.updateAddress(newAddress);
      } else {
        await addressService.addAddress(newAddress);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        
        if (errorMsg.contains('Account conflict')) {
           // Show a giant alert explaining the DB orphaned account issue
           showDialog(
             context: context,
             builder: (ctx) => AlertDialog(
               backgroundColor: Colors.white,
               surfaceTintColor: Colors.transparent,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
               title: const Row(
                 children: [
                   Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                   SizedBox(width: 10),
                   Expanded(child: Text('Database Conflict', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
                 ],
               ),
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Text(
                     'Your email exists in the database with an old deleted account ID. '
                     'Because you have past notifications linked to the old ID, we cannot auto-merge them.',
                     style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                   ),
                   const SizedBox(height: 16),
                   const Text('How to fix this:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                   const SizedBox(height: 8),
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                     child: const Text('1. Log out\n2. Sign up with a DIFFERENT email to test (e.g. vedant+1@getcarigar.com)', style: TextStyle(fontSize: 13, height: 1.5)),
                   ),
                   const SizedBox(height: 12),
                   const Center(child: Text('— OR —', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 12))),
                   const SizedBox(height: 12),
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                     child: const Text('Run the SQL script from "troubleshooting.md" in your Supabase SQL Editor to wipe the old data.', style: TextStyle(fontSize: 13, height: 1.5)),
                   ),
                 ],
               ),
               actions: [
                 TextButton(
                   onPressed: () => Navigator.pop(ctx),
                   child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                 ),
               ],
             )
           );
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text('Failed to save address: $errorMsg'),
               backgroundColor: Colors.red,
             ),
           );
        }
      }
    }
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.grey[500],
      ),
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: Colors.grey[400])
          : null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 4,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: _formKey,
                child: _isLoadingUserType
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(
                                Color(0xFF4F46E5)),
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            widget.address != null
                                ? 'Edit Address'
                                : 'Add New Address',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Auto-detect button
                          GestureDetector(
                            onTap: _isDetectingLocation
                                ? null
                                : _autoDetectLocation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5)
                                    .withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF4F46E5)
                                      .withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _isDetectingLocation
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation(
                                                    Color(0xFF4F46E5)),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.my_location_rounded,
                                          size: 18,
                                          color: Color(0xFF4F46E5)),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isDetectingLocation
                                        ? 'Detecting...'
                                        : 'Auto-detect from GPS',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Building Name
                          TextFormField(
                            controller: _buildingNameController,
                            decoration: _inputDecoration(
                              _isCompany
                                  ? 'Project / Site Name*'
                                  : 'Building / Society (Optional)',
                              icon: Icons.apartment_rounded,
                            ),
                            validator: _isCompany
                                ? (v) => v == null || v.isEmpty
                                    ? 'Required'
                                    : null
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Flat & Floor
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _flatNumberController,
                                  decoration: _inputDecoration(
                                    _isCompany
                                        ? 'Shop / Unit No*'
                                        : 'Flat No.',
                                  ),
                                  validator: _isCompany
                                      ? (v) => v == null || v.isEmpty
                                          ? 'Required'
                                          : null
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _floorNumberController,
                                  decoration: _inputDecoration(
                                    _isCompany
                                        ? 'Plot / Floor'
                                        : 'Floor',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Street
                          TextFormField(
                            controller: _streetAddressController,
                            decoration: _inputDecoration('Street Address*',
                                icon: Icons.route_rounded),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Please enter street address'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Landmark
                          TextFormField(
                            controller: _landmarkController,
                            decoration: _inputDecoration(
                                'Landmark (Optional)',
                                icon: Icons.near_me_rounded),
                          ),
                          const SizedBox(height: 12),

                          // City & State
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _cityController,
                                  decoration:
                                      _inputDecoration('City*'),
                                  validator: (v) =>
                                      v == null || v.isEmpty
                                          ? 'Required'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _stateController,
                                  decoration:
                                      _inputDecoration('State*'),
                                  validator: (v) =>
                                      v == null || v.isEmpty
                                          ? 'Required'
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Pincode
                          TextFormField(
                            controller: _pincodeController,
                            decoration: _inputDecoration('Pincode*',
                                icon: Icons.pin_drop_rounded),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Required';
                              }
                              if (v.length != 6) {
                                return 'Enter valid 6-digit pincode';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Label chips
                          const Text(
                            'Address Label',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _isCompany ? 'Site' : 'Home',
                              'Office',
                              'Other',
                            ].map((label) {
                              final isSelected =
                                  _selectedLabel == label;
                              return Padding(
                                padding:
                                    const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _selectedLabel = label),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF4F46E5)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(
                                                0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),

                          // Default toggle
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4),
                            child: Row(
                              children: [
                                const Text(
                                  'Set as default address',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const Spacer(),
                                Switch.adaptive(
                                  value: _isDefault,
                                  onChanged: (v) =>
                                      setState(() => _isDefault = v),
                                  activeColor:
                                      const Color(0xFF4F46E5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Save button
                          GestureDetector(
                            onTap: _saveAddress,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4F46E5),
                                    Color(0xFF6366F1)
                                  ],
                                ),
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  widget.address != null
                                      ? 'Update Address'
                                      : 'Save Address',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
