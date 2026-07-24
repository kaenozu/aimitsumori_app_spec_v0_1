package com.kaenozu.aimitsumori.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "requirements",
    foreignKeys = [ForeignKey(
        entity = ProjectEntity::class,
        parentColumns = ["id"],
        childColumns = ["projectId"],
        onDelete = ForeignKey.CASCADE
    )],
    indices = [Index("projectId")]
)
data class RequirementEntity(
    @PrimaryKey val id: String,
    val projectId: String,
    val categoryCode: String,
    val requirementType: String,
    val specification: String? = null,
    val quantity: String? = null,
    val unit: String? = null,
    val note: String? = null
)
