package com.kaenozu.aimitsumori.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "ocr_blocks",
    foreignKeys = [ForeignKey(
        entity = DocumentPageEntity::class,
        parentColumns = ["id"],
        childColumns = ["documentPageId"],
        onDelete = ForeignKey.CASCADE
    )],
    indices = [Index("documentPageId")]
)
data class OcrBlockEntity(
    @PrimaryKey val id: String,
    val documentPageId: String,
    val text: String,
    val boundingBox: String,
    val confidence: Float,
    val blockOrder: Int
)
