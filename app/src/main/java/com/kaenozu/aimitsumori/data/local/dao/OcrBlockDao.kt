package com.kaenozu.aimitsumori.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.kaenozu.aimitsumori.data.local.entity.OcrBlockEntity

@Dao
interface OcrBlockDao {
    @Query("SELECT * FROM ocr_blocks WHERE documentPageId = :pageId ORDER BY blockOrder")
    suspend fun getByPage(pageId: String): List<OcrBlockEntity>

    @Query("SELECT * FROM ocr_blocks WHERE id = :id")
    suspend fun get(id: String): OcrBlockEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entities: List<OcrBlockEntity>)

    @Update
    suspend fun update(entity: OcrBlockEntity)

    @Delete
    suspend fun delete(entity: OcrBlockEntity)

    @Query("DELETE FROM ocr_blocks WHERE documentPageId = :pageId")
    suspend fun deleteByPage(pageId: String)
}
