package com.kaenozu.aimitsumori.feature.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.kaenozu.aimitsumori.data.repository.QuoteRepository
import com.kaenozu.aimitsumori.domain.model.Project
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn

sealed interface HomeUiState {
    data object Loading : HomeUiState
    data class Ready(val projects: List<Project>) : HomeUiState
}

class HomeViewModel(
    repository: QuoteRepository,
) : ViewModel() {
    val uiState: StateFlow<HomeUiState> = repository.observeProjects()
        .map<List<Project>, HomeUiState>(HomeUiState::Ready)
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = HomeUiState.Loading,
        )

    class Factory(
        private val repository: QuoteRepository,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            HomeViewModel(repository) as T
    }
}
