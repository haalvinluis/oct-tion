package com.auctiongame.mobile

import android.Manifest
import android.content.Context
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Base64
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.LinkedBlockingQueue

class MainActivity : FlutterActivity() {
    private val ORIENTATION_CHANNEL = "com.auctiongame.mobile/orientation"
    private val PERMISSION_CHANNEL = "com.auctiongame.mobile/mic_permission"
    private val SOUND_CHANNEL = "com.auctiongame.mobile/sound"
    private val VOICE_CHANNEL = "com.auctiongame.mobile/voice"
    private val DEEPLINK_CHANNEL = "com.auctiongame.mobile/deeplink"
    private val MIC_PERMISSION_REQUEST_CODE = 2001

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var voiceChannel: MethodChannel? = null
    private var deeplinkChannel: MethodChannel? = null

    @Volatile
    private var isAppForeground: Boolean = true

    // Audio SFX tracking for clean shutdown
    private val activeSfxTracks = Collections.newSetFromMap(ConcurrentHashMap<AudioTrack, Boolean>())

    // Voice Capture (AudioRecord)
    @Volatile
    private var isCapturingVoice: Boolean = false
    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null

    // Voice Playback (AudioTrack streaming)
    private var voicePlaybackTrack: AudioTrack? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Force Screen Orientation Channel (Overriding OS lock on physical devices)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ORIENTATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setLandscape" -> {
                    requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                    result.success(true)
                }
                "setPortrait" -> {
                    requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 2. Native Microphone Runtime Permission Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkMicPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestMicPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                    if (granted) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECORD_AUDIO),
                            MIC_PERMISSION_REQUEST_CODE
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 3. High-Fidelity Game Sound Synthesis Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOUND_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playSound" -> {
                    val soundType = call.argument<String>("sound") ?: "click"
                    playPcmSound(soundType)
                    result.success(true)
                }
                "stopAllSound" -> {
                    stopAllSfx()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 4. Real-Time High-Fidelity Voice Chat Channel
        val vChan = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL)
        voiceChannel = vChan
        vChan.setMethodCallHandler { call, result ->
            when (call.method) {
                "startVoiceCapture" -> {
                    val ok = startVoiceRecording()
                    result.success(ok)
                }
                "stopVoiceCapture" -> {
                    stopVoiceRecording()
                    result.success(true)
                }
                "playVoiceChunk" -> {
                    val chunkBase64 = call.argument<String>("chunk")
                    if (chunkBase64 != null) {
                        playVoicePcmChunk(chunkBase64)
                    }
                    result.success(true)
                }
                "stopAllVoice" -> {
                    stopAllVoice()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 5. Deep Linking Channel (Auto-join auction rooms via shared links)
        val dlChan = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEPLINK_CHANNEL)
        deeplinkChannel = dlChan
        dlChan.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    val link = intent?.dataString
                    result.success(link)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { link ->
            deeplinkChannel?.invokeMethod("onLink", link)
        }
    }

    override fun onResume() {
        super.onResume()
        isAppForeground = true
    }

    override fun onPause() {
        super.onPause()
        isAppForeground = false
        stopAllAudio()
    }

    override fun onStop() {
        super.onStop()
        isAppForeground = false
        stopAllAudio()
    }

    override fun onDestroy() {
        super.onDestroy()
        isAppForeground = false
        stopAllAudio()
    }

    private fun stopAllAudio() {
        stopAllSfx()
        stopAllVoice()
    }

    private fun stopAllSfx() {
        try {
            val iterator = activeSfxTracks.iterator()
            while (iterator.hasNext()) {
                val track = iterator.next()
                try {
                    track.pause()
                    track.flush()
                    track.stop()
                    track.release()
                } catch (_: Exception) {}
                iterator.remove()
            }
        } catch (_: Exception) {}
    }

    private fun playPcmSound(soundType: String) {
        if (!isAppForeground) return

        Thread {
            try {
                if (!isAppForeground) return@Thread
                val sampleRate = 22050
                val (numSamples, buffer) = when (soundType) {
                    "gavel_strike" -> {
                        // Deep resonant wooden auction gavel strike
                        val count = (sampleRate * 0.22).toInt()
                        val buf = ShortArray(count)
                        for (i in 0 until count) {
                            val t = i.toDouble() / sampleRate
                            val freq = 240.0 * Math.exp(-t * 14.0) + 60.0
                            val env = Math.exp(-t * 16.0)
                            val sample = (Math.sin(2.0 * Math.PI * freq * t) * env * 32000).toInt()
                            buf[i] = sample.coerceIn(-32768, 32767).toShort()
                        }
                        Pair(count, buf)
                    }
                    "coin_bid" -> {
                        // Bright gold coin clink (metallic chime with harmonic overtone)
                        val count = (sampleRate * 0.26).toInt()
                        val buf = ShortArray(count)
                        for (i in 0 until count) {
                            val t = i.toDouble() / sampleRate
                            val env = Math.exp(-t * 11.0)
                            val s1 = Math.sin(2.0 * Math.PI * 1480.0 * t)
                            val s2 = Math.sin(2.0 * Math.PI * 1975.0 * t)
                            val sample = ((s1 * 0.6 + s2 * 0.4) * env * 28000).toInt()
                            buf[i] = sample.coerceIn(-32768, 32767).toShort()
                        }
                        Pair(count, buf)
                    }
                    "timer_tick" -> {
                        // Sharp countdown warning tick
                        val count = (sampleRate * 0.05).toInt()
                        val buf = ShortArray(count)
                        for (i in 0 until count) {
                            val t = i.toDouble() / sampleRate
                            val env = Math.exp(-t * 45.0)
                            val sample = (Math.sin(2.0 * Math.PI * 880.0 * t) * env * 30000).toInt()
                            buf[i] = sample.coerceIn(-32768, 32767).toShort()
                        }
                        Pair(count, buf)
                    }
                    "outbid_alert" -> {
                        // Descending double warning alert
                        val count = (sampleRate * 0.22).toInt()
                        val buf = ShortArray(count)
                        for (i in 0 until count) {
                            val t = i.toDouble() / sampleRate
                            val freq = if (t < 0.11) 600.0 else 440.0
                            val env = Math.exp(-(t % 0.11) * 18.0)
                            val sample = (Math.sin(2.0 * Math.PI * freq * t) * env * 28000).toInt()
                            buf[i] = sample.coerceIn(-32768, 32767).toShort()
                        }
                        Pair(count, buf)
                    }
                    "victory" -> {
                        // Ascending fanfare arpeggio: C5 -> E5 -> G5 -> C6
                        val count = (sampleRate * 0.45).toInt()
                        val buf = ShortArray(count)
                        val notes = doubleArrayOf(523.25, 659.25, 783.99, 1046.50)
                        for (i in 0 until count) {
                            val t = i.toDouble() / sampleRate
                            val noteIdx = ((t / 0.45) * 4).toInt().coerceIn(0, 3)
                            val freq = notes[noteIdx]
                            val localT = t % 0.1125
                            val env = Math.exp(-localT * 10.0)
                            val sample = (Math.sin(2.0 * Math.PI * freq * t) * env * 28000).toInt()
                            buf[i] = sample.coerceIn(-32768, 32767).toShort()
                        }
                        Pair(count, buf)
                    }
                    else -> { // Default crisp button click
                        val count = (sampleRate * 0.04).toInt()
                        val buf = ShortArray(count)
                        for (i in 0 until count) {
                            val t = i.toDouble() / sampleRate
                            val env = Math.exp(-t * 60.0)
                            val sample = (Math.sin(2.0 * Math.PI * 900.0 * t) * env * 26000).toInt()
                            buf[i] = sample.coerceIn(-32768, 32767).toShort()
                        }
                        Pair(count, buf)
                    }
                }

                if (!isAppForeground) return@Thread

                val track = AudioTrack(
                    AudioManager.STREAM_MUSIC,
                    sampleRate,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    numSamples * 2,
                    AudioTrack.MODE_STATIC
                )
                activeSfxTracks.add(track)
                track.write(buffer, 0, numSamples)
                if (isAppForeground) {
                    track.play()
                    Thread.sleep((numSamples * 1000L / sampleRate) + 30)
                }
                activeSfxTracks.remove(track)
                try {
                    track.release()
                } catch (_: Exception) {}
            } catch (_: Exception) {}
        }.start()
    }

    // ==================== Real-Time Voice Chat Engine ====================
    private val VOICE_SAMPLE_RATE = 16000
    private val VOICE_FRAME_SIZE = 640 // 40ms frame at 16kHz mono 16-bit
    private val voicePlaybackQueue = LinkedBlockingQueue<ByteArray>(50)
    private var playbackThread: Thread? = null
    @Volatile
    private var isPlaybackRunning: Boolean = false

    private fun ensurePlaybackThreadRunning() {
        if (isPlaybackRunning && playbackThread?.isAlive == true) return
        isPlaybackRunning = true
        playbackThread = Thread {
            try {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                audioManager.isSpeakerphoneOn = true

                val minBuf = AudioTrack.getMinBufferSize(
                    VOICE_SAMPLE_RATE,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT
                )
                val bufSize = Math.max(minBuf, VOICE_FRAME_SIZE * 8 * 2)

                val attributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()

                val format = AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(VOICE_SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()

                val track = AudioTrack.Builder()
                    .setAudioAttributes(attributes)
                    .setAudioFormat(format)
                    .setBufferSizeInBytes(bufSize)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()

                voicePlaybackTrack = track
                track.play()

                while (isPlaybackRunning && isAppForeground) {
                    val pcmBytes = voicePlaybackQueue.poll(200, java.util.concurrent.TimeUnit.MILLISECONDS)
                    if (pcmBytes != null && track.state == AudioTrack.STATE_INITIALIZED) {
                        track.write(pcmBytes, 0, pcmBytes.size)
                    }
                }
                track.stop()
                track.release()
            } catch (_: Exception) {}
            voicePlaybackTrack = null
            isPlaybackRunning = false
        }.apply {
            isDaemon = true
            start()
        }
    }

    private fun startVoiceRecording(): Boolean {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            return false
        }
        if (isCapturingVoice) return true

        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            audioManager.isSpeakerphoneOn = true

            val minBuf = AudioRecord.getMinBufferSize(
                VOICE_SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val bufferSize = Math.max(minBuf, VOICE_FRAME_SIZE * 4)

            val record = AudioRecord(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                VOICE_SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )

            if (record.state != AudioRecord.STATE_INITIALIZED) {
                return false
            }

            audioRecord = record
            isCapturingVoice = true
            record.startRecording()

            val thread = Thread {
                val pcmBuffer = ShortArray(VOICE_FRAME_SIZE)
                val byteBuffer = ByteArray(VOICE_FRAME_SIZE * 2)

                while (isCapturingVoice && isAppForeground) {
                    val read = record.read(pcmBuffer, 0, VOICE_FRAME_SIZE)
                    if (read > 0) {
                        var sum = 0.0
                        for (i in 0 until read) {
                            val sample = pcmBuffer[i].toInt()
                            sum += sample * sample
                            byteBuffer[i * 2] = (sample and 0xFF).toByte()
                            byteBuffer[i * 2 + 1] = ((sample shr 8) and 0xFF).toByte()
                        }
                        val rms = Math.sqrt(sum / read)
                        if (rms > 70) {
                            val base64Chunk = Base64.encodeToString(byteBuffer, 0, read * 2, Base64.NO_WRAP)
                            mainHandler.post {
                                if (isCapturingVoice && isAppForeground) {
                                    voiceChannel?.invokeMethod("onVoiceChunk", base64Chunk)
                                }
                            }
                        }
                    }
                }
            }
            captureThread = thread
            thread.isDaemon = true
            thread.start()
            return true
        } catch (e: Exception) {
            return false
        }
    }

    private fun stopVoiceRecording() {
        isCapturingVoice = false
        try {
            audioRecord?.let {
                try {
                    it.stop()
                    it.release()
                } catch (_: Exception) {}
            }
            audioRecord = null
            captureThread = null
        } catch (_: Exception) {}
    }

    private fun playVoicePcmChunk(chunkBase64: String) {
        if (!isAppForeground) return
        try {
            val pcmBytes = Base64.decode(chunkBase64, Base64.NO_WRAP)
            ensurePlaybackThreadRunning()
            voicePlaybackQueue.offer(pcmBytes)
        } catch (_: Exception) {}
    }

    private fun stopAllVoice() {
        stopVoiceRecording()
        isPlaybackRunning = false
        voicePlaybackQueue.clear()
        try {
            voicePlaybackTrack?.let {
                it.stop()
                it.release()
            }
            voicePlaybackTrack = null
        } catch (_: Exception) {}
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.mode = AudioManager.MODE_NORMAL
        } catch (_: Exception) {}
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == MIC_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }
}
