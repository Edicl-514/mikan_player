import csv
import statistics

def load(path):
    with open(path, encoding='utf-8') as f:
        rows = list(csv.DictReader(f))
    for r in rows:
        for k, v in list(r.items()):
            if k == 'Timestamp' or k == 'PackageName' or k == 'ProcessState' or k == 'Error':
                continue
            try:
                r[k] = float(v) if v not in ('', None) else None
            except ValueError:
                r[k] = None
    return rows

mikan = load(r'D:\code\mikan_player\mikan-play-90s.csv')
animeko = load(r'D:\code\mikan_player\animeko-play-90s.csv')

def get_col(rows, name):
    return [r[name] for r in rows if r[name] is not None]

def stats(rows, name):
    vals = get_col(rows, name)
    if not vals:
        return None
    return {
        'min': min(vals),
        'max': max(vals),
        'avg': statistics.mean(vals),
        'last': rows[-1][name] if rows[-1][name] is not None else None,
        'first': rows[0][name] if rows[0][name] is not None else None,
    }

def fmt(s):
    if s is None:
        return 'N/A'
    return f"min={s['min']/1024:7.1f} max={s['max']/1024:7.1f} avg={s['avg']/1024:7.1f} last={s['last']/1024:7.1f} MiB"

def fmt_raw(s):
    if s is None:
        return 'N/A'
    return f"min={s['min']:>10.0f} max={s['max']:>10.0f} avg={s['avg']:>10.0f} last={s['last']:>10.0f}"

def peak_after(rows, t_seconds, name):
    sub = [r for r in rows if r['ElapsedMs']/1000.0 >= t_seconds and r[name] is not None]
    if not sub:
        return None
    return max(sub, key=lambda r: r[name])

print("="*100)
print(f"mikan samples={len(mikan)}  elapsed={mikan[-1]['ElapsedMs']/1000:.1f}s")
print(f"animeko samples={len(animeko)}  elapsed={animeko[-1]['ElapsedMs']/1000:.1f}s")
print("="*100)

print("\n[1] TotalPSS (MiB) - overall")
print(f"  mikan  : {fmt(stats(mikan, 'TotalPssKb'))}")
print(f"  animeko: {fmt(stats(animeko, 'TotalPssKb'))}")

print("\n[2] TotalRSS (MiB) - overall")
print(f"  mikan  : {fmt(stats(mikan, 'TotalRssKb'))}")
print(f"  animeko: {fmt(stats(animeko, 'TotalRssKb'))}")

print("\n[3] Component breakdown - last sample (MiB) + avg (MiB)")
components = [
    ('JavaHeapPssKb', 'Java Heap'),
    ('DalvikHeapPssKb', 'Dalvik Heap'),
    ('NativeHeapPssKb', 'Native Heap'),
    ('GraphicsPssKb', 'Graphics'),
    ('CodePssKb', 'Code'),
    ('StackPssKb', 'Stack'),
    ('PrivateOtherPssKb', 'Private Other'),
    ('SystemPssKb', 'System'),
]
print(f"  {'Component':<16} {'mikan last':>12} {'mikan avg':>12} {'animeko last':>14} {'animeko avg':>14}")
for c, label in components:
    ms = stats(mikan, c)
    as_ = stats(animeko, c)
    ml = ms['last']/1024 if ms else 0
    ma = ms['avg']/1024 if ms else 0
    al = as_['last']/1024 if as_ else 0
    aa = as_['avg']/1024 if as_ else 0
    print(f"  {label:<16} {ml:>10.1f}    {ma:>10.1f}    {al:>12.1f}    {aa:>12.1f}")

print("\n[4] Dalvik/Native heap details (last sample, MiB)")
for app, rows in [('mikan', mikan), ('animeko', animeko)]:
    print(f"  {app}:")
    for k in ['NativeHeapSizeKb','NativeHeapAllocKb','NativeHeapFreeKb','DalvikHeapSizeKb','DalvikHeapAllocKb','DalvikHeapFreeKb']:
        v = rows[-1][k]
        print(f"    {k:<22} {v/1024:>8.1f} MiB")
    print(f"    NativeAlloc/Size ratio: {rows[-1]['NativeHeapAllocKb']/rows[-1]['NativeHeapSizeKb']*100:.1f}%")
    print(f"    DalvikAlloc/Size ratio: {rows[-1]['DalvikHeapAllocKb']/rows[-1]['DalvikHeapSizeKb']*100:.1f}%")

