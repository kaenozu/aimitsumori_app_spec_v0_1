package com.kaenozu.aimitsumori.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.kaenozu.aimitsumori.data.local.entity.RequirementEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface RequirementDao {
    @Query("SELECT * FROM requirements WHERE projectId = :projectId")
    fun observeByProject(projectId: String): Flow<List<RequirementEntity>>

    @Query("SELECT * FROM requirements WHERE id = :id")
    suspend fun get(id: String): RequirementEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: RequirementEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entities: List<RequirementEntity>)

    @Update
    suspend fun update(entity: RequirementEntity)

    @Delete
    suspend fun delete(entity: RequirementEntity)

    @Query("DELETE FROM requirements WHERE projectId = :projectId")
    suspend fun deleteByProject(projectId: String)
}
