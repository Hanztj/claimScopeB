import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = File(rootProject.projectDir, "app/key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    throw GradleException("key.properties not found at ${keystorePropertiesFile.absolutePath}")
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.hfestimates.claimscope" 
    compileSdk = 36
    ndkVersion = "27.0.12077973"

compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17 // ← Cambiado a 17
        targetCompatibility = JavaVersion.VERSION_17 // ← Cambiado a 17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString() // ← Cambiado a 17
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            if (storeFilePath == null) {
                throw GradleException("storeFile not defined in key.properties")
            }
            storeFile = file(storeFilePath)
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    defaultConfig {
        applicationId = "com.hfestimates.claimscope" 
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true 
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.5.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
}

flutter {
    source = "../.."
}