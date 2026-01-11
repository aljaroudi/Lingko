package com.aljaroudi.lingko

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.mutableStateOf
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.aljaroudi.lingko.shortcuts.AppShortcutManager
import com.aljaroudi.lingko.ui.navigation.NavGraph
import com.aljaroudi.lingko.ui.theme.LingkoTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    private val sharedText = mutableStateOf<String?>(null)
    private val shortcutAction = mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        // Install splash screen before super.onCreate
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        
        // Initialize app shortcuts
        AppShortcutManager.createShortcuts(this)
        
        // Handle incoming intent
        handleIntent(intent)
        
        setContent {
            LingkoTheme {
                NavGraph(
                    sharedText = sharedText.value,
                    shortcutAction = shortcutAction.value,
                    onSharedTextConsumed = { sharedText.value = null },
                    onShortcutActionConsumed = { shortcutAction.value = null }
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_SEND -> {
                if (intent.type == "text/plain") {
                    intent.getStringExtra(Intent.EXTRA_TEXT)?.let { text ->
                        sharedText.value = text
                    }
                }
            }
            ACTION_QUICK_TRANSLATE -> {
                shortcutAction.value = ACTION_QUICK_TRANSLATE
            }
            ACTION_HISTORY -> {
                shortcutAction.value = ACTION_HISTORY
            }
            ACTION_IMAGE_TRANSLATE -> {
                shortcutAction.value = ACTION_IMAGE_TRANSLATE
            }
        }
    }

    companion object {
        const val ACTION_QUICK_TRANSLATE = "com.aljaroudi.lingko.QUICK_TRANSLATE"
        const val ACTION_HISTORY = "com.aljaroudi.lingko.HISTORY"
        const val ACTION_IMAGE_TRANSLATE = "com.aljaroudi.lingko.IMAGE_TRANSLATE"
    }
}