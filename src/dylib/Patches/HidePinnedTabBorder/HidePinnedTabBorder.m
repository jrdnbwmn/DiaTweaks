#import "StdPatch/Hide.h"

static BOOL DPIsPinnedTabOutline(NSView *view) { return DPIsKind(view, DPDiaPinnedTabOutline); }

extern DPPatch DPHidePinnedTabBorder;
static char DPGradientHiddenKey;

static void DPRefreshPinnedGradient(NSView *pin) {
    NSView *outline = DPFindView(pin, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaPinnedTabOutline); });
    if (!outline) return;
    BOOL selected = !outline.hidden || [DPSuppressed containsObject:outline];
    for (CALayer *layer in outline.superview.layer.sublayers) {
        if (![layer isKindOfClass:CAGradientLayer.class]) continue;
        if (DPHidePinnedTabBorder.on && selected) {
            if (!DPGet(layer, &DPGradientHiddenKey)) DPSet(layer, &DPGradientHiddenKey, @(layer.hidden));
            layer.hidden = YES;
        } else if (DPGet(layer, &DPGradientHiddenKey)) {
            BOOL original = [DPGet(layer, &DPGradientHiddenKey) boolValue];
            DPSet(layer, &DPGradientHiddenKey, nil);
            if (selected || !DPHidePinnedTabBorder.on) layer.hidden = original;
        }
    }
}

static void DPApplyPinnedBorder(DPPatch *patch) {
    DPApplyHides(patch);
    for (NSView *pin in DPFindViews(DPDiaPinnedTab)) DPRefreshPinnedGradient(pin);
}

static void DPPinnedTab_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPPinnedTab_updateLayer, self);
    DPRefreshPinnedGradient(self);
}

static void DPPinnedOutline_setHidden(NSView *self, SEL _cmd, BOOL hidden) {
    DPCallOriginal(DPPinnedOutline_setHidden, self, hidden);
    NSView *pin = self.superview;
    while (pin && !DPIsKind(pin, DPDiaPinnedTab)) pin = pin.superview;
    if (pin) DPRefreshPinnedGradient(pin);
}

// The outline sits inside each pinned tab, deeper than the bars hide patches search.
static void DPPinnedTab_layout(NSView *self, SEL _cmd) {
    [DPHideHosts addObject:self];
    DPEnforceHides(self);
    DPCallOriginal(DPPinnedTab_layout, self);
    DPRefreshPinnedGradient(self);
}

static void DPInstallHidePinnedTabBorder(void) {
    DPHook(DPDiaPinnedTab, @selector(layout), (IMP)DPPinnedTab_layout);
    DPHook(DPDiaPinnedTab, @selector(updateLayer), (IMP)DPPinnedTab_updateLayer);
    DPHook(DPDiaPinnedTabOutline, @selector(setHidden:), (IMP)DPPinnedOutline_setHidden);
}

static NSString *DPVerifyPinnedTabBorder(DPPatch *patch) {
    NSString *problem = DPVerifyHides(patch);
    if (problem || !patch->on) return problem;
    for (NSView *pin in DPFindViews(DPDiaPinnedTab)) {
        NSView *outline = DPFindView(pin, ^BOOL(NSView *v) { return DPIsKind(v, DPDiaPinnedTabOutline); });
        if (!outline || ![DPSuppressed containsObject:outline] || outline.superview.hiddenOrHasHiddenAncestor) continue;
        for (CALayer *layer in outline.superview.layer.sublayers)
            if ([layer isKindOfClass:CAGradientLayer.class] && !layer.hidden) return @"selected pinned tab still has an inner border";
    }
    return nil;
}

DP_PATCH(DPHidePinnedTabBorder) {
    .key = @"hidePinnedTabBorder",
    .order = 82,
    .title = @"Hide pinned tab border",
    .detail = @"Remove the colored border around the selected pinned tab.",
    .symbol = @"square.dashed",
    .tint = @"systemIndigoColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaPinnedTab, DPDiaPinnedTabOutline),
    .hides = DPIsPinnedTabOutline,
    .verify = DPVerifyPinnedTabBorder,
    .install = DPInstallHidePinnedTabBorder,
    .apply = DPApplyPinnedBorder,
};
