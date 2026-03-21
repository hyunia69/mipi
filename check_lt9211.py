import paramiko
import time

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.219.125', username='hyunia', password='123456', timeout=10)

def run(cmd, wait=3):
    stdin, stdout, stderr = ssh.exec_command(cmd)
    time.sleep(wait)
    return stdout.read().decode().strip()

def run_sudo(cmd, wait=3):
    stdin, stdout, stderr = ssh.exec_command(cmd, get_pty=True)
    stdin.write('123456\n')
    stdin.flush()
    time.sleep(wait)
    out = stdout.read().decode()
    lines = [l for l in out.split('\n') if '123456' not in l and '[sudo]' not in l]
    return '\n'.join(lines).strip()

# 1. Module params
print("=== Module parameters ===")
out = run('ls /sys/module/lt9211cmipi/parameters/ 2>/dev/null')
print(out if out else "(none)")

# 2. Driver strings - mode related
print("\n=== Driver mode strings ===")
out = run('strings /lib/modules/5.15.148-tegra/updates/drivers/media/i2c/lt9211cmipi.ko | grep -i -E "30fps|60fps|mode|frame_rate|select|init_reg|write_table" | sort -u')
print(out)

# 3. I2C bus 9 devices
print("\n=== I2C bus 9 ===")
out = run('i2cdetect -y -r 9 2>/dev/null')
print(out)

# 4. Try reading LT9211C registers (force, bypass driver)
print("\n=== LT9211C registers (0x10) ===")
# LT9211C bank switching: write 0xFF with bank number, then read registers
# Common LT9211C register banks: 0x80, 0x81, 0x82, 0xD0, 0xD8
regs = run_sudo('sudo i2cset -y -f 9 0x10 0xFF 0x81 2>/dev/null; for r in 0x00 0x01 0x02 0x03 0x04 0x05 0x06 0x07 0x08 0x09 0x0A 0x0B 0x0C 0x0D 0x0E 0x0F; do printf "0x81:%s = " $r; sudo i2cget -y -f 9 0x10 $r 2>/dev/null; done', wait=5)
print("Bank 0x81:")
print(regs)

# Check LT9211C chip ID (typically at bank 0x81, reg 0x00-0x01)
print("\n=== LT9211C Chip ID ===")
regs = run_sudo('sudo i2cset -y -f 9 0x10 0xFF 0x81 2>/dev/null; printf "ChipID[0]: "; sudo i2cget -y -f 9 0x10 0x00 2>/dev/null; printf "ChipID[1]: "; sudo i2cget -y -f 9 0x10 0x01 2>/dev/null; printf "ChipID[2]: "; sudo i2cget -y -f 9 0x10 0x02 2>/dev/null', wait=3)
print(regs)

# 5. Check LVDS RX status (bank 0xD0)
print("\n=== LVDS RX Status (bank 0xD0) ===")
regs = run_sudo('sudo i2cset -y -f 9 0x10 0xFF 0xD0 2>/dev/null; for r in 0x80 0x81 0x82 0x83 0x84 0x85 0x86 0x87 0x88 0x89 0x8A 0x8B 0x8C 0x8D 0x8E 0x8F; do printf "0xD0:%s = " $r; sudo i2cget -y -f 9 0x10 $r 2>/dev/null; done', wait=5)
print(regs)

# 6. MIPI TX status (bank 0xD8)
print("\n=== MIPI TX Status (bank 0xD8) ===")
regs = run_sudo('sudo i2cset -y -f 9 0x10 0xFF 0xD8 2>/dev/null; for r in 0x00 0x01 0x02 0x03 0x04 0x05 0x06 0x07 0x08 0x09 0x0A 0x0B 0x0C 0x0D 0x0E 0x0F; do printf "0xD8:%s = " $r; sudo i2cget -y -f 9 0x10 $r 2>/dev/null; done', wait=5)
print(regs)

ssh.close()
