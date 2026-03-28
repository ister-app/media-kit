// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/video_output.h"
#include "include/media_kit_video/texture_gl.h"
#include "include/media_kit_video/texture_sw.h"

#include <epoxy/egl.h>
#include <epoxy/gl.h>
#include <epoxy/glx.h>
#include <gdk/gdkwayland.h>
#include <gdk/gdkx.h>

// EGL extension function pointers (file-scope statics, guarded to avoid
// redefinition when epoxy already provides the symbol as a macro/function).
#ifndef eglCreateImageKHR
static EGLImageKHR (*eglCreateImageKHR)(EGLDisplay, EGLContext, EGLenum,
                                        EGLClientBuffer,
                                        const EGLint*) = NULL;
#endif
#ifndef eglDestroyImageKHR
static EGLBoolean (*eglDestroyImageKHR)(EGLDisplay, EGLImageKHR) = NULL;
#endif
// EGL_KHR_fence_sync
#ifndef eglCreateSyncKHR
static EGLSyncKHR (*eglCreateSyncKHR)(EGLDisplay, EGLenum,
                                      const EGLint*) = NULL;
#endif
#ifndef eglDestroySyncKHR
static EGLBoolean (*eglDestroySyncKHR)(EGLDisplay, EGLSyncKHR) = NULL;
#endif
#ifndef eglClientWaitSyncKHR
static EGLint (*eglClientWaitSyncKHR)(EGLDisplay, EGLSyncKHR, EGLint,
                                      EGLTimeKHR) = NULL;
#endif

static gpointer vo_init_egl_extensions_once(gpointer data) {
#ifndef eglCreateImageKHR
  eglCreateImageKHR =
      (EGLImageKHR(*)(EGLDisplay, EGLContext, EGLenum, EGLClientBuffer,
                      const EGLint*))eglGetProcAddress("eglCreateImageKHR");
#endif
#ifndef eglDestroyImageKHR
  eglDestroyImageKHR = (EGLBoolean(*)(EGLDisplay,
                                      EGLImageKHR))eglGetProcAddress(
      "eglDestroyImageKHR");
#endif
#ifndef eglCreateSyncKHR
  eglCreateSyncKHR = (EGLSyncKHR(*)(EGLDisplay, EGLenum,
                                    const EGLint*))eglGetProcAddress(
      "eglCreateSyncKHR");
#endif
#ifndef eglDestroySyncKHR
  eglDestroySyncKHR =
      (EGLBoolean(*)(EGLDisplay, EGLSyncKHR))eglGetProcAddress(
          "eglDestroySyncKHR");
#endif
#ifndef eglClientWaitSyncKHR
  eglClientWaitSyncKHR =
      (EGLint(*)(EGLDisplay, EGLSyncKHR, EGLint,
                 EGLTimeKHR))eglGetProcAddress("eglClientWaitSyncKHR");
#endif
  return NULL;
}

static void vo_init_egl_extensions() {
  static GOnce once = G_ONCE_INIT;
  g_once(&once, vo_init_egl_extensions_once, NULL);
}

struct _VideoOutput {
  GObject parent_instance;
  TextureGL* texture_gl;
  EGLDisplay egl_display; /* EGL display (shared with Flutter). */
  EGLContext egl_context; /* Isolated EGL context owned by render thread. */
  EGLSurface egl_surface; /* Placeholder surface (unused). */
  guint8* pixel_buffer;
  TextureSW* texture_sw;
  GMutex mutex; /* S/W rendering only. */
  mpv_handle* handle;
  mpv_render_context* render_context;
  gint64 width;
  gint64 height;
  VideoOutputConfiguration configuration;
  TextureUpdateCallback texture_update_callback;
  gpointer texture_update_callback_context;
  GDestroyNotify texture_update_callback_context_destroy;
  FlTextureRegistrar* texture_registrar;
  gboolean destroyed;

  /* ---- Render thread ---- */
  GThread* render_thread;
  GMutex render_mutex; /* guards render_requested + destroyed */
  GCond render_cond;
  gboolean render_requested;

