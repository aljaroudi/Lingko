package com.aljaroudi.lingko

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.aljaroudi.lingko.ui.navigation.NavGraph
import com.aljaroudi.lingko.ui.theme.LingkoTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            LingkoTheme {
                NavGraph()
            }
        }
    }
}