package com.example.teen_patti

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var soundPool: SoundPool? = null
    private val loadedSounds = mutableMapOf<String, Int>()
    private var loopPlayer: MediaPlayer? = null
    private var currentLoopVolume: Float = 0.12f

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        soundPool = SoundPool.Builder()
            .setMaxStreams(6)
            .setAudioAttributes(attrs)
            .build()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ace_society/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playSfx" -> {
                        val assetPath = call.argument<String>("assetPath")
                        val volume = (call.argument<Double>("volume") ?: 0.6).toFloat().coerceIn(0f, 1f)
                        if (assetPath != null) {
                            playSfx(assetPath, volume)
                        }
                        result.success(null)
                    }
                    "startLoop" -> {
                        val assetPath = call.argument<String>("assetPath")
                        val volume = (call.argument<Double>("volume") ?: 0.12).toFloat().coerceIn(0f, 1f)
                        currentLoopVolume = volume
                        if (assetPath != null) {
                            startLoop(assetPath, volume)
                        }
                        result.success(null)
                    }
                    "stopLoop" -> {
                        stopLoop()
                        result.success(null)
                    }
                    "setLoopVolume" -> {
                        val volume = (call.argument<Double>("volume") ?: 0.12).toFloat().coerceIn(0f, 1f)
                        currentLoopVolume = volume
                        loopPlayer?.setVolume(volume, volume)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun playSfx(assetPath: String, volume: Float) {
        val pool = soundPool ?: return
        val cached = loadedSounds[assetPath]
        if (cached != null) {
            pool.play(cached, volume, volume, 1, 0, 1f)
            return
        }
        try {
            val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
            val afd = assets.openFd(key)
            val soundId = pool.load(afd, 1)
            afd.close()
            loadedSounds[assetPath] = soundId
            pool.setOnLoadCompleteListener { sp, id, status ->
                if (status == 0 && id == soundId) {
                    sp.play(id, volume, volume, 1, 0, 1f)
                }
            }
        } catch (_: Exception) {
        }
    }

    private fun startLoop(assetPath: String, volume: Float) {
        stopLoop()
        try {
            val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
            val afd = assets.openFd(key)
            val player = MediaPlayer().apply {
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                isLooping = true
                setVolume(volume, volume)
                prepare()
                start()
            }
            afd.close()
            loopPlayer = player
        } catch (_: Exception) {
        }
    }

    private fun stopLoop() {
        try {
            loopPlayer?.stop()
            loopPlayer?.release()
        } catch (_: Exception) {
        }
        loopPlayer = null
    }

    override fun onDestroy() {
        stopLoop()
        soundPool?.release()
        soundPool = null
        super.onDestroy()
    }
}
