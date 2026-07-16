package com.kaenozu.aimitsumori.feature.project

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.kaenozu.aimitsumori.data.repository.QuoteRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class CreateProjectUiState(
    val name: String = "",
    val isSaving: Boolean = false,
    val errorMessage: String? = null,
)

class CreateProjectViewModel(
    private val repository: QuoteRepository,
) : ViewModel() {
    private val _uiState = MutableStateFlow(CreateProjectUiState())
    val uiState: StateFlow<CreateProjectUiState> = _uiState.asStateFlow()

    fun updateName(value: String) {
        _uiState.value = _uiState.value.copy(name = value, errorMessage = null)
    }

    fun save(onCreated: (String) -> Unit) {
        val name = _uiState.value.name.trim()
        if (name.isEmpty()) {
            _uiState.value = _uiState.value.copy(errorMessage = "案件名を入力してください。")
            return
        }
        if (_uiState.value.isSaving) return

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSaving = true, errorMessage = null)
            runCatching { repository.createProject(name) }
                .onSuccess(onCreated)
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(
                        isSaving = false,
                        errorMessage = error.message ?: "保存に失敗しました。",
                    )
                }
        }
    }

    class Factory(
        private val repository: QuoteRepository,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            CreateProjectViewModel(repository) as T
    }
}
