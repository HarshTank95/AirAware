package com.airaware.airaware

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Home-screen widget showing the latest AQI for the saved location.
/// Data is pushed from Dart via the home_widget plugin.
class AqiWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.aqi_widget).apply {
                val aqi = readInt(widgetData, "aqi", -1)
                val category = widgetData.getString("category", "Tap to refresh") ?: "Tap to refresh"
                val place = widgetData.getString("place", "AirAware") ?: "AirAware"
                val color = readInt(widgetData, "color", 0xFF4CAF50.toInt())

                setTextViewText(R.id.widget_aqi, if (aqi >= 0) aqi.toString() else "—")
                setTextViewText(R.id.widget_category, category)
                setTextViewText(R.id.widget_place, place)
                setTextColor(R.id.widget_aqi, color)

                // Tint the band-colored accents.
                setInt(R.id.widget_glow, "setColorFilter", color)
                setInt(R.id.widget_glow, "setImageAlpha", 150)
                setInt(R.id.widget_dot, "setColorFilter", color)

                // Tap anywhere → open the app.
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /// Read an int that may have been stored as either an int or a long
    /// (home_widget stores large values like ARGB colors as longs).
    private fun readInt(prefs: SharedPreferences, key: String, def: Int): Int {
        return try {
            prefs.getInt(key, def)
        } catch (e: ClassCastException) {
            prefs.getLong(key, def.toLong()).toInt()
        }
    }
}
