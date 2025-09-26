package com.aiscribe.copilot.ai_scribe_copilot

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodChannelName = "ai_scribe_copilot/mic"
    private val eventChannelName = "ai_scribe_copilot/interruption"
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var audioManager: AudioManager
    private var audioFocusRequest: AudioFocusRequest? = null
    private var phoneStateListener: PhoneStateListener? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        registerPhoneStateListener()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler(::handleMethodCall)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setGain" -> {
                val gain = (call.argument<Number>("gain")?.toFloat()) ?: 1.0f
                setInputGain(gain)
                result.success(null)
            }
            "requestFocus" -> {
                requestAudioFocus()
                result.success(null)
            }
            "abandonFocus" -> {
                abandonAudioFocus()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun setInputGain(gain: Float) {
        // While Android does not expose direct microphone gain APIs, we map this
        // request to the VOICE_COMMUNICATION stream to bias AGC.
        val scaled = (audioManager.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL) * gain).toInt()
        val clamped = scaled.coerceIn(1, audioManager.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL))
        audioManager.setStreamVolume(AudioManager.STREAM_VOICE_CALL, clamped, 0)
    }

    private fun requestAudioFocus() {
        val listener = AudioManager.OnAudioFocusChangeListener { focusChange ->
            when (focusChange) {
                AudioManager.AUDIOFOCUS_GAIN -> emitEvent("audioFocusGained")
                AudioManager.AUDIOFOCUS_LOSS, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> emitEvent("audioFocusLost")
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .build()
                )
                .setOnAudioFocusChangeListener(listener)
                .build()
            audioFocusRequest = request
            audioManager.requestAudioFocus(request)
        } else {
            audioManager.requestAudioFocus(
                listener,
                AudioManager.STREAM_VOICE_CALL,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE
            )
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            audioManager.abandonAudioFocus(null)
        }
    }

    private fun registerPhoneStateListener() {
        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        phoneStateListener = object : PhoneStateListener() {
            override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                when (state) {
                    TelephonyManager.CALL_STATE_OFFHOOK, TelephonyManager.CALL_STATE_RINGING -> emitEvent("phoneCallStarted")
                    TelephonyManager.CALL_STATE_IDLE -> emitEvent("phoneCallEnded")
                }
            }
        }
        telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
    }

    private fun emitEvent(type: String) {
        runOnUiThread {
            eventSink?.success(mapOf("type" to type))
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        phoneStateListener?.let { telephonyManager.listen(it, PhoneStateListener.LISTEN_NONE) }
    }
}
