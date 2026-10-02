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
import org.json.JSONArray
import org.json.JSONObject

private const val FALLBACK_COLOR = 0xFF7C3AED.toInt()
private const val KIND_POSITIVE = 0
private const val KIND_NEGATIVE = 1
private const val KIND_QUANTITATIVE = 2

private const val LABEL_WIDTH_DP = 104
private const val TODAY_INDEX = 6
private const val DOT_DP = 22

class HabitWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        provideContent {
            currentState(GlanceWidgets.REVISION)
            val style = WidgetStyle.loadFor(context, appWidgetId)
            WidgetSurface(style) { Body(context, style) }
        }
    }

    @Composable
    private fun Body(context: Context, style: WidgetStyle) {
        val data = WidgetPayload.aligned(context)
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .clickable(actionStartActivity<MainActivity>()),
        ) {
            val habits = data?.optJSONArray("habits")
            val days = data?.optJSONArray("days")
            when {
                data == null -> EmptyNote(
                    WidgetText.get(context, "no_data", "No data yet\nOpen Streak to sync"),
                    style,
                )
                habits == null || days == null || habits.length() == 0 -> EmptyNote(
                    WidgetText.get(context, "no_habits", "No habits yet\nTap to open Streak"),
                    style,
                )
                else -> {
                    val offset = data.optInt("weekOffset", 0)
                        .coerceIn(0, maxOf(0, days.length() - 7))
                    Header(style, data.optJSONObject("summary"), days, offset)
                    Spacer(GlanceModifier.height(10.dp))
                    val keys = List(days.length()) {
                        days.optJSONObject(it)?.optString("key") ?: WidgetPayload.todayKey(context)
                    }
                    LazyColumn(modifier = GlanceModifier.fillMaxWidth().defaultWeight()) {
                        items(habits.length()) { index ->
                            habits.optJSONObject(index)?.let { HabitRow(style, it, keys, offset) }
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun Header(style: WidgetStyle, summary: JSONObject?, days: JSONArray, offset: Int) {
        val total = summary?.optInt("total", 0) ?: 0
        val done = summary?.optInt("doneToday", 0) ?: 0
        val ratio = summary?.optDouble("ratio", Double.NaN)?.takeIf { !it.isNaN() }?.toFloat()
            ?: if (total > 0) done.toFloat() / total else 0f
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(
                modifier = GlanceModifier.width(LABEL_WIDTH_DP.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "${(ratio * 100).toInt()}%",
                    style = TextStyle(
                        color = ColorProvider(style.content),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                    maxLines = 1,
                )
            }
            Spacer(GlanceModifier.width(8.dp))
            Row(modifier = GlanceModifier.defaultWeight()) {
                for (i in offset until offset + 7) {
                    val day = days.optJSONObject(i)
                    val today = day?.optBoolean("isToday", false) == true
                    Box(modifier = GlanceModifier.defaultWeight(), contentAlignment = Alignment.Center) {
                        Box(
                            modifier = GlanceModifier
                                .size(DOT_DP.dp)
                                .cornerRadius((DOT_DP / 2).dp)
                                .background(
                                    ColorProvider(if (today) style.content else Color.Transparent),
                                ),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = day?.optString("label").orEmpty(),
                                style = TextStyle(
                                    color = ColorProvider(
                                        if (today) inverse(style) else style.muted,
                                    ),
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                ),
                                maxLines = 1,
                            )
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun HabitRow(style: WidgetStyle, habit: JSONObject, keys: List<String>, offset: Int) {
        val context = androidx.glance.LocalContext.current
        val habitId = habit.optString("id")
        val color = Color(habit.optInt("color", FALLBACK_COLOR))
        val completions = habit.optJSONArray("completions") ?: JSONArray()
        val counts = habit.optJSONArray("counts")
        val kind = habit.optInt("kind", KIND_POSITIVE)
        val target = habit.optDouble("perDayTarget", 1.0).coerceAtLeast(1.0)
        val quantified = kind == KIND_QUANTITATIVE || target > 1
        val clock = habit.optBoolean("clock", false)

        Row(
            modifier = GlanceModifier.fillMaxWidth().padding(vertical = 1.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(
                modifier = GlanceModifier.width(LABEL_WIDTH_DP.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = habit.optString("name"),
                    style = TextStyle(
                        color = ColorProvider(style.content),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                    ),
                    maxLines = 2,
                    modifier = GlanceModifier.defaultWeight(),
                )
                StreakChip(habit.optInt("streak", 0), style)
            }
            Spacer(GlanceModifier.width(8.dp))
            Row(modifier = GlanceModifier.defaultWeight(), verticalAlignment = Alignment.CenterVertically) {
                for (i in offset until offset + 7) {
                    val completed = i < completions.length() && completions.optBoolean(i, false)
                    val count = counts?.optDouble(i, 0.0) ?: 0.0
                    val future = i > TODAY_INDEX
                    val cell = GlanceModifier
                        .defaultWeight()
                        .padding(vertical = 3.dp)
                        .cornerRadius(markRadius(DOT_DP.dp, style))
                    Box(
                        modifier = if (future) cell else cell.clickable(
                            actionSendBroadcast(
                                WidgetActionReceiver.intent(
                                    context,
                                    habitId,
                                    keys.getOrElse(i) { WidgetPayload.todayKey(context) },
                                ),
                            ),
                        ),
                        contentAlignment = Alignment.Center,
                    ) {
                        when {
                            future -> DayDot(DayMark.FUTURE, color, style, DOT_DP.dp)
                            kind == KIND_NEGATIVE && count > 0 ->
                                DayDot(DayMark.RELAPSE, color, style, DOT_DP.dp)
                            completed -> DayDot(DayMark.DONE, color, style, DOT_DP.dp)
                            quantified && count > 0 -> Partial(
                                if (clock) WidgetText.clock(count) else WidgetText.compact(count),
                                (count / target).toFloat(),
                                color,
                                style,
                            )
                            i == TODAY_INDEX -> DayDot(DayMark.TODAY, color, style, DOT_DP.dp)
                            else -> DayDot(DayMark.MISSED, color, style, DOT_DP.dp)
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun Partial(label: String, ratio: Float, color: Color, style: WidgetStyle) {
        val filled = ratio.coerceIn(0f, 1f)
        Box(
            modifier = GlanceModifier
                .size(DOT_DP.dp)
                .cornerRadius(markRadius(DOT_DP.dp, style))
                .background(ColorProvider(color.copy(alpha = 0.22f + 0.5f * filled))),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = label,
                style = TextStyle(
                    color = ColorProvider(Color.White),
                    fontSize = when {
                        label.length > 3 -> 7.sp
                        label.length > 2 -> 8.sp
                        else -> 10.sp
                    },
                    fontWeight = FontWeight.Bold,
                ),
                maxLines = 1,
            )
        }
    }

    private fun inverse(style: WidgetStyle): Color =
        if (style.content == Color.White) Color(0xFF111114) else Color.White
}
