/* mit_smoke.c - Run NI MIT model .so files on the NI Linux RT target without LabVIEW.
 *
 * Calls the same NI Model Framework entry points that MIT uses (NIRT_*): loads each model,
 * prints its interface (base step, inport/outport element counts, parameter paths), sets
 * scalar parameters by path, steps the models in argument order with optional same-step
 * wiring (like chained Take Model Time Step calls in one Timed Loop iteration), and prints
 * the step time and min/max/last of every outport element. FAIL on any load, parameter or
 * step error, or on a non-finite output. A failing dlopen here means MIT cannot load the
 * .so either.
 *
 * Build on the Windows host (NI Linux RT cross compiler 2017):
 *   x86_64-nilrt-linux-gcc --sysroot=C:/build/17.0/x64/sysroots/core2-64-nilrt-linux
 *       -std=gnu99 -O2 -Wall -o mit_smoke mit_smoke.c -ldl -lm -lpthread
 * Run on the target:
 *   ./mit_smoke [-n steps] [-s model/param=value]... [-w dst:in=src:out]... a.so [b.so ...]
 *     -n steps               steps to run (default 10000; 0 = load and print the interface only)
 *     -s model/param=value   set a scalar parameter by its MIT path before stepping (repeatable)
 *     -w dst:in=src:out      before model dst steps, copy outport element `out` of model src into
 *                            inport element `in` of model dst; models are numbered from 0 in
 *                            argument order and src < dst (repeatable). Unwired inports stay 0.
 *   Example: ./mit_smoke -s signal_filter/filter_mode=0 -w 1:0=0:1 \
 *                /home/lvuser/models/noise_gen.so /home/lvuser/models/signal_filter.so
 * -lpthread is required: the MF 2020 .so files use sem_* without listing libpthread as a
 * dependency, so the loading process must provide it (lvrt already does).
 * RTLD_LOCAL is required: every MF 2020 .so exports the same global names (MdlOutputs, S,
 * rtParameter, NIRT_*); with RTLD_GLOBAL a second model binds to the first one's symbols.
 * Single-rate models only (NIRT_Schedule is called with dispatchtasks = NULL).
 */
#include <dlfcn.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define MAX_MODELS 8
#define MAX_SETS 32
#define MAX_WIRES 32

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
    double *in, *out, *omin, *omax;   /* inport/outport element buffers, outport statistics */
} Model;

typedef struct { int dst, in, src, out; } Wire;
typedef struct { const char *id; double value; } Setting;

static int usage(const char *prog)
{
    printf("usage: %s [-n steps] [-s model/param=value]... [-w dst:in=src:out]... model.so [model.so ...]\n", prog);
    return 2;
}

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

/* Load one model, run InitializeModel and ModelStart, print its interface. */
static int load(Model *m, int num, const char *path)
{
    int ok = 1;
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
    printf("model %d %s: base step %g s, inport elements %d, outport elements %d, tasks %d\n",
           num, path, m->ts, m->nin, m->nout, m->ntask);
    if (m->ntask > 1) { printf("  multirate models are not supported\n"); return 0; }

    m->in = calloc(m->nin > 0 ? m->nin : 1, sizeof(double));
    m->out = calloc(m->nout > 0 ? m->nout : 1, sizeof(double));
    m->omin = calloc(m->nout > 0 ? m->nout : 1, sizeof(double));
    m->omax = calloc(m->nout > 0 ? m->nout : 1, sizeof(double));
    if (m->in == NULL || m->out == NULL || m->omin == NULL || m->omax == NULL) { printf("  out of memory\n"); return 0; }

    int32_t idx = -1, zero = 0;
    int32_t n = m->pspec(&idx, NULL, &zero, NULL, &zero, NULL, NULL, NULL);   /* ID == NULL: parameter count */
    for (int32_t i = 0; i < n; i++) {
        char id[256];
        int32_t k = i, idlen = sizeof id, nd = -1;   /* nd = -1: query the dimension count, copy no dims */
        if (m->pspec(&k, id, &idlen, NULL, &zero, NULL, NULL, &nd) == 0)
            printf("  parameter %d: %.*s\n", (int)i, (int)idlen, id);
    }
    return 1;
}

/* Index of a parameter by its path, or -1. */
static int32_t param_index(const Model *m, const char *id)
{
    char buf[256];
    int32_t idx = -1, idlen = (int32_t)strlen(id), pnlen = 0, nd = -1;
    int32_t n = m->pspec(&idx, NULL, &pnlen, NULL, &pnlen, NULL, NULL, NULL);
    strncpy(buf, id, sizeof buf - 1);
    buf[sizeof buf - 1] = '\0';
    m->pspec(&idx, buf, &idlen, NULL, &pnlen, NULL, NULL, &nd);
    return (idx >= 0 && idx < n) ? idx : -1;
}

