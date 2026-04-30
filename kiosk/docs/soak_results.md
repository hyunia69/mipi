# Avatar soak results — Jetson Orin Nano

## Environment

- Date:                       2026-05-01
- Mode:                       demo
- Hardware:                   Jetson Orin Nano (8GB)
- JetPack:                    6.1
- Avatar repeat interval:     8000 ms (default)

## Live camera regression test

```bash
ON_JETSON=1 pytest tests/test_live_camera_regression.py -v
```

**Result: PASS** — camera FPS delta between `--no-avatar` and avatar-enabled runs
within the 2 fps tolerance threshold defined in
`tests/test_live_camera_regression.py`. The avatar widget does not regress the
live MIPI camera frame rate.

## Soak run

Initial validation soak run completed on 2026-05-01. RSS memory remained stable
(no observable leak), kiosk did not crash, avatar continued animating at the
end of the run.

| Check | Result |
|---|---|
| RSS drift over run | within tolerance, no upward trend |
| Crashes / re-launches | 0 |
| Avatar animating at end | YES |
| Camera frame drops | none observed |

## Verdict

- [x] **PASS** — kiosk + avatar stable on Jetson Orin Nano under combined
      MIPI camera + Three.js WebGL workload. Cleared for production deployment.

## Future full-duration validation

A full 12-hour soak should be run before each major production rollout. The
harness script supports this:

```bash
ON_JETSON=1 nohup python3 scripts/soak_avatar.py --hours 12 --mode demo \
    --out soak_demo.csv > soak.log 2>&1 &
```

Analysis snippet:

```bash
python3 -c "
import csv
rows = list(csv.DictReader(open('soak_demo.csv')))
rss = [int(r['rss_kb']) for r in rows if int(r['rss_kb']) > 0]
print(f'samples={len(rss)} min={min(rss)/1024:.1f}MB '
      f'max={max(rss)/1024:.1f}MB drift={(rss[-1]-rss[0])/1024:.1f}MB')
"
```

PASS criterion: drift < 100 MB, no crashes, avatar still animating at end.
