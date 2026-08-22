/**
 * This file is a part of media_kit (https://github.com/media-kit/media-kit).
 * <p>
 * Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
 * All rights reserved.
 * Use of this source code is governed by MIT license that can be found in the LICENSE file.
 */
package com.alexmercerind.media_kit_video;

import android.content.Context;
import android.view.SurfaceView;
import android.view.View;

import java.util.Map;

import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

/**
 * Creates the {@link SurfaceView} platform views used by the SurfaceView video output path.
 * The creation params carry the player {@code handle}; the created view is attached to the
 * {@link SurfaceViewVideoOutput} previously registered under that handle by
 * {@code VideoOutputManager.Create}.
 */
public class SurfaceViewFactory extends PlatformViewFactory {
    public static final String VIEW_TYPE = "com.alexmercerind/media_kit_video/surface_view";

    private final VideoOutputManager videoOutputManager;

    SurfaceViewFactory(VideoOutputManager videoOutputManager) {
        super(StandardMessageCodec.INSTANCE);
        this.videoOutputManager = videoOutputManager;
    }

    @Override
    public PlatformView create(Context context, int viewId, Object args) {
        @SuppressWarnings("unchecked") final Map<String, Object> params = (Map<String, Object>) args;
        final long handle = ((Number) params.get("handle")).longValue();

        final SurfaceView surfaceView = new SurfaceView(context);
        final SurfaceViewVideoOutput videoOutput = videoOutputManager.getSurfaceViewOutput(handle);
        if (videoOutput != null) {
            videoOutput.attach(surfaceView);
        }

        return new PlatformView() {
            @Override
            public View getView() {
                return surfaceView;
            }

            @Override
            public void dispose() {
                final SurfaceViewVideoOutput output = videoOutputManager.getSurfaceViewOutput(handle);
                if (output != null) {
                    output.detach(surfaceView);
                }
            }
        };
    }
}
