// Copyright 2011 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "util.h"

#ifdef _WIN32
#include <windows.h>
#endif

#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifndef _WIN32
#include <sys/time.h>
#endif

#include <vector>

#ifdef _WIN32
#include <direct.h>  // _mkdir
#endif

#include "edit_distance.h"

void Fatal(const char* msg, ...) {
  va_list ap;
  fprintf(stderr, "ninja: FATAL: ");
  va_start(ap, msg);
  vfprintf(stderr, msg, ap);
  va_end(ap);
  fprintf(stderr, "\n");
  exit(1);
}

void Warning(const char* msg, ...) {
  va_list ap;
  fprintf(stderr, "ninja: WARNING: ");
  va_start(ap, msg);
  vfprintf(stderr, msg, ap);
  va_end(ap);
  fprintf(stderr, "\n");
}

void Error(const char* msg, ...) {
  va_list ap;
  fprintf(stderr, "ninja: ERROR: ");
  va_start(ap, msg);
  vfprintf(stderr, msg, ap);
  va_end(ap);
  fprintf(stderr, "\n");
}

bool CanonicalizePath(string* path, string* err) {
  // WARNING: this function is performance-critical; please benchmark
  // any changes you make to it.

  if (path->empty()) {
    *err = "empty path";
    return false;
  }

  const int kMaxPathComponents = 30;
  char* components[kMaxPathComponents];
  int component_count = 0;

  char* start = &(*path)[0];
  char* dst = start;
  const char* src = start;
  const char* end = start + path->size();

  if (*src == '/') {
    ++src;
    ++dst;
  }

  while (src < end) {
    const char* sep = (const char*)memchr(src, '/', end - src);
    if (sep == NULL)
      sep = end;

    if (*src == '.') {
      if (sep - src == 1) {
        // '.' component; eliminate.
        src += 2;
        continue;
      } else if (sep - src == 2 && src[1] == '.') {
        // '..' component.  Back up if possible.
        if (component_count > 0) {
          dst = components[component_count - 1];
          src += 3;
          --component_count;
        } else {
          while (src <= sep)
            *dst++ = *src++;
        }
        continue;
      }
    }

    if (sep > src) {
      if (component_count == kMaxPathComponents)
        Fatal("path has too many components");
      components[component_count] = dst;
      ++component_count;
      while (src <= sep) {
        *dst++ = *src++;
      }
    }

    src = sep + 1;
  }

  path->resize(dst - path->c_str() - 1);
  return true;
}

int MakeDir(const string& path) {
#ifdef _WIN32
  return _mkdir(path.c_str());
#else
  return mkdir(path.c_str(), 0777);
#endif
}

int ReadFile(const string& path, string* contents, string* err) {
  FILE* f = fopen(path.c_str(), "r");
  if (!f) {
    err->assign(strerror(errno));
    return -errno;
  }

  char buf[64 << 10];
  size_t len;
  while ((len = fread(buf, 1, sizeof(buf), f)) > 0) {
    contents->append(buf, len);
  }
  if (ferror(f)) {
    err->assign(strerror(errno));  // XXX errno?
    contents->clear();
    fclose(f);
    return -errno;
  }
  fclose(f);
  return 0;
}

void SetCloseOnExec(int fd) {
#ifndef _WIN32
  int flags = fcntl(fd, F_GETFD);
  if (flags < 0) {
    perror("fcntl(F_GETFD)");
  } else {
    if (fcntl(fd, F_SETFD, flags | FD_CLOEXEC) < 0)
      perror("fcntl(F_SETFD)");
  }
#else
  // On Windows, handles must be explicitly marked to be passed to a
  // spawned process, so there's nothing to do here.
  NINJA_UNUSED_ARG(fd);
#endif  // ! _WIN32
}

int64_t GetTimeMillis() {
#ifdef _WIN32
  // GetTickCount64 is only available on Vista or later.
  return GetTickCount();
#else
  timeval now;
  gettimeofday(&now, NULL);
  return ((int64_t)now.tv_sec * 1000) + (now.tv_usec / 1000);
#endif
}

const char* SpellcheckString(const string& text, ...) {
  const bool kAllowReplacements = true;
  const int kMaxValidEditDistance = 3;

  va_list ap;
  va_start(ap, text);
  const char* correct_spelling;

  int min_distance = kMaxValidEditDistance + 1;
  const char* result = NULL;
  while ((correct_spelling = va_arg(ap, const char*))) {
    int distance = EditDistance(
        correct_spelling, text, kAllowReplacements, kMaxValidEditDistance);
    if (distance < min_distance) {
      min_distance = distance;
      result = correct_spelling;
    }
  }

  va_end(ap);
  return result;
}

#ifdef WIN32
string GetLastErrorString() {
  DWORD err = GetLastError();

  char* msg_buf;
  FormatMessageA(
        FORMAT_MESSAGE_ALLOCATE_BUFFER |
        FORMAT_MESSAGE_FROM_SYSTEM |
        FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL,
        err,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        (char*)&msg_buf,
        0,
        NULL);
  string msg = msg_buf;
  LocalFree(msg_buf);
  return msg;
}
#endif
