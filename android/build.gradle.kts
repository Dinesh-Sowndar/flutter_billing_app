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

// Force compileSdk 36 on all subprojects except :app (which already sets it
// and is already evaluated via evaluationDependsOn).
subprojects {
    if (project.name != "app") {
        afterEvaluate {
            if (project.hasProperty("android")) {
                val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
                android.compileSdkVersion(36)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
