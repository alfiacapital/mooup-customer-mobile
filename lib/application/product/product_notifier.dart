import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:upmoo25/infrastructure/services/time_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:upmoo25/domain/interface/brands.dart';
import 'package:upmoo25/domain/interface/categories.dart';
import 'package:upmoo25/domain/interface/products.dart';
import 'package:upmoo25/domain/interface/shops.dart';
import 'package:upmoo25/domain/interface/cart.dart';
import 'package:upmoo25/infrastructure/models/models.dart';
import 'package:upmoo25/infrastructure/models/data/addons_data.dart';
import 'package:upmoo25/infrastructure/models/request/cart_request.dart';
import 'package:upmoo25/infrastructure/services/app_connectivity.dart';
import 'package:upmoo25/infrastructure/services/app_helpers.dart';
import 'package:upmoo25/infrastructure/services/enums.dart';
import 'package:upmoo25/infrastructure/services/local_storage.dart';
import 'package:http/http.dart' as http;
import 'package:upmoo25/infrastructure/services/marker_image_cropper.dart';
import 'package:upmoo25/domain/interface/draw.dart';
import 'package:upmoo25/infrastructure/models/response/all_products_response.dart';
import 'package:share_plus/share_plus.dart';
import '../../app_constants.dart';
import 'package:upmoo25/infrastructure/services/tr_keys.dart';
import 'product_state.dart';

class ProductNotifier extends StateNotifier<ProductState> {
  final ProductsRepositoryFacade _productsRepository;
  final CartRepositoryFacade _cartRepository;

  ProductNotifier(this._cartRepository, this._productsRepository)
      : super(const ProductState());
  String? shareLink;

  void change(int index) {
    state = state.copyWith(currentIndex: index);
  }

  void changeImage(Galleries image) {
    state = state.copyWith(selectImage: image);
  }

  Future<void> getProductDetails(
    BuildContext context,
    ProductData productData,
    String? shopType,
    int? shopId,
  ) async {
    final List<Stocks> stocks = productData.stocks ?? <Stocks>[];
    state = state.copyWith(
      count: productData.minQty ?? 1,
      isCheckShopOrder: false,
      productData: productData,
      activeImageUrl: '${productData.img}',
      selectImage: Galleries(path: productData.img),
      initialStocks: stocks,
    );
    generateShareLink(shopType, shopId);
    if (stocks.isNotEmpty) {
      final int groupsCount = stocks[0].extras?.length ?? 0;
      final List<int> selectedIndexes = List.filled(groupsCount, 0);
      initialSetSelectedIndexes(context, selectedIndexes);
    }
    getProductDetailsById(context, productData.uuid ?? "", shopType, shopId,
        isLoading: true);
  }

