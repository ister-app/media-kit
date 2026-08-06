// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/texture_gl.h"

#include <epoxy/gl.h>

// ---------------------------------------------------------------------------
// _TextureGL — owns only the Flutter-side GL texture name.
// The FBOs, mpv textures and EGLImages live in VideoOutput's buffer ring.
// ---------------------------------------------------------------------------

struct _TextureGL {
  FlTextureGL parent_instance;
  guint32 name;           /* Flutter GL texture name (raster thread only). */
  guint32 current_width;
  guint32 current_height;
  VideoOutput* video_output;
};

G_DEFINE_TYPE(TextureGL, texture_gl, fl_texture_gl_get_type())

static void texture_gl_init(TextureGL* self) {
  self->name = 0;
  self->current_width = 1;
  self->current_height = 1;
  self->video_output = NULL;
}

static void texture_gl_dispose(GObject* object) {
  TextureGL* self = TEXTURE_GL(object);

  // Delete Flutter's texture in the current (Flutter raster) context.
  if (self->name != 0) {
    glDeleteTextures(1, &self->name);
    self->name = 0;
  }

  self->current_width = 1;
  self->current_height = 1;
  self->video_output = NULL;
  G_OBJECT_CLASS(texture_gl_parent_class)->dispose(object);
}

static void texture_gl_class_init(TextureGLClass* klass) {
  FL_TEXTURE_GL_CLASS(klass)->populate = texture_gl_populate_texture;
  G_OBJECT_CLASS(klass)->dispose = texture_gl_dispose;
}

TextureGL* texture_gl_new(VideoOutput* video_output) {
  TextureGL* self = TEXTURE_GL(g_object_new(texture_gl_get_type(), NULL));
  self->video_output = video_output;
  return self;
}

// ---------------------------------------------------------------------------
// populate_texture — called on Flutter's raster thread.
//
// No EGL context switch: VideoOutput binds the newest EGLImage produced by
// the render thread to our GL texture (atomically under its buffer mutex).
// ---------------------------------------------------------------------------

gboolean texture_gl_populate_texture(FlTextureGL* texture,
                                     guint32* target,
                                     guint32* name,
                                     guint32* width,
                                     guint32* height,
                                     GError** error) {
  TextureGL* self = TEXTURE_GL(texture);
  VideoOutput* video_output = self->video_output;

  // Create Flutter's texture on first use, with 1×1 placeholder storage so
  // sampling is defined until the first video frame is bound.
  if (self->name == 0) {
    glGenTextures(1, &self->name);
    glBindTexture(GL_TEXTURE_2D, self->name);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_RGBA,
                 GL_UNSIGNED_BYTE, NULL);
    glBindTexture(GL_TEXTURE_2D, 0);
    self->current_width = 1;
    self->current_height = 1;
  }

  guint32 fw = 0, fh = 0;
  gboolean valid =
      video_output_bind_display_image(video_output, self->name, &fw, &fh);

  if (valid) {
    // Notify Flutter about dimension changes.
    if (self->current_width != fw || self->current_height != fh) {
      self->current_width = fw;
      self->current_height = fh;
      video_output_notify_texture_update(video_output);
    }
  }
  // When no valid frame exists yet, keep reporting the placeholder (or the
  // last valid) dimensions — avoids spurious 1×1 resize events.

  *target = GL_TEXTURE_2D;
  *name = self->name;
  *width = self->current_width;
  *height = self->current_height;
  return TRUE;
}
