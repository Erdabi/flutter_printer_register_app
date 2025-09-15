plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_printer_register_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flutter_printer_register_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
// --- Patch for plugins missing a namespace (AGP 7/8), no imports needed ---
subprojects {
    if (name == "thermal_printer") {
        plugins.withId("com.android.library") {
            // Grab the Android 'library' extension and set 'namespace' via reflection
            extensions.findByName("android")?.let { ext ->
                try {
                    val m = ext.javaClass.getMethod("setNamespace", String::class.java)
                    m.invoke(ext, "com.codingdevs.thermal_printer")
                    println("Applied namespace to :$name")
                } catch (t: Throwable) {
                    println("Could not set namespace for :$name -> ${t.message}")
                }
            }
        }
    }
}
