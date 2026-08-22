/**
 * This file is a part of media_kit (https://github.com/media-kit/media-kit).
 * <p>
 * Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
 * All rights reserved.
 * Use of this source code is governed by MIT license that can be found in the LICENSE file.
 */
package com.alexmercerind.media_kit_video;

import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Locale;
import java.util.Objects;

/**
 * A video output backed by a real {@link SurfaceView} (embedded as a platform view) instead of a
 * Flutter texture. SurfaceFlinger composites the SurfaceView's surface directly, which is what
 * makes HDR passthrough and {@link Surface#setFrameRate} possible — a Flutter texture is always
 * composited into the engine's own (SDR, 8-bit) scene.
 * <p>
 * The {@link SurfaceView} itself is created by {@link SurfaceViewFactory} when the corresponding
 * platform view is embedded on the Dart side; this object is created earlier, by
 * {@code VideoOutputManager.Create}, and the two meet in {@link #attach}.
 */
public class SurfaceViewVideoOutput implements SurfaceHolder.Callback {
    private static final String TAG = "SurfaceViewVideoOutput";
    private static final Method newGlobalObjectRef;
    private static final Method deleteGlobalObjectRef;
    private static final Handler handler = new Handler(Looper.getMainLooper());

    static {
        try {
            final Class<?> mediaKitAndroidHelperClass = Class.forName("com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper");
            newGlobalObjectRef = mediaKitAndroidHelperClass.getDeclaredMethod("newGlobalObjectRef", Object.class);
            deleteGlobalObjectRef = mediaKitAndroidHelperClass.getDeclaredMethod("deleteGlobalObjectRef", long.class);
            newGlobalObjectRef.setAccessible(true);
            deleteGlobalObjectRef.setAccessible(true);
        } catch (Throwable e) {
            Log.i("media_kit", "package:media_kit_libs_android_video missing. Make sure you have added it to pubspec.yaml.");
            throw new RuntimeException("Failed to initialize com.alexmercerind.media_kit_video.SurfaceViewVideoOutput.");
        }
    }

    private long wid = 0;
    private SurfaceView surfaceView;
    private float requestedFrameRate = 0.0f;
    private int pendingWidth = 0;
    private int pendingHeight = 0;

    /**
     * All currently alive platform views for this output, in attach order.
     * More than one can be alive at once: on a route change (e.g. entering
     * fullscreen) Flutter creates the new platform view while the old page —
     * still mounted below the route — keeps its view. The latest attached view
     * is the one mpv renders into; when it goes away (leaving fullscreen), the
     * output falls back to the previous still-alive view, whose surface will
     * NOT fire surfaceChanged again and must be re-published explicitly.
     */
    private final ArrayList<SurfaceView> views = new ArrayList<>();

    private final TextureUpdateCallback textureUpdateCallback;
    private final Object lock = new Object();

    SurfaceViewVideoOutput(TextureUpdateCallback textureUpdateCallback) {
        this.textureUpdateCallback = textureUpdateCallback;
    }

    /** Binds the platform view's SurfaceView. Called from {@link SurfaceViewFactory}. */
    public void attach(SurfaceView view) {
        synchronized (lock) {
            views.remove(view);
            views.add(view);
            makeCurrent(view);
        }
    }

    /** Unbinds the platform view's SurfaceView. Called when the platform view is disposed. */
    public void detach(SurfaceView view) {
        synchronized (lock) {
            views.remove(view);
            view.getHolder().removeCallback(this);
            if (surfaceView == view) {
                // The current surface is going away: follow the wid=0/vo=null
                // protocol before the surface dies.
                textureUpdateCallback.onTextureUpdate(-1, 0, 0, 0);
                releaseWid();
                surfaceView = null;
                if (!views.isEmpty()) {
                    makeCurrent(views.get(views.size() - 1));
                }
            }
        }
    }

    private void makeCurrent(SurfaceView view) {
        if (surfaceView == view) {
            return;
        }
        if (surfaceView != null) {
            surfaceView.getHolder().removeCallback(this);
        }
        releaseWid();
        surfaceView = view;
        // The wanted buffer size usually arrives (via setSurfaceSize) before
        // the platform view exists — apply it now.
        if (pendingWidth > 0 && pendingHeight > 0) {
            view.getHolder().setFixedSize(pendingWidth, pendingHeight);
        }
        view.getHolder().addCallback(this);
        publishIfValid();
    }