  /* ---- Back buffer (render thread only) ---- */
  GLuint back_fbo;
  GLuint back_mpv_texture;
  EGLImageKHR back_egl_image;
  guint32 back_width;
  guint32 back_height;

  /* ---- Front buffer (shared, protected by front_mutex) ---- */
  GMutex front_mutex;
  GLuint front_fbo;
  GLuint front_mpv_texture;
  EGLImageKHR front_egl_image;
  guint32 front_width;
  guint32 front_height;
  gboolean front_dirty;

  /* ---- Video-dimensions cache (avoids mpv_get_property every frame) ---- */
  GMutex dims_mutex;
  gint64 cached_dw;
  gint64 cached_dh;
  gint64 cached_rotate;
  gboolean dims_valid; /* FALSE = cache must be refreshed from mpv */
};

G_DEFINE_TYPE(VideoOutput, video_output, G_TYPE_OBJECT)

// ---------------------------------------------------------------------------
// Render thread
// ---------------------------------------------------------------------------

static gpointer render_thread_func(gpointer data) {
  VideoOutput* self = (VideoOutput*)data;

  // Take ownership of egl_context on this thread.
  eglMakeCurrent(self->egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                 self->egl_context);

  g_mutex_lock(&self->render_mutex);
  while (TRUE) {
    while (!self->render_requested && !self->destroyed)
      g_cond_wait(&self->render_cond, &self->render_mutex);

    if (self->destroyed) {
      g_mutex_unlock(&self->render_mutex);
      break;
    }

    self->render_requested = FALSE;
    g_mutex_unlock(&self->render_mutex);

    gint32 w = (gint32)video_output_get_width(self);
    gint32 h = (gint32)video_output_get_height(self);

    if (w > 0 && h > 0) {
      // Rebuild back buffer when dimensions changed (or on first frame when
      // back resources are still zero / came from initial front swap).
      if (w != (gint32)self->back_width || h != (gint32)self->back_height) {
        // Destroy stale back resources.
        if (self->back_egl_image != EGL_NO_IMAGE_KHR) {
          eglDestroyImageKHR(self->egl_display, self->back_egl_image);
          self->back_egl_image = EGL_NO_IMAGE_KHR;
        }
        if (self->back_fbo) {
          glDeleteFramebuffers(1, &self->back_fbo);
          self->back_fbo = 0;
        }
        if (self->back_mpv_texture) {
          glDeleteTextures(1, &self->back_mpv_texture);
          self->back_mpv_texture = 0;
        }

        // Create texture.
        glGenTextures(1, &self->back_mpv_texture);
        glBindTexture(GL_TEXTURE_2D, self->back_mpv_texture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA,
                     GL_UNSIGNED_BYTE, NULL);
        glBindTexture(GL_TEXTURE_2D, 0);

        // Create FBO.
        glGenFramebuffers(1, &self->back_fbo);
        glBindFramebuffer(GL_FRAMEBUFFER, self->back_fbo);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                               GL_TEXTURE_2D, self->back_mpv_texture, 0);
        GLenum fbo_status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        if (fbo_status != GL_FRAMEBUFFER_COMPLETE) {
          g_printerr(
              "media_kit: render_thread: Framebuffer incomplete: 0x%x\n",
              fbo_status);
          glDeleteFramebuffers(1, &self->back_fbo);
          self->back_fbo = 0;
          glDeleteTextures(1, &self->back_mpv_texture);
          self->back_mpv_texture = 0;
          g_mutex_lock(&self->render_mutex);
          continue;
        }

        // Create EGLImage from the new texture.
        EGLint img_attribs[] = {EGL_NONE};
        self->back_egl_image = eglCreateImageKHR(
            self->egl_display, self->egl_context, EGL_GL_TEXTURE_2D_KHR,
            (EGLClientBuffer)(guintptr)self->back_mpv_texture, img_attribs);

        self->back_width = (guint32)w;
        self->back_height = (guint32)h;
      }

      // Render mpv frame into back buffer.
      mpv_opengl_fbo fbo = {(gint32)self->back_fbo, w, h, 0};
      int flip_y = 0;
      mpv_render_param params[] = {
          {MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
          {MPV_RENDER_PARAM_FLIP_Y, &flip_y},
          {MPV_RENDER_PARAM_INVALID, NULL},
      };
      mpv_render_context_render(self->render_context, params);

      // Wait for the GPU to finish rendering before swapping. A fence sync
      // is more precise than glFinish(): it inserts a marker into the command
      // stream and blocks only until that point is reached.
      if (eglCreateSyncKHR && eglClientWaitSyncKHR && eglDestroySyncKHR) {
        EGLSyncKHR sync =
            eglCreateSyncKHR(self->egl_display, EGL_SYNC_FENCE_KHR, NULL);
        if (sync != EGL_NO_SYNC_KHR) {
          eglClientWaitSyncKHR(self->egl_display, sync,
                               EGL_SYNC_FLUSH_COMMANDS_BIT_KHR,
                               EGL_FOREVER_KHR);
          eglDestroySyncKHR(self->egl_display, sync);
        } else {
          glFlush();
        }
      } else {
        glFlush();
      }

      // Swap back <-> front (full resource swap, no GPU copy).
      g_mutex_lock(&self->front_mutex);

      EGLImageKHR tmp_img = self->front_egl_image;
      self->front_egl_image = self->back_egl_image;
      self->back_egl_image = tmp_img;

      GLuint tmp_fbo = self->front_fbo;
      self->front_fbo = self->back_fbo;
      self->back_fbo = tmp_fbo;

      GLuint tmp_tex = self->front_mpv_texture;
      self->front_mpv_texture = self->back_mpv_texture;
      self->back_mpv_texture = tmp_tex;

      guint32 tmp_w = self->front_width;
      guint32 tmp_h = self->front_height;
      self->front_width = self->back_width;
      self->front_height = self->back_height;
      self->back_width = tmp_w;
      self->back_height = tmp_h;

      self->front_dirty = TRUE;
      g_mutex_unlock(&self->front_mutex);

      fl_texture_registrar_mark_texture_frame_available(
          self->texture_registrar, FL_TEXTURE(self->texture_gl));
    }

    g_mutex_lock(&self->render_mutex);
  }

  // Release egl_context before the thread exits.
  eglMakeCurrent(self->egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                 EGL_NO_CONTEXT);
  return NULL;
}

