buildscript {

    repositories {
        google()
        mavenCentral()
    }

    // ...
    dependencies {
        // 使用新版 Google Services Plugin
        classpath("com.android.tools.build:gradle:8.3.0") // 根據你的 AGP 版本
        classpath("com.google.gms:google-services:4.4.1") // ✅ Firebase Plugin (最新版)
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
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

