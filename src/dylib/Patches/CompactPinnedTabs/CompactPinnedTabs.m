#import "StdPatch/StdPatch.h"

extern DPPatch DPCompactPinnedTabs;
static char DPFrameKey, DPContainerFrameKey;
#define DPListView "_TtC7TabList11TabListView"
#define DPDockView "_TtC10TabSurface11TabDockView"

static void DPPin_setFrame(NSView *self, SEL _cmd, NSRect requested) {
    NSRect frame = requested;
    if (DPCompactPinnedTabs.on && [DPTabLayout() isEqualToString:@"vertical"] && NSHeight(frame) > 34) {
        CGFloat reduction = NSHeight(frame) - 34;
        CGFloat row = round(NSMinY(frame) / (NSHeight(frame) + 6));
        frame.origin.y -= row * reduction;
        frame.size.height = 34;
    }
    DPOverride(self, &DPFrameKey, @(requested), @(frame));
    DPCallOriginal(DPPin_setFrame, self, frame);
}

static void DPSetContainerFrame(NSView *view, NSRect frame, BOOL on) {
    NSRect original = [DPDiaValue(view, &DPContainerFrameKey, @(view.frame)) rectValue];
    NSRect target = on ? frame : original;
    DPOverride(view, &DPContainerFrameKey, @(original), @(target));
    if (!NSEqualRects(view.frame, target)) view.frame = target;
}

static void DPLayoutPinnedRows(NSView *list) {
    NSView *dock = DPSubview(list, DPDockView);
    if (!dock) return;
    BOOL on = DPCompactPinnedTabs.on && [DPTabLayout() isEqualToString:@"vertical"];
    CGFloat reduction = 0;
    for (NSView *pin in dock.subviews) {
        if (!DPIsKind(pin, DPDiaPinnedTab)) continue;
        NSRect original = [DPDiaValue(pin, &DPFrameKey, @(pin.frame)) rectValue];
        CGFloat row = round(NSMinY(original) / (NSHeight(original) + 6));
        reduction = MAX(reduction, (row + 1) * MAX(0, NSHeight(original) - 34));
        pin.frame = original;
    }
    NSRect dockFrame = [DPDiaValue(dock, &DPContainerFrameKey, @(dock.frame)) rectValue];
    NSRect adjustedDock = dockFrame;
    adjustedDock.size.height -= reduction;
    DPSetContainerFrame(dock, adjustedDock, on);
    for (NSView *view in list.subviews) {
        if (view == dock) continue;
        NSRect original = [DPDiaValue(view, &DPContainerFrameKey, @(view.frame)) rectValue];
        if (NSMinY(original) < NSMaxY(dockFrame)) continue;
        NSRect adjusted = original;
        adjusted.origin.y -= reduction;
        if ([view isKindOfClass:NSScrollView.class]) adjusted.size.height += reduction;
        DPSetContainerFrame(view, adjusted, on);
    }
}

static void DPList_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPList_layout, self);
    DPLayoutPinnedRows(self);
}

static void DPApplyCompactPinnedTabs(DPPatch *patch) {
    for (NSView *list in DPFindViews(DPListView)) DPLayoutPinnedRows(list);
}

static void DPInstallCompactPinnedTabs(void) {
    DPHook(DPDiaPinnedTab, @selector(setFrame:), (IMP)DPPin_setFrame);
    DPHook(DPListView, @selector(layout), (IMP)DPList_layout);
}

// A regular sidebar tab's visible background is 34 points high with 10-point corners.
static NSString *DPVerifyCompactPinnedTabs(DPPatch *patch) {
    if (!patch->on || ![DPTabLayout() isEqualToString:@"vertical"]) return nil;
    for (NSView *pin in DPFindViews(DPDiaPinnedTab)) {
        if (pin.hiddenOrHasHiddenAncestor) continue;
        if (fabs(NSHeight(pin.bounds) - 34) > 0.5) return @"pinned tab height differs from a normal tab";
        NSView *outline = DPFindView(pin, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaPinnedTabOutline); });
        if (outline && fabs(outline.layer.cornerRadius - 10) > 0.5) return @"pinned tab corners differ from a normal tab";
        for (NSView *other in pin.superview.subviews) {
            if (other == pin || !DPIsKind(other, DPDiaPinnedTab) || other.hidden) continue;
            if (fabs(NSMidX(pin.frame) - NSMidX(other.frame)) > 1) continue;
            CGFloat rowGap = fabs(NSMidY(pin.frame) - NSMidY(other.frame)) - NSHeight(pin.frame);
            if (rowGap > 8 && rowGap < 30) return @"too much space between pinned tab rows";
        }
    }
    return nil;
}

DP_PATCH(DPCompactPinnedTabs) {
    .key = @"compactPinnedTabs",
    .order = 155,
    .title = @"Compact pinned tabs",
    .detail = @"Match pinned tab height and corners to regular sidebar tabs.",
    .symbol = @"pin",
    .tint = @"systemBlueColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaPinnedTab, DPDiaPinnedTabOutline),
    .install = DPInstallCompactPinnedTabs,
    .apply = DPApplyCompactPinnedTabs,
    .verify = DPVerifyCompactPinnedTabs,
};
