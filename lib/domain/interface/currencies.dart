import 'package:upmoo25/infrastructure/models/models.dart';
import 'package:upmoo25/domain/handlers/handlers.dart';

abstract class CurrenciesRepositoryFacade {
  Future<ApiResult<CurrenciesResponse>> getCurrencies();
}
