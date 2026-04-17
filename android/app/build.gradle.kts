plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.heartconnect.app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.heartconnect.app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }


    signingConfigs {
        // To use a keystore for release builds, create android/key.properties:
        //   storeFile=<path-to-keystore.jks>
        //   storePassword=<store-password>
        //   keyAlias=<key-alias>
        //   keyPassword=<key-password>
        // Then uncomment the block below and remove the debug signingConfig in buildTypes.
        //
        // create("release") {
        //     val props = java.util.Properties().also {
        //         it.load(rootProject.file("key.properties").inputStream())
        //     }
        //     keyAlias = props["keyAlias"] as String
        //     keyPassword = props["keyPassword"] as String
        //     storeFile = file(props["storeFile"] as String)
        //     storePassword = props["storePassword"] as String
        // }
    }

    buildTypes {
        release {
            // IMPORTANT: Replace the debug signingConfig below with the release
            // signingConfig once you have created a keystore (see signingConfigs above).
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    applicationVariants.all {
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            output.outputFileName = "HeartConnect.apk"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
