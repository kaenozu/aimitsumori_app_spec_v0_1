package com.kaenozu.aimitsumori.app

import android.content.Context
import androidx.room.Room
import com.kaenozu.aimitsumori.data.local.AimitsumoriDatabase
import com.kaenozu.aimitsumori.data.repository.QuoteRepository
import com.kaenozu.aimitsumori.domain.clarification.QuestionGenerator
import com.kaenozu.aimitsumori.domain.comparison.ComparisonEngine
import com.kaenozu.aimitsumori.domain.normalization.Normalizer
import com.kaenozu.aimitsumori.domain.purchase.UnlockManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class AppContainer(context: Context) {
    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    val database: AimitsumoriDatabase = Room.databaseBuilder(
        context.applicationContext,
        AimitsumoriDatabase::class.java,
        "aimitsumori.db",
    ).build()

    val repository = QuoteRepository(database)
    val requirementDao = database.requirementDao()
    val normalizer = Normalizer()
    val unlockManager = UnlockManager(context)
    val questionGenerator = QuestionGenerator()
    val comparisonEngine = ComparisonEngine()

    fun seedSampleData() {
        applicationScope.launch {
            repository.seedSampleIfEmpty()
        }
    }
}
