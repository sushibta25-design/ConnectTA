#include "../MTAdaptiveLayout.h"
#include <assert.h>

int main(void) {
    assert(!MTYouTubeTabletMode(MTYouTubeLogicalWidth(190), false, false));
    assert(MTYouTubeTabletMode(MTYouTubeLogicalWidth(382), false, false));
    bool tablet = false;
    const double widths[] = {600, 680, 699, 700, 690, 640, 621, 620, 650, 699, 700};
    const bool expected[] = {false, false, false, true, true, true, true, false, false, false, true};
    for (unsigned i = 0; i < sizeof(widths)/sizeof(widths[0]); ++i) {
        tablet = MTYouTubeTabletMode(widths[i], true, tablet);
        assert(tablet == expected[i]);
    }
    assert(MTYouTubeLogicalWidth(300) / 300 == MTYouTubeLogicalWidth(200) / 200);
    return 0;
}