print("\n[5] Peak TotalPSS in two phases (MiB)")
for label, t0, t1 in [('first 30s', 0, 30), ('30-60s', 30, 60), ('60-90s (idle on home)', 60, 90)]:
    ms = [r for r in mikan if t0 <= r['ElapsedMs']/1000.0 < t1 and r['TotalPssKb'] is not None]
    as_ = [r for r in animeko if t0 <= r['ElapsedMs']/1000.0 < t1 and r['TotalPssKb'] is not None]
    print(f"  {label:<25} mikan peak={max(r['TotalPssKb']/1024 for r in ms):.1f}  avg={statistics.mean(r['TotalPssKb']/1024 for r in ms):.1f}   animeko peak={max(r['TotalPssKb']/1024 for r in as_):.1f}  avg={statistics.mean(r['TotalPssKb']/1024 for r in as_):.1f}")

print("\n[6] Battery/Energy")
def battery_stats(rows, label):
    pw = get_col(rows, 'BatteryDischargePowerMw')
    cur = get_col(rows, 'BatteryCurrentUa')
    temp = get_col(rows, 'BatteryTemperatureC')
    level = get_col(rows, 'BatteryLevelPercent')
    print(f"  {label}:")
    if pw:
        print(f"    DischargePower  avg={statistics.mean(pw):7.1f} mW  min={min(pw):7.1f}  max={max(pw):7.1f}  total_J≈{statistics.mean(pw)*(rows[-1]['ElapsedMs']-rows[0]['ElapsedMs'])/1000:.1f}")
    if cur:
        print(f"    Current         avg={statistics.mean(cur)/1000:7.1f} mA  min={min(cur)/1000:7.1f}  max={max(cur)/1000:7.1f}")
    if temp:
        print(f"    Temperature     avg={statistics.mean(temp):.1f} C   min={min(temp):.1f}  max={max(temp):.1f}  delta={max(temp)-min(temp):.1f}")
    if level:
        print(f"    Level           {level[0]:.0f} -> {level[-1]:.0f}  delta={level[0]-level[-1]:.0f}%")

battery_stats(mikan, 'mikan')
battery_stats(animeko, 'animeko')

print("\n[7] VmHWM (peak resident set, MiB) - end-of-run")
print(f"  mikan  : {mikan[-1]['VmHwmKb']/1024:.1f}")
print(f"  animeko: {animeko[-1]['VmHwmKb']/1024:.1f}")

print("\n[8] Stability - coefficient of variation of TotalPss over [40s, end)")
def cov(rows, name, t_from=40):
    sub = [r[name] for r in rows if r['ElapsedMs']/1000.0 >= t_from and r[name] is not None]
    if len(sub) < 2:
        return None
    m = statistics.mean(sub)
    return statistics.pstdev(sub)/m*100 if m else None
print(f"  mikan  CoV={cov(mikan,'TotalPssKb'):.1f}%")
print(f"  animeko CoV={cov(animeko,'TotalPssKb'):.1f}%")

print("\n[9] Sample collection latency (ms)")
mc = get_col(mikan, 'CollectionMs')
ac = get_col(animeko, 'CollectionMs')
print(f"  mikan  avg={statistics.mean(mc):.0f}  max={max(mc)}  min={min(mc)}")
print(f"  animeko avg={statistics.mean(ac):.0f}  max={max(ac)}  min={min(ac)}")

print("\n[10] PSS growth from first 5 samples avg to last 5 samples avg (MiB)")
for app, rows in [('mikan', mikan), ('animeko', animeko)]:
    head = statistics.mean([r['TotalPssKb'] for r in rows[:5] if r['TotalPssKb'] is not None])/1024
    tail = statistics.mean([r['TotalPssKb'] for r in rows[-5:] if r['TotalPssKb'] is not None])/1024
    print(f"  {app}: head={head:.1f}  tail={tail:.1f}  delta={tail-head:+.1f} MiB ({(tail-head)/head*100:+.1f}%)")

print("\n[11] Largest single components at end (% of TotalPSS)")
total_m = mikan[-1]['TotalPssKb']
total_a = animeko[-1]['TotalPssKb']
print("  mikan:")
for c, label in components:
    print(f"    {label:<16} {mikan[-1][c]/total_m*100:>5.1f}%")
print("  animeko:")
for c, label in components:
    print(f"    {label:<16} {animeko[-1][c]/total_a*100:>5.1f}%")

print("\n[12] Note on sampling alignment")
print(f"  mikan  first t={mikan[0]['ElapsedMs']/1000:.1f}s  last t={mikan[-1]['ElapsedMs']/1000:.1f}s  count={len(mikan)}")
print(f"  animeko first t={animeko[0]['ElapsedMs']/1000:.1f}s  last t={animeko[-1]['ElapsedMs']/1000:.1f}s  count={len(animeko)}")
