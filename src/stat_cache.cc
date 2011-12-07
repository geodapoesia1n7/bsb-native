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

#include "stat_cache.h"

#include <stdio.h>

#include "edit_distance.h"
#include "graph.h"

Node* StatCache::GetFile(const std::string& path) {
  Node* node = LookupFile(path);
  if (node)
    return node;
  node = new Node(path);
  paths_[node->path().c_str()] = node;
  return node;
}

Node* StatCache::LookupFile(const std::string& path) {
  Paths::iterator i = paths_.find(path.c_str());
  if (i != paths_.end())
    return i->second;
  return NULL;
}

Node* StatCache::SpellcheckFile(const std::string& path) {
  const bool kAllowReplacements = true;
  const int kMaxValidEditDistance = 3;

  int min_distance = kMaxValidEditDistance + 1;
  Node* result = NULL;
  for (Paths::iterator i = paths_.begin(); i != paths_.end(); ++i) {
    int distance = EditDistance(
        i->first, path, kAllowReplacements, kMaxValidEditDistance);
    if (distance < min_distance && i->second) {
      min_distance = distance;
      result = i->second;
    }
  }
  return result;
}

void StatCache::Dump() {
  for (Paths::iterator i = paths_.begin(); i != paths_.end(); ++i) {
    Node* node = i->second;
    printf("%s %s\n",
           node->path().c_str(),
           node->status_known() ? (node->dirty() ? "dirty" : "clean")
                                : "unknown");
  }
}

void StatCache::Invalidate() {
  for (Paths::iterator i = paths_.begin(); i != paths_.end(); ++i)
    i->second->ResetState();
}
