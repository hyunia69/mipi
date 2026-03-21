import smbus2
import time

bus = smbus2.SMBus(9)
LT_ADDR = 0x10

def set_bank(bank):
    bus.write_byte_data(LT_ADDR, 0xFF, bank, force=True)
    time.sleep(0.01)

def read_reg(bank, reg):
    set_bank(bank)
    return bus.read_byte_data(LT_ADDR, reg, force=True)

def dump_range(bank, start, end):
    set_bank(bank)
    for r in range(start, end + 1):
        val = bus.read_byte_data(LT_ADDR, r, force=True)
        print("  [0x%02X:0x%02X] = 0x%02X" % (bank, r, val))

# 1. Chip ID
print("=== Chip ID (bank 0x81) ===")
dump_range(0x81, 0x00, 0x02)

# 2. System Status
print("\n=== System Status (bank 0x80) ===")
dump_range(0x80, 0x00, 0x0F)

# 3. PLL Config (bank 0x82)
print("\n=== PLL Config (bank 0x82) ===")
dump_range(0x82, 0x00, 0x1F)

# 4. LVDS RX (bank 0xD0)
print("\n=== LVDS RX (bank 0xD0) ===")
dump_range(0xD0, 0x00, 0x2F)

# 5. Video check - input resolution detection
print("\n=== Video Input (bank 0xD0:0x80-0x90) ===")
dump_range(0xD0, 0x80, 0x90)

# 6. MIPI TX (bank 0xD4)
print("\n=== MIPI TX (bank 0xD4) ===")
dump_range(0xD4, 0x00, 0x1F)

# 7. MIPI TX2 (bank 0xD8)
print("\n=== MIPI TX2 (bank 0xD8) ===")
dump_range(0xD8, 0x00, 0x1F)

# 8. Pattern Gen / Test (bank 0x84)
print("\n=== Pattern / Test (bank 0x84) ===")
dump_range(0x84, 0x00, 0x1F)

bus.close()
