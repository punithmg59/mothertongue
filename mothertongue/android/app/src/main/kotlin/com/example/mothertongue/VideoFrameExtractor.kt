package com.example.mothertongue

import android.media.MediaMetadataRetriever
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.File

class VideoFrameExtractor {
    companion object {
        private const val TAG = "VideoFrameExtractor"
        
        fun extractFrames(
            videoPath: String,
            outputDir: String,
            intervalSeconds: Double,
            result: MethodChannel.Result
        ) {
            try {
                val retriever = MediaMetadataRetriever()
                retriever.setDataSource(videoPath)
                
                val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                val durationMs = durationStr?.toLongOrNull() ?: 0L
                val durationSec = durationMs / 1000.0
                
                val outputDirFile = File(outputDir)
                if (!outputDirFile.exists()) {
                    outputDirFile.mkdirs()
                }
                
                val frames = mutableListOf<Map<String, Any>>()
                var frameIndex = 0
                var currentTimeMs = 0L
                val intervalMs = (intervalSeconds * 1000).toLong()
                
                while (currentTimeMs < durationMs) {
                    val frame = retriever.getFrameAtTime(currentTimeMs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    
                    if (frame != null) {
                        val frameFile = File(outputDirFile, "frame_$frameIndex.jpg")
                        frameFile.outputStream().use { out ->
                            frame.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, out)
                        }
                        
                        frames.add(mapOf(
                            "frameIndex" to frameIndex,
                            "timestamp" to (currentTimeMs / 1000.0),
                            "path" to frameFile.absolutePath,
                            "width" to frame.width,
                            "height" to frame.height
                        ))
                        
                        frame.recycle()
                    }
                    
                    currentTimeMs += intervalMs
                    frameIndex++
                }
                
                retriever.release()
                
                result.success(mapOf(
                    "success" to true,
                    "duration" to durationSec,
                    "frameCount" to frames.size,
                    "frames" to frames
                ))
                
            } catch (e: Exception) {
                Log.e(TAG, "Error extracting frames", e)
                result.error("EXTRACT_ERROR", e.message, null)
            }
        }
        
        fun getVideoDuration(videoPath: String, result: MethodChannel.Result) {
            try {
                val retriever = MediaMetadataRetriever()
                retriever.setDataSource(videoPath)
                
                val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                val durationMs = durationStr?.toLongOrNull() ?: 0L
                val durationSec = durationMs / 1000.0
                
                retriever.release()
                
                result.success(durationSec)
                
            } catch (e: Exception) {
                Log.e(TAG, "Error getting video duration", e)
                result.error("DURATION_ERROR", e.message, null)
            }
        }
    }
}
