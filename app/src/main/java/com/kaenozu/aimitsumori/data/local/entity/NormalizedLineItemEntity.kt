package com.kaenozu.aimitsumori.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "normalized_line_items",
    foreignKeys = [
        ForeignKey(
            entity = RawLineItemEntity::class,
            parentColumns = ["id"],
            childColumns = ["rawLineItemId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("rawLineItemId")]
)
data class NormalizedLineItemEntity(
    @PrimaryKey val id: String,
    val rawLineItemId: String,
    val categoryCode: String? = null,
    val inclusionStatus: String = "unknown",
    val normalizationConfidence: Float? = null,
    val userConfirmed: Boolean = false,
    val specification: String? = null,
    val comparisonGroupId: String? = null
)
