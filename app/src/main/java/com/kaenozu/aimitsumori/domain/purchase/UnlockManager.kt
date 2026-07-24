package com.kaenozu.aimitsumori.domain.purchase

data class UnlockState(
    val isUnlocked: Boolean = false,
    val unlockType: UnlockType? = null,
)

enum class UnlockType {
    REWARD_AD,
    PURCHASE,
    PROMOTIONAL,
}

class UnlockManager {
    private val unlockedProjects = mutableSetOf<String>()

    fun isUnlocked(projectId: String): Boolean = projectId in unlockedProjects

    fun unlockWithAd(projectId: String): Boolean {
        unlockedProjects.add(projectId)
        return true
    }

    fun unlockWithPurchase(projectId: String): Boolean {
        unlockedProjects.add(projectId)
        return true
    }

    fun getUnlockState(projectId: String): UnlockState {
        if (projectId in unlockedProjects) {
            return UnlockState(isUnlocked = true, unlockType = UnlockType.PURCHASE)
        }
        return UnlockState()
    }
}
