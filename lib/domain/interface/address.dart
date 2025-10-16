import 'package:upmoo25/infrastructure/models/models.dart';
import 'package:upmoo25/domain/handlers/handlers.dart';

abstract class AddressRepositoryFacade {
  Future<ApiResult<AddressesResponse>> getUserAddresses();

  Future<ApiResult<void>> deleteAddress(int addressId);

  Future<ApiResult<SingleAddressResponse>> createAddress(
    LocalAddressData address,
  );
}
