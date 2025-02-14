// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "components/mus/public/cpp/event_matcher.h"

namespace mus {

mojom::EventMatcherPtr CreateKeyMatcher(mojom::KeyboardCode code,
                                        mojom::EventFlags flags) {
  mojom::EventMatcherPtr matcher(mojom::EventMatcher::New());
  matcher->type_matcher = mojom::EventTypeMatcher::New();
  matcher->flags_matcher = mojom::EventFlagsMatcher::New();
  matcher->ignore_flags_matcher = mojom::EventFlagsMatcher::New();
  // Ignoring these makes most accelerator scenarios more straight forward. Code
  // that needs to check them can override this setting.
  matcher->ignore_flags_matcher->flags =
      static_cast<mojom::EventFlags>(mojom::EVENT_FLAGS_NUM_LOCK_ON |
                                     mojom::EVENT_FLAGS_CAPS_LOCK_ON |
                                     mojom::EVENT_FLAGS_SCROLL_LOCK_ON);
  matcher->key_matcher = mojom::KeyEventMatcher::New();

  matcher->type_matcher->type = mus::mojom::EVENT_TYPE_KEY_PRESSED;
  matcher->flags_matcher->flags = flags;
  matcher->key_matcher->keyboard_code = code;
  return matcher;
}

}  // namespace mus
