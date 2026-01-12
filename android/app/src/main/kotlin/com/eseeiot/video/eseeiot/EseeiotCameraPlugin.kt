package com.eseeiot.video.eseeiot

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.util.ArrayMap
import android.util.Log
import android.view.View
import androidx.annotation.NonNull
import androidx.core.view.ViewCompat
import com.eseeiot. basemodule.device.base.MonitorDevice
import com.eseeiot.basemodule.device.common.Parameter
import com.eseeiot.basemodule.device.ptz.PTZ
import com.eseeiot.basemodule.listener.CaptureCallback
import com.eseeiot.basemodule.listener.RecordCallback
import com.eseeiot. basemodule.player.DevicePlayer
import com.eseeiot.basemodule.player.RenderPipe
import com.eseeiot.basemodule.player.listener.OnPlayErrorListener
import com. eseeiot.basemodule.player. listener.OnRenderChangedListener
import com.eseeiot. core.view.JAGLSurfaceView
import com.eseeiot. device.DeviceManager
import com.eseeiot.device.pojo.DeviceInfo
import com.eseeiot.live.JAPTZController
import com.eseeiot.live. player.JALivePlayer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins. activity.ActivityAware
import io. flutter.embedding.engine.plugins.activity. ActivityPluginBinding
import io.flutter.plugin. common.EventChannel
import io. flutter.plugin.common.MethodCall
import io.flutter.plugin.common. MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io. flutter.plugin.common.MethodChannel. Result

/**
 * EseeiotCameraPlugin - Flutter plugin for eseeiot camera SDK
 *
 * Based on Godrej Locks app's LiveViewActivity implementation
 */
