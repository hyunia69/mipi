import smbus2, time

bus = smbus2.SMBus(9)
I2C_ADDR = 0x48

def write_reg(s, d):
    bus.write_byte_data(I2C_ADDR, (s << 3) | 0x00, d)

def read_reg(s):
    return bus.read_byte_data(I2C_ADDR, (s << 3) | 0x00)

# Init UART
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

def send(cmd, t=1.0):
    flush()
    for b in cmd:
        while not (read_reg(0x05) & 0x20):
            time.sleep(0.005)
        write_reg(0x00, b)
    time.sleep(t)
    r = []
    while read_reg(0x05) & 0x01:
        r.append(read_reg(0x00))
    return r

# Init VISCA
send([0x88, 0x30, 0x01, 0xFF])
time.sleep(0.2)
send([0x88, 0x01, 0x00, 0x01, 0xFF])
time.sleep(0.2)

# Query register 0x72
r = send([0x81, 0x09, 0x04, 0x24, 0x72, 0xFF])
print("Reg 0x72 response: %s" % " ".join("0x%02X" % b for b in r))
if len(r) >= 5:
    for i in range(len(r) - 4):
        if r[i] == 0x90 and r[i + 1] == 0x50:
            val = (r[i + 2] << 4) | r[i + 3]
            modes = {
                0x06: "1080p/30", 0x07: "1080p/30",
                0x09: "720p/60", 0x0A: "720p/60",
                0x13: "1080p/60", 0x15: "1080p/60",
            }
            name = modes.get(val, "other(0x%02X)" % val)
            print("Current format: 0x%02X = %s" % (val, name))

# If still 1080p/30, set to 1080p/60 again
if len(r) >= 5:
    for i in range(len(r) - 4):
        if r[i] == 0x90 and r[i + 1] == 0x50:
            val = (r[i + 2] << 4) | r[i + 3]
            if val != 0x13 and val != 0x15:
                print("Setting to 1080p/60...")
                r2 = send([0x81, 0x01, 0x04, 0x24, 0x72, 0x01, 0x03, 0xFF], t=3.0)
                print("Set response: %s" % " ".join("0x%02X" % b for b in r2))
                time.sleep(1.0)
                # Verify
                r3 = send([0x81, 0x09, 0x04, 0x24, 0x72, 0xFF])
                print("Verify: %s" % " ".join("0x%02X" % b for b in r3))
            else:
                print("Already 1080p/60, no change needed")
            break

bus.close()
