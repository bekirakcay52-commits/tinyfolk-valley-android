#!/usr/bin/env bash
set -euo pipefail

ROOT="TinyValley"
echo "Creating project in ./${ROOT} ..."

mkdir -p "${ROOT}/app/src/main/java/com/tinyfolk/valley"
mkdir -p "${ROOT}/app/src/main"
mkdir -p "${ROOT}/.github/workflows"

# settings.gradle
cat > "${ROOT}/settings.gradle" <<'EOF'
rootProject.name = "TinyValley"
include ":app"
EOF

# build.gradle (project)
cat > "${ROOT}/build.gradle" <<'EOF'
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath "com.android.tools.build:gradle:8.1.0"
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.22"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
EOF

# app/build.gradle
cat > "${ROOT}/app/build.gradle" <<'EOF'
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
}

android {
    compileSdk 34

    defaultConfig {
        applicationId "com.tinyfolk.valley"
        minSdk 21
        targetSdk 34
        versionCode 1
        versionName "0.1"
    }

    buildTypes {
        debug {
            // debug APK auto-signed by Gradle/Android Studio
        }
        release {
            // Unsigned release (no signingConfig)
            isMinifyEnabled false
        }
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib:1.8.22"
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.core:core-ktx:1.10.1'
}
EOF

# AndroidManifest.xml
cat > "${ROOT}/app/src/main/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest package="com.tinyfolk.valley"
    xmlns:android="http://schemas.android.com/apk/res/android">

    <application
        android:label="Tiny Valley"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:allowBackup="true"
        android:supportsRtl="true">
        <activity android:name=".MainActivity"
                  android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>

</manifest>
EOF

# MainActivity.kt
cat > "${ROOT}/app/src/main/java/com/tinyfolk/valley/MainActivity.kt" <<'EOF'
package com.tinyfolk.valley

import android.content.Context
import android.graphics.*
import android.os.Bundle
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import androidx.appcompat.app.AppCompatActivity

/* =========================
   MAIN ACTIVITY
   ========================= */
class MainActivity : AppCompatActivity() {

    private lateinit var gameView: GameView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        gameView = GameView(this)
        setContentView(gameView)
    }

    override fun onResume() {
        super.onResume()
        gameView.resume()
    }

    override fun onPause() {
        gameView.pause()
        super.onPause()
    }
}

/* =========================
   GAME VIEW (GAME LOOP)
   ========================= */
class GameView(context: Context) : SurfaceView(context), SurfaceHolder.Callback, Runnable {

    @Volatile
    private var running = false
    private var thread: Thread? = null
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val buildings = mutableListOf<Building>()
    private val grid = GridMap()

    // Timing
    private var lastTimeNs: Long = 0L

    init {
        holder.addCallback(this)
        isFocusable = true
    }

    // SurfaceHolder.Callback
    override fun surfaceCreated(holder: SurfaceHolder) {
        startThread()
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        stopThread()
    }

    private fun startThread() {
        if (running) return
        running = true
        lastTimeNs = System.nanoTime()
        thread = Thread(this, "GameThread").also { it.start() }
    }

    private fun stopThread() {
        running = false
        try {
            thread?.join()
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        } finally {
            thread = null
        }
    }

    fun resume() {
        if (holder.surface.isValid) startThread()
    }

    fun pause() {
        stopThread()
    }

    override fun run() {
        while (running) {
            val now = System.nanoTime()
            val deltaSec = (now - lastTimeNs) / 1_000_000_000.0f
            lastTimeNs = now

            update(deltaSec.coerceAtMost(0.05f))
            render()

            try {
                Thread.sleep(16)
            } catch (e: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }
    }

    private fun update(delta: Float) {
        synchronized(buildings) {
            buildings.forEach { it.update(delta) }
        }
    }

    private fun render() {
        if (!holder.surface.isValid) return
        val canvas = holder.lockCanvas() ?: return
        try {
            canvas.drawColor(Color.rgb(190, 231, 232))
            drawGrid(canvas, paint)
            synchronized(buildings) {
                buildings.forEach { it.draw(canvas) }
            }
        } finally {
            holder.unlockCanvasAndPost(canvas)
        }
    }

    private fun drawGrid(canvas: Canvas, p: Paint) {
        p.style = Paint.Style.STROKE
        p.color = Color.argb(60, 0, 0, 0)
        p.strokeWidth = 1f
        val size = GridMap.CELL_SIZE
        var x = 0
        while (x < width) {
            canvas.drawLine(x.toFloat(), 0f, x.toFloat(), height.toFloat(), p)
            x += size
        }
        var y = 0
        while (y < height) {
            canvas.drawLine(0f, y.toFloat(), width.toFloat(), y.toFloat(), p)
            y += size
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_DOWN) {
            val (x, y) = grid.snap(event.x, event.y)
            synchronized(buildings) {
                buildings.add(Building(x, y))
            }
        }
        return true
    }
}

/* =========================
   GRID SYSTEM
   ========================= */
class GridMap {
    companion object {
        const val CELL_SIZE = 128
    }

