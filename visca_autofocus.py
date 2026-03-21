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

# 1. Auto Focus ON
print("=== Auto Focus ON ===")
r = send([0x81, 0x01, 0x04, 0x38, 0x02, 0xFF])
print("AF ON response: %s" % " ".join("0x%02X" % b for b in r))
time.sleep(1.0)

# 2. One-push AF trigger
print("=== One-push AF Trigger ===")
r = send([0x81, 0x01, 0x04, 0x18, 0x01, 0xFF])
print("AF Trigger response: %s" % " ".join("0x%02X" % b for b in r))
time.sleep(3.0)

# 3. Auto Exposure (AE) Full Auto
print("=== AE Full Auto ===")
r = send([0x81, 0x01, 0x04, 0x39, 0x00, 0xFF])
print("AE Auto response: %s" % " ".join("0x%02X" % b for b in r))
time.sleep(1.0)

# 4. White Balance Auto
print("=== WB Auto ===")
r = send([0x81, 0x01, 0x04, 0x35, 0x00, 0xFF])
print("WB Auto response: %s" % " ".join("0x%02X" % b for b in r))
time.sleep(1.0)

print("\n=== Done. Run capture test now. ===")

bus.close()
