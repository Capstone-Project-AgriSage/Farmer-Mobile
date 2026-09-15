import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

// Debt model — 5 trạng thái bám sát DebtStatus của Farmer-Web
enum DebtStatus { normal, soonDue, due, overdue, paid }

extension DebtStatusX on DebtStatus {
  String get label {
    switch (this) {
      case DebtStatus.normal: return 'Bình thường';
      case DebtStatus.soonDue: return 'Sắp đến hạn';
      case DebtStatus.due: return 'Đến hạn';
      case DebtStatus.overdue: return 'Quá hạn';
      case DebtStatus.paid: return 'Đã thanh toán';
    }
  }

  Color get color {
    switch (this) {
      case DebtStatus.normal: return AppColors.debtNormal;
      case DebtStatus.soonDue: return AppColors.debtSoonDue;
      case DebtStatus.due: return AppColors.debtDue;
      case DebtStatus.overdue: return AppColors.debtOverdue;
      case DebtStatus.paid: return AppColors.debtPaid;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case DebtStatus.normal: return AppColors.primaryLight;
      case DebtStatus.soonDue: return const Color(0xFFFFF8E1);
      case DebtStatus.due: return const Color(0xFFFFF3E0);
      case DebtStatus.overdue: return AppColors.statusErrorSurface;
      case DebtStatus.paid: return const Color(0xFFF5F5F5);
    }
  }
}

class Debt {
  final String id;
  final String agentName;
  final double amount;
  final DateTime createdAt;
  final DateTime dueDate;
  final DebtStatus status;
  final bool farmerConfirmed;   // Nông dân đã xác nhận 2 chiều chưa
  final bool agentConfirmed;    // Đại lý đã xác nhận chưa
  final String? note;

  const Debt({
    required this.id,
    required this.agentName,
    required this.amount,
    required this.createdAt,
    required this.dueDate,
    required this.status,
    required this.farmerConfirmed,
    required this.agentConfirmed,
    this.note,
  });

  bool get fullyConfirmed => farmerConfirmed && agentConfirmed;
}

// Hạn mức sổ nợ mùa vụ
const double kDebtCreditLimit = 50000000.0; // 50 triệu VNĐ