// ---------------------------------------------------------------------------
// GObject lifecycle
// ---------------------------------------------------------------------------

static void video_output_dispose(GObject* object) {
  VideoOutput* self = VIDEO_OUTPUT(object);

  // H/W
  if (self->texture_gl) {
    // 1. Stop mpv from firing new render callbacks.
    if (self->render_context) {
      mpv_render_context_set_update_callback(self->render_context, NULL, NULL);
    }

    // 2. Unregister the Flutter texture so populate_texture is never called
    //    again. Keep texture_gl alive until after thread join to prevent the
    //    render thread from reading a dangling FL_TEXTURE(self->texture_gl).
    fl_texture_registrar_unregister_texture(self->texture_registrar,
                                            FL_TEXTURE(self->texture_gl));

    // 3. Signal render thread to stop.
    g_mutex_lock(&self->render_mutex);
    self->destroyed = TRUE;
    g_cond_signal(&self->render_cond);
    g_mutex_unlock(&self->render_mutex);

    // 4. Wait for render thread to finish (it releases egl_context first).
    if (self->render_thread) {
      g_thread_join(self->render_thread);
      self->render_thread = NULL;
    }

    // 5a. Safe to release texture_gl now — render thread has exited.
    g_object_unref(self->texture_gl);
    self->texture_gl = NULL;

    // 5b. Make egl_context current on this thread for resource cleanup.
    if (self->egl_context != EGL_NO_CONTEXT) {
      eglMakeCurrent(self->egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                     self->egl_context);
    }

    // 6. Free mpv render context.
    if (self->render_context) {
      mpv_render_context_free(self->render_context);
      self->render_context = NULL;
    }

    // 7. Clean up all GL/EGL resources (egl_context is current).
    if (self->back_egl_image != EGL_NO_IMAGE_KHR) {
      eglDestroyImageKHR(self->egl_display, self->back_egl_image);
      self->back_egl_image = EGL_NO_IMAGE_KHR;
    }
    if (self->back_fbo) {
      glDeleteFramebuffers(1, &self->back_fbo);
      self->back_fbo = 0;
    }
    if (self->back_mpv_texture) {
      glDeleteTextures(1, &self->back_mpv_texture);
      self->back_mpv_texture = 0;
    }
    if (self->front_egl_image != EGL_NO_IMAGE_KHR) {
      eglDestroyImageKHR(self->egl_display, self->front_egl_image);
      self->front_egl_image = EGL_NO_IMAGE_KHR;
    }
    if (self->front_fbo) {
      glDeleteFramebuffers(1, &self->front_fbo);
      self->front_fbo = 0;
    }
    if (self->front_mpv_texture) {
      glDeleteTextures(1, &self->front_mpv_texture);
      self->front_mpv_texture = 0;
    }

    // 8. Release and destroy the isolated EGL context.
    if (self->egl_context != EGL_NO_CONTEXT) {
      eglMakeCurrent(self->egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                     EGL_NO_CONTEXT);
      eglDestroyContext(self->egl_display, self->egl_context);
      self->egl_context = EGL_NO_CONTEXT;
    }
  }

  // S/W
  if (self->texture_sw) {
    fl_texture_registrar_unregister_texture(self->texture_registrar,
                                            FL_TEXTURE(self->texture_sw));
    g_free(self->pixel_buffer);
    g_object_unref(self->texture_sw);
    self->destroyed = TRUE;
    if (self->render_context != NULL) {
      mpv_render_context_free(self->render_context);
      self->render_context = NULL;
    }
  }

  if (self->texture_update_callback_context_destroy &&
      self->texture_update_callback_context) {
    self->texture_update_callback_context_destroy(
        self->texture_update_callback_context);
    self->texture_update_callback_context = NULL;
  }

  g_mutex_clear(&self->mutex);
  g_mutex_clear(&self->render_mutex);
  g_cond_clear(&self->render_cond);
  g_mutex_clear(&self->front_mutex);
  g_mutex_clear(&self->dims_mutex);
  G_OBJECT_CLASS(video_output_parent_class)->dispose(object);
}

