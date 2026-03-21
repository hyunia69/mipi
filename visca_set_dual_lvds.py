import smbus2
import time

bus = smbus2.SMBus(9)
I2C_ADDR = 0x48

def write_reg(s, d):
    bus.write_byte_data(I2C_ADDR, (s << 3) | 0x00, d)

def read_reg(s):
    return bus.read_byte_data(I2C_ADDR, (s << 3) | 0x00)

def init_uart():
    write_reg(0x03, 0x80)
    write_reg(0x00, 0x60)
    write_reg(0x01, 0x00)
    write_reg(0x03, 0x03)
    write_reg(0x02, 0x07)
    time.sleep(0.01)
    write_reg(0x02, 0x01)

def flush():
    while read_reg(0x05) & 0x01:
        read_reg(0x00)

def send(cmd, label="", t=1.0):
    flush()
    for b in cmd:
        while not (read_reg(0x05) & 0x20):
            time.sleep(0.005)
        write_reg(0x00, b)
    cmd_hex = " ".join("%02X" % b for b in cmd)
    time.sleep(t)
    r = []
    while read_reg(0x05) & 0x01:
        r.append(read_reg(0x00))
    resp_hex = " ".join("%02X" % b for b in r) if r else "(none)"
    if label:
        print("  [%s] TX: %s" % (label, cmd_hex))
    else:
        print("  TX: %s" % cmd_hex)
    print("  RX: %s" % resp_hex)
    return r

def query_reg(reg_num, label=""):
    r = send([0x81, 0x09, 0x04, 0x24, reg_num, 0xFF], label, t=1.0)
    if len(r) >= 5:
        for i in range(len(r) - 4):
            if r[i] == 0x90 and r[i+1] == 0x50:
                val = (r[i+2] << 4) | r[i+3]
                return val
    return None

def set_reg(reg_num, value, label=""):
    hi = (value >> 4) & 0x0F
    lo = value & 0x0F
    r = send([0x81, 0x01, 0x04, 0x24, reg_num, hi, lo, 0xFF], label, t=3.0)
    return r

# =============================================
print("=== LVDS Dual Mode + 1080p60 Setup ===")
print("")

init_uart()
print("[1] UART initialized")

# VISCA init
print("")
print("[2] VISCA init")
send([0x88, 0x30, 0x01, 0xFF], "AddrSet")
time.sleep(0.3)
send([0x88, 0x01, 0x00, 0x01, 0xFF], "IF Clear")
time.sleep(0.3)

# Query current states
print("")
print("[3] Current register values")

val72 = query_reg(0x72, "Reg 0x72 (Monitor Mode)")
modes72 = {
    0x06: "1080p/30", 0x07: "1080p/30",
    0x09: "720p/60", 0x0A: "720p/60",
    0x13: "1080p/60", 0x15: "1080p/60",
}
if val72 is not None:
    print("  >> Reg 0x72 = 0x%02X (%s)" % (val72, modes72.get(val72, "other")))
time.sleep(0.3)

val74 = query_reg(0x74, "Reg 0x74 (LVDS Mode)")
modes74 = {0x00: "Single", 0x01: "Dual"}
if val74 is not None:
    print("  >> Reg 0x74 = 0x%02X (%s)" % (val74, modes74.get(val74, "unknown")))
time.sleep(0.3)

# Ensure 1080p60
if val72 != 0x13 and val72 != 0x15:
    print("")
    print("[4] Setting Register 0x72 = 0x13 (1080p/60)")
    set_reg(0x72, 0x13, "Set 1080p60")
    time.sleep(2.0)
    val72 = query_reg(0x72, "Verify 0x72")
    if val72 is not None:
        print("  >> Reg 0x72 = 0x%02X (%s)" % (val72, modes72.get(val72, "other")))
    time.sleep(0.3)
else:
    print("")
    print("[4] Already 1080p/60, skip")

# Set Dual LVDS
print("")
print("[5] Setting Register 0x74 = 0x01 (Dual LVDS)")
set_reg(0x74, 0x01, "Set Dual LVDS")
time.sleep(2.0)

val74 = query_reg(0x74, "Verify 0x74")
if val74 is not None:
    print("  >> Reg 0x74 = 0x%02X (%s)" % (val74, modes74.get(val74, "unknown")))
time.sleep(0.3)

# Save Custom Preset
print("")
print("[6] Saving Custom Preset")
send([0x81, 0x01, 0x04, 0x3F, 0x01, 0x7F, 0xFF], "Custom Set", t=3.0)
time.sleep(1.0)
send([0x81, 0x01, 0x04, 0x3F, 0x11, 0x7F, 0xFF], "Custom Active", t=2.0)
time.sleep(0.5)

# Final verify
print("")
print("[7] Final verification")
val72 = query_reg(0x72, "Reg 0x72")
val74 = query_reg(0x74, "Reg 0x74")
if val72 is not None:
    print("  >> Monitor Mode: 0x%02X (%s)" % (val72, modes72.get(val72, "other")))
if val74 is not None:
    print("  >> LVDS Mode: 0x%02X (%s)" % (val74, modes74.get(val74, "unknown")))

print("")
print("=== Done ===")
print("Camera: 1080p/60 + Dual LVDS")
print("Reload driver and test capture now.")
bus.close()
