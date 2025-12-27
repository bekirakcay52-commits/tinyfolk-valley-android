package com.tinyfolk.valley

import android.content.Context
import android.graphics.*
import android.os.Bundle
import android.view.MotionEvent
import android.view.SurfaceView
import androidx.appcompat.app.AppCompatActivity

/* =========================
   MAIN ACTIVITY
   ========================= */
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(GameView(this))
    }
}

/* =========================
   GAME VIEW (GAME LOOP)
   ========================= */
class GameView(context: Context) : SurfaceView(context), Runnable {

    private val thread = Thread(this)
    private var running = true
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val buildings = mutableListOf<Building>()
    private val grid = GridMap()

    init {
        thread.start()
    }

    override fun run() {
        while (running) {
            update()
            render()
        }
    }

    private fun update() {
        buildings.forEach { it.update(0.016f) }
    }

    private fun render() {
        if (!holder.surface.isValid) return
        val canvas = holder.lockCanvas()

        // Arka plan (cozy renk)
        canvas.drawColor(Color.rgb(190, 231, 232))

        // Binalar
        buildings.forEach { it.draw(canvas, paint) }

        holder.unlockCanvasAndPost(canvas)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_DOWN) {
            val (x, y) = grid.snap(event.x, event.y)
            buildings.add(Building(x, y))
        }
        return true
    }
}

/* =========================
   GRID SYSTEM
   ========================= */
class GridMap {
    private val cellSize = 128
    fun snap(x: Float, y: Float): Pair<Int, Int> {
        val gx = (x / cellSize).toInt() * cellSize
        val gy = (y / cellSize).toInt() * cellSize
        return Pair(gx, gy)
    }
}

/* =========================
   BUILDING
   ========================= */
class Building(
    private var x: Int,
    private var y: Int
) {
    private val paint = Paint().apply {
        color = Color.rgb(141, 110, 99) // cozy brown
    }

    fun update(delta: Float) {
        // üretim / animasyon buraya eklenir
    }

    fun draw(canvas: Canvas, p: Paint) {
        canvas.drawRoundRect(
            RectF(
                x.toFloat(),
                y.toFloat(),
                (x + 128).toFloat(),
                (y + 128).toFloat()
            ),
            24f,
            24f,
            paint
        )
    }
}