static void video_output_class_init(VideoOutputClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = video_output_dispose;
}

static void video_output_init(VideoOutput* self) {
  self->texture_gl = NULL;
  self->egl_display = EGL_NO_DISPLAY;
  self->egl_context = EGL_NO_CONTEXT;
  self->egl_surface = EGL_NO_SURFACE;
  self->texture_sw = NULL;
  self->pixel_buffer = NULL;
  self->handle = NULL;
  self->render_context = NULL;
  self->width = 0;
  self->height = 0;
  self->configuration = VideoOutputConfiguration{};
  self->texture_update_callback = NULL;
  self->texture_update_callback_context = NULL;
  self->texture_update_callback_context_destroy = NULL;
  self->texture_registrar = NULL;
  self->destroyed = FALSE;
  g_mutex_init(&self->mutex);

  // Render thread.
  self->render_thread = NULL;
  self->render_requested = FALSE;
  g_mutex_init(&self->render_mutex);
  g_cond_init(&self->render_cond);

  // Back buffer.
  self->back_fbo = 0;
  self->back_mpv_texture = 0;
  self->back_egl_image = EGL_NO_IMAGE_KHR;
  self->back_width = 0;
  self->back_height = 0;

  // Front buffer.
  g_mutex_init(&self->front_mutex);
  self->front_fbo = 0;
  self->front_mpv_texture = 0;
  self->front_egl_image = EGL_NO_IMAGE_KHR;
  self->front_width = 0;
  self->front_height = 0;
  self->front_dirty = FALSE;

  // Dimensions cache.
  g_mutex_init(&self->dims_mutex);
  self->cached_dw = 0;
  self->cached_dh = 0;
  self->cached_rotate = 0;
  self->dims_valid = FALSE;
}

