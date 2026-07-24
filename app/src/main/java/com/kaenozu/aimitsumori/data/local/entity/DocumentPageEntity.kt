package com.kaenozu.aimitsumori.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "document_pages",
    foreignKeys = [ForeignKey(
        entity = QuoteRevisionEntity::class,
        parentColumns = ["id"],
        childColumns = ["quoteRevisionId"],
        onDelete = ForeignKey.CASCADE
    )],
    indices = [Index("quoteRevisionId")]
)
data class DocumentPageEntity(
    @PrimaryKey val id: String,
    val quoteRevisionId: String,
    val pageNumber: Int,
    val localFilePath: String,
    val pageType: String? = null,
    val rotation: Int = 0,
    val width: Int? = null,
    val height: Int? = null,
    val ocrStatus: String = "pending"
)
