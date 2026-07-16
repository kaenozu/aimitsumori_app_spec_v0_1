package com.kaenozu.aimitsumori.data.repository

import androidx.room.withTransaction
import com.kaenozu.aimitsumori.data.local.AimitsumoriDatabase
import com.kaenozu.aimitsumori.data.local.SampleData
import com.kaenozu.aimitsumori.data.local.entity.ClarificationQuestionEntity
import com.kaenozu.aimitsumori.data.local.entity.ProjectEntity
import com.kaenozu.aimitsumori.data.local.entity.ProjectWithQuotes
import com.kaenozu.aimitsumori.data.local.entity.QuoteEntity
import com.kaenozu.aimitsumori.data.local.entity.QuoteLineItemEntity
import com.kaenozu.aimitsumori.data.local.entity.QuoteWithItems
import com.kaenozu.aimitsumori.domain.model.ClarificationQuestion
import com.kaenozu.aimitsumori.domain.model.ContractorQuote
import com.kaenozu.aimitsumori.domain.model.InclusionStatus
import com.kaenozu.aimitsumori.domain.model.Project
import com.kaenozu.aimitsumori.domain.model.ProjectStatus
import com.kaenozu.aimitsumori.domain.model.QuestionStatus
import com.kaenozu.aimitsumori.domain.model.QuoteLineItem
import java.util.UUID
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

class QuoteRepository(
    private val database: AimitsumoriDatabase,
) {
    private val projectDao = database.projectDao()
    private val quoteDao = database.quoteDao()
    private val quoteLineItemDao = database.quoteLineItemDao()
    private val questionDao = database.clarificationQuestionDao()

    fun observeProjects(): Flow<List<Project>> =
        projectDao.observeAll().map { rows -> rows.map(ProjectWithQuotes::toDomain) }

    fun observeProject(projectId: String): Flow<Project?> =
        projectDao.observeById(projectId).map { it?.toDomain() }

    suspend fun createProject(name: String): String {
        val now = System.currentTimeMillis()
        val project = Project(
            id = UUID.randomUUID().toString(),
            name = name.trim(),
            status = ProjectStatus.DRAFT,
            createdAtEpochMillis = now,
            updatedAtEpochMillis = now,
        )
        saveProject(project)
        return project.id
    }

    suspend fun saveProject(project: Project) {
        database.withTransaction {
            projectDao.upsert(project.toEntity())
            quoteDao.deleteByProjectId(project.id)
            if (project.quotes.isNotEmpty()) {
                quoteDao.upsertAll(project.quotes.map { it.toEntity(project.id) })
                quoteLineItemDao.upsertAll(
                    project.quotes.flatMap { quote ->
                        quote.lineItems.map { it.toEntity(quote.id) }
                    },
                )
            }
        }
    }

    suspend fun replaceQuestions(
        projectId: String,
        questions: List<ClarificationQuestion>,
    ) {
        database.withTransaction {
            questionDao.deleteByProjectId(projectId)
            if (questions.isNotEmpty()) {
                questionDao.upsertAll(questions.map(ClarificationQuestion::toEntity))
            }
        }
    }

    suspend fun seedSampleIfEmpty() {
        if (projectDao.count() == 0) {
            saveProject(SampleData.project())
        }
    }
}

private fun Project.toEntity(): ProjectEntity = ProjectEntity(
    id = id,
    name = name,
    status = status.code,
    createdAtEpochMillis = createdAtEpochMillis,
    updatedAtEpochMillis = updatedAtEpochMillis,
)

private fun ContractorQuote.toEntity(projectId: String): QuoteEntity = QuoteEntity(
    id = id,
    projectId = projectId,
    contractorName = contractorName,
    totalAmountYen = totalAmountYen,
    note = note,
    createdAtEpochMillis = createdAtEpochMillis,
)

private fun QuoteLineItem.toEntity(quoteId: String): QuoteLineItemEntity = QuoteLineItemEntity(
    id = id,
    quoteId = quoteId,
    categoryId = categoryId,
    rawLabel = rawLabel,
    amountYen = amountYen,
    inclusionStatus = inclusionStatus.code,
    quantity = quantity,
    unit = unit,
    specification = specification,
    note = note,
    sortOrder = sortOrder,
)

private fun ClarificationQuestion.toEntity(): ClarificationQuestionEntity =
    ClarificationQuestionEntity(
        id = id,
        projectId = projectId,
        quoteId = quoteId,
        contractorName = contractorName,
        categoryId = categoryId,
        templateKey = templateKey,
        questionText = questionText,
        status = status.code,
        createdAtEpochMillis = createdAtEpochMillis,
    )

private fun ProjectWithQuotes.toDomain(): Project = Project(
    id = project.id,
    name = project.name,
    status = ProjectStatus.fromCode(project.status),
    createdAtEpochMillis = project.createdAtEpochMillis,
    updatedAtEpochMillis = project.updatedAtEpochMillis,
    quotes = quotes
        .sortedBy { it.quote.createdAtEpochMillis }
        .map(QuoteWithItems::toDomain),
)

private fun QuoteWithItems.toDomain(): ContractorQuote = ContractorQuote(
    id = quote.id,
    contractorName = quote.contractorName,
    totalAmountYen = quote.totalAmountYen,
    note = quote.note,
    createdAtEpochMillis = quote.createdAtEpochMillis,
    lineItems = lineItems
        .sortedWith(compareBy<QuoteLineItemEntity> { it.sortOrder }.thenBy { it.id })
        .map { item ->
            QuoteLineItem(
                id = item.id,
                categoryId = item.categoryId,
                rawLabel = item.rawLabel,
                amountYen = item.amountYen,
                inclusionStatus = InclusionStatus.fromCode(item.inclusionStatus),
                quantity = item.quantity,
                unit = item.unit,
                specification = item.specification,
                note = item.note,
                sortOrder = item.sortOrder,
            )
        },
)
