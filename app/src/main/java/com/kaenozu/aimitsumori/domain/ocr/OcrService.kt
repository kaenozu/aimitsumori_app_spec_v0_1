package com.kaenozu.aimitsumori.domain.ocr

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions

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
        val task = recognizer.process(image)
        val visionText = kotlinx.coroutines.tasks.await(task)

        val blocks = visionText.textBlocks.map { block ->
            val box = block.boundingBox ?: return@map null
            OcrTextBlock(
                text = block.text,
                boundingBox = Rect(box.left, box.top, box.right, box.bottom),
                lines = block.lines.map { line ->
                    val lineBox = line.boundingBox ?: return@map null
                    OcrTextLine(
                        text = line.text,
                        boundingBox = Rect(lineBox.left, lineBox.top, lineBox.right, lineBox.bottom),
                    )
                },
            )
        }.filterNotNull()

        return OcrResult(
            rawText = visionText.text,
            blocks = blocks,
        )
    }

    fun close() {
        recognizer.close()
    }
}
