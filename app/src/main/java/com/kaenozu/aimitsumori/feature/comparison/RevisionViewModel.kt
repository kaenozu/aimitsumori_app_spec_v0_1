package com.kaenozu.aimitsumori.feature.comparison

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.kaenozu.aimitsumori.data.repository.QuoteRepository
import com.kaenozu.aimitsumori.domain.model.Project
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class RevisionViewModel(
    projectId: String,
    repository: QuoteRepository,
) : ViewModel() {
    private val _project = MutableStateFlow<Project?>(null)
    val project: StateFlow<Project?> = _project.asStateFlow()

    init {
        viewModelScope.launch {
            _project.value = repository.observeProject(projectId).first()
        }
    }

    class Factory(
        private val projectId: String,
        private val repository: QuoteRepository,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            RevisionViewModel(projectId, repository) as T
    }
}
