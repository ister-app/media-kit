// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/texture_gl.h"

#include <epoxy/gl.h>
#include <epoxy/egl.h>

// glEGLImageTargetTexture2DOES extension function pointer.
typedef void (*PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)(GLenum target,
                                                    GLeglImageOES image);

#ifndef glEGLImageTargetTexture2DOES
static PFNGLEGLIMAGETARGETTEXTURE2DOESPROC glEGLImageTargetTexture2DOES = NULL;
#endif

static gpointer init_extensions_once(gpointer data) {
#ifndef glEGLImageTargetTexture2DOES
  glEGLImageTargetTexture2DOES =
      (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)eglGetProcAddress(
          "glEGLImageTargetTexture2DOES");
#endif
  return NULL;
}

static void init_egl_image_extensions() {
  static GOnce once = G_ONCE_INIT;
  g_once(&once, init_extensions_once, NULL);
}

// ---------------------------------------------------------------------------
// _TextureGL — owns only the Flutter-side GL texture name.
// The FBO, mpv texture, and EGLImages live in VideoOutput's double-buffer.
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
  init_egl_image_extensions();
  TextureGL* self = TEXTURE_GL(g_object_new(texture_gl_get_type(), NULL));
  self->video_output = video_output;
  return self;
}

// ---------------------------------------------------------------------------
// populate_texture — called on Flutter's raster thread.
//
// No EGL context switch: we just read the front EGLImage produced by the
// render thread and bind it to a Flutter GL texture.
// ---------------------------------------------------------------------------

gboolean texture_gl_populate_texture(FlTextureGL* texture,
                                     guint32* target,
                                     guint32* name,
                                     guint32* width,
                                     guint32* height,
                                     GError** error) {
  TextureGL* self = TEXTURE_GL(texture);
  VideoOutput* video_output = self->video_output;

  // Atomically snapshot the front buffer state.
  EGLImageKHR front = EGL_NO_IMAGE_KHR;
  guint32 fw = 0, fh = 0;
  gboolean dirty = FALSE;
  gboolean valid =
      video_output_get_front_image(video_output, &front, &fw, &fh, &dirty);

  if (!valid) {
    // No valid frame yet — create a 1×1 placeholder on first call, otherwise
    // keep returning the last valid frame (avoids spurious 1×1 resize events).
    if (self->name == 0) {
      glGenTextures(1, &self->name);
      glBindTexture(GL_TEXTURE_2D, self->name);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_RGBA,
                   GL_UNSIGNED_BYTE, NULL);
      glBindTexture(GL_TEXTURE_2D, 0);
      self->current_width = 1;
      self->current_height = 1;
    }
    *target = GL_TEXTURE_2D;
    *name = self->name;
    *width = self->current_width;
    *height = self->current_height;
    return TRUE;
  }

  // Create Flutter's texture on first use.
  if (self->name == 0) {
    glGenTextures(1, &self->name);
    glBindTexture(GL_TEXTURE_2D, self->name);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    dirty = TRUE; // force initial bind
  }

  // Rebind whenever the render thread produced a new frame.
  if (dirty) {
    glBindTexture(GL_TEXTURE_2D, self->name);
    glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, (GLeglImageOES)front);
    glBindTexture(GL_TEXTURE_2D, 0);
  }

  // Notify Flutter about dimension changes.
  if (self->current_width != fw || self->current_height != fh) {
    self->current_width = fw;
    self->current_height = fh;
    video_output_notify_texture_update(video_output);
  }

  *target = GL_TEXTURE_2D;
  *name = self->name;
  *width = self->current_width;
  *height = self->current_height;
  return TRUE;
}
