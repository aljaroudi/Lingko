package com.aljaroudi.lingko.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.aljaroudi.lingko.ui.history.HistoryScreen
import com.aljaroudi.lingko.ui.translation.TranslationScreen

sealed class Screen(val route: String) {
    data object Translation : Screen("translation")
    data object History : Screen("history")
}

@Composable
fun NavGraph(
    navController: NavHostController = rememberNavController()
) {
    NavHost(
        navController = navController,
        startDestination = Screen.Translation.route
    ) {
        composable(Screen.Translation.route) {
            TranslationScreen(
                onNavigateToHistory = {
                    navController.navigate(Screen.History.route)
                }
            )
        }

        composable(Screen.History.route) {
            HistoryScreen(
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }
    }
}
