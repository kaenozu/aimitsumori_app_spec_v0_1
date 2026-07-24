package com.kaenozu.aimitsumori.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.kaenozu.aimitsumori.data.local.entity.UnlockEntitlementEntity

@Dao
interface UnlockEntitlementDao {
    @Query("SELECT * FROM unlock_entitlements WHERE projectId = :projectId")
    suspend fun getByProject(projectId: String): List<UnlockEntitlementEntity>

    @Query("SELECT * FROM unlock_entitlements WHERE id = :id")
    suspend fun get(id: String): UnlockEntitlementEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: UnlockEntitlementEntity)

    @Query("DELETE FROM unlock_entitlements WHERE projectId = :projectId")
    suspend fun deleteByProject(projectId: String)
}