    fun snap(x: Float, y: Float): Pair<Int, Int> {
        val gx = (x / CELL_SIZE).toInt() * CELL_SIZE
        val gy = (y / CELL_SIZE).toInt() * CELL_SIZE
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
        color = Color.rgb(141, 110, 99)
        style = Paint.Style.FILL
    }

    fun update(delta: Float) {
        // üretim / animasyon buraya eklenir
    }

    fun draw(canvas: Canvas) {
        val size = GridMap.CELL_SIZE.toFloat()
        canvas.drawRoundRect(
            RectF(
                x.toFloat(),
                y.toFloat(),
                x.toFloat() + size,
                y.toFloat() + size
            ),
            24f,
            24f,
            paint
        )
    }
}
EOF

# .gitignore
cat > "${ROOT}/.gitignore" <<'EOF'
.gradle/
local.properties
/.idea/
/build/
/app/build/
/captures/
/.gradle/
*.iml
EOF

# README.md
cat > "${ROOT}/README.md" <<'EOF'
TinyValley — Build instructions

1) Repo oluştur ve bu dosyaları koy:
   - settings.gradle
   - build.gradle
   - app/ (içeriği yukarıda)
   - .github/workflows/build-apk.yml
   - .gitignore
   - README.md

2) Commit & push:
   git init
   git add .
   git commit -m "Initial TinyValley project"
   git branch -M main
   git remote add origin https://github.com/YOURUSERNAME/YOURREPO.git
   git push -u origin main

3) GitHub Actions:
   - Push sonrası Actions sekmesinden workflow çalışacaktır.
   - Başarılı run tamamlandığında Actions > ilgili run sayfasında "Artifacts" altında app-debug-apk göreceksin.
   - Artifact'i indir, içinde debug APK vardır: app-debug.apk (bu APK debug anahtarı ile imzalanmıştır, doğrudan adb install ile cihaza yükleyebilirsin).

Alternatif — Lokal build:
- Eğer Android Studio kullanacaksan: projeyi aç, Build > Build APK(s).
- Komut satırı:
  - Eğer gradle wrapper yoksa (biz wrapper dosyalarını eklemedik) runner tarafında gradle yoksa:
    - Lokal makinanda: gradle wrapper --gradle-version 8.3
    - Sonra ./gradlew assembleDebug
  - veya Android Studio wrapper oluşturacaktır.

Not:
- Unsigned release APK doğrudan cihaza yüklenemez; debug APK cihaza yüklenebilir.
EOF

# GitHub Actions workflow
cat > "${ROOT}/.github/workflows/build-apk.yml" <<'EOF'
name: Build Debug APK

on:
  push:
    branches:
      - main
      - master
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"

      - name: Build debug APK (using Gradle action)
        uses: gradle/gradle-build-action@v3
        with:
          gradle-version: 8.3
          arguments: assembleDebug

      - name: Upload Debug APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: app-debug-apk
          path: app/build/outputs/apk/debug/
EOF

# Optionally create Gradle wrapper if gradle is available
if command -v gradle >/dev/null 2>&1; then
  echo "Gradle detected on system — generating Gradle wrapper (gradlew) with gradle wrapper --gradle-version 8.3 ..."
  (cd "${ROOT}" && gradle wrapper --gradle-version 8.3)
else
  echo "Gradle not found locally. Gradle wrapper not created. You can create it later with 'gradle wrapper --gradle-version 8.3' or open project in Android Studio to generate it."
fi

# Create the zip
ZIPNAME="TinyValley.zip"
if [ -f "${ZIPNAME}" ]; then
  rm -f "${ZIPNAME}"
fi

echo "Creating zip: ${ZIPNAME} ..."
zip -r "${ZIPNAME}" "${ROOT}" >/dev/null

echo "Done. Created ${ZIPNAME} in current directory."
echo "Contents:"
unzip -l "${ZIPNAME}" | sed -n '1,10p'
echo ""
echo "You can now upload ${ZIPNAME} to GitHub or unzip locally."
EOF

Kısa ve net: betiği oluşturup çalıştır; TinyValley.zip üretilecek. Yardım istersen betiği senin için doğrudan düzenleyip içerik değişiklikleri yaparım (ör. farklı package, uygulama adı, veya gradle wrapper'ı dahil etme). Hemen şimdi betiği çalıştırıp ZIP'i elde etmek ister misin, yoksa başka bir değişiklik yapayım mı?