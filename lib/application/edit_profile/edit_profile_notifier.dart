import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:upmoo25/domain/interface/gallery.dart';
import 'package:upmoo25/domain/interface/user.dart';
import 'package:upmoo25/infrastructure/models/models.dart';
import 'package:upmoo25/infrastructure/models/request/edit_profile.dart';
import 'package:upmoo25/infrastructure/services/app_connectivity.dart';
import 'package:upmoo25/infrastructure/services/app_helpers.dart';
import 'package:upmoo25/infrastructure/services/enums.dart';
import 'package:upmoo25/infrastructure/services/tr_keys.dart';
import 'package:upmoo25/presentation/theme/theme.dart';
import 'package:upmoo25/infrastructure/services/local_storage.dart';
import 'package:upmoo25/infrastructure/services/marker_image_cropper.dart';
import 'package:upmoo25/application/profile/profile_provider.dart';
import 'edit_profile_state.dart';

class EditProfileNotifier extends StateNotifier<EditProfileState> {
  final UserRepositoryFacade _userRepository;
  final GalleryRepositoryFacade _galleryRepository;
  final Ref _ref;

  EditProfileNotifier(this._userRepository, this._galleryRepository, this._ref)
      : super(const EditProfileState());

  void setUser(ProfileData user) {
    state = state.copyWith(
      email: user.email ?? "",
      firstName: user.firstname ?? "",
      lastName: user.lastname ?? "",
      phone: user.phone ?? "",
      secondPhone: user.secondPhone ?? "",
      gender: user.gender ?? "",
      birth: user.birthday ?? "",
    );
  }

  void setEmail(String email) {
    state = state.copyWith(email: email);
  }

  void setFirstName(String firstName) {
    state = state.copyWith(firstName: firstName);
  }

  void setLastName(String lastName) {
    state = state.copyWith(lastName: lastName);
  }

  void setPhone(String phone) {
    state = state.copyWith(phone: phone);
  }

  void setSecondPhone(String phone) {
    state = state.copyWith(secondPhone: phone);
  }

  void setBirth(String birth) {
    state = state.copyWith(birth: birth);
  }

  void setGender(String gender) {
    state = state.copyWith(gender: gender);
  }

  getPhotoWithUrl(String url) async {
    ImageCropperForMarker imageMarker = ImageCropperForMarker();
    final file = await imageMarker.urlToFile(url);
    state = state.copyWith(imagePath: file.path);
  }

