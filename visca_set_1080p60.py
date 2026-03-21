import smbus2
import time

bus = smbus2.SMBus(9)
I2C_ADDR = 0x48

def write_reg(subaddr, data, channel=0):
    reg = (subaddr << 3) | (channel << 1)
    bus.write_byte_data(I2C_ADDR, reg, data)

def read_reg(subaddr, channel=0):
    reg = (subaddr << 3) | (channel << 1)
    return bus.read_byte_data(I2C_ADDR, reg)

def init_uart():
    write_reg(0x03, 0x80)
    write_reg(0x00, 0x60)  # 9600 baud @ 14.7456MHz
    write_reg(0x01, 0x00)
    write_reg(0x03, 0x03)  # 8N1
    write_reg(0x02, 0x07)  # Reset FIFOs
    time.sleep(0.01)
    write_reg(0x02, 0x01)  # Enable FIFO

def flush_rx():
    while read_reg(0x05) & 0x01:
        read_reg(0x00)

def send_visca(cmd, label="", timeout_s=1.0):
    flush_rx()
    for b in cmd:
        t = 100
        while not (read_reg(0x05) & 0x20) and t > 0:
            time.sleep(0.005)
            t -= 1
        write_reg(0x00, b)

    cmd_hex = " ".join("%02X" % b for b in cmd)
    if label:
        print("  [%s] TX: %s" % (label, cmd_hex))
    else:
        print("  TX: %s" % cmd_hex)

    time.sleep(timeout_s)
    response = []
    while read_reg(0x05) & 0x01:
        response.append(read_reg(0x00))
    resp_hex = " ".join("%02X" % b for b in response) if response else "(none)"
    print("  RX: %s" % resp_hex)
    return response

# =============================================
print("=== Set Camera to 1080p60 via Register 0x72 ===")
print("")

# 1. Init
init_uart()
print("[1] UART initialized")

# 2. VISCA network init
print("")
print("[2] VISCA init")
send_visca([0x88, 0x30, 0x01, 0xFF], "AddrSet")
time.sleep(0.3)
send_visca([0x88, 0x01, 0x00, 0x01, 0xFF], "IF Clear")
time.sleep(0.3)

# 3. Query current Monitoring Mode (Register 0x72)
# CAM_RegisterValueInq: 8x 09 04 24 mm FF
print("")
print("[3] Query current output format (Register 0x72)")
resp = send_visca([0x81, 0x09, 0x04, 0x24, 0x72, 0xFF], "RegInq 0x72")

# Parse response: y0 50 0p 0p FF -> pp is register value
if resp and len(resp) >= 5:
    # Find 90 50 pattern
    for i in range(len(resp) - 4):
        if resp[i] == 0x90 and resp[i+1] == 0x50:
            val = (resp[i+2] << 4) | resp[i+3]
            mode_map = {
                0x01: "1080i/60", 0x02: "1080i/60",
                0x04: "1080i/50",
                0x06: "1080p/30", 0x07: "1080p/30",
                0x08: "1080p/25",
                0x09: "720p/60", 0x0A: "720p/60",
                0x0C: "720p/50",
                0x0E: "720p/30", 0x0F: "720p/30",
                0x11: "720p/25",
                0x13: "1080p/60", 0x14: "1080p/50",
                0x15: "1080p/60",
            }
            mode_name = mode_map.get(val, "Unknown(0x%02X)" % val)
            print("  >> Current format: 0x%02X = %s" % (val, mode_name))
            break
time.sleep(0.3)

# 4. Set Register 0x72 = 0x13 (1080p/60)
# CAM_RegisterValue: 8x 01 04 24 mm 0p 0q FF
# 0x13 -> 0p=0x01, 0q=0x03
print("")
print("[4] Setting Register 0x72 = 0x13 (1080p/60)")
resp = send_visca([0x81, 0x01, 0x04, 0x24, 0x72, 0x01, 0x03, 0xFF], "RegSet 0x72=0x13", timeout_s=3.0)
time.sleep(1.0)

# 5. Verify
print("")
print("[5] Verify new format")
resp = send_visca([0x81, 0x09, 0x04, 0x24, 0x72, 0xFF], "RegInq 0x72")
if resp and len(resp) >= 5:
    for i in range(len(resp) - 4):
        if resp[i] == 0x90 and resp[i+1] == 0x50:
            val = (resp[i+2] << 4) | resp[i+3]
            mode_map = {
                0x01: "1080i/60", 0x02: "1080i/60",
                0x04: "1080i/50",
                0x06: "1080p/30", 0x07: "1080p/30",
                0x08: "1080p/25",
                0x09: "720p/60", 0x0A: "720p/60",
                0x0C: "720p/50",
                0x0E: "720p/30", 0x0F: "720p/30",
                0x11: "720p/25",
                0x13: "1080p/60", 0x14: "1080p/50",
                0x15: "1080p/60",
            }
            mode_name = mode_map.get(val, "Unknown(0x%02X)" % val)
            print("  >> New format: 0x%02X = %s" % (val, mode_name))
            break
time.sleep(0.3)

# 6. Save with CAM_Custom Set + Active (persist across power cycle)
print("")
print("[6] Saving to Custom Preset (persist across reboot)")
# CAM_Custom Set: 8x 01 04 3F 01 7F FF
send_visca([0x81, 0x01, 0x04, 0x3F, 0x01, 0x7F, 0xFF], "Custom Set", timeout_s=3.0)
time.sleep(1.0)
# CAM_Custom Active: 8x 01 04 3F 11 7F FF
send_visca([0x81, 0x01, 0x04, 0x3F, 0x11, 0x7F, 0xFF], "Custom Active", timeout_s=2.0)
time.sleep(0.5)

print("")
print("=== Done ===")
print("Camera should now output 1080p/60.")
print("Next: restore DT overlay to 60fps and reboot.")
bus.close()
