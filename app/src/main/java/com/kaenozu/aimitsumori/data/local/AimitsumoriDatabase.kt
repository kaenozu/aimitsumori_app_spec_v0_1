package com.kaenozu.aimitsumori.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import com.kaenozu.aimitsumori.data.local.dao.ClarificationQuestionDao
import com.kaenozu.aimitsumori.data.local.dao.ProjectDao
import com.kaenozu.aimitsumori.data.local.dao.QuoteDao
import com.kaenozu.aimitsumori.data.local.dao.QuoteLineItemDao
import com.kaenozu.aimitsumori.data.local.dao.RequirementDao
import com.kaenozu.aimitsumori.data.local.entity.ClarificationQuestionEntity
import com.kaenozu.aimitsumori.data.local.entity.ProjectEntity
import com.kaenozu.aimitsumori.data.local.entity.QuoteEntity
import com.kaenozu.aimitsumori.data.local.entity.QuoteLineItemEntity
import com.kaenozu.aimitsumori.data.local.entity.RequirementEntity

@Database(
    entities = [
        ProjectEntity::class,
        QuoteEntity::class,
        QuoteLineItemEntity::class,
        ClarificationQuestionEntity::class,
        RequirementEntity::class,
    ],
    version = 1,
    exportSchema = true,
)
abstract class AimitsumoriDatabase : RoomDatabase() {
    abstract fun projectDao(): ProjectDao
    abstract fun quoteDao(): QuoteDao
    abstract fun quoteLineItemDao(): QuoteLineItemDao
    abstract fun clarificationQuestionDao(): ClarificationQuestionDao
    abstract fun requirementDao(): RequirementDao
}
