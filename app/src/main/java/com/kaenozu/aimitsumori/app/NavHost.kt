package com.kaenozu.aimitsumori.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.kaenozu.aimitsumori.feature.comparison.ComparisonScreen
import com.kaenozu.aimitsumori.feature.comparison.ComparisonViewModel
import com.kaenozu.aimitsumori.feature.comparison.RevisionScreen
import com.kaenozu.aimitsumori.feature.comparison.RevisionViewModel
import com.kaenozu.aimitsumori.feature.home.HomeScreen
import com.kaenozu.aimitsumori.feature.home.HomeViewModel
import com.kaenozu.aimitsumori.feature.project.ChecklistScreen
import com.kaenozu.aimitsumori.feature.project.ChecklistViewModel
import com.kaenozu.aimitsumori.feature.project.CreateProjectScreen
import com.kaenozu.aimitsumori.feature.project.CreateProjectViewModel
import com.kaenozu.aimitsumori.feature.quote.ImportScreen
import com.kaenozu.aimitsumori.feature.quote.ImportViewModel
import com.kaenozu.aimitsumori.feature.review.ReviewScreen
import com.kaenozu.aimitsumori.feature.review.ReviewViewModel

private object Routes {
    const val HOME = "home"
    const val CREATE_PROJECT = "create-project"
    const val CHECKLIST = "checklist/{projectId}"
    const val IMPORT = "import/{projectId}"
    const val REVIEW = "review/{projectId}"
    const val COMPARISON = "comparison/{projectId}"
    const val REVISION = "revision/{projectId}"

    fun checklist(projectId: String): String = "checklist/$projectId"
    fun import(projectId: String): String = "import/$projectId"
    fun review(projectId: String): String = "review/$projectId"
    fun comparison(projectId: String): String = "comparison/$projectId"
    fun revision(projectId: String): String = "revision/$projectId"
}

@Composable
fun AimitsumoriNavHost(container: AppContainer) {
    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = Routes.HOME,
    ) {
        composable(Routes.HOME) {
            val homeViewModel: HomeViewModel = viewModel(
                factory = HomeViewModel.Factory(container.repository),
            )
            HomeScreen(
                viewModel = homeViewModel,
                onCreateProject = { navController.navigate(Routes.CREATE_PROJECT) },
                onOpenProject = { projectId ->
                    navController.navigate(Routes.comparison(projectId))
                },
            )
        }

        composable(Routes.CREATE_PROJECT) {
            val createProjectViewModel: CreateProjectViewModel = viewModel(
                factory = CreateProjectViewModel.Factory(container.repository),
            )
            CreateProjectScreen(
                viewModel = createProjectViewModel,
                onBack = { navController.popBackStack() },
                onCreated = { projectId ->
                    navController.navigate(Routes.checklist(projectId)) {
                        popUpTo(Routes.HOME)
                    }
                },
            )
        }

        composable(
            route = Routes.CHECKLIST,
            arguments = listOf(
                navArgument("projectId") { type = NavType.StringType },
            ),
        ) { backStackEntry ->
            val projectId = requireNotNull(backStackEntry.arguments?.getString("projectId"))
            val checklistViewModel: ChecklistViewModel = viewModel(
                key = "checklist-$projectId",
                factory = ChecklistViewModel.Factory(
                    projectId = projectId,
                    requirementDao = container.requirementDao,
                ),
            )
            ChecklistScreen(
                viewModel = checklistViewModel,
                onBack = { navController.popBackStack() },
                onSaved = {
                    navController.navigate(Routes.comparison(projectId)) {
                        popUpTo(Routes.HOME)
                    }
                },
            )
        }

        composable(
            route = Routes.COMPARISON,
            arguments = listOf(
                navArgument("projectId") { type = NavType.StringType },
            ),
        ) { backStackEntry ->
            val projectId = requireNotNull(backStackEntry.arguments?.getString("projectId"))
            val comparisonViewModel: ComparisonViewModel = viewModel(
                key = "comparison-$projectId",
                factory = ComparisonViewModel.Factory(
                    projectId = projectId,
                    repository = container.repository,
                    normalizer = container.normalizer,
                    questionGenerator = container.questionGenerator,
                    comparisonEngine = container.comparisonEngine,
                    unlockManager = container.unlockManager,
                ),
            )
            ComparisonScreen(
                viewModel = comparisonViewModel,
                onBack = { navController.popBackStack() },
                onAddQuote = { navController.navigate(Routes.import(projectId)) },
                onRevision = { navController.navigate(Routes.revision(projectId)) },
            )
        }

        composable(
            route = Routes.IMPORT,
            arguments = listOf(
                navArgument("projectId") { type = NavType.StringType },
            ),
        ) { backStackEntry ->
            val projectId = requireNotNull(backStackEntry.arguments?.getString("projectId"))
            val importViewModel: ImportViewModel = viewModel(
                key = "import-$projectId",
                factory = ImportViewModel.Factory(
                    projectId = projectId,
                    repository = container.repository,
                ),
            )
            ImportScreen(
                viewModel = importViewModel,
                onBack = { navController.popBackStack() },
                onComplete = {
                    navController.navigate(Routes.review(projectId)) {
                        popUpTo(Routes.HOME)
                    }
                },
            )
        }

        composable(
            route = Routes.REVIEW,
            arguments = listOf(
                navArgument("projectId") { type = NavType.StringType },
            ),
        ) { backStackEntry ->
            val projectId = requireNotNull(backStackEntry.arguments?.getString("projectId"))
            val reviewViewModel: ReviewViewModel = viewModel(
                key = "review-$projectId",
                factory = ReviewViewModel.Factory(
                    projectId = projectId,
                    repository = container.repository,
                ),
            )
            ReviewScreen(
                viewModel = reviewViewModel,
                onBack = { navController.popBackStack() },
                onComplete = {
                    navController.navigate(Routes.comparison(projectId)) {
                        popUpTo(Routes.HOME)
                    }
                },
            )
        }

        composable(
            route = Routes.REVISION,
            arguments = listOf(
                navArgument("projectId") { type = NavType.StringType },
            ),
        ) { backStackEntry ->
            val projectId = requireNotNull(backStackEntry.arguments?.getString("projectId"))
            val revisionViewModel: RevisionViewModel = viewModel(
                key = "revision-$projectId",
                factory = RevisionViewModel.Factory(
                    projectId = projectId,
                    repository = container.repository,
                ),
            )
            val project by revisionViewModel.project.collectAsStateWithLifecycle()
            project?.let { p ->
                RevisionScreen(
                    project = p,
                    onBack = { navController.popBackStack() },
                )
            }
        }
    }
}
