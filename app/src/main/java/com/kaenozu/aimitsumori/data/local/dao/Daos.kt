package com.kaenozu.aimitsumori.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import com.kaenozu.aimitsumori.data.local.entity.ClarificationQuestionEntity
import com.kaenozu.aimitsumori.data.local.entity.ProjectEntity
import com.kaenozu.aimitsumori.data.local.entity.ProjectWithQuotes
import com.kaenozu.aimitsumori.data.local.entity.QuoteEntity
import com.kaenozu.aimitsumori.data.local.entity.QuoteLineItemEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface ProjectDao {
    @Transaction
    @Query("SELECT * FROM projects ORDER BY updatedAtEpochMillis DESC")
    fun observeAll(): Flow<List<ProjectWithQuotes>>

    @Transaction
    @Query("SELECT * FROM projects WHERE id = :projectId LIMIT 1")
    fun observeById(projectId: String): Flow<ProjectWithQuotes?>

    @Query("SELECT COUNT(*) FROM projects")
    suspend fun count(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(project: ProjectEntity)
}

@Dao
interface QuoteDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(quotes: List<QuoteEntity>)

    @Query("DELETE FROM quotes WHERE projectId = :projectId")
    suspend fun deleteByProjectId(projectId: String)
}

@Dao
interface QuoteLineItemDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(items: List<QuoteLineItemEntity>)
}

@Dao
interface ClarificationQuestionDao {
    @Query(
        "SELECT * FROM clarification_questions " +
            "WHERE projectId = :projectId ORDER BY createdAtEpochMillis, id",
    )
    fun observeByProjectId(projectId: String): Flow<List<ClarificationQuestionEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(questions: List<ClarificationQuestionEntity>)

    @Query("DELETE FROM clarification_questions WHERE projectId = :projectId")
    suspend fun deleteByProjectId(projectId: String)
}
