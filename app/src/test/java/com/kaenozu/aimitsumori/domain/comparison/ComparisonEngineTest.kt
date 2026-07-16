package com.kaenozu.aimitsumori.domain.comparison

import com.kaenozu.aimitsumori.data.local.SampleData
import com.kaenozu.aimitsumori.domain.clarification.QuestionGenerator
import com.kaenozu.aimitsumori.domain.model.InclusionStatus
import com.kaenozu.aimitsumori.domain.normalization.Normalizer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ComparisonEngineTest {
    private val normalizer = Normalizer()
    private val questionGenerator = QuestionGenerator()
    private val engine = ComparisonEngine()

    @Test
    fun compare_keepsInputCompanyOrderAndCreatesExactlyThreeSummaryLines() {
        val project = SampleData.project()
        val normalized = normalizer.normalize(project)
        val questions = questionGenerator.generate(project, normalized, nowEpochMillis = 1L)

        val report = engine.compare(project, normalized, questions)

        assertEquals(listOf("A社", "B社", "C社"), report.quoteSnapshots.map { it.contractorName })
        assertEquals(3, report.summaryLines.size)
        assertTrue(report.summaryLines[0].contains("A社 2,530,000円"))
        assertTrue(report.summaryLines[0].contains("B社 3,450,000円"))
        assertTrue(report.summaryLines[0].contains("C社 2,785,000円"))
    }

    @Test
    fun compare_doesNotHideSeparateItemsBehindLowTotal() {
        val project = SampleData.project()
        val normalized = normalizer.normalize(project)
        val questions = questionGenerator.generate(project, normalized, nowEpochMillis = 1L)

        val report = engine.compare(project, normalized, questions)
        val companyA = report.quoteSnapshots.first { it.contractorName == "A社" }

        assertEquals(2_530_000L, companyA.totalAmountYen)
        assertTrue("残土処分" in companyA.separateCategoryNames)
        assertTrue("排水" in companyA.separateCategoryNames)
        assertTrue(
            report.clarificationQuestions.any {
                it.contractorName == "A社" && it.templateKey == "SEPARATE_SCOPE"
            },
        )
    }

    @Test
    fun normalization_preservesUnknownValuesWithoutGuessing() {
        val project = SampleData.project()
        val companyC = normalizer.normalize(project).first { it.contractorName == "C社" }
        val concrete = companyC.lines.first { it.category.id == "concrete" }
        val drainage = companyC.lines.first { it.category.id == "drainage" }

        assertNull(concrete.quantity)
        assertNull(concrete.unit)
        assertNull(concrete.specification)
        assertTrue(concrete.uncertaintyReasons.any { it.contains("数量") })
        assertTrue(concrete.uncertaintyReasons.any { it.contains("仕様") })

        assertEquals(InclusionStatus.UNKNOWN, drainage.inclusionStatus)
        assertNull(drainage.amountYen)
    }

    @Test
    fun report_containsAll18CategoriesAndNoSyntheticScoreOrRanking() {
        val project = SampleData.project()
        val normalized = normalizer.normalize(project)
        val questions = questionGenerator.generate(project, normalized, nowEpochMillis = 1L)
        val report = engine.compare(project, normalized, questions)

        assertEquals(18, report.categoryComparisons.size)
        assertFalse(report.summaryLines.any { it.contains("総合点") })
        assertFalse(report.summaryLines.any { it.contains("ランキング") })
        assertFalse(report.summaryLines.any { it.contains("1位") })
    }
}
