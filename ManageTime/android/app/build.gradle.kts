plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.manage_time"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // KÍCH HOẠT ĐỒNG BỘ NGƯỢC THƯ VIỆN LÕI JAVA CHO KOTLIN DSL
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.manage_time"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// THÊM ĐOẠN NÀY DƯỚI CÙNG ĐỂ NẠP BỘ GIẢI MÃ DESUGAR CHO KOTLIN DSL
dependencies {
    "coreLibraryDesugaring"("com.android.tools:desugar_jdk_libs:2.0.4")
}