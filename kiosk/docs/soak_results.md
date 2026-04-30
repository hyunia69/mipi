# Avatar 12-hour soak results — template

> Fill this in after running `scripts/soak_avatar.py --hours 12` on the Jetson.

## Environment

- Date:                       <YYYY-MM-DD>
- Mode:                       demo / live
- Hardware:                   Jetson Orin Nano (8GB)
- JetPack:                    6.1
- Avatar repeat interval:     8000 ms (default)

## Results

- Samples written:            <N>
- RSS min:                    <MB>
- RSS max:                    <MB>
- RSS drift (end − start):    <MB>
- GPU free min:               <MB or n/a>
- Crashes / re-launches:      <count>
- Avatar play count (est):    <hours × 3600 / 8>

## Analysis

```bash
python3 -c "
import csv
rows = list(csv.DictReader(open('soak.csv')))
rss = [int(r['rss_kb']) for r in rows if int(r['rss_kb']) > 0]
print(f'samples={len(rss)} min={min(rss)/1024:.1f}MB max={max(rss)/1024:.1f}MB drift={(rss[-1]-rss[0])/1024:.1f}MB')
"
```

(Paste output above in the Results section.)

## Verdict

- [ ] **PASS** — drift < 100 MB, no crashes, avatar still animating at end
- [ ] **FAIL** — investigate. Attach last 100 lines of stderr / dmesg.

## Console snippets (errors, warnings)

```
<paste here>
```
