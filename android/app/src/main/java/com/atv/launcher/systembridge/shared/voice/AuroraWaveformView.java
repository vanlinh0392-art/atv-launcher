package com.atv.launcher.systembridge.shared.voice;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.os.Handler;
import android.os.Looper;
import android.util.AttributeSet;
import android.util.TypedValue;
import android.view.View;

public class AuroraWaveformView extends View {
    private static final int BAR_COUNT = 4;
    private static final int[] COLORS = {0xFF38BDF8, 0xFF818CF8, 0xFFC084FC, 0xFFF472B6}; // Gemini Sky Blue, Indigo, Purple, Pink

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF rect = new RectF();
    private final float[] currentFactors = new float[BAR_COUNT];
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private float targetRms = 0f;
    private float currentRms = 0f;
    private boolean isAnimating = false;
    private boolean isTtsMode = false;

    private final Runnable animRunnable = new Runnable() {
        @Override
        public void run() {
            if (!isAnimating) return;

            long time = System.currentTimeMillis();

            if (isTtsMode) {
                // Nhịp sóng phát âm sống động nhiều tầng khi TTS đang đọc
                for (int i = 0; i < BAR_COUNT; i++) {
                    float wave1 = (float) Math.sin(time * 0.008 + i * 1.35);
                    float wave2 = (float) Math.cos(time * 0.012 + i * 0.75);
                    float factor = 0.30f + 0.70f * Math.abs(wave1 * 0.6f + wave2 * 0.4f);
                    currentFactors[i] += (factor - currentFactors[i]) * 0.32f;
                }
            } else {
                currentRms += (targetRms - currentRms) * 0.24f;
                for (int i = 0; i < BAR_COUNT; i++) {
                    float wave = (float) Math.sin(time * 0.007 + i * 1.35);
                    float factor = Math.max(0.18f, Math.min(1.0f, (currentRms / 10.0f) * 0.72f + 0.28f * (wave + 1) * 0.5f));
                    currentFactors[i] += (factor - currentFactors[i]) * 0.35f;
                }
            }

            invalidate(); // Chỉ vẽ lại GPU, KHÔNG gọi requestLayout -> 0% rung lắc

            if (isAnimating) {
                mainHandler.postDelayed(this, 16);
            }
        }
    };

    public AuroraWaveformView(Context context) {
        super(context);
        init();
    }

    public AuroraWaveformView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }

    public AuroraWaveformView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init();
    }

    private void init() {
        paint.setStyle(Paint.Style.FILL);
        for (int i = 0; i < BAR_COUNT; i++) {
            currentFactors[i] = 0.25f;
        }
    }

    public void startAnimation() {
        if (!isAnimating) {
            isAnimating = true;
            mainHandler.post(animRunnable);
        }
    }

    public void setTtsMode(boolean ttsMode) {
        this.isTtsMode = ttsMode;
        if (ttsMode) {
            startAnimation();
        }
    }

    public void stopAnimation() {
        isAnimating = false;
        isTtsMode = false;
        targetRms = 0f;
        mainHandler.removeCallbacks(animRunnable);
        for (int i = 0; i < BAR_COUNT; i++) {
            currentFactors[i] = 0.25f;
        }
        invalidate();
    }

    public void setRms(float rms) {
        this.targetRms = Math.max(0, rms);
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int desiredWidth = dpToPx(54);
        int desiredHeight = dpToPx(36);
        setMeasuredDimension(desiredWidth, desiredHeight);
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        int width = getWidth();
        int height = getHeight();
        if (width <= 0 || height <= 0) return;

        float barWidth = dpToPx(7);
        float spacing = dpToPx(5);
        float totalWidth = (BAR_COUNT * barWidth) + ((BAR_COUNT - 1) * spacing);
        float startX = (width - totalWidth) / 2.0f;
        float cornerRadius = dpToPx(10);

        float minHeight = dpToPx(8);
        float maxHeight = dpToPx(28);

        for (int i = 0; i < BAR_COUNT; i++) {
            paint.setColor(COLORS[i]);
            float barH = minHeight + (maxHeight - minHeight) * currentFactors[i];
            float left = startX + i * (barWidth + spacing);
            float top = (height - barH) / 2.0f;
            float right = left + barWidth;
            float bottom = top + barH;

            rect.set(left, top, right, bottom);
            canvas.drawRoundRect(rect, cornerRadius, cornerRadius, paint);
        }
    }

    private int dpToPx(int dp) {
        return (int) TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                dp,
                getResources().getDisplayMetrics()
        );
    }
}
