import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Unit Model
class UnitModel {
  final String id;
  final String name;
  final String code;
  final String? symbol;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UnitModel({
    required this.id,
    required this.name,
    required this.code,
    this.symbol,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory UnitModel.fromJson(Map<String, dynamic> json) {
    return UnitModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      symbol: json['symbol'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'symbol': symbol,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }

  UnitModel copyWith({
    String? id,
    String? name,
    String? code,
    String? symbol,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UnitModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      symbol: symbol ?? this.symbol,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayName => '$name ($code)';
}

// Unit State
class UnitState {
  final List<UnitModel> units;
  final bool isLoading;
  final String? error;

  UnitState({
    this.units = const [],
    this.isLoading = false,
    this.error,
  });

  UnitState copyWith({
    List<UnitModel>? units,
    bool? isLoading,
    String? error,
  }) {
    return UnitState(
      units: units ?? this.units,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Unit Notifier
class UnitNotifier extends StateNotifier<UnitState> {
  final SupabaseClient _supabase;

  UnitNotifier(this._supabase) : super(UnitState()) {
    loadUnits();
  }

  Future<void> loadUnits() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _supabase
          .from('units')
          .select('*')
          .order('sort_order', ascending: true);

      final units = (response as List)
          .map((json) => UnitModel.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(units: units, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> addUnit({
    required String name,
    required String code,
    String? symbol,
  }) async {
    try {
      final maxSortOrder = state.units.isEmpty 
          ? 0 
          : state.units.map((u) => u.sortOrder).reduce((a, b) => a > b ? a : b);

      await _supabase.from('units').insert({
        'name': name,
        'code': code,
        'symbol': symbol,
        'is_active': true,
        'sort_order': maxSortOrder + 1,
      });

      await loadUnits();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateUnit(UnitModel unit) async {
    try {
      await _supabase.from('units').update({
        'name': unit.name,
        'code': unit.code,
        'symbol': unit.symbol,
        'is_active': unit.isActive,
        'sort_order': unit.sortOrder,
      }).eq('id', unit.id);

      await loadUnits();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> toggleUnitActive(String unitId, bool isActive) async {
    try {
      await _supabase.from('units').update({
        'is_active': isActive,
      }).eq('id', unitId);

      await loadUnits();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteUnit(String unitId) async {
    try {
      await _supabase.from('units').delete().eq('id', unitId);
      await loadUnits();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> reorderUnits(List<String> unitIds) async {
    try {
      for (int i = 0; i < unitIds.length; i++) {
        await _supabase.from('units').update({
          'sort_order': i + 1,
        }).eq('id', unitIds[i]);
      }
      await loadUnits();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider
final unitProvider = StateNotifierProvider<UnitNotifier, UnitState>((ref) {
  return UnitNotifier(Supabase.instance.client);
});

// Convenience providers
final activeUnitsProvider = Provider<List<UnitModel>>((ref) {
  final units = ref.watch(unitProvider).units;
  return units.where((u) => u.isActive).toList();
});

final allUnitsProvider = Provider<List<UnitModel>>((ref) {
  return ref.watch(unitProvider).units;
});
