allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force compileSdk 36 on all subprojects. If already evaluated, set immediately.
subprojects {
    if (project.name != "app") {
        if (project.state.executed) {
            val android = extensions.findByName("android")
            if (android != null) {
                (android as com.android.build.gradle.BaseExtension).compileSdkVersion(36)
            }
        } else {
            afterEvaluate {
                val android = extensions.findByName("android")
                if (android != null) {
                    (android as com.android.build.gradle.BaseExtension).compileSdkVersion(36)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
