# Deep Link Configuration for open.mooup.ma/open-app

## Overview
This app has been configured to handle deep links from the domain `open.mooup.ma`. The specific route `/open-app` will open the app and navigate to the main screen.

## Configuration Details

### Android Configuration
The Android manifest (`android/app/src/main/AndroidManifest.xml`) already includes the necessary intent filter:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="mooup.ma" />
    <data android:scheme="https" android:host="open.mooup.ma" />
</intent-filter>
```

This configuration allows the app to handle all HTTPS links from `open.mooup.ma`, including the `/open-app` path.

### iOS Configuration
The iOS configuration has been updated in `ios/Runner/Runner.entitlements`:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:foodyman.page.link</string>
    <string>applinks:open.mooup.ma</string>
</array>
```

This enables Universal Links for the `open.mooup.ma` domain on iOS.

### Flutter Code Implementation
The deep link handling is implemented in `lib/infrastructure/services/deep_links.dart`:

```dart
// Handle the /open-app deep link to just open the app
if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'open-app') {
  // Navigate to main route to open the app
  await router.push(const MainRoute());
  return;
}
```

## How It Works

1. **User clicks link**: When a user clicks on `https://open.mooup.ma/open-app`
2. **System recognition**: The operating system recognizes this as a deep link for your app
3. **App opens**: The app opens and the `DeepLinksHandler` processes the incoming URI
4. **Route navigation**: The handler detects the `/open-app` path and navigates to the `MainRoute`
5. **App is ready**: The user is now in the main app interface

## Testing

### Android
- Install the app on an Android device
- Click on a link like `https://open.mooup.ma/open-app`
- The app should open and navigate to the main screen

### iOS
- Install the app on an iOS device
- Click on a link like `https://open.mooup.ma/open-app`
- The app should open and navigate to the main screen

## Additional Notes

- The deep link handler is initialized in the `AppWidget` class
- The handler processes both initial links (when app is opened from a link) and subsequent links (when app is already running)
- The `/open-app` route is processed before other deep link logic, ensuring it takes priority
- This implementation uses the `app_links` package for cross-platform deep link handling

## Troubleshooting

If the deep link is not working:

1. **Verify domain ownership**: Ensure you have control over the `open.mooup.ma` domain
2. **Check SSL certificate**: The domain must have a valid SSL certificate
3. **App installation**: The app must be installed on the device
4. **Build and test**: Rebuild the app after making configuration changes
5. **Clear app data**: Sometimes clearing app data can help with testing

## Future Enhancements

You can easily add more deep link routes by extending the `_handleUri` method in the `DeepLinksHandler` class. For example:

```dart
// Handle other custom routes
if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'custom-route') {
  // Handle custom route
  await router.push(CustomRoute());
  return;
}
```
