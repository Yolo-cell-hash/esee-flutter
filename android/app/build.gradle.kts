plugins {
            id("com.android.application")
            id("kotlin-android")
            id("dev.flutter.flutter-gradle-plugin")
        }

        android {
            namespace = "com.eseeiot.video.eseeiot"
            compileSdk = flutter.compileSdkVersion
            ndkVersion = flutter.ndkVersion

            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }

            kotlin {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }

            defaultConfig {
                applicationId = "com.eseeiot.video.eseeiot"
                minSdk = flutter.minSdkVersion
                targetSdk = flutter.targetSdkVersion
                versionCode = flutter.versionCode
                versionName = flutter.versionName
            }

            buildTypes {
                release {
                    signingConfig = signingConfigs.getByName("debug")
                }
            }

            repositories {
                flatDir {
                    dirs("libs")
                }
            }
        }

        flutter {
            source = "../.."
        }

        dependencies {
            // eseeiot SDK
            implementation(files("libs/esee_main_release_v1.0.0.aar"))

            // Required dependencies
            implementation("com.google.code.gson:gson:2.11.0")
            implementation("androidx.appcompat:appcompat:1.7.0")
            implementation("androidx.constraintlayout:constraintlayout:2.1.4")
        }