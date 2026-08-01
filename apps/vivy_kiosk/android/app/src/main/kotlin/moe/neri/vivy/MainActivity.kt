package moe.neri.vivy

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), SensorEventListener {
    private var lightSink: EventChannel.EventSink? = null
    private var motionSink: EventChannel.EventSink? = null
    private lateinit var sensorManager: SensorManager
    private var lightSensor: Sensor? = null
    private var accelerometer: Sensor? = null
    private var gyroscope: Sensor? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        lightSensor = sensorManager.getDefaultSensor(Sensor.TYPE_LIGHT)
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.vivy/kiosk")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPinnedMode" -> {
                        try {
                            startLockTask()
                            result.success(null)
                        } catch (error: IllegalStateException) {
                            result.error("PINNING_UNAVAILABLE", error.message, null)
                        }
                    }
                    "exitPinnedMode" -> {
                        stopLockTask()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.vivy/ambient_light")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    lightSink = events
                    if (lightSensor == null) {
                        events?.error("NO_LIGHT_SENSOR", "This device has no ambient light sensor", null)
                    }
                    updateSensorRegistration()
                }

                override fun onCancel(arguments: Any?) {
                    lightSink = null
                    updateSensorRegistration()
                }
            })
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.vivy/device_motion")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    motionSink = events
                    if (accelerometer == null && gyroscope == null) {
                        events?.error("NO_MOTION_SENSOR", "This device has no motion sensors", null)
                    }
                    updateSensorRegistration()
                }

                override fun onCancel(arguments: Any?) {
                    motionSink = null
                    updateSensorRegistration()
                }
            })
    }

    private fun updateSensorRegistration() {
        sensorManager.unregisterListener(this)
        if (lightSink != null) {
            lightSensor?.let {
                sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
            }
        }
        if (motionSink != null) {
            accelerometer?.let {
                sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            }
            gyroscope?.let {
                sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            }
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_LIGHT -> lightSink?.success(event.values.firstOrNull()?.toDouble())
            Sensor.TYPE_ACCELEROMETER -> emitMotion("accelerometer", event)
            Sensor.TYPE_GYROSCOPE -> emitMotion("gyroscope", event)
        }
    }

    private fun emitMotion(type: String, event: SensorEvent) {
        val rawX = event.values.getOrElse(0) { 0f }
        val rawY = event.values.getOrElse(1) { 0f }
        val rawZ = event.values.getOrElse(2) { 0f }
        val (screenX, screenY) = when (windowManager.defaultDisplay.rotation) {
            Surface.ROTATION_90 -> rawY to -rawX
            Surface.ROTATION_180 -> -rawX to -rawY
            Surface.ROTATION_270 -> -rawY to rawX
            else -> rawX to rawY
        }
        motionSink?.success(
            mapOf(
                "type" to type,
                "x" to screenX.toDouble(),
                "y" to screenY.toDouble(),
                "z" to rawZ.toDouble(),
            ),
        )
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
