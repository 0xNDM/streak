package com.streak.app

import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.appwidget.cornerRadius
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider

object WidgetInk {
    val done = Color(0xFF34C759)
    val flame = Color(0xFFFF6A2B)
    val danger = Color(0xFFFF453A)
}

enum class DayMark { DONE, TODAY, MISSED, FUTURE, RELAPSE }

@Composable
fun Caps(text: String, style: WidgetStyle, size: TextUnit = 10.sp) {
    Text(
        text = text.uppercase(),
        style = TextStyle(
            color = ColorProvider(style.muted),
            fontSize = size,
            fontWeight = FontWeight.Bold,
        ),
        maxLines = 1,
    )
}

fun markRadius(size: Dp, style: WidgetStyle): Dp =
    if (style.round) size / 2 else (size.value * 0.3f).dp

@Composable
fun DayDot(mark: DayMark, color: Color, style: WidgetStyle, size: Dp) {
    val shaped = GlanceModifier.size(size).cornerRadius(markRadius(size, style))
    val glyph = (size.value * 0.6f).dp
    when (mark) {
        DayMark.DONE -> Box(shaped.background(ColorProvider(color)), Alignment.Center) {
            Glyph(R.drawable.ic_widget_check, glyph)
        }
        DayMark.RELAPSE -> Box(shaped.background(ColorProvider(WidgetInk.danger)), Alignment.Center) {
            Glyph(R.drawable.ic_widget_cross, glyph)
        }
        DayMark.TODAY -> Image(
            provider = ImageProvider(WidgetMarks.ring(color, size, style.round)),
            contentDescription = null,
            modifier = GlanceModifier.size(size),
        )
        DayMark.MISSED -> Box(shaped.background(ColorProvider(style.cell))) {}
        DayMark.FUTURE -> Box(
            shaped.background(ColorProvider(style.cell.copy(alpha = style.cell.alpha * 0.45f))),
        ) {}
    }
}

object WidgetMarks {
    private val rings = HashMap<String, Bitmap>()

    fun ring(color: Color, size: Dp, round: Boolean): Bitmap {
        val argb = color.toArgb()
        val key = "$argb:${size.value}:$round"
        synchronized(rings) { rings[key]?.let { return it } }
        val density = Resources.getSystem().displayMetrics.density
        val px = (size.value * density).toInt().coerceAtLeast(1)
        val stroke = 2f * density
        val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val inset = stroke / 2
        val rect = RectF(inset, inset, px - inset, px - inset)
        val radius = if (round) px / 2f else px * 0.3f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = color.copy(alpha = 0.14f).toArgb()
        canvas.drawRoundRect(rect, radius, radius, paint)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = stroke
        paint.color = argb
        canvas.drawRoundRect(rect, radius - inset, radius - inset, paint)
        synchronized(rings) {
            if (rings.size > 64) rings.clear()
            rings[key] = bitmap
        }
        return bitmap
    }
}

@Composable
fun Glyph(res: Int, size: Dp, tint: Color? = null) {
    Image(
        provider = ImageProvider(res),
        contentDescription = null,
        colorFilter = tint?.let { ColorFilter.tint(ColorProvider(it)) },
        modifier = GlanceModifier.size(size),
    )
}

@Composable
fun Flame(size: Dp) {
    Image(
        provider = ImageProvider(R.drawable.widget_flame_3d),
        contentDescription = null,
        modifier = GlanceModifier.size(size),
    )
}

@Composable
fun StreakChip(streak: Int, style: WidgetStyle) {
    if (streak <= 0) return
    Row(verticalAlignment = Alignment.CenterVertically) {
        Spacer(GlanceModifier.width(6.dp))
        Flame(15.dp)
        Spacer(GlanceModifier.width(2.dp))
        Text(
            text = if (streak > 999) "999+" else streak.toString(),
            style = TextStyle(
                color = ColorProvider(style.content),
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
            ),
            maxLines = 1,
        )
    }
}

@Composable
fun WidgetDivider(style: WidgetStyle) {
    Box(
        modifier = GlanceModifier
            .fillMaxWidth()
            .height(1.dp)
            .background(ColorProvider(style.cell)),
    ) {}
}

@Composable
fun EmptyNote(text: String, style: WidgetStyle) {
    Text(
        text = text,
        style = TextStyle(color = ColorProvider(style.muted), fontSize = 13.sp),
    )
}
