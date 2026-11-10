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

subprojects {
    if (project.name != "app") {
        val configureSubproject: () -> Unit = {
            val android = project.extensions.findByName("android")
            if (android != null) {
                val getCompileSdk = android.javaClass.methods.firstOrNull {
                    (it.name == "getCompileSdk" || it.name == "getCompileSdkVersion") && it.parameterCount == 0
                }
                val currentSdkVal = try { getCompileSdk?.invoke(android)?.toString() } catch (_: Throwable) { null }
                val currentSdkInt = currentSdkVal?.filter { it.isDigit() }?.toIntOrNull()

                // Only upgrade subprojects with compileSdk < 34 (e.g. mobile_scanner with 33)
                // Modern subprojects like sqflite_android (which uses 36) remain untouched
                if (currentSdkInt == null || currentSdkInt < 34) {
                    for (method in android.javaClass.methods) {
                        if (method.name in listOf("compileSdkVersion", "setCompileSdkVersion", "setCompileSdk") && method.parameterCount == 1) {
                            val paramType = method.parameterTypes[0]
                            try {
                                if (paramType == Int::class.javaPrimitiveType || paramType == java.lang.Integer::class.java) {
                                    method.invoke(android, 34)
                                } else if (paramType == java.lang.String::class.java && method.name == "compileSdkVersion") {
                                    method.invoke(android, "android-34")
                                }
                            } catch (_: Throwable) {}
                        }
                    }
                }
            }
        }

        if (project.state.executed) {
            configureSubproject()
        } else {
            project.afterEvaluate { configureSubproject() }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

