package com.kaenozu.aimitsumori.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.kaenozu.aimitsumori.data.local.entity.VendorEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface VendorDao {
    @Query("SELECT * FROM vendors WHERE projectId = :projectId ORDER BY createdAt")
    fun observeByProject(projectId: String): Flow<List<VendorEntity>>

    @Query("SELECT * FROM vendors WHERE id = :id")
    suspend fun get(id: String): VendorEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: VendorEntity)

    @Update
    suspend fun update(entity: VendorEntity)

    @Delete
    suspend fun delete(entity: VendorEntity)
}
