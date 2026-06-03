allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17 // ← Cambiado a 17
                targetCompatibility = JavaVersion.VERSION_17 // ← Cambiado a 17
            }
        }
    }
    
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) // ← Cambiado a 17
        }
    }
    
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17" // ← Cambiado a 17
        targetCompatibility = "17" // ← Cambiado a 17
    }
}


val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
plugins {
  // ...

  // Add the dependency for the Google services Gradle plugin
  id("com.google.gms.google-services") version "4.4.3" apply false
}
