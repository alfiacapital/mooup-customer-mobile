# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# UCrop library compatibility fixes
-keep class com.yalantis.ucrop** { *; }
-keep interface com.yalantis.ucrop** { *; }
-dontwarn com.yalantis.ucrop**

# Keep UCrop utility classes
-keep class com.yalantis.ucrop.util.** { *; }
-keep class com.yalantis.ucrop.callback.** { *; }

# Firebase compatibility
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable classes
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep R classes
-keep class **.R$* {
    public static <fields>;
}

# Keep View constructors
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# Keep onClick methods
-keepclassmembers class * extends android.app.Activity {
   public void *(android.view.View);
}

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep generic signatures
-keepattributes Signature

# Keep annotations
-keepattributes *Annotation*

# Keep source file names for debugging
-keepattributes SourceFile,LineNumberTable

# Keep native method names
-keepattributes Native

# Keep exception stack traces
-keepattributes Exceptions

# Keep inner classes
-keepattributes InnerClasses

# Keep synthetic methods
-keepattributes Synthetic

# Keep bridge methods
-keepattributes BridgeMethods

# Keep deprecated methods
-keepattributes Deprecated

# Keep constant pool
-keepattributes ConstantPool

# Keep local variable table
-keepattributes LocalVariableTable

# Keep local variable type table
-keepattributes LocalVariableTypeTable

# Keep method parameters
-keepattributes MethodParameters

# Keep runtime visible annotations
-keepattributes RuntimeVisibleAnnotations

# Keep runtime visible parameter annotations
-keepattributes RuntimeVisibleParameterAnnotations

# Keep runtime visible type annotations
-keepattributes RuntimeVisibleTypeAnnotations

# Keep runtime invisible annotations
-keepattributes RuntimeInvisibleAnnotations

# Keep runtime invisible parameter annotations
-keepattributes RuntimeInvisibleParameterAnnotations

# Keep runtime invisible type annotations
-keepattributes RuntimeInvisibleTypeAnnotations

# Keep enclosing method
-keepattributes EnclosingMethod

# Keep signature
-keepattributes Signature

# Keep stack map table
-keepattributes StackMapTable

# Keep bootstrap methods
-keepattributes BootstrapMethods

# Keep method parameters
-keepattributes MethodParameters

# Keep module
-keepattributes Module

# Keep module packages
-keepattributes ModulePackages

# Keep module main class
-keepattributes ModuleMainClass

# Keep module version
-keepattributes ModuleVersion

# Keep module hashes
-keepattributes ModuleHashes

# Keep module resolution
-keepattributes ModuleResolution

# Keep module target platform
-keepattributes ModuleTargetPlatform

# Keep module host platform
-keepattributes ModuleHostPlatform

# Keep module static
-keepattributes ModuleStatic

# Keep module open
-keepattributes ModuleOpen

# Keep module packages
-keepattributes ModulePackages

# Keep module main class
-keepattributes ModuleMainClass

# Keep module version
-keepattributes ModuleVersion

# Keep module hashes
-keepattributes ModuleHashes

# Keep module resolution
-keepattributes ModuleResolution

# Keep module target platform
-keepattributes ModuleTargetPlatform

# Keep module host platform
-keepattributes ModuleHostPlatform

# Keep module static
-keepattributes ModuleStatic

# Keep module open
-keepattributes ModuleOpen
