# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Mobile Scanner
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class dev.steenbakker.mobile_scanner.* { *; }
-keep class dev.steenbakker.mobile_scanner.MobileScannerController { *; }
-keep class dev.steenbakker.mobile_scanner.MobileScanner { *; }
-keep class dev.steenbakker.mobile_scanner.MobileScannerArguments { *; }
-keep class dev.steenbakker.mobile_scanner.MobileScannerError { *; }
-keep class dev.steenbakker.mobile_scanner.BarcodeCapture { *; }
-keep class dev.steenbakker.mobile_scanner.Barcode { *; }
-keep class dev.steenbakker.mobile_scanner.MobileScannerErrorCode { *; }
-keep class dev.steenbakker.mobile_scanner.DetectionSpeed { *; }
-keep class dev.steenbakker.mobile_scanner.BarcodeFormat { *; }
-keep class dev.steenbakker.mobile_scanner.MobileScannerErrorDetails { *; }

# Mobile Scanner Permissions
-keep class dev.steenbakker.mobile_scanner.MobileScannerPermissions { *; }

# CameraX (used by mobile_scanner)
-keep class androidx.camera.** { *; }
-keep class androidx.camera.core.** { *; }
-keep class androidx.camera.camera2.** { *; }
-keep class androidx.camera.view.** { *; }
-keep class androidx.camera.lifecycle.** { *; }
-keep class androidx.camera.extensions.** { *; }
-keep class androidx.camera.mlkit.** { *; }

# ML Kit (Barcode Scanning)
-keep class com.google.mlkit.vision.barcode.** { *; }
-keep class com.google.mlkit.vision.barcode.common.** { *; }
-keep class com.google.mlkit.common.** { *; }
-keep class com.google.mlkit.common.model.** { *; }

# Google Play Services
-keep class com.google.android.gms.** { *; }


# Google Play Core (SplitCompat, SplitInstall, etc.)
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallManager { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallManagerFactory { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallRequest { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallRequest$Builder { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallSessionState { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener { *; }
-keep class com.google.android.play.core.splitinstall.SplitInstallException { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.tasks.Task { *; }
-keep class com.google.android.play.core.tasks.OnSuccessListener { *; }
-keep class com.google.android.play.core.tasks.OnFailureListener { *; }
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication { *; }
-dontwarn com.google.android.play.core.**

