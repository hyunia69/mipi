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

print("=== SC16IS752 Diagnostic ===")

# 1. Scratch register read/write test
try:
    write_reg(0x07, 0xAA)
    val = read_reg(0x07)
    r1 = "PASS" if val == 0xAA else "FAIL"
    print("[1] Scratch reg: wrote 0xAA, read 0x%02X -> %s" % (val, r1))

    write_reg(0x07, 0x55)
    val = read_reg(0x07)
    r2 = "PASS" if val == 0x55 else "FAIL"
    print("    Scratch reg: wrote 0x55, read 0x%02X -> %s" % (val, r2))
except Exception as e:
    print("[1] I2C communication FAILED: %s" % e)

# 2. Initialize UART
print("")
print("[2] Initializing UART...")
write_reg(0x03, 0x80)  # LCR: Enable divisor latch

dll = read_reg(0x00)
dlh = read_reg(0x01)
print("    Current divisor: DLL=0x%02X DLH=0x%02X" % (dll, dlh))

write_reg(0x00, 0x60)  # DLL: 96 for 9600 baud @ 14.7456MHz
write_reg(0x01, 0x00)  # DLH: 0

dll = read_reg(0x00)
dlh = read_reg(0x01)
print("    After set: DLL=0x%02X DLH=0x%02X (expect 0x60, 0x00)" % (dll, dlh))

write_reg(0x03, 0x03)  # LCR: 8N1
lcr = read_reg(0x03)
print("    LCR: 0x%02X (expect 0x03 for 8N1)" % lcr)

# Reset FIFOs
write_reg(0x02, 0x07)  # FCR: Enable + reset TX/RX FIFO
time.sleep(0.01)
write_reg(0x02, 0x01)  # FCR: Enable FIFO

# 3. Line Status Register
lsr = read_reg(0x05)
print("")
print("[3] LSR: 0x%02X" % lsr)
print("    THR empty: %s" % ("Yes" if lsr & 0x20 else "No"))
print("    TX empty:  %s" % ("Yes" if lsr & 0x40 else "No"))

# 4. IIR - FIFO status
iir = read_reg(0x02)
print("")
print("[4] IIR: 0x%02X" % iir)
print("    FIFO enabled: %s" % ("Yes" if iir & 0xC0 else "No"))

# 5. MCR
mcr = read_reg(0x04)
print("")
print("[5] MCR: 0x%02X" % mcr)

# 6. VISCA commands
print("")
print("[6] Sending VISCA commands...")

def send_visca(cmd, label):
    lsr = read_reg(0x05)
    thr_ok = "Y" if lsr & 0x20 else "N"
    print("    Pre-send LSR: 0x%02X (THR empty: %s)" % (lsr, thr_ok))

    for i, b in enumerate(cmd):
        timeout = 100
        while not (read_reg(0x05) & 0x20) and timeout > 0:
            time.sleep(0.005)
            timeout -= 1
        if timeout == 0:
            print("    TIMEOUT at byte %d" % i)
            return
        write_reg(0x00, b)

    cmd_hex = " ".join("0x%02X" % b for b in cmd)
    print("    Sent %s: %s" % (label, cmd_hex))

    time.sleep(0.5)
    lsr = read_reg(0x05)
    rx_ok = "Y" if lsr & 0x01 else "N"
    print("    Post-send LSR: 0x%02X (RX data: %s)" % (lsr, rx_ok))

    response = []
    while read_reg(0x05) & 0x01:
        response.append(read_reg(0x00))
    if response:
        resp_hex = " ".join("0x%02X" % b for b in response)
        print("    Response: %s" % resp_hex)
    else:
        print("    No response received")

# VISCA Address Set (broadcast)
send_visca([0x88, 0x30, 0x01, 0xFF], "Address Set")
time.sleep(0.3)

# VISCA IF_Clear (broadcast)
send_visca([0x88, 0x01, 0x00, 0x01, 0xFF], "IF Clear")
time.sleep(0.3)

# VISCA Zoom Tele (slow speed)
send_visca([0x81, 0x01, 0x04, 0x07, 0x02, 0xFF], "Zoom Tele")

print("")
print("=== Diagnostic Complete ===")
bus.close()
