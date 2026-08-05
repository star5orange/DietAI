buildscript {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/public/") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin/") }
        google()
        mavenCentral()
    }
    dependencies {
        // 示例 classpath，如果你需要：
        // classpath("com.android.tools.build:gradle:8.7.3")
    }
}


allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://maven.aliyun.com/repository/public/") }
        maven { url = uri("https://maven.aliyun.com/repository/google/") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin/") }
        maven { url = uri("https://mirrors.huaweicloud.com/repository/maven/") }
    }
}

// 修改默认 build 目录到项目外层的 build 目录
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// 在全部项目配置并 finalize 完成后（compileOptions 此时可安全读取），
// 将各模块 Kotlin 的 jvmTarget 对齐到其自身的 Java 编译目标，
// 避免 Java/Kotlin JVM 目标不一致。不修改 compileOptions，
// 也不直接改 JavaCompile 任务属性（会破坏 AGP 的 bootclasspath）。
gradle.projectsEvaluated {
    subprojects {
        val androidExt = extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?: extensions.findByType(com.android.build.gradle.AppExtension::class.java)
        if (androidExt == null) return@subprojects
        val javaTarget = androidExt.compileOptions.targetCompatibility.toString()
        val targetVersion = when (javaTarget) {
            "1.8" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
            "11" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
            "17" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            "21" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
            else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(targetVersion)
            }
        }
    }
}

// 自定义 clean 任务
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}