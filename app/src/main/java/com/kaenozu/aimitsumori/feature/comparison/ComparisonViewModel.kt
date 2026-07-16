package com.kaenozu.aimitsumori.feature.comparison

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.kaenozu.aimitsumori.data.repository.QuoteRepository
import com.kaenozu.aimitsumori.domain.clarification.QuestionGenerator
import com.kaenozu.aimitsumori.domain.comparison.ComparisonEngine
import com.kaenozu.aimitsumori.domain.model.ComparisonReport
import com.kaenozu.aimitsumori.domain.normalization.Normalizer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

sealed interface ComparisonUiState {
    data object Loading : ComparisonUiState
    data class Ready(val report: ComparisonReport) : ComparisonUiState
    data class Error(val message: String) : ComparisonUiState
}

class ComparisonViewModel(
    projectId: String,
    private val repository: QuoteRepository,
    private val normalizer: Normalizer,
    private val questionGenerator: QuestionGenerator,
    private val comparisonEngine: ComparisonEngine,
) : ViewModel() {
    private val _uiState = MutableStateFlow<ComparisonUiState>(ComparisonUiState.Loading)
    val uiState: StateFlow<ComparisonUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            repository.observeProject(projectId).collectLatest { project ->
                if (project == null) {
                    _uiState.value = ComparisonUiState.Error("案件が見つかりません。")
                    return@collectLatest
                }

                runCatching {
                    val normalizedQuotes = normalizer.normalize(project)
                    val questions = questionGenerator.generate(project, normalizedQuotes)
                    val report = comparisonEngine.compare(project, normalizedQuotes, questions)
                    repository.replaceQuestions(project.id, questions)
                    report
                }.onSuccess { report ->
                    _uiState.value = ComparisonUiState.Ready(report)
                }.onFailure { error ->
                    _uiState.value = ComparisonUiState.Error(
                        error.message ?: "比較処理に失敗しました。",
                    )
                }
            }
        }
    }

    class Factory(
        private val projectId: String,
        private val repository: QuoteRepository,
        private val normalizer: Normalizer,
        private val questionGenerator: QuestionGenerator,
        private val comparisonEngine: ComparisonEngine,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            ComparisonViewModel(
                projectId = projectId,
                repository = repository,
                normalizer = normalizer,
                questionGenerator = questionGenerator,
                comparisonEngine = comparisonEngine,
            ) as T
    }
}
