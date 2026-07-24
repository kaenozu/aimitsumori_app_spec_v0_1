package com.kaenozu.aimitsumori.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.kaenozu.aimitsumori.data.local.entity.QuoteRevisionEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface QuoteRevisionDao {
    @Query("SELECT * FROM quote_revisions WHERE vendorId = :vendorId ORDER BY revisionNumber DESC")
    fun observeByVendor(vendorId: String): Flow<List<QuoteRevisionEntity>>

    @Query("SELECT * FROM quote_revisions WHERE id = :id")
    suspend fun get(id: String): QuoteRevisionEntity?

    @Query("SELECT * FROM quote_revisions WHERE vendorId = :vendorId ORDER BY revisionNumber DESC LIMIT 1")
    suspend fun getLatest(vendorId: String): QuoteRevisionEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: QuoteRevisionEntity)

    @Update
    suspend fun update(entity: QuoteRevisionEntity)

    @Delete
    suspend fun delete(entity: QuoteRevisionEntity)
}
