/* mit_smoke.c - Run the MIT model .so files on the NI Linux RT target without LabVIEW.
 *
 * Calls the same NI Model Framework entry points that MIT uses (NIRT_*), chains the two
 * models like the RT VI (noise_gen.y_noisy -> signal_filter.u) and prints the error of
 * y_filt against y_clean. A failing dlopen here means the .so cannot load under MIT either.
 *
 * Build on the Windows host (NI Linux RT cross compiler 2017), then copy and run on the target:
 *   x86_64-nilrt-linux-gcc --sysroot=C:/build/17.0/x64/sysroots/core2-64-nilrt-linux
 *       -std=gnu99 -O2 -Wall -o mit_smoke mit_smoke.c -ldl -lm -lpthread
 *   ./mit_smoke [model folder, default /home/lvuser/models] [steps per phase, default 10000]
 * -lpthread is required: the MF 2020 .so files use sem_* without listing libpthread as a
 * dependency, so the loading process must provide it (lvrt already does).
 */
#include <dlfcn.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct {
    void *h;
    int32_t (*init)(double, double *, int32_t *, int32_t *, int32_t *);
    int32_t (*start)(void);
    int32_t (*sched)(double *, double *, double *, int32_t *);
    int32_t (*update)(void);
    int32_t (*setp)(uint32_t, uint32_t, double);
    int32_t (*pspec)(int32_t *, char *, int32_t *, char *, int32_t *, int32_t *, int32_t *, int32_t *);
    int32_t (*errmsg)(char *, int32_t *);
    int32_t (*fin)(void);
    double ts;
    int32_t nin, nout, ntask;
} Model;

static void *sym(void *h, const char *name, int *ok)
{
    void *p = dlsym(h, name);
    if (p == NULL) {
        printf("  missing symbol %s\n", name);
        *ok = 0;
    }
    return p;
}

static void print_err(const Model *m, const char *what)
{
    char msg[512];
    int32_t len = sizeof msg;
    msg[0] = '\0';
    if (m->errmsg != NULL && m->errmsg(msg, &len) == 0 && len > 0) printf("  %s: %.*s\n", what, (int)len, msg);
    else printf("  %s failed\n", what);
}

/* Load one model, print its interface, run InitializeModel and ModelStart. */
static int load(Model *m, const char *dir, const char *name)
{
    char path[512];
    int ok = 1;
    memset(m, 0, sizeof *m);
    snprintf(path, sizeof path, "%s/%s.so", dir, name);
    m->h = dlopen(path, RTLD_NOW | RTLD_LOCAL);   /* RTLD_NOW: fail here on any unresolved symbol */
    if (m->h == NULL) {
        printf("dlopen %s: %s\n", path, dlerror());
        return 0;
    }
    *(void **)&m->init = sym(m->h, "NIRT_InitializeModel", &ok);
    *(void **)&m->start = sym(m->h, "NIRT_ModelStart", &ok);
    *(void **)&m->sched = sym(m->h, "NIRT_Schedule", &ok);
    *(void **)&m->update = sym(m->h, "NIRT_ModelUpdate", &ok);
    *(void **)&m->setp = sym(m->h, "NIRT_SetScalarParameterInline", &ok);
    *(void **)&m->pspec = sym(m->h, "NIRT_GetParameterSpec", &ok);
    *(void **)&m->errmsg = sym(m->h, "NIRT_ModelError", &ok);
    *(void **)&m->fin = sym(m->h, "NIRT_FinalizeModel", &ok);
    if (!ok) return 0;

    if (m->init(-1.0, &m->ts, &m->nin, &m->nout, &m->ntask) != 0) { print_err(m, "InitializeModel"); return 0; }
    if (m->start() != 0) { print_err(m, "ModelStart"); return 0; }
    printf("%s: base step %g s, inports %d, outports %d, tasks %d\n", path, m->ts, m->nin, m->nout, m->ntask);

    int32_t idx = -1, zero = 0;
    int32_t n = m->pspec(&idx, NULL, &zero, NULL, &zero, NULL, NULL, NULL);   /* ID == NULL: parameter count */
    for (int32_t i = 0; i < n; i++) {
        char id[256], pname[256];
        int32_t k = i, idlen = sizeof id, pnlen = sizeof pname, dtype = 0, dims[8], nd = 8;
        if (m->pspec(&k, id, &idlen, pname, &pnlen, &dtype, dims, &nd) == 0)
            printf("  parameter %d: %.*s\n", (int)i, (int)idlen, id);
    }
    return 1;
}

/* Index of a parameter by its path, or -1. */
static int32_t param_index(const Model *m, const char *id)
{
    char buf[256];
    int32_t idx = -1, idlen = (int32_t)strlen(id), pnlen = 0, dtype = 0, dims[8], nd = 8;
    int32_t n = m->pspec(&idx, NULL, &pnlen, NULL, &pnlen, NULL, NULL, NULL);
    strncpy(buf, id, sizeof buf - 1);
    buf[sizeof buf - 1] = '\0';
    pnlen = 0;
    m->pspec(&idx, buf, &idlen, NULL, &pnlen, &dtype, dims, &nd);
    return (idx >= 0 && idx < n) ? idx : -1;
}