    /**
     * Hands an already-live surface to mpv. Needed when falling back to a view
     * whose surface was created long ago: SurfaceHolder only fires
     * surfaceChanged on actual changes, so nothing would re-deliver the wid.
     */
    private void publishIfValid() {
        if (surfaceView == null) {
            return;
        }
        final SurfaceHolder holder = surfaceView.getHolder();
        final Surface surface = holder.getSurface();
        if (surface == null || !surface.isValid()) {
            return;
        }
        final int width = holder.getSurfaceFrame().width();
        final int height = holder.getSurfaceFrame().height();
        if (width <= 0 || height <= 0) {
            return;
        }
        Log.i(TAG, String.format(Locale.ENGLISH, "publishIfValid: %d %d", width, height));
        wid = newGlobalObjectRef(surface);
        textureUpdateCallback.onTextureUpdate(-1, wid, width, height);
        applyFrameRate();
    }

    private boolean isCurrent(SurfaceHolder holder) {
        return surfaceView != null && surfaceView.getHolder() == holder;
    }

    public void dispose() {
        synchronized (lock) {
            for (final SurfaceView view : views) {
                view.getHolder().removeCallback(this);
            }
            views.clear();
            surfaceView = null;
            releaseWid();
        }
    }

    /**
     * Matches the texture path's contract: mpv renders at exactly
     * {@code android-surface-size}, so pin the buffer size to it; SurfaceFlinger scales the
     * buffer to the view.
     */
    public void setSurfaceSize(int width, int height) {
        synchronized (lock) {
            if (width <= 0 || height <= 0) {
                return;
            }
            pendingWidth = width;
            pendingHeight = height;
            if (surfaceView != null) {
                surfaceView.getHolder().setFixedSize(width, height);
            }
        }
    }

    /**
     * Requests a display refresh rate matching the content's frame rate. {@code fps = 0} clears
     * the request. No-op before API 30 (setFrameRate) resp. API 31 (change strategy).
     */
    public void setFrameRate(float fps) {
        synchronized (lock) {
            requestedFrameRate = fps;
            applyFrameRate();
        }
    }

    private void applyFrameRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || surfaceView == null) {
            return;
        }
        final Surface surface = surfaceView.getHolder().getSurface();
        if (surface == null || !surface.isValid()) {
            return;
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                surface.setFrameRate(
                        requestedFrameRate,
                        Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE,
                        Surface.CHANGE_FRAME_RATE_ONLY_IF_SEAMLESS);
            } else {
                surface.setFrameRate(requestedFrameRate, Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE);
            }
            Log.i(TAG, String.format(Locale.ENGLISH, "setFrameRate: %f", requestedFrameRate));
        } catch (Throwable e) {
            Log.e(TAG, "setFrameRate", e);
        }
    }

    // --- SurfaceHolder.Callback ---

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        Log.i(TAG, "surfaceCreated");
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        synchronized (lock) {
            if (!isCurrent(holder)) {
                Log.i(TAG, "surfaceChanged: stale holder, ignored");
                return;
            }
            Log.i(TAG, String.format(Locale.ENGLISH, "surfaceChanged: %d %d", width, height));
            // The Surface object survives size changes; only take a new global ref when the
            // underlying surface actually changed (first attach / re-creation after destroy).
            if (wid == 0) {
                wid = newGlobalObjectRef(holder.getSurface());
            }
            textureUpdateCallback.onTextureUpdate(-1, wid, width, height);
            applyFrameRate();
        }
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        synchronized (lock) {
            if (!isCurrent(holder)) {
                Log.i(TAG, "surfaceDestroyed: stale holder, ignored");
                return;
            }
            Log.i(TAG, "surfaceDestroyed");
            // Same protocol as the texture path's onSurfaceCleanup: tell Dart to drop --wid
            // (vo=null) before the surface goes away, release the global ref shortly after.
            textureUpdateCallback.onTextureUpdate(-1, 0, 0, 0);
            releaseWid();
        }
    }

    private void releaseWid() {
        if (wid != 0) {
            final long widReference = wid;
            wid = 0;
            handler.postDelayed(() -> deleteGlobalObjectRef(widReference), 5000);
        }
    }

    private static long newGlobalObjectRef(Object object) {
        Log.i(TAG, String.format(Locale.ENGLISH, "newGlobalRef: object = %s", object));
        try {
            return (long) Objects.requireNonNull(newGlobalObjectRef.invoke(null, object));
        } catch (Throwable e) {
            Log.e(TAG, "newGlobalRef", e);
            return 0;
        }
    }

    private static void deleteGlobalObjectRef(long ref) {
        Log.i(TAG, String.format(Locale.ENGLISH, "deleteGlobalObjectRef: ref = %d", ref));
        try {
            deleteGlobalObjectRef.invoke(null, ref);
        } catch (Throwable e) {
            Log.e(TAG, "deleteGlobalObjectRef", e);
        }
    }
}
