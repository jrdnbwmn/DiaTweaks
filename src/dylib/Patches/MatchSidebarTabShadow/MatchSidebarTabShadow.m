#import "StdPatch/Hide.h"

#define DPPinnedTab "_TtC5TabUI15TabDockItemView"
#define DPTabBackground "_TtC5TabUI17TabBackgroundView"

static CALayer *DPPageShadow(void) {
    for (NSView *container in DPFindViews(DPDiaContentContainer))
        for (NSView *view in container.subviews)
            if (DPIsKind(view, DPDiaShadowView))
                for (CALayer *layer in view.layer.sublayers)
                    if (layer.shadowOpacity > 0) return layer;
    return nil;
}

static NSArray<NSView *> *DPSidebarTabShapes(void) {
    NSMutableArray<NSView *> *shapes = [NSMutableArray new];
    for (NSView *background in DPFindViews(DPTabBackground)) {
        BOOL sidebar = NO;
        for (NSView *v = background.superview; v; v = v.superview)
            if ([NSStringFromClass(v.class) containsString:@"SidebarRootView"]) { sidebar = YES; break; }
        if (!sidebar) continue;
        for (NSView *shape in background.subviews)
            if ([NSStringFromClass(shape.class) containsString:@"TabShapeView"])
                [shapes addObject:shape];
    }
    return shapes;
}

static CALayer *DPTabShadow(NSView *shape) {
    for (CALayer *layer in shape.layer.sublayers)
        if ([layer isKindOfClass:CAShapeLayer.class] && layer.shadowOpacity > 0) return layer;
    return nil;
}

static NSString *DPVerifyMatchingTabShadow(DPPatch *patch) {
    if (!patch->on || !DPFindViews(DPDiaSidebarFooter).count) return nil;
    CALayer *page = DPPageShadow();
    if (!page) return @"no page shadow found";
    for (NSView *pinned in DPFindViews(DPPinnedTab)) {
        NSView *selection = DPFindView(pinned, ^BOOL(NSView *v) { return [NSStringFromClass(v.class) containsString:@"SelectionOutlineView"]; });
        // When the border patch suppresses Dia's selected outline, it must still have the selected shadow.
        if (!selection || selection.superview.hiddenOrHasHiddenAncestor ||
            (selection.hidden && ![DPSuppressed containsObject:selection])) continue;
        CALayer *shadow = pinned.layer;
        if (fabs(shadow.shadowOpacity - page.shadowOpacity) > 0.001 || fabs(shadow.shadowRadius - page.shadowRadius) > 0.001 ||
            !CGSizeEqualToSize(shadow.shadowOffset, page.shadowOffset) || !CGColorEqualToColor(shadow.shadowColor, page.shadowColor))
            return @"selected pinned tab shadow differs from page shadow";
    }
    NSArray<NSView *> *shapes = DPSidebarTabShapes();

    for (NSView *shape in shapes) {
        if (shape.hiddenOrHasHiddenAncestor) continue;
        CALayer *tab = DPTabShadow(shape);
        if (!tab) return @"active tab has no shadow";
        if (tab.hidden) return @"active tab shadow is hidden";
        if (fabs(tab.shadowOpacity - page.shadowOpacity) > 0.001 ||
            fabs(tab.shadowRadius - page.shadowRadius) > 0.001 ||
            !CGSizeEqualToSize(tab.shadowOffset, page.shadowOffset) ||
            !CGColorEqualToColor(tab.shadowColor, page.shadowColor)) return @"active tab shadow differs from page shadow";
    }
    return nil;
}

extern DPPatch DPMatchSidebarTabShadow;
static char DPRadiusKey, DPOpacityKey, DPOffsetKey, DPColorKey, DPHiddenKey;
static void DPApplyShadowLayer(CALayer *tab, CALayer *page, BOOL on, BOOL showLayer) {
    // AIDEV-NOTE: remember Dia's own shadow, so disabling the patch restores its appearance.
    id hidden = DPDiaValue(tab, &DPHiddenKey, @(tab.hidden));
    id newHidden = on && showLayer ? @NO : hidden;
    DPOverride(tab, &DPHiddenKey, hidden, newHidden);
    id radius = DPDiaValue(tab, &DPRadiusKey, @(tab.shadowRadius));
    id opacity = DPDiaValue(tab, &DPOpacityKey, @(tab.shadowOpacity));
    id offset = DPDiaValue(tab, &DPOffsetKey, [NSValue valueWithSize:NSSizeFromCGSize(tab.shadowOffset)]);
    id color = DPDiaValue(tab, &DPColorKey, (__bridge id)tab.shadowColor);
    id newRadius = on ? @(page.shadowRadius) : radius;
    id newOpacity = on ? @(page.shadowOpacity) : opacity;
    id newOffset = on ? [NSValue valueWithSize:NSSizeFromCGSize(page.shadowOffset)] : offset;
    id newColor = on ? (__bridge id)page.shadowColor : color;
    DPOverride(tab, &DPRadiusKey, radius, newRadius);
    DPOverride(tab, &DPOpacityKey, opacity, newOpacity);
    DPOverride(tab, &DPOffsetKey, offset, newOffset);
    DPOverride(tab, &DPColorKey, color, newColor);
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    tab.hidden = [newHidden boolValue];
    tab.shadowRadius = [newRadius doubleValue];
    tab.shadowOpacity = [newOpacity floatValue];
    tab.shadowOffset = NSSizeToCGSize([newOffset sizeValue]);
    tab.shadowColor = (__bridge CGColorRef)newColor;
    [CATransaction commit];
}

