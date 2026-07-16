package com.kaenozu.aimitsumori.app

import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.kaenozu.aimitsumori.feature.comparison.ComparisonScreen
import com.kaenozu.aimitsumori.feature.comparison.ComparisonViewModel
import com.kaenozu.aimitsumori.feature.home.HomeScreen
import com.kaenozu.aimitsumori.feature.home.HomeViewModel
import com.kaenozu.aimitsumori.feature.project.CreateProjectScreen
import com.kaenozu.aimitsumori.feature.project.CreateProjectViewModel

private object Routes {
    const val HOME = "home"
    const val CREATE_PROJECT = "create-project"
    const val COMPARISON = "comparison/{projectId}"

    fun comparison(projectId: String): String = "comparison/$projectId"
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
                ),
            )
            ComparisonScreen(
                viewModel = comparisonViewModel,
                onBack = { navController.popBackStack() },
            )
        }
    }
}
