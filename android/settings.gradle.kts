pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.13.2" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.4") apply false
    id("com.google.firebase.crashlytics") version("3.0.6") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

// Keep Flutter/Dart on the published plugin API while replacing only the
// Android native core with the pinned fork in vendor/. This makes enhanced
// Android behavior reproducible without publishing over Traccar's Maven
// coordinates or relying on a mutable branch at build time.
includeBuild("../vendor/traccar-client-sdk") {
    dependencySubstitution {
        substitute(module("org.traccar:traccar-client-sdk")).using(project(":core"))
    }
}

include(":app")
