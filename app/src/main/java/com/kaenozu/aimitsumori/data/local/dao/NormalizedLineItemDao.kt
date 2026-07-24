package com.kaenozu.aimitsumori.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.kaenozu.aimitsumori.data.local.entity.NormalizedLineItemEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface NormalizedLineItemDao {
    @Query("""
        SELECT n.* FROM normalized_line_items n
        INNER JOIN raw_line_items r ON r.id = n.rawLineItemId
        WHERE r.quoteRevisionId = :revisionId
    """)
    fun observeByRevision(revisionId: String): Flow<List<NormalizedLineItemEntity>>

    @Query("SELECT * FROM normalized_line_items WHERE id = :id")
    suspend fun get(id: String): NormalizedLineItemEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entities: List<NormalizedLineItemEntity>)

    @Update
    suspend fun update(entity: NormalizedLineItemEntity)

    @Delete
    suspend fun delete(entity: NormalizedLineItemEntity)

    @Query("DELETE FROM normalized_line_items WHERE rawLineItemId IN (SELECT id FROM raw_line_items WHERE quoteRevisionId = :revisionId)")
    suspend fun deleteByRevision(revisionId: String)

    @Query("SELECT * FROM normalized_line_items WHERE comparisonGroupId = :groupId")
    suspend fun getByComparisonGroup(groupId: String): List<NormalizedLineItemEntity>
}
