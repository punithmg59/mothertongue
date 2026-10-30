package com.example.mothertongue

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.mothertongue/video"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "extractFrames" -> {
                    val videoPath = call.argument<String>("videoPath")
                    val outputDir = call.argument<String>("outputDir")
                    val intervalSeconds = call.argument<Double>("intervalSeconds") ?: 1.0
                    
                    if (videoPath != null && outputDir != null) {
                        VideoFrameExtractor.extractFrames(videoPath, outputDir, intervalSeconds, result)
                    } else {
                        result.error("INVALID_ARGS", "Missing required arguments", null)
                    }
                }
                "getVideoDuration" -> {
                    val videoPath = call.argument<String>("videoPath")
                    if (videoPath != null) {
                        VideoFrameExtractor.getVideoDuration(videoPath, result)
                    } else {
                        result.error("INVALID_ARGS", "Missing video path", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
