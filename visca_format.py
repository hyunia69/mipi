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
    write_reg(0x03, 0x80)  # LCR: Enable divisor latch
    write_reg(0x00, 0x60)  # DLL: 96 (9600 baud @ 14.7456MHz)
    write_reg(0x01, 0x00)  # DLH: 0
    write_reg(0x03, 0x03)  # LCR: 8N1
    write_reg(0x02, 0x07)  # FCR: Enable + reset FIFOs
    time.sleep(0.01)
    write_reg(0x02, 0x01)  # FCR: Enable FIFO

def send_visca(cmd, label="", timeout_s=1.0):
    # Wait for TX ready
    for b in cmd:
        t = 100
        while not (read_reg(0x05) & 0x20) and t > 0:
            time.sleep(0.005)
            t -= 1
        write_reg(0x00, b)

    cmd_hex = " ".join("%02X" % b for b in cmd)
    if label:
        print("  TX [%s]: %s" % (label, cmd_hex))
    else:
        print("  TX: %s" % cmd_hex)

    # Read response
    time.sleep(timeout_s)
    response = []
    while read_reg(0x05) & 0x01:
        response.append(read_reg(0x00))
    if response:
        resp_hex = " ".join("%02X" % b for b in response)
        print("  RX: %s" % resp_hex)
    else:
        print("  RX: (no response)")
    return response

# =============================================
print("=== VISCA Format Change to 1080p60 ===")
print("")

# 1. Init
init_uart()
print("[1] UART initialized (9600 baud)")

# 2. VISCA network init
print("")
print("[2] VISCA network init")
send_visca([0x88, 0x30, 0x01, 0xFF], "Address Set")
time.sleep(0.3)
send_visca([0x88, 0x01, 0x00, 0x01, 0xFF], "IF Clear")
time.sleep(0.3)

# 3. Query camera version
print("")
print("[3] Camera Version Inquiry")
send_visca([0x81, 0x09, 0x00, 0x02, 0xFF], "CAM_VersionInq", timeout_s=1.0)
time.sleep(0.3)

# 4. Query current video format
print("")
print("[4] Current Video Format Inquiry")
resp = send_visca([0x81, 0x09, 0x06, 0x35, 0xFF], "VideoFormatInq", timeout_s=1.0)
time.sleep(0.3)

# 5. Try setting 1080p59.94/60
# Common format codes for Sony FCB-EV compatible cameras:
#   0x03 = 1080p/29.97
#   0x06 = 1080p/59.94 (most common for 1080p60)
#   0x08 = 1080p/59.94 (some models)
#   0x12 = 1080p/59.94 (newer models)
print("")
print("[5] Setting Video Format to 1080p60")
print("    Trying format code 0x06 (1080p/59.94)...")
resp = send_visca([0x81, 0x01, 0x06, 0x35, 0x00, 0x06, 0xFF], "VideoFormat Set 0x06", timeout_s=2.0)
time.sleep(0.5)

# Check if ACK received (90 4x FF = ACK)
got_ack = False
if resp:
    for i in range(len(resp) - 2):
        if resp[i] == 0x90 and (resp[i+1] & 0xF0) == 0x40:
            got_ack = True
            break

if not got_ack and resp:
    # Check for error (90 60 02 FF = syntax error, 90 60 03 FF = not executable)
    print("    Code 0x06 may not be supported, trying 0x08...")
    time.sleep(0.3)
    resp = send_visca([0x81, 0x01, 0x06, 0x35, 0x00, 0x08, 0xFF], "VideoFormat Set 0x08", timeout_s=2.0)
    time.sleep(0.5)

# 6. Verify new format
print("")
print("[6] Verify Video Format")
send_visca([0x81, 0x09, 0x06, 0x35, 0xFF], "VideoFormatInq", timeout_s=1.0)

print("")
print("=== Done ===")
print("NOTE: Camera may need 5-10 seconds to switch format.")
print("      If format changed, re-test gstreamer pipeline.")
bus.close()
