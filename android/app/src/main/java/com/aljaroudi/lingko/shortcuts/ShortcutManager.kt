package com.aljaroudi.lingko.shortcuts

import android.content.Context
import android.content.Intent
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.aljaroudi.lingko.MainActivity
import com.aljaroudi.lingko.R

object AppShortcutManager {
    
    fun createShortcuts(context: Context) {
        val shortcuts = listOf(
            createQuickTranslateShortcut(context),
            createHistoryShortcut(context),
            createImageTranslateShortcut(context)
        )
        
        ShortcutManagerCompat.setDynamicShortcuts(context, shortcuts)
    }
    
    private fun createQuickTranslateShortcut(context: Context): ShortcutInfoCompat {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_QUICK_TRANSLATE
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        return ShortcutInfoCompat.Builder(context, "quick_translate")
            .setShortLabel("Quick Translate")
            .setLongLabel("Quick Translate Text")
            .setIcon(IconCompat.createWithResource(context, R.drawable.ic_launcher_foreground))
            .setIntent(intent)
            .build()
    }
    
    private fun createHistoryShortcut(context: Context): ShortcutInfoCompat {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_HISTORY
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        return ShortcutInfoCompat.Builder(context, "history")
            .setShortLabel("History")
            .setLongLabel("Translation History")
            .setIcon(IconCompat.createWithResource(context, R.drawable.ic_launcher_foreground))
            .setIntent(intent)
            .build()
    }
    
    private fun createImageTranslateShortcut(context: Context): ShortcutInfoCompat {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_IMAGE_TRANSLATE
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        return ShortcutInfoCompat.Builder(context, "image_translate")
            .setShortLabel("Image Translate")
            .setLongLabel("Translate from Image")
            .setIcon(IconCompat.createWithResource(context, R.drawable.ic_launcher_foreground))
            .setIntent(intent)
            .build()
    }
}
