import 'package:upmoo25/infrastructure/models/response/categories_paginate_response.dart';
import 'package:upmoo25/domain/handlers/handlers.dart';

abstract class CategoriesRepositoryFacade {
  Future<ApiResult<CategoriesPaginateResponse>> getAllCategories(
      {required int page});

  Future<ApiResult<CategoriesPaginateResponse>> searchCategories({
    required String text,
  });

  Future<ApiResult<CategoriesPaginateResponse>> getCategoriesByShop(
      {required String shopId});
}
