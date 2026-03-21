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
    write_reg(0x00, 0x60)
    write_reg(0x01, 0x00)
    write_reg(0x03, 0x03)
    write_reg(0x02, 0x07)
    time.sleep(0.01)
    write_reg(0x02, 0x01)

def flush_rx():
    while read_reg(0x05) & 0x01:
        read_reg(0x00)

def send_visca(cmd, label="", timeout_s=0.8):
    flush_rx()
    for b in cmd:
        t = 100
        while not (read_reg(0x05) & 0x20) and t > 0:
            time.sleep(0.005)
            t -= 1
        write_reg(0x00, b)

    cmd_hex = " ".join("%02X" % b for b in cmd)

    time.sleep(timeout_s)
    response = []
    while read_reg(0x05) & 0x01:
        response.append(read_reg(0x00))

    resp_hex = " ".join("%02X" % b for b in response) if response else "(none)"
    tag = "[%s]" % label if label else ""
    print("  %s TX: %s" % (tag, cmd_hex))
    print("  %s RX: %s" % (tag, resp_hex))

    # Check error
    is_error = False
    if response:
        for i in range(len(response)):
            if i + 2 < len(response) and (response[i] & 0xF0) == 0x90 and (response[i+1] & 0xF0) == 0x60:
                err_code = response[i+2]
                err_names = {1: "MsgLen", 2: "Syntax", 3: "BufFull", 4: "Cancelled", 5: "NoSocket", 0x41: "NotExec"}
                ename = err_names.get(err_code, "0x%02X" % err_code)
                print("  %s ERROR: %s" % (tag, ename))
                is_error = True
                break
    return response, is_error

# =============================================
print("=== VISCA Command Probe ===")
print("")

init_uart()

# Network init
send_visca([0x88, 0x30, 0x01, 0xFF], "AddrSet")
time.sleep(0.2)
send_visca([0x88, 0x01, 0x00, 0x01, 0xFF], "IFClear")
time.sleep(0.3)

# 1. Try various video format / system commands
print("")
print("=== [A] Video Format Commands ===")

# Standard Sony Video Format Set (different codes)
codes_to_try = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x12, 0x13, 0x14]

# First try the inquiry with different command IDs
print("")
print("--- Format inquiries ---")

# Sony standard: 81 09 06 35 FF
send_visca([0x81, 0x09, 0x06, 0x35, 0xFF], "Inq 06 35")
time.sleep(0.2)

# Alternative: 81 09 06 24 FF (some older models)
send_visca([0x81, 0x09, 0x06, 0x24, 0xFF], "Inq 06 24")
time.sleep(0.2)

# CAM_VideoSystemInq (NTSC/PAL): 81 09 06 23 FF
send_visca([0x81, 0x09, 0x06, 0x23, 0xFF], "Inq 06 23 VideoSys")
time.sleep(0.2)

# 2. Try different Set command formats
print("")
print("--- Format set attempts ---")

# Without extra 0x00: 81 01 06 35 06 FF
resp, err = send_visca([0x81, 0x01, 0x06, 0x35, 0x06, 0xFF], "Set 06 35 06 (no 0x00)")
time.sleep(0.3)

# 81 01 06 24 00 06 FF (alternative command)
resp, err = send_visca([0x81, 0x01, 0x06, 0x24, 0x00, 0x06, 0xFF], "Set 06 24 00 06")
time.sleep(0.3)

# 81 01 04 24 72 FF (HD format in some cameras - 72 = 1080p60)
resp, err = send_visca([0x81, 0x01, 0x04, 0x24, 0x72, 0xFF], "Set 04 24 72")
time.sleep(0.3)

# 3. OSD Menu access
print("")
print("=== [B] OSD Menu Commands ===")

# CAM_MenuMode On: 81 01 06 06 02 FF
resp, err = send_visca([0x81, 0x01, 0x06, 0x06, 0x02, 0xFF], "Menu ON")
time.sleep(0.3)

# If menu opened, close it
if not err:
    send_visca([0x81, 0x01, 0x06, 0x06, 0x03, 0xFF], "Menu OFF")
    time.sleep(0.3)

# 4. Some useful inquiries
print("")
print("=== [C] Camera Info Inquiries ===")

# Power inquiry
send_visca([0x81, 0x09, 0x04, 0x00, 0xFF], "PowerInq")
time.sleep(0.2)

# Zoom Position inquiry
send_visca([0x81, 0x09, 0x04, 0x47, 0xFF], "ZoomPosInq")
time.sleep(0.2)

# Focus mode inquiry
send_visca([0x81, 0x09, 0x04, 0x38, 0xFF], "FocusModeInq")
time.sleep(0.2)

# 5. Try register-based format commands (some KT&C specific)
print("")
print("=== [D] Alternative Format Commands ===")

# Some cameras use category 7 for system
# 81 01 07 xx commands
send_visca([0x81, 0x09, 0x07, 0x18, 0xFF], "Inq 07 18 SysInfo")
time.sleep(0.2)

# HDMIVideoFormat (some block cameras)
send_visca([0x81, 0x09, 0x06, 0x26, 0xFF], "Inq 06 26 HDMIFmt")
time.sleep(0.2)

# LVDSVideoFormat
send_visca([0x81, 0x09, 0x06, 0x36, 0xFF], "Inq 06 36")
time.sleep(0.2)

print("")
print("=== Probe Complete ===")
bus.close()
