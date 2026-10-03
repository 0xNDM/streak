package com.streak.app

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionSendBroadcast
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import org.json.JSONObject

private const val FALLBACK_COLOR = 0xFF7C3AED.toInt()
private const val KIND_NEGATIVE = 1
private const val KIND_QUANTITATIVE = 2
private const val BOX_DP = 28

class TodayWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        provideContent {
            currentState(GlanceWidgets.REVISION)
            val style = WidgetStyle.loadFor(context, appWidgetId)
            WidgetSurface(style) { Body(context, style, appWidgetId) }
        }
    }

    @Composable
    private fun Body(context: Context, style: WidgetStyle, appWidgetId: Int) {
        val data = WidgetPayload.forWidget(context, appWidgetId)
        val habits = data?.optJSONArray("habits")
        val summary = data?.optJSONObject("summary")
        val done = summary?.optInt("doneToday") ?: 0
        val total = summary?.optInt("total") ?: 0

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(16.dp)
                .clickable(actionStartActivity<MainActivity>()),
        ) {
            Text(
                text = WidgetText.format(
                    context, "today_progress", "Today  $done/$total",
                    "{done}" to done.toString(), "{total}" to total.toString(),
                ),
                style = TextStyle(
                    color = ColorProvider(style.content),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                ),
                maxLines = 1,
            )
            Spacer(GlanceModifier.height(10.dp))

            if (habits != null && habits.length() > 0) {
                LazyColumn(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
                    items(habits.length()) { i ->
                        habits.optJSONObject(i)?.let { HabitRow(style, it) }
                    }
                }
            } else {
                EmptyNote(WidgetText.get(context, "open_to_sync", "Open Streak to sync"), style)
            }
        }
    }

    @Composable
    private fun HabitRow(style: WidgetStyle, habit: JSONObject) {
        val context = androidx.glance.LocalContext.current
        val color = Color(habit.optInt("color", FALLBACK_COLOR))
        val kind = habit.optInt("kind", 0)
        val target = habit.optDouble("perDayTarget", 1.0).coerceAtLeast(1.0)
        val today = WidgetPayload.TODAY
        val count = habit.optJSONArray("counts")?.optDouble(today, 0.0) ?: 0.0
        val done = habit.optJSONArray("completions")?.optBoolean(today, false) == true
        val quantified = kind == KIND_QUANTITATIVE || target > 1
        val format: (Double) -> String =
            if (habit.optBoolean("clock", false)) WidgetText::clock else WidgetText::amount

        Row(
            modifier = GlanceModifier.fillMaxWidth().padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = GlanceModifier.defaultWeight()) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = habit.optString("name"),
                        style = TextStyle(
                            color = ColorProvider(style.content),
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium,
                        ),
                        maxLines = 1,
                        modifier = GlanceModifier.defaultWeight(),
                    )
                    StreakChip(habit.optInt("streak", 0), style)
                }
                if (quantified) {
                    Text(
                        text = "${format(count)}/${format(target)}",
                        style = TextStyle(color = ColorProvider(style.muted), fontSize = 11.sp),
                    )
                }
            }
            Spacer(GlanceModifier.width(10.dp))
            Box(
                modifier = GlanceModifier
                    .size(BOX_DP.dp)
                    .cornerRadius(markRadius(BOX_DP.dp, style))
                    .background(ColorProvider(boxColor(color, kind, done, count, target)))
                    .clickable(
                        actionSendBroadcast(
                            WidgetActionReceiver.intent(
                                context,
                                habit.optString("id"),
                                WidgetPayload.todayKey(context),
                            ),
                        ),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Mark(style, kind, done, count)
            }
        }
    }

    private fun boxColor(color: Color, kind: Int, done: Boolean, count: Double, target: Double): Color =
        when (kind) {
            KIND_NEGATIVE -> if (count > 0) color.copy(alpha = 0.18f) else color
            KIND_QUANTITATIVE -> color.copy(alpha = 0.25f + 0.75f * (count / target).toFloat().coerceIn(0f, 1f))
            else -> if (done) color else color.copy(alpha = 0.18f)
        }

    @Composable
    private fun Mark(style: WidgetStyle, kind: Int, done: Boolean, count: Double) {
        val glyph = (BOX_DP * 0.6f).dp
        when {
            kind == KIND_NEGATIVE && count > 0 -> Glyph(R.drawable.ic_widget_cross, glyph, style.content)
            kind == KIND_NEGATIVE || done -> Glyph(R.drawable.ic_widget_check, glyph)
            kind == KIND_QUANTITATIVE -> Text(
                text = "+",
                style = TextStyle(
                    color = ColorProvider(Color.White),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
        }
    }
}
