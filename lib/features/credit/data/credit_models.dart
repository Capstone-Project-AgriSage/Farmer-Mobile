import '../../../core/utils/json_utils.dart';

/// `GET /api/me/credit`: the farmer's credit line with the store. A farmer with no credit profile gets a 404, which the
/// repository turns into `null`.
class MyCredit {
  const MyCredit({
    required this.status,
    required this.creditLimit,
    required this.availableCredit,
    required this.outstandingReceivable,
    required this.reservedCredit,
    this.paymentTermDays,
  });

  final String status;
  final double creditLimit;
  final double availableCredit;
  final double outstandingReceivable;

  /// Credit held for orders placed on credit that are not delivered yet.
  final double reservedCredit;
  final int? paymentTermDays;

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory MyCredit.fromJson(Map<String, dynamic> json) => MyCredit(
        status: asString(json['status']),
        creditLimit: asDouble(json['creditLimit']),
        availableCredit: asDouble(json['availableCredit']),
        outstandingReceivable: asDouble(json['outstandingReceivable']),
        reservedCredit: asDouble(json['reservedCredit']),
        paymentTermDays: json['paymentTermDays'] == null ? null : asInt(json['paymentTermDays']),
      );
}

/// Whether "Mua ghi nợ" may be chosen for an order, and if not, why.
enum CreditChoice { available, noProfile, notActive, notEnough }

/// The page only decides what to offer; the server checks the limit again when the order is created.
CreditChoice creditChoiceFor(MyCredit? credit, double orderTotal) {
  if (credit == null) return CreditChoice.noProfile;
  if (!credit.isActive) return CreditChoice.notActive;
  if (orderTotal > credit.availableCredit) return CreditChoice.notEnough;
  return CreditChoice.available;
}
