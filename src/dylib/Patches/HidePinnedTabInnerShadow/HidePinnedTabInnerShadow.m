#import "StdPatch/StdPatch.h"

extern DPPatch DPHidePinnedTabInnerShadow;
#define DPDebossedView "_TtC5TabUI12DebossedView"
static char DPInnerShadowHiddenKey, DPInsetBorderWidthKey;

static void DPApplyInnerShadow(CALayer *layer, BOOL hide) {
    if (hide && layer.borderWidth > 0) {
        if (!DPGet(layer, &DPInsetBorderWidthKey)) DPSet(layer, &DPInsetBorderWidthKey, @(layer.borderWidth));
        layer.borderWidth = 0;
    } else if (!hide && DPGet(layer, &DPInsetBorderWidthKey)) {
        layer.borderWidth = [DPGet(layer, &DPInsetBorderWidthKey) doubleValue];
        DPSet(layer, &DPInsetBorderWidthKey, nil);
    }
    if ([NSStringFromClass(layer.class) isEqualToString:@"TabUI.InnerShadowLayer"]) {
        if (hide) {
            if (!DPGet(layer, &DPInnerShadowHiddenKey)) DPSet(layer, &DPInnerShadowHiddenKey, @(layer.hidden));
            layer.hidden = YES;
        } else if (DPGet(layer, &DPInnerShadowHiddenKey)) {
            layer.hidden = [DPGet(layer, &DPInnerShadowHiddenKey) boolValue];
            DPSet(layer, &DPInnerShadowHiddenKey, nil);
        }
    }
    for (CALayer *sub in layer.sublayers) DPApplyInnerShadow(sub, hide);
}

static void DPRefreshInset(NSView *inset) {
    NSView *pin = inset.superview;
    while (pin && !DPIsKind(pin, DPDiaPinnedTab)) pin = pin.superview;
    if (pin) DPApplyInnerShadow(inset.layer, DPHidePinnedTabInnerShadow.on);
}

static void DPInset_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPInset_layout, self);
    DPRefreshInset(self);
}

static void DPInset_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPInset_updateLayer, self);
    DPRefreshInset(self);
}

static void DPApplyPinnedInnerShadow(DPPatch *patch) {
    for (NSView *pin in DPFindViews(DPDiaPinnedTab)) {
        NSView *inset = DPFindView(pin, ^BOOL(NSView *view) { return DPIsKind(view, DPDebossedView); });
        if (inset) DPRefreshInset(inset);
    }
}

static void DPInstallPinnedInnerShadow(void) {
    DPHook(DPDebossedView, @selector(layout), (IMP)DPInset_layout);
    DPHook(DPDebossedView, @selector(updateLayer), (IMP)DPInset_updateLayer);
}

static BOOL DPVisibleInnerShadow(CALayer *layer) {
    if ([NSStringFromClass(layer.class) isEqualToString:@"TabUI.InnerShadowLayer"] && !layer.hidden) return YES;
    if (!layer.hidden && layer.borderWidth > 0) return YES;
    for (CALayer *sub in layer.sublayers) if (DPVisibleInnerShadow(sub)) return YES;
    return NO;
}

static NSString *DPVerifyPinnedInnerShadow(DPPatch *patch) {
    if (!patch->on) return nil;
    for (NSView *pin in DPFindViews(DPDiaPinnedTab)) {
        NSView *inset = DPFindView(pin, ^BOOL(NSView *view) { return [NSStringFromClass(view.class) isEqualToString:@"TabUI.DebossedView"]; });
        if (inset && !inset.hiddenOrHasHiddenAncestor && DPVisibleInnerShadow(inset.layer))
            return @"inactive pinned tab still has an inset shadow or outline";
    }
    return nil;
}

DP_PATCH(DPHidePinnedTabInnerShadow) {
    .key = @"hidePinnedTabInnerShadow",
    .order = 156,
    .title = @"Hide pinned tab inner shadow",
    .detail = @"Remove the inset shadow and outline from inactive pinned tabs in the sidebar.",
    .symbol = @"pin.slash",
    .tint = @"systemBlueColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaPinnedTab, DPDebossedView),
    .install = DPInstallPinnedInnerShadow,
    .apply = DPApplyPinnedInnerShadow,
    .verify = DPVerifyPinnedInnerShadow,
};