  Future<void> getProductDetailsById(
      BuildContext context, String productId, String? shopType, int? shopId,
      {bool isLoading = true}) async {
    final connected = await AppConnectivity.connectivity();
    if (connected) {
      if (isLoading) {
        state = state.copyWith(
          isLoading: true,
          productData: null,
          activeImageUrl: '',
        );
      }
      final response = await _productsRepository.getProductDetails(productId);
      response.when(
        success: (data) async {
          final List<Stocks> stocks = data.data?.stocks ?? <Stocks>[];
          state = state.copyWith(
            count: state.count == 1 ? data.data?.minQty ?? 1 : state.count,
            productData: data.data,
            activeImageUrl: '${data.data?.img}',
            initialStocks: stocks,
            isLoading: false,
          );
          generateShareLink(shopType, shopId);
          if (stocks.isNotEmpty) {
            final int groupsCount = stocks[0].extras?.length ?? 0;
            final List<int> selectedIndexes = List.filled(groupsCount, 0);
            initialSetSelectedIndexes(context, selectedIndexes);
          }
        },
        failure: (failure, s) {
          state = state.copyWith(isLoading: false);
          AppHelpers.showCheckTopSnackBar(
            context,
            failure,
          );
          debugPrint('==> get product details failure: $failure');
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

  void addCount(BuildContext context) {
    int count = state.count;
    if (count < (state.productData?.maxQty ?? 1)) {
      state = state.copyWith(count: ++count);
    } else {
      AppHelpers.showCheckTopSnackBarInfo(context,
          "${AppHelpers.getTranslation(TrKeys.maxQty)} ${state.count}");
    }
  }

  void disCount(BuildContext context) {
    int count = state.count;
    if (count > (state.productData?.minQty ?? 1)) {
      state = state.copyWith(count: --count);
    } else {
      AppHelpers.showCheckTopSnackBarInfo(
          context, AppHelpers.getTranslation(TrKeys.minQty));
    }
  }

  void createCart(BuildContext context, int shopId, VoidCallback onSuccess,
      {int? stockId,
      int? count,
      VoidCallback? onError,
      bool isGroupOrder = false,
      String? cartId,
      String? userUuid}) async {
    state = state.copyWith(isCheckShopOrder: false);
    if (shopId == state.productData?.shopId) {
      final connected = await AppConnectivity.connectivity();
      if (connected) {
        state = state.copyWith(isAddLoading: true);
        List<CartRequest> list = [
          CartRequest(
              stockId: stockId ?? state.selectedStock?.id ?? 0,
              quantity: count ?? state.count)
        ];
        for (Addons element in state.selectedStock?.addons ?? []) {
          list.add(
            CartRequest(
                stockId: element.product?.stock?.id,
                quantity: (element.active ?? false) ? element.quantity : 0,
                parentId: stockId ?? state.selectedStock?.id ?? 0),
          );
        }
        final response = isGroupOrder
            ? await _cartRepository.insertCartWithGroup(
                cart: CartRequest(
                    shopId: state.productData?.shopId ?? 0,
                    cartId: cartId,
                    userUuid: userUuid,
                    stockId: stockId ?? state.selectedStock?.id ?? 0,
                    quantity: count ?? state.count,
                    carts: list),
              )
            : await _cartRepository.insertCart(
                cart: CartRequest(
                    shopId: state.productData?.shopId ?? 0,
                    stockId: stockId ?? state.selectedStock?.id ?? 0,
                    quantity: count ?? state.count,
                    carts: list),
              );
        response.when(
          success: (data) {
            state = state.copyWith(isAddLoading: false);
            onSuccess();
          },
          failure: (failure, status) {
            if (status != 400) {
              state = state.copyWith(isAddLoading: false);
              AppHelpers.showCheckTopSnackBar(
                context,
                failure,
              );
            } else {
              onError?.call();
            }
          },
        );
      } else {
        if (context.mounted) {
          AppHelpers.showNoConnectionSnackBar(context);
        }
      }
    } else {
      state = state.copyWith(isCheckShopOrder: true);
    }
  }

  void updateSelectedIndexes(BuildContext context, int index, int value) {
    final newList = state.selectedIndexes.sublist(0, index);
    newList.add(value);
    final postList =
        List.filled(state.selectedIndexes.length - newList.length, 0);
    newList.addAll(postList);
    initialSetSelectedIndexes(context, newList);
  }

  void initialSetSelectedIndexes(BuildContext context, List<int> indexes) {
    state = state.copyWith(selectedIndexes: indexes);
    updateExtras(context);
  }

  void updateExtras(BuildContext context) {
    final int groupsCount = state.initialStocks[0].extras?.length ?? 0;
    final List<TypedExtra> groupExtras = [];
    for (int i = 0; i < groupsCount; i++) {
      if (i == 0) {
        final TypedExtra extras = getFirstExtras(state.selectedIndexes[0]);
        groupExtras.add(extras);
      } else {
        final TypedExtra extras =
            getUniqueExtras(groupExtras, state.selectedIndexes, i);
        groupExtras.add(extras);
      }
    }
    final Stocks? selectedStock = getSelectedStock(groupExtras);
    int stockCount = 0;
    state = state.copyWith(
      typedExtras: groupExtras,
      selectedStock: selectedStock,
      stockCount: stockCount,
    );
  }

  void updateIngredient(BuildContext context, int selectIndex) {
    List<Addons>? data = state.selectedStock?.addons;
    data?[selectIndex].active = !(data[selectIndex].active ?? false);
    List<Stocks>? stocks = state.productData?.stocks;
    Stocks? newStock = stocks?.first.copyWith(addons: data);
    ProductData? product = state.productData;
    ProductData? newProduct = product?.copyWith(stocks: [newStock!]);
    state = state.copyWith(productData: newProduct);
  }

  void addIngredient(
    BuildContext context,
    int selectIndex,
  ) {
    if ((state.selectedStock?.addons?[selectIndex].product?.maxQty ?? 0) >
            (state.selectedStock?.addons?[selectIndex].quantity ?? 0) &&
        (state.selectedStock?.addons?[selectIndex].product?.stock?.quantity ??
                0) >
            (state.selectedStock?.addons?[selectIndex].quantity ?? 0)) {
      List<Addons>? data = state.selectedStock?.addons;
      data?[selectIndex].quantity = (data[selectIndex].quantity ?? 0) + 1;
      List<Stocks>? stocks = state.productData?.stocks;
      Stocks? newStock = stocks?.first.copyWith(addons: data);
      ProductData? product = state.productData;
      ProductData? newProduct = product?.copyWith(stocks: [newStock!]);
      state = state.copyWith(productData: newProduct);
    } else {
      AppHelpers.showCheckTopSnackBarInfo(context,
          "${AppHelpers.getTranslation(TrKeys.maxQty)} ${state.selectedStock?.addons?[selectIndex].quantity ?? 1}");
    }
  }

  void removeIngredient(BuildContext context, int selectIndex) {
    if ((state.selectedStock?.addons?[selectIndex].product?.minQty ?? 0) <
        (state.selectedStock?.addons?[selectIndex].quantity ?? 0)) {
      List<Addons>? data = state.selectedStock?.addons;
      data?[selectIndex].quantity = (data[selectIndex].quantity ?? 0) - 1;
      List<Stocks>? stocks = state.productData?.stocks;
      Stocks? newStock = stocks?.first.copyWith(addons: data);
      ProductData? product = state.productData;
      ProductData? newProduct = product?.copyWith(stocks: [newStock!]);
      state = state.copyWith(productData: newProduct);
    } else {
      AppHelpers.showCheckTopSnackBarInfo(
          context, AppHelpers.getTranslation(TrKeys.minQty));
    }
  }

  Stocks? getSelectedStock(List<TypedExtra> groupExtras) {
    List<Stocks> stocks = List.from(state.initialStocks);
    for (int i = 0; i < groupExtras.length; i++) {
      String selectedExtrasValue =
          groupExtras[i].uiExtras[state.selectedIndexes[i]].value;
      stocks = getSelectedStocks(stocks, selectedExtrasValue, i);
    }
    return stocks[0];
  }

  List<Stocks> getSelectedStocks(List<Stocks> stocks, String value, int index) {
    List<Stocks> included = [];
    for (int i = 0; i < stocks.length; i++) {
      if (stocks[i].extras?[index].value == value) {
        included.add(stocks[i]);
      }
    }
    return included;
  }

  TypedExtra getFirstExtras(int selectedIndex) {
    ExtrasType type = ExtrasType.text;
    String title = '';
    final List<String> uniques = [];
    for (int i = 0; i < state.initialStocks.length; i++) {
      uniques.add(state.initialStocks[i].extras?[0].value ?? '');
      title = state.initialStocks[i].extras?[0].group?.translation?.title ?? '';
      type = AppHelpers.getExtraTypeByValue(
          state.initialStocks[i].extras?[0].group?.type);
    }
    final setOfUniques = uniques.toSet().toList();
    final List<UiExtra> extras = [];
    for (int i = 0; i < setOfUniques.length; i++) {
      if (selectedIndex == i) {
        extras.add(UiExtra(
          setOfUniques[i],
          true,
          i,
        ));
      } else {
        extras.add(UiExtra(setOfUniques[i], false, i));
      }
    }
    return TypedExtra(type, extras, title, 0);
  }

  TypedExtra getUniqueExtras(
    List<TypedExtra> groupExtras,
    List<int> selectedIndexes,
    int index,
  ) {
    List<Stocks> includedStocks = List.from(state.initialStocks);
    for (int i = 0; i < groupExtras.length; i++) {
      final String includedValue =
          groupExtras[i].uiExtras[selectedIndexes[i]].value;
      includedStocks = getIncludedStocks(includedStocks, i, includedValue);
    }
    final List<String> uniques = [];
    String title = '';
    ExtrasType type = ExtrasType.text;
    for (int i = 0; i < includedStocks.length; i++) {
      uniques.add(includedStocks[i].extras?[index].value ?? '');
      title = includedStocks[i].extras?[index].group?.translation?.title ?? '';
      type = AppHelpers.getExtraTypeByValue(
          includedStocks[i].extras?[index].group?.type ?? '');
    }
    final setOfUniques = uniques.toSet().toList();
    final List<UiExtra> extras = [];
    for (int i = 0; i < setOfUniques.length; i++) {
      if (selectedIndexes[groupExtras.length] == i) {
        extras.add(UiExtra(setOfUniques[i], true, i));
      } else {
        extras.add(UiExtra(setOfUniques[i], false, i));
      }
    }
    return TypedExtra(type, extras, title, index);
  }

  List<Stocks> getIncludedStocks(
    List<Stocks> includedStocks,
    int index,
    String includedValue,
  ) {
    List<Stocks> stocks = [];
    for (int i = 0; i < includedStocks.length; i++) {
      if (includedStocks[i].extras?[index].value == includedValue) {
        stocks.add(includedStocks[i]);
      }
    }
    return stocks;
  }

  void changeActiveImageUrl(String url) {
    state = state.copyWith(activeImageUrl: url);
  }

  Future<void> generateShareLink(String? shopType, int? shopId) async {
    try {
      if (shopType == null || shopId == null || state.productData?.uuid == null) {
        debugPrint("Missing required data for share link generation");
        return;
      }

      // Generate custom deep link for your service
      final productLink = '${AppConstants.webUrl}/shop/$shopId?product=${state.productData?.uuid}';
      
      // Create the custom deep link using your domain
      final customDeepLink = 'swipe.mooup.ma/shop/$shopId/product/${state.productData?.uuid}';
      
      // For now, use the custom deep link directly since you're not using Firebase
      // You can modify this to call your custom deep link service if needed
      shareLink = customDeepLink;
      
      debugPrint("Generated custom deep link: $shareLink");
      debugPrint("Product link: $productLink");
      
      // If you have a custom deep link service, you can uncomment and modify this:
      /*
      final res = await http.post(
        Uri.parse('YOUR_CUSTOM_DEEP_LINK_SERVICE_URL'), 
        body: jsonEncode({
          "shopId": shopId,
          "productId": state.productData?.uuid,
          "shopType": shopType,
          "productTitle": state.productData?.translation?.title,
          "productDescription": state.productData?.translation?.description,
          "productImage": state.productData?.img,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (res.statusCode == 200) {
        final responseBody = jsonDecode(res.body);
        if (responseBody['shortLink'] != null) {
          shareLink = responseBody['shortLink'];
          debugPrint("share link product_notifier: $shareLink");
        } else {
          debugPrint("No shortLink in response: $responseBody");
        }
      } else {
        debugPrint("Failed to generate share link. Status: ${res.statusCode}, Body: ${res.body}");
      }
      */
      
    } catch (e) {
      debugPrint("Error generating share link: $e");
      // Fallback to direct product link
      if (shopId != null && state.productData?.uuid != null) {
        shareLink = '${AppConstants.webUrl}/shop/$shopId?product=${state.productData?.uuid}';
      }
    }
  }

  Future<void> shareProduct({String? shopType, int? shopId}) async {
    debugPrint("shareProduct called with shopType: $shopType, shopId: $shopId");
    
    // Use provided shopType and shopId, or fall back to product state
    final finalShopType = shopType ?? state.productData?.shop?.type;
    final finalShopId = shopId ?? state.productData?.shopId;
    
    debugPrint("Final shop data - type: $finalShopType, id: $finalShopId");
    debugPrint("Current shareLink: $shareLink");
    
    // Check if shareLink is empty or null, generate it if needed
    if (shareLink == null || shareLink!.isEmpty) {
      debugPrint("Share link is empty, attempting to generate new one");
      if (finalShopType != null && finalShopId != null) {
        await generateShareLink(finalShopType, finalShopId);
        debugPrint("Generated share link: $shareLink");
      } else {
        debugPrint("Cannot generate share link - missing shop data");
      }
    }
    
    // Check again if we have a valid share link
    if (shareLink != null && shareLink!.isNotEmpty) {
      debugPrint("Sharing with dynamic link: $shareLink");
      await Share.share(shareLink!,
        subject: state.productData?.translation?.title ?? "upmoo25",
        // title: state.productData?.translation?.description ?? "",
      );
    } else {
      debugPrint("Using fallback sharing method");
      // Fallback: share basic product info with direct link if dynamic link generation fails
      final productTitle = state.productData?.translation?.title ?? "Product";
      final productDescription = state.productData?.translation?.description ?? "";
      
      String fallbackText = "$productTitle\n\n$productDescription";
      
      // Add direct product link if we have shop info
      if (finalShopId != null && state.productData?.uuid != null) {
        final directLink = '${AppConstants.webUrl}/shop/$finalShopId?product=${state.productData?.uuid}';
        fallbackText += "\n\nView product: $directLink";
        debugPrint("Added direct link to fallback: $directLink");
      }
      
      await Share.share(fallbackText,
        subject: productTitle,
      );
    }
  }
}
