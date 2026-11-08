// 测试进程里的窗口在后台运行：新建的窗口一律透明，挂上与收起 sheet 都不播放动画。
//
// 测试进程不能成为当前应用，窗口也就不会成为 key window；窗口透明之后照常排进窗口列表、挂上 sheet、
// 排版与成为第一响应者，只是测试运行期间屏幕上看不到它们。
// sheet 的动画会在主线程上同步播放约 0.27 s，看不见的窗口不必播放。

#include <CoreGraphics/CGGeometry.h>
#include <objc/message.h>
#include <objc/runtime.h>

/// `-[NSWindow initWithContentRect:styleMask:backing:defer:]` 的函数类型；其余初始化方法最后都会调到它。
typedef id (*WindowInitializer)(id, SEL, CGRect, unsigned long, unsigned long, BOOL);

/// 替换前的窗口初始化方法。
static WindowInitializer originalInitializer;

/// 照常初始化窗口，再把它设为完全透明。
static id initializeTransparentWindow(
    id self,
    SEL command,
    CGRect contentRect,
    unsigned long style,
    unsigned long backing,
    BOOL defer
) {
    id window = originalInitializer(self, command, contentRect, style, backing, defer);

    if (window != nil) {
        ((void (*)(id, SEL, double))objc_msgSend)(window, sel_registerName("setAlphaValue:"), 0);
    }

    return window;
}

/// sheet 一律跳过动画。
static BOOL skipSheetAnimation(id self, SEL command) {
    return YES;
}

/// 加载测试包时由 dyld 调用，早于任何测试建立窗口。
__attribute__((constructor))
static void installInvisibleWindows(void) {
    Class window = objc_getClass("NSWindow");

    if (window == Nil) {
        return;
    }

    SEL initializer = sel_registerName("initWithContentRect:styleMask:backing:defer:");
    Method method = class_getInstanceMethod(window, initializer);
    originalInitializer = (WindowInitializer)method_setImplementation(method, (IMP)initializeTransparentWindow);

    // 决定 sheet 是否播放动画的是 AppKit 的内部类，系统里找不到它时照常播放
    Class helper = objc_getClass("NSSheetMoveHelper");
    Method animation = helper == Nil ? NULL : class_getInstanceMethod(helper, sel_registerName("shouldSkipAnimation"));

    if (animation != NULL) {
        method_setImplementation(animation, (IMP)skipSheetAnimation);
    }
}