static int set_param(const Model *m, int nm, const char *id, double value)
{
    for (int i = 0; i < nm; i++) {
        int32_t idx = param_index(&m[i], id);
        if (idx < 0) continue;
        if (m[i].setp((uint32_t)idx, 0, value) != 0) { print_err(&m[i], id); return 0; }
        printf("set %s = %g (model %d, parameter index %d)\n", id, value, i, (int)idx);
        return 1;
    }
    printf("parameter %s not found\n", id);
    return 0;
}

static int check_wire(const Model *m, int nm, const Wire *w)
{
    if (w->src < 0 || w->dst <= w->src || w->dst >= nm ||
        w->in < 0 || w->in >= m[w->dst].nin || w->out < 0 || w->out >= m[w->src].nout) {
        printf("bad wire %d:%d=%d:%d: need 0 <= src < dst < %d and element indexes inside the ports\n",
               w->dst, w->in, w->src, w->out, nm);
        return 0;
    }
    return 1;
}

static double now_us(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1e6 + t.tv_nsec * 1e-3;
}

/* Step all models `steps` times; models step in argument order, wires copy within one step. */
static int run(Model *m, int nm, const Wire *wire, int nw, long steps)
{
    double t = 0.0, step_sum = 0.0, step_max = 0.0;
    for (int i = 0; i < nm; i++)
        for (int j = 0; j < m[i].nout; j++) { m[i].omin[j] = INFINITY; m[i].omax[j] = -INFINITY; }

    for (long k = 0; k < steps; k++) {
        double t0 = now_us();
        for (int i = 0; i < nm; i++) {
            for (int w = 0; w < nw; w++)
                if (wire[w].dst == i) m[i].in[wire[w].in] = m[wire[w].src].out[wire[w].out];
            if (m[i].sched(m[i].in, m[i].out, &t, NULL) != 0 || m[i].update() != 0) {
                printf("step %ld, model %d:\n", k, i);
                print_err(&m[i], "step");
                return 0;
            }
        }
        double dt = now_us() - t0;
        step_sum += dt;
        if (dt > step_max) step_max = dt;

        for (int i = 0; i < nm; i++)
            for (int j = 0; j < m[i].nout; j++) {
                double y = m[i].out[j];
                if (!isfinite(y)) { printf("step %ld: model %d outport element %d = %g\n", k, i, j, y); return 0; }
                if (y < m[i].omin[j]) m[i].omin[j] = y;
                if (y > m[i].omax[j]) m[i].omax[j] = y;
            }
    }
    printf("ran %ld steps: step time mean %.1f us, max %.1f us (all models)\n", steps, step_sum / steps, step_max);
    for (int i = 0; i < nm; i++)
        for (int j = 0; j < m[i].nout; j++)
            printf("  model %d outport element %d: min %.4g  max %.4g  last %.4g\n",
                   i, j, m[i].omin[j], m[i].omax[j], m[i].out[j]);
    return 1;
}

int main(int argc, char **argv)
{
    Model m[MAX_MODELS];
    Setting set[MAX_SETS];
    Wire wire[MAX_WIRES];
    int nm, ns = 0, nw = 0, ok = 1, c;
    long steps = 10000;
    char *end;

    setvbuf(stdout, NULL, _IONBF, 0);   /* unbuffered: keep the output printed before a segfault */
    memset(m, 0, sizeof m);
    while ((c = getopt(argc, argv, "n:s:w:")) != -1) {
        switch (c) {
        case 'n':
            steps = strtol(optarg, &end, 10);
            if (end == optarg || *end != '\0' || steps < 0) return usage(argv[0]);
            break;
        case 's': {
            char *eq = strrchr(optarg, '=');
            if (ns == MAX_SETS || eq == NULL || eq == optarg) return usage(argv[0]);
            *eq = '\0';
            set[ns].id = optarg;
            set[ns].value = strtod(eq + 1, &end);
            if (end == eq + 1 || *end != '\0') return usage(argv[0]);
            ns++;
            break;
        }
        case 'w': {
            char extra;
            if (nw == MAX_WIRES || sscanf(optarg, "%d:%d=%d:%d%c", &wire[nw].dst, &wire[nw].in,
                                          &wire[nw].src, &wire[nw].out, &extra) != 4)
                return usage(argv[0]);
            nw++;
            break;
        }
        default:
            return usage(argv[0]);
        }
    }
    nm = argc - optind;
    if (nm < 1 || nm > MAX_MODELS) return usage(argv[0]);

    for (int i = 0; i < nm && ok; i++) ok = load(&m[i], i, argv[optind + i]);
    for (int k = 0; k < nw && ok; k++) ok = check_wire(m, nm, &wire[k]);
    for (int k = 0; k < ns && ok; k++) ok = set_param(m, nm, set[k].id, set[k].value);
    if (ok && steps > 0) ok = run(m, nm, wire, nw, steps);

    for (int i = 0; i < nm; i++) {
        if (m[i].h != NULL && m[i].fin != NULL) m[i].fin();
        if (m[i].h != NULL) dlclose(m[i].h);
        free(m[i].in);
        free(m[i].out);
        free(m[i].omin);
        free(m[i].omax);
    }
    printf(ok ? "PASS\n" : "FAIL\n");
    return ok ? 0 : 1;
}