VideoOutput* video_output_new(FlTextureRegistrar* texture_registrar,
                              FlView* view,
                              gint64 handle,
                              VideoOutputConfiguration configuration) {
  VideoOutput* self = VIDEO_OUTPUT(g_object_new(video_output_get_type(), NULL));
  self->texture_registrar = texture_registrar;
  self->handle = (mpv_handle*)handle;
  self->width = configuration.width;
  self->height = configuration.height;
  self->configuration = configuration;
#ifndef MPV_RENDER_API_TYPE_SW
  // MPV_RENDER_API_TYPE_SW must be available for S/W rendering.
  if (!self->configuration.enable_hardware_acceleration) {
    g_printerr("media_kit: VideoOutput: S/W rendering is not supported.\n");
  }
  self->configuration.enable_hardware_acceleration = TRUE;
#endif
  mpv_set_option_string(self->handle, "video-sync", "audio");
  gboolean hardware_acceleration_supported = FALSE;
  if (self->configuration.enable_hardware_acceleration) {
    vo_init_egl_extensions();

    EGLDisplay flutter_display = eglGetCurrentDisplay();
    EGLContext flutter_context = eglGetCurrentContext();
    EGLSurface flutter_draw_surface = eglGetCurrentSurface(EGL_DRAW);
    EGLSurface flutter_read_surface = eglGetCurrentSurface(EGL_READ);

    if (flutter_display != EGL_NO_DISPLAY && flutter_context != EGL_NO_CONTEXT) {
      self->egl_display = flutter_display;

      eglBindAPI(EGL_OPENGL_ES_API);

      EGLConfig config = NULL;
      EGLint config_id = 0;

      if (eglQueryContext(self->egl_display, flutter_context, EGL_CONFIG_ID,
                          &config_id)) {
        g_print("media_kit: VideoOutput: Flutter's EGL config ID: %d\n",
                config_id);

        EGLint num_configs = 0;
        EGLint config_attribs[] = {EGL_CONFIG_ID, config_id, EGL_NONE};

        if (eglChooseConfig(self->egl_display, config_attribs, &config, 1,
                            &num_configs) &&
            num_configs > 0) {
          g_print("media_kit: VideoOutput: Using Flutter's EGL config.\n");
        } else {
          g_printerr(
              "media_kit: VideoOutput: Failed to get Flutter's EGL config by "
              "ID.\n");
          config = NULL;
        }
      } else {
        g_printerr(
            "media_kit: VideoOutput: Failed to query Flutter's EGL config "
            "ID.\n");
      }

      if (config != NULL) {
        EGLint context_attribs[] = {
            EGL_CONTEXT_CLIENT_VERSION, 2,
            EGL_NONE,
        };

        self->egl_context = eglCreateContext(self->egl_display, config,
                                             EGL_NO_CONTEXT, context_attribs);

        if (self->egl_context != EGL_NO_CONTEXT) {
          // Make our isolated context current for mpv initialisation.
          if (eglMakeCurrent(self->egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                             self->egl_context)) {
            self->texture_gl = texture_gl_new(self);

            if (fl_texture_registrar_register_texture(
                    texture_registrar, FL_TEXTURE(self->texture_gl))) {
              mpv_opengl_init_params gl_init_params{
                  [](auto, auto name) {
                    return (void*)eglGetProcAddress(name);
                  },
                  NULL,
              };

              mpv_render_param params[] = {
                  {MPV_RENDER_PARAM_API_TYPE,
                   (void*)MPV_RENDER_API_TYPE_OPENGL},
                  {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS,
                   (void*)&gl_init_params},
                  {MPV_RENDER_PARAM_INVALID, (void*)0},
                  {MPV_RENDER_PARAM_INVALID, (void*)0},
              };

              GdkDisplay* display = gdk_display_get_default();
              if (GDK_IS_WAYLAND_DISPLAY(display)) {
                params[2].type = MPV_RENDER_PARAM_WL_DISPLAY;
                params[2].data =
                    gdk_wayland_display_get_wl_display(display);
              } else if (GDK_IS_X11_DISPLAY(display)) {
                params[2].type = MPV_RENDER_PARAM_X11_DISPLAY;
                params[2].data = gdk_x11_display_get_xdisplay(display);
              }

              if (mpv_render_context_create(&self->render_context,
                                            self->handle, params) == 0) {
                // Signal the render thread instead of calling
                // fl_texture_registrar_mark_texture_frame_available directly.
                mpv_render_context_set_update_callback(
                    self->render_context,
                    [](void* data) {
                      VideoOutput* self = (VideoOutput*)data;
                      if (self->destroyed) {
                        return;
                      }
                      // Invalidate dimension cache so the render thread
                      // fetches fresh video-out-params for this frame.
                      g_mutex_lock(&self->dims_mutex);
                      self->dims_valid = FALSE;
                      g_mutex_unlock(&self->dims_mutex);

                      g_mutex_lock(&self->render_mutex);
                      self->render_requested = TRUE;
                      g_cond_signal(&self->render_cond);
                      g_mutex_unlock(&self->render_mutex);
                    },
                    self);

                hardware_acceleration_supported = TRUE;
                g_print(
                    "media_kit: VideoOutput: H/W rendering with dedicated "
                    "render thread.\n");
              } else {
                g_printerr(
                    "media_kit: VideoOutput: Failed to create "
                    "mpv_render_context.\n");
              }
            } else {
              g_printerr(
                  "media_kit: VideoOutput: Failed to register texture.\n");
            }

            // Release egl_context from this thread before the render thread
            // takes ownership.
            eglMakeCurrent(self->egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                           EGL_NO_CONTEXT);
            // Restore Flutter's context.
            if (!eglMakeCurrent(flutter_display, flutter_draw_surface,
                                flutter_read_surface, flutter_context)) {
              g_printerr(
                  "media_kit: VideoOutput: Failed to restore Flutter EGL "
                  "context: 0x%x\n",
                  eglGetError());
            }

            if (hardware_acceleration_supported) {
              // Start the dedicated render thread.
              self->render_thread =
                  g_thread_new("media_kit_render", render_thread_func, self);
            }
          } else {
            g_printerr(
                "media_kit: VideoOutput: Failed to make isolated EGL context "
                "current. Error: 0x%x\n",
                eglGetError());
          }
        } else {
          g_printerr(
              "media_kit: VideoOutput: Failed to create isolated EGL context. "
              "Error: 0x%x\n",
              eglGetError());
        }
      } else {
        g_printerr(
            "media_kit: VideoOutput: Could not obtain Flutter's EGL config.\n");
      }
    } else {
      g_printerr(
          "media_kit: VideoOutput: EGL display or context is invalid.\n");
    }
  }
#ifdef MPV_RENDER_API_TYPE_SW
  if (!hardware_acceleration_supported) {
    g_printerr("media_kit: VideoOutput: S/W rendering.\n");
    self->pixel_buffer = g_new0(guint8, SW_RENDERING_PIXEL_BUFFER_SIZE);
    self->texture_gl = NULL;
    self->texture_sw = texture_sw_new(self);
    if (fl_texture_registrar_register_texture(texture_registrar,
                                              FL_TEXTURE(self->texture_sw))) {
      mpv_render_param params[] = {
          {MPV_RENDER_PARAM_API_TYPE, (void*)MPV_RENDER_API_TYPE_SW},
          {MPV_RENDER_PARAM_INVALID, (void*)0},
      };
      if (mpv_render_context_create(&self->render_context, self->handle,
                                    params) == 0) {
        mpv_render_context_set_update_callback(
            self->render_context,
            [](void* data) {
              gdk_threads_add_idle(
                  [](gpointer data) -> gboolean {
                    VideoOutput* self = (VideoOutput*)data;
                    if (self->destroyed) {
                      return FALSE;
                    }
                    g_mutex_lock(&self->mutex);
                    gint64 width = video_output_get_width(self);
                    gint64 height = video_output_get_height(self);
                    if (width > 0 && height > 0) {
                      gint32 size[]{(gint32)width, (gint32)height};
                      gint32 pitch = 4 * (gint32)width;
                      mpv_render_param params[]{
                          {MPV_RENDER_PARAM_SW_SIZE, size},
                          {MPV_RENDER_PARAM_SW_FORMAT, (void*)"rgb0"},
                          {MPV_RENDER_PARAM_SW_STRIDE, &pitch},
                          {MPV_RENDER_PARAM_SW_POINTER, self->pixel_buffer},
                          {MPV_RENDER_PARAM_INVALID, (void*)0},
                      };
                      mpv_render_context_render(self->render_context, params);
                      fl_texture_registrar_mark_texture_frame_available(
                          self->texture_registrar,
                          FL_TEXTURE(self->texture_sw));
                    }
                    g_mutex_unlock(&self->mutex);
                    return FALSE;
                  },
                  data);
            },
            self);
      }
    }
  }
#endif
  return self;
}