static int set_param(const Model *m, const char *id, double value)
{
    int32_t idx = param_index(m, id);
    if (idx < 0) { printf("  parameter %s not found\n", id); return 0; }
    if (m->setp((uint32_t)idx, 0, value) != 0) { print_err(m, id); return 0; }
    return 1;
}

static double now_us(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1e6 + t.tv_nsec * 1e-3;
}

/* Run both models for `steps` steps. Error statistics skip the first 0.05 s (filter convergence). */
static int run(Model *ng, Model *sf, int steps, double ts, const char *label)
{
    double in_ng[1] = {0.0}, out_ng[8], in_sf[1], out_sf[8], t = 0.0;
    double se = 0.0, sum_e = 0.0, max_e = 0.0, sn = 0.0, sn2 = 0.0, step_max = 0.0, step_sum = 0.0;
    int skip = (int)ceil(0.05 / ts), cnt = 0;

    for (int k = 0; k < steps; k++) {
        double t0 = now_us();
        if (ng->sched(in_ng, out_ng, &t, NULL) != 0 || ng->update() != 0) { print_err(ng, "noise_gen step"); return 0; }
        in_sf[0] = out_ng[1];                                   /* u = y_noisy */
        if (sf->sched(in_sf, out_sf, &t, NULL) != 0 || sf->update() != 0) { print_err(sf, "signal_filter step"); return 0; }
        double dt = now_us() - t0;
        step_sum += dt;
        if (dt > step_max) step_max = dt;

        if (k < skip) continue;
        double e = out_sf[0] - out_ng[0];                       /* e = y_filt - y_clean */
        double w = out_ng[1] - out_ng[0];                       /* added noise */
        se += e * e; sum_e += e; sn += w; sn2 += w * w; cnt++;
        if (fabs(e) > max_e) max_e = fabs(e);
    }
    double mean_w = sn / cnt;
    printf("%-28s RMSE %.4f  bias %+.5f  max|e| %.4f  noise std %.4f  step mean %.1f us, max %.1f us\n",
           label, sqrt(se / cnt), sum_e / cnt, max_e, sqrt(sn2 / cnt - mean_w * mean_w), step_sum / steps, step_max);
    return 1;
}

int main(int argc, char **argv)
{
    const char *dir = argc > 1 ? argv[1] : "/home/lvuser/models";
    int steps = argc > 2 ? atoi(argv[2]) : 10000;
    Model ng, sf;
    int ok = load(&ng, dir, "noise_gen") && load(&sf, dir, "signal_filter");

    /* Phase 1: compiled defaults (Ts 1e-4, filter_mode 4 Kalman). */
    ok = ok && run(&ng, &sf, steps, 1e-4, "Ts 1e-4, mode 4 (Kalman)");
    /* Phase 2: Set Parameter Inline path, as the RT VI uses it. */
    ok = ok && set_param(&sf, "signal_filter/filter_mode", 0) && run(&ng, &sf, steps, 1e-4, "Ts 1e-4, mode 0 (bypass)");
    ok = ok && set_param(&sf, "signal_filter/filter_mode", 1) && run(&ng, &sf, steps, 1e-4, "Ts 1e-4, mode 1 (LPF 1st)");
    /* Phase 3: Ts change in both models. */
    ok = ok && set_param(&ng, "noise_gen/Ts", 1e-3) && set_param(&sf, "signal_filter/Ts", 1e-3) &&
         set_param(&sf, "signal_filter/filter_mode", 4) && run(&ng, &sf, steps, 1e-3, "Ts 1e-3, mode 4 (Kalman)");
    /* Phase 4: particle filter cost, the largest step time (grows linearly with pf_N). */
    ok = ok && set_param(&ng, "noise_gen/Ts", 1e-4) && set_param(&sf, "signal_filter/Ts", 1e-4) &&
         set_param(&sf, "signal_filter/filter_mode", 5) && run(&ng, &sf, steps, 1e-4, "Ts 1e-4, mode 5, pf_N 200");
    ok = ok && set_param(&sf, "signal_filter/pf_N", 1000) && run(&ng, &sf, steps, 1e-4, "Ts 1e-4, mode 5, pf_N 1000");

    if (ng.h != NULL && ng.fin != NULL) ng.fin();
    if (sf.h != NULL && sf.fin != NULL) sf.fin();
    if (ng.h != NULL) dlclose(ng.h);
    if (sf.h != NULL) dlclose(sf.h);
    printf(ok ? "PASS\n" : "FAIL\n");
    return ok ? 0 : 1;
}
