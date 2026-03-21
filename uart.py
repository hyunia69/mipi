import smbus2
import time

bus = smbus2.SMBus(9)
I2C_ADDR = 0x48  # A0=A1=0

def write_reg(subaddr, data, channel=0):
    # Channel A: subaddr << 3 | 0x00
    bus.write_byte_data(I2C_ADDR, (subaddr << 3) | 0x00, data)

def read_reg(subaddr, channel=0):
    return bus.read_byte_data(I2C_ADDR, (subaddr << 3) | 0x00)

# Initialize UART A (Sony FCB-EV compatible cameras)
write_reg(0x03, 0x80)  # LCR: Enable divisor latch
write_reg(0x00, 0x5B)  # DLL: 91 (9600 baud, 14.7456MHz crystal)
write_reg(0x01, 0x00)  # DLH: 0
write_reg(0x03, 0x03)  # LCR: 8N1
write_reg(0x02, 0x01)  # FCR: Enable FIFO
write_reg(0x01, 0x03)  # IER: Enable TX holding

# Verify LSR (Line Status Register) for TX ready
while not (read_reg(0x05) & 0x20):  # Check THR empty
    time.sleep(0.01)

# Send data
data = [0x81, 0x01, 0x04, 0x07, 0x27, 0xFF]
data1 = [0x81, 0x01, 0x04, 0x07, 0x37, 0xFF]
for b in data:
    write_reg(0x00, b)  # THR: Write byte
    time.sleep(0.01)  # Small delay for stability
time.sleep(4)
for b in data1:
    write_reg(0x00, b)  # THR: Write byte
    time.sleep(0.01)  # Small delay for stability
