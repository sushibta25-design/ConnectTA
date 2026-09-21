#pragma once
#include <stdbool.h>

// Stable density: widening a pane reveals more content instead of shrinking it.
// These are logical layout points, not physical display pixels.
static inline double MTYouTubeLogicalWidth(double viewportWidth) {
    return viewportWidth * 2.4;
}

static inline bool MTYouTubeTabletMode(double width, bool initialized, bool wasTablet) {
    if (!initialized) return width >= 700.0;
    return wasTablet ? width > 620.0 : width >= 700.0;
}
