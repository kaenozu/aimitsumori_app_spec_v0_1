package com.kaenozu.aimitsumori.data.local.entity

import androidx.room.Embedded
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import androidx.room.Relation

@Entity(tableName = "projects")
data class ProjectEntity(
    @PrimaryKey val id: String,
    val name: String,
    val status: String,
    val createdAtEpochMillis: Long,
    val updatedAtEpochMillis: Long,
)

@Entity(
    tableName = "quotes",
    foreignKeys = [
        ForeignKey(
            entity = ProjectEntity::class,
            parentColumns = ["id"],
            childColumns = ["projectId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("projectId")],
)
data class QuoteEntity(
    @PrimaryKey val id: String,
    val projectId: String,
    val contractorName: String,
    val totalAmountYen: Long?,
    val note: String?,
    val createdAtEpochMillis: Long,
)

@Entity(
    tableName = "quote_line_items",
    foreignKeys = [
        ForeignKey(
            entity = QuoteEntity::class,
            parentColumns = ["id"],
            childColumns = ["quoteId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("quoteId"), Index("categoryId")],
)
data class QuoteLineItemEntity(
    @PrimaryKey val id: String,
    val quoteId: String,
    val categoryId: String,
    val rawLabel: String,
    val amountYen: Long?,
    val inclusionStatus: String,
    val quantity: Double?,
    val unit: String?,
    val specification: String?,
    val note: String?,
    val sortOrder: Int,
)

@Entity(
    tableName = "clarification_questions",
    foreignKeys = [
        ForeignKey(
            entity = ProjectEntity::class,
            parentColumns = ["id"],
            childColumns = ["projectId"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = QuoteEntity::class,
            parentColumns = ["id"],
            childColumns = ["quoteId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("projectId"), Index("quoteId"), Index("categoryId")],
)
data class ClarificationQuestionEntity(
    @PrimaryKey val id: String,
    val projectId: String,
    val quoteId: String?,
    val contractorName: String?,
    val categoryId: String?,
    val templateKey: String,
    val questionText: String,
    val status: String,
    val createdAtEpochMillis: Long,
)

data class QuoteWithItems(
    @Embedded val quote: QuoteEntity,
    @Relation(
        parentColumn = "id",
        entityColumn = "quoteId",
    )
    val lineItems: List<QuoteLineItemEntity>,
)

data class ProjectWithQuotes(
    @Embedded val project: ProjectEntity,
    @Relation(
        parentColumn = "id",
        entityColumn = "projectId",
        entity = QuoteEntity::class,
    )
    val quotes: List<QuoteWithItems>,
)
