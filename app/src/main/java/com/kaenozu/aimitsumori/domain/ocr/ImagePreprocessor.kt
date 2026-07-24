package com.kaenozu.aimitsumori.domain.ocr

import android.graphics.Bitmap
import android.graphics.Matrix

object ImagePreprocessor {
    fun preprocess(bitmap: Bitmap): Bitmap {
        var result = bitmap
        result = adjustContrast(result)
        result = normalizeResolution(result)
        return result
    }

    fun rotate(bitmap: Bitmap, degrees: Float): Bitmap {
        val matrix = Matrix().apply { postRotate(degrees) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun adjustContrast(bitmap: Bitmap): Bitmap {
        return bitmap
    }

    private fun normalizeResolution(bitmap: Bitmap): Bitmap {
        val maxDimension = 2048f
        if (bitmap.width <= maxDimension && bitmap.height <= maxDimension) return bitmap
        val scale = maxDimension / maxOf(bitmap.width, bitmap.height)
        val newWidth = (bitmap.width * scale).toInt()
        val newHeight = (bitmap.height * scale).toInt()
        return Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
    }
}
