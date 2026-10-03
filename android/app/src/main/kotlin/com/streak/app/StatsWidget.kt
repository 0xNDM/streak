package com.streak.app

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import org.json.JSONObject
import kotlin.math.min

class StatsWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        provideContent {
            currentState(GlanceWidgets.REVISION)
            Content(context, WidgetStyle.loadFor(context, appWidgetId), appWidgetId)
        }
    }

    @Composable
    private fun Content(context: Context, style: WidgetStyle, appWidgetId: Int) {
        val data = WidgetPayload.forWidget(context, appWidgetId)
        val single = WidgetPayload.single(context, appWidgetId, data)
        val summary = data?.optJSONObject("summary")
        val done = single?.optInt("streak") ?: summary?.optInt("doneToday") ?: 0
        val total = summary?.optInt("total") ?: 0
        val best = single?.optInt("best") ?: summary?.optInt("bestStreak") ?: 0

        val size = LocalSize.current
        val full = size.width.value >= 200f && size.height.value >= 150f
        val pad = if (full) 16 else 13
        val inner = (size.width.value - pad * 2).coerceAtLeast(0f).dp

        WidgetSurface(style) {
            Column(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .padding(pad.dp)
                    .clickable(openPageAction(context, "stats")),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Flame(if (full) 44.dp else 36.dp)
                    Spacer(GlanceModifier.width(10.dp))
                    Column(modifier = GlanceModifier.defaultWeight()) {
                        Caps(
                            single?.optString("name")
                                ?: WidgetText.get(context, "done_today", "done today"),
                            style,
                        )
                        Row(verticalAlignment = Alignment.Bottom) {
                            Text(
                                text = WidgetText.compact(done),
                                style = TextStyle(
                                    color = ColorProvider(style.content),
                                    fontSize = if (full) 30.sp else 24.sp,
                                    fontWeight = FontWeight.Bold,
                                ),
                                maxLines = 1,
                            )
                            if (single == null) {
                            Spacer(GlanceModifier.width(3.dp))
                            Text(
                                text = "/${WidgetText.compact(total)}",
                                style = TextStyle(
                                    color = ColorProvider(style.muted),
                                    fontSize = if (full) 15.sp else 13.sp,
                                    fontWeight = FontWeight.Medium,
                                ),
                                maxLines = 1,
                                modifier = GlanceModifier.padding(bottom = if (full) 4.dp else 3.dp),
                            )
                            }
                        }
                    }
                    if (full) Best(context, style, best)
                }

                if (full) {
                    Spacer(GlanceModifier.height(12.dp))
                    WidgetDivider(style)
                    Spacer(GlanceModifier.height(12.dp))
                    Week(style, data, inner)
                }
            }
        }
    }

    @Composable
    private fun Best(context: Context, style: WidgetStyle, best: Int) {
        Column(horizontalAlignment = Alignment.End) {
            Caps(WidgetText.get(context, "label_best", "Best"), style)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Flame(16.dp)
                Spacer(GlanceModifier.width(3.dp))
                Text(
                    text = WidgetText.compact(best),
                    style = TextStyle(
                        color = ColorProvider(style.content),
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                    maxLines = 1,
                )
            }
        }
    }

    @Composable
    private fun Week(style: WidgetStyle, data: JSONObject?, width: Dp) {
        val days = data?.optJSONArray("days")
        val marks = marksOf(data)
        val dot = min(28f, width.value / WidgetPayload.WEEK - 8f).coerceAtLeast(14f).dp
        Row(modifier = GlanceModifier.fillMaxWidth()) {
            for (day in 0 until WidgetPayload.WEEK) {
                val info = days?.optJSONObject(day)
                val today = info?.optBoolean("isToday", false) == true
                Column(
                    modifier = GlanceModifier.defaultWeight(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    DayDot(marks[day], WidgetInk.done, style, dot)
                    Spacer(GlanceModifier.height(5.dp))
                    Text(
                        text = info?.optString("label").orEmpty(),
                        style = TextStyle(
                            color = ColorProvider(if (today) style.content else style.muted),
                            fontSize = 10.sp,
                            fontWeight = if (today) FontWeight.Bold else FontWeight.Medium,
                        ),
                        maxLines = 1,
                    )
                }
            }
        }
    }

    private fun marksOf(data: JSONObject?): List<DayMark> {
        val habits = data?.optJSONArray("habits")
        return List(WidgetPayload.WEEK) { day ->
            var due = 0
            var done = 0
            for (i in 0 until (habits?.length() ?: 0)) {
                val habit = habits?.optJSONObject(i) ?: continue
                val scheduled = habit.optJSONArray("scheduled")
                if (scheduled != null && !scheduled.optBoolean(day, false)) continue
                due++
                if (habit.optJSONArray("completions")?.optBoolean(day, false) == true) done++
            }
            when {
                due > 0 && done == due -> DayMark.DONE
                day == WidgetPayload.TODAY -> DayMark.TODAY
                else -> DayMark.MISSED
            }
        }
    }
}
