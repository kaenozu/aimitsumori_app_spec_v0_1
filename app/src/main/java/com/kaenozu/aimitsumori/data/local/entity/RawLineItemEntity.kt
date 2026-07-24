package com.kaenozu.aimitsumori.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "raw_line_items",
    foreignKeys = [ForeignKey(
        entity = QuoteRevisionEntity::class,
        parentColumns = ["id"],
        childColumns = ["quoteRevisionId"],
        onDelete = ForeignKey.CASCADE
    )],
    indices = [Index("quoteRevisionId")]
)
data class RawLineItemEntity(
    @PrimaryKey val id: String,
    val quoteRevisionId: String,
    val originalText: String,
    val description: String? = null,
    val quantity: String? = null,
    val unit: String? = null,
    val unitPrice: Long? = null,
    val amount: Long? = null,
    val pageNumber: Int? = null,
    val boundingBox: String? = null,
    val confidence: Float? = null,
    val isLumpSum: Boolean = false
)
