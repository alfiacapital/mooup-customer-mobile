import 'package:upmoo25/infrastructure/models/models.dart';
import 'package:upmoo25/domain/handlers/handlers.dart';

abstract class BlogsRepositoryFacade {
  Future<ApiResult<BlogsPaginateResponse>> getBlogs(int page, String type);

  Future<ApiResult<BlogDetailsResponse>> getBlogDetails(String uuid);
}
