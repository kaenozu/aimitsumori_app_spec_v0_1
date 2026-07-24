package com.kaenozu.aimitsumori.feature.project

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.kaenozu.aimitsumori.data.local.RequirementMaster
import com.kaenozu.aimitsumori.data.local.dao.RequirementDao
import com.kaenozu.aimitsumori.data.local.entity.RequirementEntity
import java.util.UUID
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

data class ItemState(
    val id: String,
    val nameJa: String,
    val requirementType: String = "unset",
    val specification: String = "",
    val quantity: String = "",
)

data class ChecklistUiState(
    val categories: List<CategoryState> = emptyList(),
    val isSaving: Boolean = false,
) {
    data class CategoryState(
        val id: String,
        val nameJa: String,
        val items: List<ItemState>,
    )
}

class ChecklistViewModel(
    private val projectId: String,
    private val requirementDao: RequirementDao,
) : ViewModel() {
    private val _uiState = MutableStateFlow(ChecklistUiState())
    val uiState: StateFlow<ChecklistUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            val existing = requirementDao.observeByProject(projectId).first()
            val existingMap = existing.associateBy { it.categoryCode }

            _uiState.value = ChecklistUiState(
                categories = RequirementMaster.categories.map { cat ->
                    ChecklistUiState.CategoryState(
                        id = cat.id,
                        nameJa = cat.nameJa,
                        items = cat.items.map { item ->
                            val saved = existingMap[item.id]
                            ItemState(
                                id = item.id,
                                nameJa = item.nameJa,
                                requirementType = saved?.requirementType ?: "unset",
                                specification = saved?.specification ?: "",
                                quantity = saved?.quantity ?: "",
                            )
                        },
                    )
                },
            )
        }
    }

    fun setRequirementType(itemId: String, type: String) {
        updateItem(itemId) { it.copy(requirementType = type) }
    }

    fun setSpecification(itemId: String, value: String) {
        updateItem(itemId) { it.copy(specification = value) }
    }

    fun setQuantity(itemId: String, value: String) {
        updateItem(itemId) { it.copy(quantity = value) }
    }

    private fun updateItem(itemId: String, transform: (ItemState) -> ItemState) {
        val current = _uiState.value
        _uiState.value = current.copy(
            categories = current.categories.map { cat ->
                cat.copy(
                    items = cat.items.map { item ->
                        if (item.id == itemId) transform(item) else item
                    },
                )
            },
        )
    }

    fun save(onSaved: () -> Unit) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSaving = true)
            val allItems = _uiState.value.categories.flatMap { cat ->
                cat.items.map { item ->
                    RequirementEntity(
                        id = UUID.nameUUIDFromBytes("$projectId|${item.id}".toByteArray()).toString(),
                        projectId = projectId,
                        categoryCode = item.id,
                        requirementType = item.requirementType,
                        specification = item.specification.ifBlank { null },
                        quantity = item.quantity.ifBlank { null },
                    )
                }
            }
            requirementDao.deleteByProject(projectId)
            requirementDao.upsertAll(allItems)
            _uiState.value = _uiState.value.copy(isSaving = false)
            onSaved()
        }
    }

    class Factory(
        private val projectId: String,
        private val requirementDao: RequirementDao,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            ChecklistViewModel(projectId, requirementDao) as T
    }
}
