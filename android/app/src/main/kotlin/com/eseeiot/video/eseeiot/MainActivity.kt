package com.eseeiot.video.eseeiot

import android. os.Bundle
import android.util.Log
import com.eseeiot.device.DeviceManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var cameraPlugin: EseeiotCameraPlugin? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Debug: Print all methods available in DeviceManager
        logClassMethods("DeviceManager", DeviceManager:: class.java)

        // Try to find the correct initialization method
        tryInitializeSdk()
    }

    private fun logClassMethods(name: String, clazz: Class<*>) {
        Log.d("SDK_DEBUG", "========== $name METHODS ==========")

        // Log all methods (including inherited)
        clazz.methods.forEach { method ->
            val params = method.parameterTypes. map { it.simpleName }.joinToString(", ")
            val modifiers = java.lang.reflect.Modifier. toString(method.modifiers)
            Log.d("SDK_DEBUG", "  $modifiers ${method.name}($params): ${method.returnType.simpleName}")
        }

        // Log declared methods only (this class only)
        Log.d("SDK_DEBUG", "---------- DECLARED METHODS ----------")
        clazz.declaredMethods. forEach { method ->
            val params = method.parameterTypes.map { it.simpleName }.joinToString(", ")
            val modifiers = java.lang.reflect. Modifier.toString(method.modifiers)
            Log.d("SDK_DEBUG", "  $modifiers ${method.name}($params): ${method.returnType.simpleName}")
        }

        // Log static fields
        Log.d("SDK_DEBUG", "---------- STATIC FIELDS ----------")
        clazz.declaredFields.forEach { field ->
            val modifiers = java.lang.reflect.Modifier. toString(field.modifiers)
            Log.d("SDK_DEBUG", "  $modifiers ${field.name}: ${field.type.simpleName}")
        }

        // Log constructors
        Log.d("SDK_DEBUG", "---------- CONSTRUCTORS ----------")
        clazz.constructors.forEach { constructor ->
            val params = constructor.parameterTypes.map { it.simpleName }.joinToString(", ")
            Log.d("SDK_DEBUG", "  ${constructor.name}($params)")
        }
    }

    private fun tryInitializeSdk() {
        Log.d("SDK_DEBUG", "========== TRYING SDK INITIALIZATION ==========")

        val context = applicationContext

        // Method 1: Try getDefault() directly
        try {
            val dm = DeviceManager.getDefault()
            Log.d("SDK_DEBUG", "getDefault() returned: $dm")
        } catch (e: Exception) {
            Log.e("SDK_DEBUG", "getDefault() failed: ${e.message}")
        }

        // Method 2: Try static init methods with reflection
        val methodsToTry = listOf(
            "init" to listOf(android.content.Context::class.java),
            "initialize" to listOf(android.content.Context::class.java),
            "setup" to listOf(android.content.Context::class.java),
            "create" to listOf(android.content.Context::class.java),
            "getInstance" to listOf(android.content.Context::class.java),
            "init" to listOf(android.app.Application::class.java),
            "initialize" to listOf(android.app.Application::class.java),
            "init" to emptyList(),
            "initialize" to emptyList(),
        )

        for ((methodName, paramTypes) in methodsToTry) {
            try {
                val method = if (paramTypes.isEmpty()) {
                    DeviceManager::class.java.getMethod(methodName)
                } else {
                    DeviceManager::class.java.getMethod(methodName, *paramTypes.toTypedArray())
                }

                val result = if (paramTypes.isEmpty()) {
                    method.invoke(null)
                } else {
                    method.invoke(null, context)
                }

                Log. d("SDK_DEBUG", "SUCCESS: $methodName(${paramTypes.map { it.simpleName }}) returned: $result")

                // Try getDefault again after successful init
                val dm = DeviceManager.getDefault()
                Log. d("SDK_DEBUG", "After $methodName, getDefault() returned: $dm")

            } catch (e: NoSuchMethodException) {
                Log. d("SDK_DEBUG", "Method not found: $methodName(${paramTypes.map { it.simpleName }})")
            } catch (e:  Exception) {
                Log.e("SDK_DEBUG", "Error calling $methodName: ${e.message}")
            }
        }

        // Method 3: Check if there's an Application class that needs to initialize the SDK
        Log.d("SDK_DEBUG", "Application class:  ${application. javaClass.name}")

        // Method 4: Look for SDK initialization in other classes
        val classesToCheck = listOf(
            "com.eseeiot.device.DeviceManager",
            "com.eseeiot.core.EseeiotSDK",
            "com.eseeiot.core.SDK",
            "com.eseeiot.EseeiotManager",
            "com.eseeiot.live.LiveManager",
            "com.eseeiot.basemodule.BaseModule",
        )

        for (className in classesToCheck) {
            try {
                val clazz = Class.forName(className)
                Log.d("SDK_DEBUG", "Found class: $className")
                logClassMethods(className, clazz)
            } catch (e: ClassNotFoundException) {
                Log.d("SDK_DEBUG", "Class not found:  $className")
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Create and register the method channel plugin
        cameraPlugin = EseeiotCameraPlugin()
        flutterEngine.plugins.add(cameraPlugin!!)

        // Register the platform view factory with plugin reference
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "eseeiot_camera_view",
            CameraViewFactory(flutterEngine.dartExecutor.binaryMessenger, cameraPlugin)
        )
    }
}