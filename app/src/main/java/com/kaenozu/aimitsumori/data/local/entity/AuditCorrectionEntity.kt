package com.kaenozu.aimitsumori.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "audit_corrections")
data class AuditCorrectionEntity(
    @PrimaryKey val id: String,
    val entityType: String,
    val entityId: String,
    val fieldName: String,
    val beforeValue: String? = null,
    val afterValue: String? = null,
    val correctedAt: Long
)