static void DPApplyTabShadow(NSView *shape) {
    BOOL sidebar = NO;
    for (NSView *v = shape.superview; v; v = v.superview)
        if ([NSStringFromClass(v.class) containsString:@"SidebarRootView"]) { sidebar = YES; break; }
    if (!sidebar) return;
    CALayer *tab = DPTabShadow(shape), *page = DPPageShadow();
    if (tab && page) DPApplyShadowLayer(tab, page, DPMatchSidebarTabShadow.on, YES);
}

static void DPApplyPinnedTab(NSView *pinned) {
    CALayer *page = DPPageShadow();
    if (!page || !pinned.layer) return;
    NSView *selection = DPFindView(pinned, ^BOOL(NSView *v) { return [NSStringFromClass(v.class) containsString:@"SelectionOutlineView"]; });
    // AIDEV-NOTE: a suppressed outline is still selected; only its border is hidden.
    BOOL selected = selection && (!selection.hidden || [DPSuppressed containsObject:selection]);
    DPApplyShadowLayer(pinned.layer, page, DPMatchSidebarTabShadow.on && selected, NO);
}

static void DPPinned_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPPinned_layout, self);
    DPApplyPinnedTab(self);
}
static void DPPinned_updateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPPinned_updateLayer, self);
    DPApplyPinnedTab(self);
}
static void DPPinnedSelection_setHidden(NSView *self, SEL _cmd, BOOL hidden) {
    DPCallOriginal(DPPinnedSelection_setHidden, self, hidden);
    NSView *pinned = self.superview;
    while (pinned && !DPIsKind(pinned, DPPinnedTab)) pinned = pinned.superview;
    if (pinned) DPApplyPinnedTab(pinned);
}

static void DPTabShape_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTabShape_layout, self);
    DPApplyTabShadow(self);
}

static void DPRefreshTabShadows(void) {
    for (NSView *pinned in DPFindViews(DPPinnedTab)) {
        NSView *selection = DPFindView(pinned, ^BOOL(NSView *v) { return [NSStringFromClass(v.class) containsString:@"SelectionOutlineView"]; });
        if (selection) DPHookClass(selection.class, @selector(setHidden:), (IMP)DPPinnedSelection_setHidden);
        DPApplyPinnedTab(pinned);
    }
    for (NSView *shape in DPSidebarTabShapes()) {
        DPHookClass(shape.class, @selector(layout), (IMP)DPTabShape_layout);
        DPApplyTabShadow(shape);
    }
}
static void DPApplyMatchingTabShadow(DPPatch *patch) { DPRefreshTabShadows(); }
static void DPTabBackground_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTabBackground_layout, self);
    DPRefreshTabShadows();
}
static void DPContentShadow_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPContentShadow_layout, self);
    if (DPIsKind(self.superview, DPDiaContentContainer))
        dispatch_async(dispatch_get_main_queue(), ^{ DPRefreshTabShadows(); });
}
static void DPInstallMatchingTabShadow(void) {
    DPHook(DPPinnedTab, @selector(layout), (IMP)DPPinned_layout);
    DPHook(DPPinnedTab, @selector(updateLayer), (IMP)DPPinned_updateLayer);
    DPHook(DPDiaShadowView, @selector(layout), (IMP)DPContentShadow_layout);
    DPHook(DPTabBackground, @selector(layout), (IMP)DPTabBackground_layout);
    DPOnLaunch(^{ DPRefreshTabShadows(); });
}

DP_PATCH(DPMatchSidebarTabShadow) {
    .key = @"matchSidebarTabShadow", .defaultOn = YES, .order = 26,
    .title = @"Match sidebar tab shadow",
    .detail = @"Match the active tab's shadow to the main content area.",
    .symbol = @"sidebar.left", .tint = @"systemGrayColor",
    .classes = DPClasses(DPTabBackground, DPDiaContentContainer, DPDiaShadowView),
    .install = DPInstallMatchingTabShadow,
    .apply = DPApplyMatchingTabShadow,
    .verify = DPVerifyMatchingTabShadow,
};
