package com.example.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

private val DarkColorScheme = darkColorScheme(
    primary = CyberTeal,
    secondary = NeonGreen,
    tertiary = CyberPink,
    background = MidnightBlack,
    surface = DeepCharcoal,
    onBackground = TextPrimary,
    onSurface = TextPrimary,
    primaryContainer = SurfaceDark,
    onPrimaryContainer = TextPrimary,
    secondaryContainer = SurfaceDark,
    onSecondaryContainer = NeonGreen,
    error = AlertRed
)

@Composable
fun MyApplicationTheme(
    darkTheme: Boolean = true, // Force ultra dark cybersecurity mode
    dynamicColor: Boolean = false, // Keep theme looking pristine and cohesive
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        typography = Typography,
        content = content
    )
}
