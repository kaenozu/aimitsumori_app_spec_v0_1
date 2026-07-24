package com.kaenozu.aimitsumori.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.kaenozu.aimitsumori.data.local.entity.DocumentPageEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface DocumentPageDao {
    @Query("SELECT * FROM document_pages WHERE quoteRevisionId = :revisionId ORDER BY pageNumber")
    fun observeByRevision(revisionId: String): Flow<List<DocumentPageEntity>>

    @Query("SELECT * FROM document_pages WHERE id = :id")
    suspend fun get(id: String): DocumentPageEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: DocumentPageEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entities: List<DocumentPageEntity>)

    @Update
    suspend fun update(entity: DocumentPageEntity)

    @Delete
    suspend fun delete(entity: DocumentPageEntity)

    @Query("DELETE FROM document_pages WHERE quoteRevisionId = :revisionId")
    suspend fun deleteByRevision(revisionId: String)
}
