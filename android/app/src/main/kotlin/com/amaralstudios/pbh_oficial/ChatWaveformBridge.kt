package com.amaralstudios.pbh_oficial

import android.app.Activity
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.sqrt

class ChatWaveformBridge(private val activity: Activity) {
    private val executor = Executors.newSingleThreadExecutor()
    private val busy = AtomicBoolean(false)
    @Volatile private var closed = false
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "extract") { result.notImplemented(); return }
        val bytes = call.argument<ByteArray>("bytes")
        val duration = call.argument<Int>("durationMs") ?: 0
        if (closed || bytes == null || bytes.isEmpty() || bytes.size > 1048576 || duration !in 1..120000 || !busy.compareAndSet(false, true)) {
            result.success(emptyList<Double>()); return
        }
        executor.execute {
            val values = try { decode(bytes, duration) } catch (_: Exception) { emptyList<Double>() }
            busy.set(false)
            activity.runOnUiThread { result.success(values) }
        }
    }
    private fun decode(bytes: ByteArray, duration: Int): List<Double> {
        val file = File.createTempFile("pbh-wave-", ".audio", activity.cacheDir)
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            file.writeBytes(bytes)
            extractor.setDataSource(file.absolutePath)
            val track = (0 until extractor.trackCount).firstOrNull { extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true } ?: return emptyList()
            val format = extractor.getTrackFormat(track)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return emptyList()
            extractor.selectTrack(track)
            val decoder = MediaCodec.createDecoderByType(mime)
            codec = decoder
            decoder.configure(format, null, null, 0)
            decoder.start()
            var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var encoding = AudioFormat.ENCODING_PCM_16BIT
            var inputDone = false
            val energy = DoubleArray(64)
            val counts = LongArray(64)
            val info = MediaCodec.BufferInfo()
            val deadline = android.os.SystemClock.elapsedRealtime() + 8000
            while (!closed && android.os.SystemClock.elapsedRealtime() < deadline) {
                if (!inputDone) {
                    val index = decoder.dequeueInputBuffer(1000)
                    if (index >= 0) {
                        val buffer = decoder.getInputBuffer(index) ?: break
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0) { decoder.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM); inputDone = true }
                        else { decoder.queueInputBuffer(index, 0, size, extractor.sampleTime, 0); extractor.advance() }
                    }
                }
                val index = decoder.dequeueOutputBuffer(info, 1000)
                if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val output = decoder.outputFormat
                    rate = output.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    channels = output.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    encoding = if (output.containsKey(MediaFormat.KEY_PCM_ENCODING)) output.getInteger(MediaFormat.KEY_PCM_ENCODING) else AudioFormat.ENCODING_PCM_16BIT
                } else if (index >= 0) {
                    try {
                        require(rate in 8000..192000 && channels in 1..8)
                        require(encoding == AudioFormat.ENCODING_PCM_16BIT || encoding == AudioFormat.ENCODING_PCM_FLOAT)
                        val buffer = decoder.getOutputBuffer(index)
                        if (buffer != null && info.size > 0) {
                            buffer.position(info.offset); buffer.limit(info.offset + info.size); buffer.order(ByteOrder.LITTLE_ENDIAN)
                            var sample = 0L
                            val width = if (encoding == AudioFormat.ENCODING_PCM_FLOAT) 4 else 2
                            while (buffer.remaining() >= width) {
                                val value = if (width == 4) buffer.float.toDouble() else buffer.short.toDouble() / 32768.0
                                val micros = info.presentationTimeUs + (sample / channels) * 1000000L / rate
                                val bin = ((micros * 64) / (duration * 1000L)).toInt().coerceIn(0, 63)
                                if (value.isFinite()) { energy[bin] += value * value; counts[bin]++ }
                                sample++
                            }
                        }
                    } finally { decoder.releaseOutputBuffer(index, false) }
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        val rms = energy.indices.map { if (counts[it] > 0) sqrt(energy[it] / counts[it]) else 0.0 }
                        val peak = rms.fold(0.0) { a, b -> max(a, b) }
                        return rms.map { if (peak > .0001) sqrt(it / peak).coerceIn(0.0, 1.0) else 0.0 }
                    }
                }
            }
            return emptyList()
        } finally {
            try { codec?.stop() } catch (_: Exception) { }
            try { codec?.release() } catch (_: Exception) { }
            try { extractor.release() } catch (_: Exception) { }
            file.delete()
        }
    }
    fun close() { closed = true; executor.shutdown() }
}