void video_output_set_texture_update_callback(
    VideoOutput* self,
    TextureUpdateCallback texture_update_callback,
    gpointer texture_update_callback_context,
    GDestroyNotify texture_update_callback_context_destroy) {
  self->texture_update_callback = texture_update_callback;
  self->texture_update_callback_context = texture_update_callback_context;
  self->texture_update_callback_context_destroy =
      texture_update_callback_context_destroy;
  gint64 texture_id = video_output_get_texture_id(self);
  if (self->width == 0 || self->height == 0) {
    self->texture_update_callback(texture_id, 1, 1,
                                  self->texture_update_callback_context);
  } else {
    self->texture_update_callback(texture_id, self->width, self->height,
                                  self->texture_update_callback_context);
  }
}

void video_output_set_size(VideoOutput* self, gint64 width, gint64 height) {
  if (self->texture_gl) {
    self->width = width;
    self->height = height;
  }
  if (self->texture_sw) {
    self->width = CLAMP(width, 0, SW_RENDERING_MAX_WIDTH);
    self->height = CLAMP(height, 0, SW_RENDERING_MAX_HEIGHT);
  }
}

mpv_render_context* video_output_get_render_context(VideoOutput* self) {
  return self->render_context;
}

EGLDisplay video_output_get_egl_display(VideoOutput* self) {
  return self->egl_display;
}

