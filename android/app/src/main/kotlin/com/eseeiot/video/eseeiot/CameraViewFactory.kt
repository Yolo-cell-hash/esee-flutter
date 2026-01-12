package com.eseeiot.video.eseeiot

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import com.eseeiot.basemodule.device.base.MonitorDevice
import com.eseeiot.basemodule.device.common.Parameter
import com.eseeiot.basemodule.player.DevicePlayer
import com.eseeiot.basemodule.player.RenderPipe
import com.eseeiot.core.view.JAGLSurfaceView
import com.eseeiot.device.DeviceManager
import com.eseeiot.live.player.JALivePlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class CameraViewFactory(
    private val messenger: BinaryMessenger,
    private val plugin: EseeiotCameraPlugin?  = null
) : PlatformViewFactory(StandardMessageCodec. INSTANCE) {

    companion object {
        private const val TAG = "CameraViewFactory"
    }

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as?  Map<String, Any? > ?: emptyMap()
        return CameraPlatformView(context, viewId, messenger, params, plugin)
    }
}

class CameraPlatformView(
    private val context: Context,
    private val viewId: Int,
    messenger: BinaryMessenger,
    params: Map<String, Any?>,
    private val plugin: EseeiotCameraPlugin?
) : PlatformView {

    companion object {
        private const val TAG = "CameraPlatformView"
    }

    private val container:  FrameLayout = FrameLayout(context)
    private var displayView: JAGLSurfaceView? = null
    private var player: JALivePlayer? = null
    private var device: MonitorDevice? = null
    private var renderPipe: RenderPipe?  = null
    private var isUsingPluginView = false

    private val methodChannel = MethodChannel(messenger, "eseeiot_camera_view_$viewId")

    init {
        val deviceId = params["deviceId"] as?  String

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> initialize(deviceId, result)
                "startPlayback" -> startPlayback(result)
                "stopPlayback" -> stopPlayback(result)
                else -> result.notImplemented()
            }
        }

        // Try to use the plugin's display view if available
        if (plugin != null && plugin.getDisplayView() != null) {
            Log.d(TAG, "Using plugin's display view")
            usePluginDisplayView()
        } else if (! deviceId.isNullOrEmpty()) {
            Log.d(TAG, "Creating new display view for device: $deviceId")
            initialize(deviceId, null)
        }
    }

    private fun usePluginDisplayView() {
        try {
            val pluginDisplayView = plugin?.getDisplayView()
            if (pluginDisplayView != null) {
                isUsingPluginView = true

                // Remove from parent if already attached
                (pluginDisplayView. parent as? FrameLayout)?.removeView(pluginDisplayView)

                container.removeAllViews()
                container. addView(pluginDisplayView, FrameLayout.LayoutParams(
                    FrameLayout. LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                ))

                Log.d(TAG, "Plugin display view attached successfully")

                // Notify Flutter that view is ready
                methodChannel.invokeMethod("onViewReady", mapOf(
                    "width" to pluginDisplayView.width,
                    "height" to pluginDisplayView. height,
                    "channelCount" to (plugin?.getDevice()?.channelCount ?: 1)
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error using plugin display view", e)
        }
    }

    private fun initialize(deviceId: String?, result: MethodChannel.Result?) {
        if (deviceId. isNullOrEmpty()) {
            result?.error("NO_DEVICE_ID", "Device ID is required", null)
            return
        }

        try {
            device = DeviceManager.getDefault().getDevice(deviceId)
            if (device == null) {
                result?.error("DEVICE_NOT_FOUND", "Device not found", null)
                return
            }

            // Create display view
            displayView = JAGLSurfaceView(context)
            displayView?.setViewAspect(16f / 9f)

            container.removeAllViews()
            container. addView(displayView, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout. LayoutParams.MATCH_PARENT
            ))

            // Create player
            player = JALivePlayer(device)
            device!! .attachPlayer(displayView. hashCode(), player)
            renderPipe = player!! .bindSurfaceView(displayView)

            renderPipe?.setSurfaceCallback { width, height ->
                renderPipe?.setScreenCount(device!! .channelCount)
                renderPipe?.setBorderColor(0x00000000)

                if (device!!.channelCount > 1) {
                    renderPipe?.setSplit(Parameter. SCRN_SPLIT_FOUR)
                }

                // Notify Flutter that view is ready
                methodChannel.invokeMethod("onViewReady", mapOf(
                    "width" to width,
                    "height" to height,
                    "channelCount" to device!! .channelCount
                ))
            }

            result?.success(mapOf("success" to true))
        } catch (e: Exception) {
            Log.e(TAG, "Initialize error", e)
            result?.error("INIT_ERROR", e.message, null)
        }
    }

    private fun startPlayback(result: MethodChannel.Result?) {
        // If using plugin view, playback is controlled by plugin
        if (isUsingPluginView) {
            result?.success(mapOf("success" to true, "message" to "Using plugin playback"))
            return
        }

        if (device == null || player == null) {
            result?.error("NOT_INITIALIZED", "Camera not initialized", null)
            return
        }

        try {
            val map = mutableMapOf<Int, Boolean>()
            for (i in 0 until device!!. channelCount) {
                map[i] = true
            }

            player?. property
                ?.put(DevicePlayer.PROP_STREAM_STATE, map)
                ?.commit()
            player?.start()

            for (i in 0 until device!!.channelCount) {
                if (! device!!.isConnected(i) && !device!!.isConnecting(i)) {
                    device!! .connect(i)
                }
            }

            result?.success(mapOf("success" to true))
        } catch (e: Exception) {
            Log.e(TAG, "Playback error", e)
            result?.error("PLAYBACK_ERROR", e.message, null)
        }
    }

    private fun stopPlayback(result: MethodChannel.Result?) {
        // If using plugin view, don't stop - let plugin control it
        if (isUsingPluginView) {
            result?.success(mapOf("success" to true))
            return
        }

        try {
            player?.stop()
            result?.success(mapOf("success" to true))
        } catch (e: Exception) {
            Log.e(TAG, "Stop error", e)
            result?.error("STOP_ERROR", e. message, null)
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        // If using plugin view, don't dispose - let plugin handle it
        if (isUsingPluginView) {
            // Just remove from container, don't release
            container.removeAllViews()
            return
        }

        player?.stop()
        player?.release()
        player = null
        device = null
        displayView = null
        renderPipe = null
    }
}