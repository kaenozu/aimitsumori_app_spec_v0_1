package com.kaenozu.aimitsumori.domain.purchase

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.runBlocking

data class UnlockState(
    val isUnlocked: Boolean = false,
    val unlockType: UnlockType? = null,
)

enum class UnlockType {
    REWARD_AD,
    PURCHASE,
    PROMOTIONAL,
}

private val Context.store: DataStore<Preferences> by preferencesDataStore(name = "unlock_prefs")

private val UNLOCKED_PROJECTS_KEY = stringSetPreferencesKey("unlocked_projects")

class UnlockManager(context: Context) {
    private val store = context.applicationContext.store
    private val _cache = MutableStateFlow<Set<String>>(emptySet())
    val unlockedProjects: StateFlow<Set<String>> = _cache.asStateFlow()

    init {
        runBlocking {
            _cache.value = store.data.first()[UNLOCKED_PROJECTS_KEY] ?: emptySet()
        }
    }

    fun isUnlocked(projectId: String): Boolean = projectId in _cache.value

    suspend fun unlockWithAd(projectId: String): Boolean {
        store.edit { prefs ->
            val current = prefs[UNLOCKED_PROJECTS_KEY] ?: emptySet()
            prefs[UNLOCKED_PROJECTS_KEY] = current + projectId
        }
        _cache.value = _cache.value + projectId
        return true
    }

    suspend fun unlockWithPurchase(projectId: String): Boolean {
        store.edit { prefs ->
            val current = prefs[UNLOCKED_PROJECTS_KEY] ?: emptySet()
            prefs[UNLOCKED_PROJECTS_KEY] = current + projectId
        }
        _cache.value = _cache.value + projectId
        return true
    }

    fun getUnlockState(projectId: String): UnlockState {
        if (projectId in _cache.value) {
            return UnlockState(isUnlocked = true, unlockType = UnlockType.PURCHASE)
        }
        return UnlockState()
    }
}