EGLContext video_output_get_egl_context(VideoOutput* self) {
  return self->egl_context;
}

EGLSurface video_output_get_egl_surface(VideoOutput* self) {
  return self->egl_surface;
}

guint8* video_output_get_pixel_buffer(VideoOutput* self) {
  return self->pixel_buffer;
}

static void get_video_dimensions(VideoOutput* self,
                                  gint64* out_width,
                                  gint64* out_height) {
  // Fast path: serve from cache (set valid by mpv update callback, refreshed
  // once per render cycle when invalidated).
  g_mutex_lock(&self->dims_mutex);
  if (self->dims_valid) {
    gint64 dw = self->cached_dw;
    gint64 dh = self->cached_dh;
    gint64 rotate = self->cached_rotate;
    g_mutex_unlock(&self->dims_mutex);

    gint64 width  = (rotate == 0 || rotate == 180) ? dw : dh;
    gint64 height = (rotate == 0 || rotate == 180) ? dh : dw;
    if (self->texture_sw != NULL) {
      if (width >= SW_RENDERING_MAX_WIDTH) {
        width  = SW_RENDERING_MAX_WIDTH;
        height = height > 0 ? width * height / (dw > 0 ? dw : 1) : 0;
      } else if (height >= SW_RENDERING_MAX_HEIGHT) {
        height = SW_RENDERING_MAX_HEIGHT;
        width  = width > 0 ? height * width / (dh > 0 ? dh : 1) : 0;
      }
    }
    *out_width  = width;
    *out_height = height;
    return;
  }
  g_mutex_unlock(&self->dims_mutex);

  // Slow path: query mpv (at most once per frame; callback invalidates cache).
  gint64 dw = 0, dh = 0, rotate = 0;
  mpv_node params;
  mpv_get_property(self->handle, "video-out-params", MPV_FORMAT_NODE, &params);
  if (params.format == MPV_FORMAT_NODE_MAP) {
    for (int32_t i = 0; i < params.u.list->num; i++) {
      char* key = params.u.list->keys[i];
      auto value = params.u.list->values[i];
      if (value.format == MPV_FORMAT_INT64) {
        if (strcmp(key, "dw") == 0)     dw     = value.u.int64;
        if (strcmp(key, "dh") == 0)     dh     = value.u.int64;
        if (strcmp(key, "rotate") == 0) rotate = value.u.int64;
      }
    }
    mpv_free_node_contents(&params);
  }

  // Update cache.
  g_mutex_lock(&self->dims_mutex);
  self->cached_dw     = dw;
  self->cached_dh     = dh;
  self->cached_rotate = rotate;
  self->dims_valid    = TRUE;
  g_mutex_unlock(&self->dims_mutex);

  gint64 width  = (rotate == 0 || rotate == 180) ? dw : dh;
  gint64 height = (rotate == 0 || rotate == 180) ? dh : dw;
  if (self->texture_sw != NULL) {
    if (width >= SW_RENDERING_MAX_WIDTH) {
      width  = SW_RENDERING_MAX_WIDTH;
      height = height > 0 ? width * height / (dw > 0 ? dw : 1) : 0;
    } else if (height >= SW_RENDERING_MAX_HEIGHT) {
      height = SW_RENDERING_MAX_HEIGHT;
      width  = width > 0 ? height * width / (dh > 0 ? dh : 1) : 0;
    }
  }
  *out_width  = width;
  *out_height = height;
}

