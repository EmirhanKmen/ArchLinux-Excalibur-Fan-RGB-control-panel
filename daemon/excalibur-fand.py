#!/usr/bin/env python3
"""
Excalibur fan/temp reader daemon.

Reads fan RPMs and CPU temp straight from the EC RAM (no WMI -> never hangs)
and publishes them to a world-readable file for the shell to consume.

EC layout (Casper Excalibur G870 / Tongfang NLXB, from DSDT):
  RPM1..RPM4 @ 0xB0-0xB3 : fan1 = LE16(0xB0,0xB1), fan2 = LE16(0xB2,0xB3)
  RTMP       @ 0x58       : CPU temperature (deg C)
"""
import time, os

EC = "/sys/kernel/debug/ec/ec0/io"
OUT = "/run/excalibur-fans"

def read_ec(off, n):
    with open(EC, "rb") as f:
        f.seek(off)
        return f.read(n)

def main():
    while True:
        try:
            b = read_ec(0xB0, 4)
            fan1 = b[0] | (b[1] << 8)
            fan2 = b[2] | (b[3] << 8)
            temp = read_ec(0x58, 1)[0]
            tmp = OUT + ".tmp"
            with open(tmp, "w") as f:
                f.write(f"{fan1} {fan2} {temp}\n")
            os.chmod(tmp, 0o644)
            os.replace(tmp, OUT)
        except Exception:
            pass
        time.sleep(2)

if __name__ == "__main__":
    main()
