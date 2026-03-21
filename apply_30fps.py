import paramiko
import time

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.219.125', username='hyunia', password='123456', timeout=10)

def run_sudo(cmd, wait=5):
    stdin, stdout, stderr = ssh.exec_command('sudo -S bash -c "%s" 2>&1' % cmd.replace('"', '\\"'), get_pty=True)
    stdin.write('123456\n')
    stdin.flush()
    time.sleep(wait)
    out = stdout.read().decode()
    lines = [l for l in out.split('\n') if '123456' not in l and '[sudo]' not in l]
    return '\n'.join(lines).strip()

def run(cmd, wait=3):
    stdin, stdout, stderr = ssh.exec_command(cmd)
    time.sleep(wait)
    return stdout.read().decode().strip()

# 1. Backup original overlay
print("[1] Backing up original overlay...")
out = run_sudo('cp /boot/tegra234-p3767-camera-p3768-imx219-C.dtbo /boot/tegra234-p3767-camera-p3768-imx219-C.dtbo.bak.60fps')
print("    Backup done")

# 2. Decompile to DTS
print("[2] Decompiling overlay to DTS...")
out = run_sudo('dtc -I dtb -O dts /boot/tegra234-p3767-camera-p3768-imx219-C.dtbo -o /tmp/imx219-C.dts', wait=5)
if out:
    print("    " + out)

# 3. Modify DTS for 1080p30
print("[3] Patching DTS for 1080p30...")
patch_cmds = [
    # pix_clk_hz: 148400000 -> 74250000 (1080p30)
    "sed -i 's/pix_clk_hz = \"148400000\"/pix_clk_hz = \"74250000\"/' /tmp/imx219-C.dts",
    # max_framerate: 60000000 -> 30000000
    "sed -i 's/max_framerate = \"60000000\"/max_framerate = \"30000000\"/' /tmp/imx219-C.dts",
    # default_framerate: 60000000 -> 30000000
    "sed -i 's/default_framerate = \"60000000\"/default_framerate = \"30000000\"/' /tmp/imx219-C.dts",
    # default_exp_time: 16667 -> 33333
    "sed -i 's/default_exp_time = \"16667\"/default_exp_time = \"33333\"/' /tmp/imx219-C.dts",
    # mclk_multiplier: 24 -> 12 (proportional to pixel clock)
    "sed -i 's/mclk_multiplier = \"24\"/mclk_multiplier = \"12\"/' /tmp/imx219-C.dts",
]
for cmd in patch_cmds:
    run_sudo(cmd, wait=1)

# Verify changes
print("    Verifying patched values...")
out = run('grep -E "pix_clk_hz|max_framerate|default_framerate|default_exp_time|mclk_multiplier" /tmp/imx219-C.dts')
for line in out.split('\n'):
    print("    " + line.strip())

# 4. Recompile to DTBO
print("[4] Compiling patched DTS to DTBO...")
out = run_sudo('dtc -I dts -O dtb /tmp/imx219-C.dts -o /tmp/imx219-C-30fps.dtbo', wait=5)
if out:
    print("    " + out)

# 5. Install new overlay
print("[5] Installing new overlay...")
out = run_sudo('cp /tmp/imx219-C-30fps.dtbo /boot/tegra234-p3767-camera-p3768-imx219-C.dtbo')
print("    Installed")

# 6. Verify
print("[6] Verifying installed overlay...")
out = run_sudo('dtc -I dtb -O dts /boot/tegra234-p3767-camera-p3768-imx219-C.dtbo 2>/dev/null | grep -E \"pix_clk_hz|max_framerate|default_framerate\"', wait=5)
for line in out.split('\n'):
    print("    " + line.strip())

print("")
print("=== DONE ===")
print("Overlay patched for 1080p30 (74.25MHz pixel clock, 30fps)")
print("Original backed up to: /boot/tegra234-p3767-camera-p3768-imx219-C.dtbo.bak.60fps")
print("")
print("REBOOT REQUIRED to apply changes.")
print("After reboot, test with:")
print("  gst-launch-1.0 v4l2src device=/dev/video0 ! 'video/x-raw,format=UYVY,width=1920,height=1080' ! videoconvert ! xvimagesink")

ssh.close()
