package com.kaenozu.aimitsumori.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.kaenozu.aimitsumori.data.local.entity.AuditCorrectionEntity

@Dao
interface AuditCorrectionDao {
    @Query("SELECT * FROM audit_corrections WHERE entityType = :entityType AND entityId = :entityId")
    suspend fun getByEntity(entityType: String, entityId: String): List<AuditCorrectionEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: AuditCorrectionEntity)
}
