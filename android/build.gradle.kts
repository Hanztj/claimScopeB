allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    val isPdfCombiner = name == "pdf_combiner"

    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
            compileOptions {
                val javaVersion = if (isPdfCombiner) {
                    JavaVersion.VERSION_1_8
                } else {
                    JavaVersion.VERSION_17
                }

                sourceCompatibility = javaVersion
                targetCompatibility = javaVersion
            }
        }
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
        .configureEach {
            compilerOptions {
                jvmTarget.set(
                    if (isPdfCombiner) {
                        org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                    } else {
                        org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                    },
                )
            }
        }

    tasks.withType<JavaCompile>().configureEach {
        val javaTarget = if (isPdfCombiner) "1.8" else "17"

        sourceCompatibility = javaTarget
        targetCompatibility = javaTarget
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
