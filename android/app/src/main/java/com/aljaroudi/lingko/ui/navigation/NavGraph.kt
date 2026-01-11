package com.aljaroudi.lingko.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.aljaroudi.lingko.ui.history.HistoryScreen
import com.aljaroudi.lingko.ui.image.ImageTranslationScreen
import com.aljaroudi.lingko.ui.translation.TranslationScreen

sealed class Screen(val route: String) {
    data object Translation : Screen("translation")
    data object History : Screen("history")
    data object ImageTranslation : Screen("image_translation")
}

@Composable
fun NavGraph(
    navController: NavHostController = rememberNavController()
) {
    val onTextExtractedCallback = remember { mutableStateOf<((String) -> Unit)?>(null) }

    NavHost(
        navController = navController,
        startDestination = Screen.Translation.route
    ) {
        composable(Screen.Translation.route) {
            TranslationScreen(
                onNavigateToHistory = {
                    navController.navigate(Screen.History.route)
                },
                onNavigateToImageTranslation = {
                    navController.navigate(Screen.ImageTranslation.route)
                },
                onTextExtractedCallback = { callback ->
                    onTextExtractedCallback.value = callback
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

        composable(Screen.ImageTranslation.route) {
            ImageTranslationScreen(
                onNavigateBack = {
                    navController.popBackStack()
                },
                onTextExtracted = { text ->
                    onTextExtractedCallback.value?.invoke(text)
                }
            )
        }
    }
}
