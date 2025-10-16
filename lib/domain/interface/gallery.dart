import 'package:upmoo25/infrastructure/models/models.dart';
import 'package:upmoo25/infrastructure/models/response/multi_gallery_upload_response.dart';
import 'package:upmoo25/infrastructure/services/enums.dart';
import 'package:upmoo25/domain/handlers/handlers.dart';

abstract class GalleryRepositoryFacade {
  Future<ApiResult<GalleryUploadResponse>> uploadImage(
      String file, UploadType uploadType);

  Future<ApiResult<MultiGalleryUploadResponse>> uploadMultiImage(
      List<String?> filePaths,
      UploadType uploadType,
      );
}