  Future<void> getPhoto() async {
    final ImagePicker picker = ImagePicker();
    XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Image Cropper',
            toolbarColor: AppStyle.white,
            toolbarWidgetColor: AppStyle.black,
            initAspectRatio: CropAspectRatioPreset.original,
          ),
          IOSUiSettings(title: 'Image Cropper', minimumAspectRatio: 1),
        ],
      );
      state = state.copyWith(imagePath: croppedFile?.path ?? "");
    }
  }

  Future<void> editProfile(BuildContext context, ProfileData user) async {
    final connected = await AppConnectivity.connectivity();
    if (connected) {
      state = state.copyWith(isLoading: true, isSuccess: false);
      if (state.imagePath.isNotEmpty) {
        if (context.mounted) {
          await updateProfileImage(context, state.imagePath);
        }
      }
      final response = await _userRepository.editProfile(
          user: EditProfile(
        firstname: state.firstName.isEmpty ? user.firstname : state.firstName,
        lastname: state.lastName.isEmpty ? user.lastname : state.lastName,
        birthday: state.birth.isEmpty ? user.birthday : state.birth,
        phone: state.phone.isEmpty ? user.phone : state.phone,
        email: state.email.isEmpty ? user.email : state.email,
        secondPhone: state.secondPhone,
        images: state.url.isEmpty ? user.img ?? "" : state.url,
        gender: state.gender.isEmpty ? user.gender : state.gender,
      ));
      response.when(
        success: (data) {
          // Get current user data from profile provider
          final currentUser = _ref.read(profileProvider).userData;
          
          // Create updated user data by preserving existing data and updating with new data
          final updatedUser = currentUser?.copyWith(
            firstname: data.data?.firstname ?? currentUser?.firstname,
            lastname: data.data?.lastname ?? currentUser?.lastname,
            email: data.data?.email ?? currentUser?.email,
            phone: data.data?.phone ?? currentUser?.phone,
            birthday: data.data?.birthday ?? currentUser?.birthday,
            gender: data.data?.gender ?? currentUser?.gender,
            img: data.data?.img ?? currentUser?.img,
          ) ?? data.data;
          
          LocalStorage.setUser(updatedUser);
          Navigator.pop(context);
          // Update profile provider immediately
          if (updatedUser != null) {
            _ref.read(profileProvider.notifier).setUser(updatedUser);
          }
          // Update edit profile state with new data
          state = state.copyWith(
            userData: updatedUser,
            isLoading: false,
            isSuccess: true,
            // Update all form fields with the new user data
            email: updatedUser?.email ?? '',
            firstName: updatedUser?.firstname ?? '',
            lastName: updatedUser?.lastname ?? '',
            phone: updatedUser?.phone ?? '',
            birth: updatedUser?.birthday ?? '',
            gender: updatedUser?.gender ?? '',
            url: updatedUser?.img ?? '',
          );
        },
        failure: (failure, status) {
          state = state.copyWith(isLoading: false);
          AppHelpers.showCheckTopSnackBar(
            context,
            AppHelpers.getTranslation(status.toString()),
          );
        },
      );
    } else {
      if (context.mounted) {
        AppHelpers.showCheckTopSnackBar(
          context,
          AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
        );
      }
    }
  }

  Future<void> updateProfileImage(BuildContext context, String path) async {
    final connected = await AppConnectivity.connectivity();
    if (connected) {
      String? url;
      final imageResponse =
          await _galleryRepository.uploadImage(path, UploadType.users);
      imageResponse.when(
        success: (data) {
          url = data.imageData?.title;
          state = state.copyWith(url: url ?? "");
        },
        failure: (failure, status) {
          state = state.copyWith(isLoading: false);
          debugPrint('==> upload profile image failure: $failure');
          AppHelpers.showCheckTopSnackBar(
            context,
            AppHelpers.getTranslation(status.toString()),
          );
        },
      );
    } else {
      if (context.mounted) {
        state = state.copyWith(isLoading: false);
        AppHelpers.showCheckTopSnackBar(
          context,
          AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
        );
      }
    }
  }

  Future<void> updatePhone(BuildContext context, String phone) async {
    final connected = await AppConnectivity.connectivity();
    if (!connected) {
      if (context.mounted) {
        AppHelpers.showCheckTopSnackBar(
          context,
          AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
        );
      }
      return;
    }
    state = state.copyWith(isLoading: true, isSuccess: false);
    final response = await _userRepository.updatePhone(phone);
    response.when(
      success: (data) {
        // Get current user data from profile provider
        final currentUser = _ref.read(profileProvider).userData;
        
        // Create updated user data by preserving existing data and updating phone
        final updatedUser = currentUser?.copyWith(
          phone: data.data?.phone ?? currentUser?.phone,
        ) ?? data.data;
        
        LocalStorage.setUser(updatedUser);
        if (context.mounted) {
          Navigator.pop(context);
          AppHelpers.showCheckTopSnackBarDone(
            context,
            'Phone number updated successfully.',
          );
        }
        // Update profile provider immediately with complete user data
        if (updatedUser != null) {
          _ref.read(profileProvider.notifier).setUser(updatedUser);
        }
        // Update edit profile state with new data
        state = state.copyWith(
          userData: updatedUser,
          isLoading: false,
          isSuccess: true,
          phone: updatedUser?.phone ?? '',
          // Preserve existing form data
          email: state.email.isNotEmpty ? state.email : (updatedUser?.email ?? ''),
          firstName: state.firstName.isNotEmpty ? state.firstName : (updatedUser?.firstname ?? ''),
          lastName: state.lastName.isNotEmpty ? state.lastName : (updatedUser?.lastname ?? ''),
          birth: state.birth.isNotEmpty ? state.birth : (updatedUser?.birthday ?? ''),
          gender: state.gender.isNotEmpty ? state.gender : (updatedUser?.gender ?? ''),
          url: state.url.isNotEmpty ? state.url : (updatedUser?.img ?? ''),
        );
      },
      failure: (failure, status) {
        state = state.copyWith(isLoading: false);
        if (context.mounted) {
          AppHelpers.showCheckTopSnackBar(
            context,
            AppHelpers.getTranslation(status.toString()),
          );
        }
      },
    );
  }
}
