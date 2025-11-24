import 'package:cloud_functions/cloud_functions.dart';

class PayNowService {
  final functions = FirebaseFunctions.instance;

  /// Calls the `createPayNowPayment` callable Cloud Function.
  /// Returns map containing { txId, paymentUrl?, qrImage? } on success.
  Future<Map<String, dynamic>> createPayNowPayment(double amount, {String? returnUrl}) async {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount', 'Must be > 0');
    final callable = functions.httpsCallable('createPayNowPayment');
    final resp = await callable.call(<String, dynamic>{'amount': amount, 'returnUrl': returnUrl});
    if (resp.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(resp.data as Map);
    }
    // defensive - try to convert
    return Map<String, dynamic>.from(resp.data as Map<dynamic, dynamic>);
  }
}

final payNowService = PayNowService();
