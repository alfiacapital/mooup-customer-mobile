import 'package:upmoo25/infrastructure/models/models.dart';
import 'package:upmoo25/domain/handlers/handlers.dart';

abstract class PaymentsRepositoryFacade {
  Future<ApiResult<PaymentsResponse?>> getPayments();

  Future<ApiResult<TransactionsResponse>> createTransaction({
    required int orderId,
    required int paymentId,
  });
}
