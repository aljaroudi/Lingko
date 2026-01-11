package com.aljaroudi.lingko.ui.navigation

import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
    navController: NavHostController = rememberNavController(),
    sharedText: String? = null,
    shortcutAction: String? = null,
    onSharedTextConsumed: () -> Unit = {},
    onShortcutActionConsumed: () -> Unit = {}
) {
    val onTextExtractedCallback = remember { mutableStateOf<((String) -> Unit)?>(null) }

    // Handle shared text
    LaunchedEffect(sharedText) {
        sharedText?.let { text ->
            onTextExtractedCallback.value?.invoke(text)
            onSharedTextConsumed()
        }
    }

    // Handle shortcut actions
    LaunchedEffect(shortcutAction) {
        shortcutAction?.let { action ->
            when (action) {
                "com.aljaroudi.lingko.QUICK_TRANSLATE" -> {
                    navController.navigate(Screen.Translation.route) {
                        popUpTo(Screen.Translation.route) { inclusive = true }
                    }
                }
                "com.aljaroudi.lingko.HISTORY" -> {
                    navController.navigate(Screen.History.route)
                }
                "com.aljaroudi.lingko.IMAGE_TRANSLATE" -> {
                    navController.navigate(Screen.ImageTranslation.route)
                }
            }
            onShortcutActionConsumed()
        }
    }

    NavHost(
        navController = navController,
        startDestination = Screen.Translation.route
    ) {
        composable(
            route = Screen.Translation.route,
            enterTransition = {
                fadeIn(animationSpec = tween(300))
            },
            exitTransition = {
                fadeOut(animationSpec = tween(300))
            }
        ) {
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

        composable(
            route = Screen.History.route,
            enterTransition = {
                slideIntoContainer(
                    towards = AnimatedContentTransitionScope.SlideDirection.Left,
                    animationSpec = tween(300)
                )
            },
            exitTransition = {
                fadeOut(animationSpec = tween(300))
            },
            popEnterTransition = {
                fadeIn(animationSpec = tween(300))
            },
            popExitTransition = {
                slideOutOfContainer(
                    towards = AnimatedContentTransitionScope.SlideDirection.Right,
                    animationSpec = tween(300)
                )
            }
        ) {
            HistoryScreen(
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }

        composable(
            route = Screen.ImageTranslation.route,
            enterTransition = {
                slideIntoContainer(
                    towards = AnimatedContentTransitionScope.SlideDirection.Up,
                    animationSpec = tween(300)
                )
            },
            exitTransition = {
                fadeOut(animationSpec = tween(300))
            },
            popEnterTransition = {
                fadeIn(animationSpec = tween(300))
            },
            popExitTransition = {
                slideOutOfContainer(
                    towards = AnimatedContentTransitionScope.SlideDirection.Down,
                    animationSpec = tween(300)
                )
            }
        ) {
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