gint64 video_output_get_width(VideoOutput* self) {
  if (self->width) {
    return self->width;
  }
  gint64 width = 0, height = 0;
  get_video_dimensions(self, &width, &height);
  return width;
}

gint64 video_output_get_height(VideoOutput* self) {
  if (self->height) {
    return self->height;
  }
  gint64 width = 0, height = 0;
  get_video_dimensions(self, &width, &height);
  return height;
}

gint64 video_output_get_texture_id(VideoOutput* self) {
  if (self->texture_gl) {
    return (gint64)self->texture_gl;
  }
  if (self->texture_sw) {
    return (gint64)self->texture_sw;
  }
  g_assert_not_reached();
  return -1;
}

void video_output_notify_texture_update(VideoOutput* self) {
  gint64 id = video_output_get_texture_id(self);
  gint64 width = video_output_get_width(self);
  gint64 height = video_output_get_height(self);
  gpointer context = self->texture_update_callback_context;
  if (self->texture_update_callback != NULL) {
    self->texture_update_callback(id, width, height, context);
  }
}

gboolean video_output_get_front_image(VideoOutput* self,
                                      EGLImageKHR* out_image,
                                      guint32* out_width,
                                      guint32* out_height,
                                      gboolean* out_dirty) {
  g_mutex_lock(&self->front_mutex);
  *out_image = self->front_egl_image;
  *out_width = self->front_width;
  *out_height = self->front_height;
  *out_dirty = self->front_dirty;
  self->front_dirty = FALSE;
  g_mutex_unlock(&self->front_mutex);
  return *out_image != EGL_NO_IMAGE_KHR && *out_width > 0 && *out_height > 0;
}