class EseeiotCameraPlugin :  FlutterPlugin, MethodCallHandler, ActivityAware,
    CaptureCallback, OnPlayErrorListener, OnRenderChangedListener {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink?  = null
    private var context: Context? = null
    private var activity: Activity? = null

    fun getDisplayView(): JAGLSurfaceView? = mDisplayView

    /**
     * Get the current device
     */
    fun getDevice(): MonitorDevice? = mDevice

    /**
     * Get the current player
     */
    fun getPlayer(): JALivePlayer? = mPlayer

    /**
     * Get the render pipe
     */
    fun getRenderPipe(): RenderPipe? = mRenderPipe

    // Camera components - matching LiveViewViewModel structure
    private var mDevice: MonitorDevice?  = null
    private var mCamera: com.eseeiot. basemodule.device. base.MonitorCamera? = null
    private var mPlayer: JALivePlayer? = null
    private var mDisplayView: JAGLSurfaceView?  = null
    private var mRenderPipe: RenderPipe? = null
    private var mPTZ: PTZ? = null
    private var mChannel: Int = 0
    private var mTempView: View? = null

    // Store current camera ID
    private var currentCameraId: String?  = null

    // Track if SDK is initialized
    private var isSdkInitialized = false

    // RecordCallback instance
    private var recordCallback: RecordCallback? = null

    companion object {
        private const val TAG = "EseeiotCameraPlugin"
        const val CHANNEL_NAME = "eseeiot_camera"
        const val EVENT_CHANNEL_NAME = "eseeiot_camera_events"
        const val MSG_STOP_PTZ = 110
    }

    // Handler for PTZ stop delay - matching LiveViewActivity
    private val mHandler:  Handler = object : Handler(Looper.getMainLooper()) {
        override fun handleMessage(msg: Message) {
            when (msg.what) {
                MSG_STOP_PTZ -> {
                    Log.d(TAG, "Stopping PTZ")
                    mPTZ?.stop()
                }
            }
        }
    }

    // ==================== FlutterPlugin Implementation ====================

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onAttachedToEngine")
        context = binding.applicationContext

        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME)
        eventChannel.setStreamHandler(object :  EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                Log.d(TAG, "Event channel listening")
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                Log.d(TAG, "Event channel cancelled")
                eventSink = null
            }
        })

        // Create record callback
        createRecordCallback()
    }

    /**
     * Create RecordCallback dynamically
     */
    private fun createRecordCallback() {
        recordCallback = object : RecordCallback {
            override fun onRecordStart() {
                Log. d(TAG, "onRecordStart")
                sendEvent("recordStart", null)
            }

            override fun onRecording(p0: Int, p1: Int) {
                Log. d(TAG, "onRecording:  p0=$p0, p1=$p1")
                sendEvent("recording", mapOf(
                    "duration" to p0,
                    "size" to p1
                ))
            }

            override fun onRecordStop(p0: String?, p1: Boolean) {
                Log.d(TAG, "onRecordStop: path=$p0, success=$p1")
                sendEvent("recordStop", mapOf(
                    "path" to p0,
                    "success" to p1
                ))
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding:  FlutterPlugin. FlutterPluginBinding) {
        Log.d(TAG, "onDetachedFromEngine")
        channel.setMethodCallHandler(null)
    }

    // ==================== MethodCallHandler Implementation ====================

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        Log.d(TAG, "Method called: ${call.method}")

        when (call.method) {
            "initializeSDK" -> initializeSDK(result)

            "saveCamera" -> {
                val cameraId = call.argument<String>("cameraId") ?: ""
                val cameraName = call.argument<String>("cameraName") ?: ""
                val username = call.argument<String>("username") ?: "admin"
                val password = call.argument<String>("password") ?: ""
                val channelCount = call.argument<Int>("channelCount") ?: 1
                saveCamera(cameraId, cameraName, username, password, channelCount, result)
            }

            "connectCamera" -> {
                val cameraId = call.argument<String>("cameraId") ?: ""
                connectCamera(cameraId, result)
            }

            "initLiveView" -> initLiveView(result)
            "startPlay" -> startPlay(result)
            "stopPlay" -> stopPlay(result)

            "ptzMoveUp" -> ptzMoveUp(result)
            "ptzMoveDown" -> ptzMoveDown(result)
            "ptzMoveLeft" -> ptzMoveLeft(result)
            "ptzMoveRight" -> ptzMoveRight(result)
            "ptzStop" -> ptzStop(result)

            "capture" -> capture(result)
            "dispose" -> dispose(result)

            else -> result.notImplemented()
        }
    }

    // ==================== SDK Methods ====================

    /**
     * Initialize SDK - This MUST be called before any other SDK methods
     *
     * The eseeiot SDK requires initialization with context before DeviceManager can be used
     */
    private fun initializeSDK(result: Result) {
        try {
            Log. d(TAG, "Initializing SDK")

            val appContext = context ?:  activity?. applicationContext
            if (appContext == null) {
                result.error("NO_CONTEXT", "Application context is not available", null)
                return
            }

            // Initialize the DeviceManager with context
            // The SDK needs to be initialized before getDefault() returns a valid instance
            try {
                // Try to initialize the SDK - this varies by SDK version
                // Method 1: Try init with context
                val initMethod = DeviceManager:: class.java.getMethod("init", Context::class. java)
                initMethod.invoke(null, appContext)
                Log.d(TAG, "SDK initialized via init(Context)")
            } catch (e: NoSuchMethodException) {
                Log. d(TAG, "init(Context) not found, trying alternative...")
                try {
                    // Method 2: Try getInstance with context
                    val getInstanceMethod = DeviceManager::class.java.getMethod("getInstance", Context::class. java)
                    getInstanceMethod.invoke(null, appContext)
                    Log. d(TAG, "SDK initialized via getInstance(Context)")
                } catch (e2: NoSuchMethodException) {
                    Log.d(TAG, "getInstance(Context) not found, trying getDefault()...")
                    // Method 3: Just call getDefault and hope it auto-initializes
                    // Some SDK versions auto-initialize on first call
                }
            }

            // Now try to get the DeviceManager
            val deviceManager = DeviceManager.getDefault()

            if (deviceManager == null) {
                Log.e(TAG, "DeviceManager. getDefault() returned null after initialization")
                result. error("SDK_INIT_FAILED", "DeviceManager initialization failed.  The SDK may require additional setup.", null)
                return
            }

            isSdkInitialized = true
            Log.d(TAG, "DeviceManager initialized successfully:  $deviceManager")
            result.success(mapOf("success" to true, "message" to "SDK initialized"))

        } catch (e: Exception) {
            Log.e(TAG, "SDK initialization failed", e)
            result.error("INIT_ERROR", e.message, e. stackTraceToString())
        }
    }

    /**
     * Ensure SDK is initialized before performing operations
     */
    private fun ensureSdkInitialized(): Boolean {
        if (!isSdkInitialized) {
            Log.w(TAG, "SDK not initialized, attempting auto-initialization...")
            try {
                val appContext = context ?:  activity?.applicationContext
                if (appContext != null) {
                    // Try auto-initialization
                    try {
                        val initMethod = DeviceManager::class.java.getMethod("init", Context::class. java)
                        initMethod.invoke(null, appContext)
                    } catch (e:  Exception) {
                        // Ignore, try getDefault
                    }

                    val deviceManager = DeviceManager.getDefault()
                    if (deviceManager != null) {
                        isSdkInitialized = true
                        Log.d(TAG, "SDK auto-initialized successfully")
                        return true
                    }
                }
            } catch (e: Exception) {
                Log. e(TAG, "Auto-initialization failed", e)
            }
            return false
        }
        return true
    }

    /**
     * Save camera - matching HomeViewModel. onSaveCamera()
     */
    /**
     * Save camera - matching HomeViewModel. onSaveCamera()
     */
    private fun saveCamera(
        cameraId: String,
        cameraName: String,
        username: String,
        password: String,  // Make sure this is passed correctly
        channelCount: Int,
        result: Result
    ) {
        try {
            Log.d(TAG, "Saving camera: id=$cameraId, name=$cameraName, username=$username, password=${if (password.isEmpty()) "(empty)" else "(set)"}")

            // Ensure SDK is initialized
            if (! ensureSdkInitialized()) {
                result.error("SDK_NOT_INITIALIZED", "Please call initializeSDK first", null)
                return
            }

            val deviceManager = DeviceManager.getDefault()
            if (deviceManager == null) {
                result.error("SDK_NOT_INITIALIZED", "DeviceManager is null", null)
                return
            }

            // Reset device list first
            deviceManager. resetList()

            // Create device info
            val deviceInfo = DeviceInfo()
            deviceInfo. deviceId = cameraId
            deviceInfo.username = username

            // IMPORTANT: Set password correctly
            // Try empty password if none provided, as some cameras don't require password
            deviceInfo.pwd = password

            deviceInfo.channelCount = channelCount

            Log.d(TAG, "DeviceInfo:  id=${deviceInfo.deviceId}, user=${deviceInfo.username}, pwd=${if (deviceInfo.pwd.isNullOrEmpty()) "(empty)" else "(set)"}, channels=${deviceInfo.channelCount}")

            // Create device
            deviceManager.createDevice(deviceInfo)

            // Store the camera ID
            currentCameraId = cameraId

            Log.d(TAG, "Camera saved successfully")
            result.success(mapOf(
                "success" to true,
                "cameraId" to cameraId,
                "cameraName" to cameraName
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Save camera failed", e)
            result.error("SAVE_CAMERA_ERROR", e.message, e. stackTraceToString())
        }
    }

    /**
     * Connect to camera - matching LiveViewActivity.init()
     */
    private fun connectCamera(cameraId:  String, result: Result) {
        try {
            Log. d(TAG, "Connecting to camera:  $cameraId")

            // Ensure SDK is initialized
            if (!ensureSdkInitialized()) {
                result.error("SDK_NOT_INITIALIZED", "Please call initializeSDK first", null)
                return
            }

            val deviceManager = DeviceManager.getDefault()
            if (deviceManager == null) {
                result. error("SDK_NOT_INITIALIZED", "DeviceManager is null", null)
                return
            }

            currentCameraId = cameraId
            mDevice = deviceManager. getDevice(cameraId)

            if (mDevice == null) {
                Log.e(TAG, "Device not found:  $cameraId")
                result.error(
                    "DEVICE_NOT_FOUND",
                    "Camera with ID $cameraId not found. Make sure to save the camera first.",
                    null
                )
                return
            }

            mCamera = mDevice!! .getCamera(mChannel)
            Log.d(TAG, "Device found: channels=${mDevice!!.channelCount}")

            result.success(mapOf(
                "success" to true,
                "channelCount" to mDevice!!.channelCount
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Connect camera failed", e)
            result.error("CONNECT_ERROR", e.message, e.stackTraceToString())
        }
    }

    /**
     * Initialize live view - matching LiveViewActivity.init()
     */
    private fun initLiveView(result:  Result) {
        if (mDevice == null) {
            result.error("NO_DEVICE", "No device connected.  Call connectCamera first.", null)
            return
        }

        try {
            Log. d(TAG, "Initializing live view")

            activity?.runOnUiThread {
                try {
                    // Create views - matching LiveViewActivity. init()
                    mTempView = View(activity)
                    mDisplayView = JAGLSurfaceView(activity!! ).apply {
                        ViewCompat.setTransitionName(this, "remote_video")
                    }
                        mDisplayView!!.setViewAspect(1.0f)
                    // Create player - matching LiveViewActivity.init()
                    if (mPlayer == null) {
                        mPlayer = JALivePlayer(mDevice)
                    } else {
                        mPlayer!!.release()
                        mPlayer = JALivePlayer(mDevice)
                    }

                    mDevice!!.attachPlayer(mDisplayView. hashCode(), mPlayer)
                    mRenderPipe = mPlayer!!.bindSurfaceView(mDisplayView)

                    // Configure render pipe - matching LiveViewActivity. init()
                    mRenderPipe!! .setSurfaceCallback { width:  Int, height: Int ->
                        Log.d(TAG, "Surface callback: ${width}x${height}")

                        mRenderPipe!!. setScreenCount(mDevice!!.channelCount)
                        mRenderPipe!!.setBorderColor(0x00000000)

                        if (mDevice!!. channelCount > 1) {
                            mRenderPipe!!.setSplit(Parameter.SCRN_SPLIT_FOUR)
                            mRenderPipe!!.setBorderColor(-0x39e9) // Selected screen color
                            mRenderPipe!!.setOnRenderChangedListener(this@EseeiotCameraPlugin)
                        }

                        // Add callbacks - matching LiveViewActivity. init()
                        mPlayer!!.addCaptureCallback(this@EseeiotCameraPlugin)

                        // Add record callback
                        if (recordCallback != null) {
                            mPlayer!!.setRecordCallback(recordCallback)
                        }

                        mPlayer!!.setOnPlayErrorListener(this@EseeiotCameraPlugin)

                        // Notify Flutter that surface is ready
                        sendEvent("surfaceReady", mapOf(
                            "width" to width,
                            "height" to height,
                            "channelCount" to mDevice!!.channelCount
                        ))
                    }

                    // Initialize PTZ - matching LiveViewActivity.initPTZ()
                    initPTZ()

                    Log.d(TAG, "Live view initialized")
                    sendEvent("liveViewInitialized", null)

                } catch (e: Exception) {
                    Log.e(TAG, "Error in initLiveView", e)
                    sendEvent("error", mapOf("message" to e. message))
                }
            }

            result.success(mapOf("success" to true))
        } catch (e:  Exception) {
            Log.e(TAG, "Init live view failed", e)
            result. error("INIT_LIVE_VIEW_ERROR", e.message, e.stackTraceToString())
        }
    }

    /**
     * Initialize PTZ - matching LiveViewActivity.initPTZ()
     */
    private fun initPTZ() {
        Log.d(TAG, "Initializing PTZ")
        mPTZ = JAPTZController()
        mPTZ?. bindCamera(mCamera)
    }

    /**
     * Start playback - matching LiveViewActivity.startPlay()
     */
    private fun startPlay(result: Result) {
        if (mDevice == null || mPlayer == null) {
            result.error("NOT_INITIALIZED", "Live view not initialized.  Call initLiveView first.", null)
            return
        }

        try {
            Log.d(TAG, "Starting playback")

            val map:  MutableMap<Int, Boolean> = ArrayMap()
            for (i in 0 until mDevice!! .channelCount) {
                map[i] = true
            }

            mPlayer!!.property
                .put(DevicePlayer.PROP_STREAM_STATE, map)
                .commit()
            mPlayer!!. start()

            for (i in 0 until mDevice!! .channelCount) {
                if (! mDevice!!.isConnected(i) && ! mDevice!!.isConnecting(i)) {
                    Log. d(TAG, "Connecting channel $i")
                    mDevice!! .connect(i)
                }
            }

            sendEvent("playbackStarted", null)
            result.success(mapOf("success" to true))
        } catch (e:  Exception) {
            Log.e(TAG, "Start play failed", e)
            result.error("START_PLAY_ERROR", e.message, e.stackTraceToString())
        }
    }

    /**
     * Stop playback
     */
    private fun stopPlay(result: Result) {
        try {
            Log. d(TAG, "Stopping playback")
            mPlayer?. stop()
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            Log. e(TAG, "Stop play failed", e)
            result. error("STOP_PLAY_ERROR", e.message, e.stackTraceToString())
        }
    }

    // ==================== PTZ Controls ====================

    private fun ptzMoveUp(result: Result) {
        try {
            Log. d(TAG, "PTZ move up")
            mHandler.removeMessages(MSG_STOP_PTZ)
            mPTZ?.moveUp()
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            Log. e(TAG, "PTZ move up failed", e)
            result.error("PTZ_ERROR", e.message, e.stackTraceToString())
        }
    }

    private fun ptzMoveDown(result: Result) {
        try {
            Log.d(TAG, "PTZ move down")
            mHandler.removeMessages(MSG_STOP_PTZ)
            mPTZ?. moveDown()
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            Log.e(TAG, "PTZ move down failed", e)
            result.error("PTZ_ERROR", e.message, e.stackTraceToString())
        }
    }

    private fun ptzMoveLeft(result:  Result) {
        try {
            Log.d(TAG, "PTZ move left")
            mHandler.removeMessages(MSG_STOP_PTZ)
            mPTZ?.moveLeft()
            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            Log. e(TAG, "PTZ move left failed", e)
            result.error("PTZ_ERROR", e.message, e. stackTraceToString())
        }
    }

    private fun ptzMoveRight(result: Result) {
        try {
            Log. d(TAG, "PTZ move right")
            mHandler. removeMessages(MSG_STOP_PTZ)
            mPTZ?.moveRight()
            result. success(mapOf("success" to true))
        } catch (e: Exception) {
            Log.e(TAG, "PTZ move right failed", e)
            result.error("PTZ_ERROR", e. message, e.stackTraceToString())
        }
    }

    private fun ptzStop(result: Result) {
        try {
            Log.d(TAG, "PTZ stop")
            val message = Message. obtain()
            message.what = MSG_STOP_PTZ
            mHandler. sendMessageDelayed(message, 100)
            result. success(mapOf("success" to true))
        } catch (e: Exception) {
            Log.e(TAG, "PTZ stop failed", e)
            result. error("PTZ_STOP_ERROR", e.message, e. stackTraceToString())
        }
    }

    private fun capture(result: Result) {
        if (mPlayer == null) {
            result.error("NO_PLAYER", "Player not initialized", null)
            return
        }

        try {
            Log.d(TAG, "Capturing snapshot")
//            mPlayer?. capture(mChannel)
            result. success(mapOf("success" to true))
        } catch (e: Exception) {
            Log.e(TAG, "Capture failed", e)
            result.error("CAPTURE_ERROR", e. message, e.stackTraceToString())
        }
    }

    /**
     * Dispose - matching LiveViewViewModel.onCleared()
     */
    private fun dispose(result: Result) {
        try {
            Log. d(TAG, "Disposing resources")

            mRenderPipe = null
            mDevice = null
            mCamera = null

            if (mPlayer != null) {
                mPlayer!!. stop()
                mPlayer!!.release()
                mPlayer = null
            }

            mDisplayView = null
            mPTZ = null
            mTempView = null
            currentCameraId = null

            result.success(mapOf("success" to true))
        } catch (e: Exception) {
            Log. e(TAG, "Dispose failed", e)
            result. error("DISPOSE_ERROR", e.message, e.stackTraceToString())
        }
    }

    private fun sendEvent(type: String, data:  Map<String, Any?>?) {
        activity?.runOnUiThread {
            try {
                eventSink?.success(mapOf(
                    "type" to type,
                    "data" to data
                ))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send event", e)
            }
        }
    }

    // ==================== CaptureCallback Implementation ====================

    override fun onCapture(p0: Boolean, p1: Int, p2: Int) {
        Log. d(TAG, "onCapture:  success=$p0, p1=$p1, p2=$p2")
        sendEvent("captureResult", mapOf(
            "success" to p0,
            "channel" to p1,
            "type" to p2
        ))
    }

    // ==================== OnPlayErrorListener Implementation ====================

    override fun onPlayError(p0: MonitorDevice?, p1: Int, p2: Int) {
        Log.e(TAG, "onPlayError:  channel=$p1, error=$p2")
        sendEvent("playError", mapOf(
            "channel" to p1,
            "error" to p2,
            "message" to "Something went wrong.  Do you want to try again?"
        ))
    }

    // ==================== OnRenderChangedListener Implementation ====================

    override fun onSingleClicked(p0: Int, p1: Int, p2: Int, p3: Int) {
        Log. d(TAG, "onSingleClicked")
        sendEvent("singleClicked", null)
    }

    override fun onDoubleClicked(p0: Int, p1: Int, p2: Int, p3: Int) {
        Log. d(TAG, "onDoubleClicked")
        sendEvent("doubleClicked", null)
    }

    override fun onPageChanged(p0: Int, p1: Int, p2: Int, p3: Int) {
        Log. d(TAG, "onPageChanged")
    }

    override fun onScroll(p0: Int) {
        Log. d(TAG, "onScroll")
    }

    override fun onScaleZoomBack(p0: Float, p1: Float, p2: Float) {
        Log. d(TAG, "onScaleZoomBack")
    }

    override fun onScreenVisibilityChanged(p0: Int, p1: IntArray?, p2: IntArray?, p3: IntArray?) {
        Log.d(TAG, "onScreenVisibilityChanged")
    }

    override fun onSelectScreenChanged(byUser: Boolean, oldScreenIndex: Int, newScreenIndex: Int) {
        Log. d(TAG, "onSelectScreenChanged: old=$oldScreenIndex, new=$newScreenIndex")

        if ((mDevice?. channelCount ?:  0) <= newScreenIndex) {
            return // Invalid channel
        }

        mChannel = newScreenIndex
        mCamera = mDevice?. getCamera(newScreenIndex)
        mDevice?.setPlayAudioIndex(newScreenIndex)
        mPTZ = mDevice?.getCamera(newScreenIndex)?.ptz

        sendEvent("screenChanged", mapOf(
            "oldIndex" to oldScreenIndex,
            "newIndex" to newScreenIndex
        ))
    }

    override fun getScene4PanoramaDoubleTap(): Int {
        return 0
    }

    override fun onCruiseStop() {
        Log.d(TAG, "onCruiseStop")
    }

    override fun onFrameSizeChange(p0: Int) {
        Log. d(TAG, "onFrameSizeChange:  $p0")
    }

    // ==================== ActivityAware Implementation ====================

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log. d(TAG, "onAttachedToActivity")
        activity = binding.activity

        // Try to auto-initialize SDK when activity is attached
        if (!isSdkInitialized && activity != null) {
            try {
                val appContext = activity!! .applicationContext
                try {
                    val initMethod = DeviceManager::class.java.getMethod("init", Context::class. java)
                    initMethod.invoke(null, appContext)
                    Log. d(TAG, "SDK auto-initialized on activity attach")
                } catch (e:  Exception) {
                    // Try getDefault
                    val dm = DeviceManager. getDefault()
                    if (dm != null) {
                        isSdkInitialized = true
                        Log.d(TAG, "SDK available via getDefault()")
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Auto-init failed:  ${e.message}")
            }
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "onDetachedFromActivityForConfigChanges")
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "onReattachedToActivityForConfigChanges")
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        Log. d(TAG, "onDetachedFromActivity")
        activity = null
    }
}