package com.kaenozu.aimitsumori.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.kaenozu.aimitsumori.data.local.entity.RawLineItemEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface RawLineItemDao {
    @Query("SELECT * FROM raw_line_items WHERE quoteRevisionId = :revisionId ORDER BY pageNumber")
    fun observeByRevision(revisionId: String): Flow<List<RawLineItemEntity>>

    @Query("SELECT * FROM raw_line_items WHERE id = :id")
    suspend fun get(id: String): RawLineItemEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entities: List<RawLineItemEntity>)

    @Update
    suspend fun update(entity: RawLineItemEntity)

    @Delete
    suspend fun delete(entity: RawLineItemEntity)

    @Query("DELETE FROM raw_line_items WHERE quoteRevisionId = :revisionId")
    suspend fun deleteByRevision(revisionId: String)
}
