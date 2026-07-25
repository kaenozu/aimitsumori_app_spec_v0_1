package com.kaenozu.aimitsumori.domain.ocr

import android.graphics.Bitmap
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

data class OcrResult(
    val rawText: String,
    val blocks: List<OcrTextBlock>,
)

data class OcrTextBlock(
    val text: String,
    val boundingBox: Rect,
    val lines: List<OcrTextLine>,
)

data class OcrTextLine(
    val text: String,
    val boundingBox: Rect,
)

data class Rect(
    val left: Int, val top: Int, val right: Int, val bottom: Int,
)

class OcrService {
    private val recognizer = TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build())

    suspend fun recognize(bitmap: Bitmap): OcrResult {
        val image = InputImage.fromBitmap(bitmap, 0)
        val visionText = recognizer.process(image).awaitResult()

        val blocks = visionText.textBlocks.mapNotNull { block ->
            val box = block.boundingBox ?: return@mapNotNull null
            OcrTextBlock(
                text = block.text,
                boundingBox = Rect(box.left, box.top, box.right, box.bottom),
                lines = block.lines.mapNotNull lineLoop@{ line ->
                    val lineBox = line.boundingBox ?: return@lineLoop null
                    OcrTextLine(
                        text = line.text,
                        boundingBox = Rect(lineBox.left, lineBox.top, lineBox.right, lineBox.bottom),
                    )
                },
            )
        }

        return OcrResult(
            rawText = visionText.text,
            blocks = blocks,
        )
    }

    fun close() {
        recognizer.close()
    }
}

private suspend fun <T> Task<T>.awaitResult(): T = suspendCancellableCoroutine { continuation ->
    addOnSuccessListener { result ->
        if (continuation.isActive) continuation.resume(result)
    }
    addOnFailureListener { error ->
        if (continuation.isActive) continuation.resumeWithException(error)
    }
    addOnCanceledListener {
        continuation.cancel()
    }
}
