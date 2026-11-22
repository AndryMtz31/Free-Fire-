#import <UIKit/UIKit.h>
#include <mach-o/dyld.h>
#include <math.h>
#include <stdio.h>

// ================= CONFIG =================
static BOOL  gOn     = NO;
static float gFOV    = 12.0f;   // grados de cono
static float gSmooth = 6.0f;    // 1 = snap duro, 20 = pegajoso
static float gMaxDist = 150.0f; // metros
static UIButton *gBtn = nil;

// ================= OFFSETS ================
// TODO: rellenar. Se rehacen en cada OB.
#define OFF_LOCAL_PLAYER  0x0
#define OFF_ENTITY_LIST   0x0
#define OFF_ENTITY_COUNT  0x0
#define OFF_POS           0x38
#define OFF_YAW           0x60
#define OFF_PITCH         0x64
// ==========================================

static void fflog(const char *fmt, ...) {
    static NSString *p = nil;
    if (!p) {
        p = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
             stringByAppendingPathComponent:@"ffaimbot.log"];
    }
    va_list a; va_start(a, fmt);
    NSString *s = [[NSString alloc] initWithFormat:[NSString stringWithUTF8String:fmt] arguments:a];
    va_end(a);
    FILE *f = fopen(p.UTF8String, "a");
    if (f) { fprintf(f, "[%s]\n", s.UTF8String); fclose(f); }
}

static uintptr_t unity_base(void) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (n && strstr(n, "UnityFramework")) return (uintptr_t)_dyld_get_image_header(i);
    }
    return 0;
}

static inline uintptr_t rd_ptr(uintptr_t a) { return a ? *(uintptr_t *)a : 0; }
static inline float     rd_f  (uintptr_t a) { return a ? *(float *)a : 0.0f; }
static inline void      wr_f  (uintptr_t a, float v) { if (a) *(float *)a = v; }

static void tick(void) {
    if (!gOn) return;

    uintptr_t b = unity_base();
    if (!b) return;

    uintptr_t local = rd_ptr(b + OFF_LOCAL_PLAYER);
    uintptr_t list  = rd_ptr(b + OFF_ENTITY_LIST);
    if (!local || !list) return;

    int count = *(int *)(b + OFF_ENTITY_COUNT);
    if (count <= 0 || count > 64) return;

    float lx = rd_f(local + OFF_POS);
    float ly = rd_f(local + OFF_POS + 4);
    float lz = rd_f(local + OFF_POS + 8);

    uintptr_t best = 0;
    float bestDist = 1e9f;
    float bestYaw = 0.0f, bestPitch = 0.0f;
    float curYaw = rd_f(local + OFF_YAW);

    for (int i = 0; i < count; i++) {
        uintptr_t e = rd_ptr(list + i * 8);
        if (!e || e == local) continue;

        float ex = rd_f(e + OFF_POS);
        float ey = rd_f(e + OFF_POS + 4);
        float ez = rd_f(e + OFF_POS + 8);

        float dx = ex - lx, dy = ey - ly, dz = ez - lz;
        float dist = sqrtf(dx * dx + dy * dy + dz * dz);
        if (dist < 1.0f || dist > gMaxDist) continue;

        float yaw = atan2f(dx, dz) * 57.29578f;
        float delta = fabsf(yaw - curYaw);
        if (delta > 180.0f) delta = 360.0f - delta;
        if (delta > gFOV) continue;               // fuera del cono

        if (dist < bestDist) {
            bestDist  = dist;
            best      = e;
            bestYaw   = yaw;
            bestPitch = -atan2f(dy, sqrtf(dx * dx + dz * dz)) * 57.29578f;
        }
    }

    if (!best) return;

    wr_f(local + OFF_YAW,   curYaw + (bestYaw - curYaw) / gSmooth);
    wr_f(local + OFF_PITCH, rd_f(local + OFF_PITCH) + (bestPitch - rd_f(local + OFF_PITCH)) / gSmooth);
}

static void makeButton(void) {
    UIWindow *w = [[UIWindow alloc] initWithFrame:CGRectMake(24, 90, 56, 56)];
    w.windowLevel = UIWindowLevelAlert + 2;
    w.backgroundColor = [UIColor clearColor];
    w.rootViewController = [UIViewController new];

    gBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    gBtn.frame = w.bounds;
    gBtn.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    gBtn.layer.cornerRadius = 28;
    gBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [gBtn setTitle:@"AIM" forState:UIControlStateNormal];
    [gBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [gBtn addTarget:gBtn action:@selector(noop) forControlEvents:UIControlEventTouchUpInside];
    [w.rootViewController.view addSubview:gBtn];

    [gBtn addAction:[UIAction actionWithHandler:^(UIAction *a) {
        gOn = !gOn;
        gBtn.backgroundColor = gOn
            ? [UIColor colorWithRed:0.13 green:0.77 blue:0.37 alpha:0.75]
            : [UIColor colorWithWhite:0 alpha:0.45];
        fflog("toggle -> %d", gOn);
    }] forControlEvents:UIControlEventTouchUpInside];

    w.hidden = NO;
    fflog("boton listo");
}

%ctor {
    fflog("FFAimbot cargado | unity base = %p", (void *)unity_base());

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        makeButton();
        dispatch_source_t t = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                                    dispatch_get_global_queue(0, 0));
        dispatch_source_set_timer(t, DISPATCH_TIME_NOW, NSEC_PER_SEC / 60, 0);
        dispatch_source_set_event_handler(t, ^{ tick(); });
        dispatch_resume(t);
    });
}
