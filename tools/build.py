#!/usr/bin/env python3
"""Build the Shinobi System 16A test ROM.

Assembles src/shinobi_test.s, stores each chip's CRC32 in the image,
and splits it into the two 27C512 EPROM images:

  out/IC43_test_even.bin   -> socket IC43 (68000 D15-D8)
  out/IC26_test_odd.bin    -> socket IC26 (68000 D7-D0)

With --mame <shinobi.zip>, it also builds out/mame/shinobi/ (the original
set with the two program ROMs swapped for the test ROM) for MAME testing.
"""
import argparse
import os
import shutil
import struct
import subprocess
import sys
import zipfile
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src", "shinobi_test.s")
OUT = os.path.join(ROOT, "out")

IMAGE_SIZE = 0x20000      # 2 x 64KB
SELFCRC_ADDR = 0x1FFF0    # must match the .equ in the source
SELFCRC_LEN = 0xFFF8      # bytes per chip covered by the self-check


def run(cmd):
    print("+", " ".join(cmd))
    subprocess.run(cmd, check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mame", metavar="ZIP", help="original shinobi.zip to build a MAME test set")
    args = ap.parse_args()

    os.makedirs(OUT, exist_ok=True)
    obj = os.path.join(OUT, "shinobi_test.o")
    elf = os.path.join(OUT, "shinobi_test.elf")
    raw = os.path.join(OUT, "shinobi_test.bin")

    run(["m68k-elf-as", "-m68000", "--register-prefix-optional",
         "-I", os.path.join(ROOT, "src"),
         "-alhns=" + os.path.join(OUT, "shinobi_test.lst"), "-o", obj, SRC])
    run(["m68k-elf-ld", "-Ttext=0", "-e", "0", "-o", elf, obj])
    run(["m68k-elf-objcopy", "-O", "binary", elf, raw])

    img = bytearray(open(raw, "rb").read())
    if len(img) != IMAGE_SIZE:
        sys.exit(f"image is {len(img):#x} bytes, expected {IMAGE_SIZE:#x}")

    even = img[0:SELFCRC_LEN * 2:2]
    odd = img[1:SELFCRC_LEN * 2:2]
    struct.pack_into(">II", img, SELFCRC_ADDR, zlib.crc32(even), zlib.crc32(odd))

    ic43 = bytes(img[0::2])
    ic26 = bytes(img[1::2])
    open(os.path.join(OUT, "shinobi_test.bin"), "wb").write(img)
    open(os.path.join(OUT, "IC43_test_even.bin"), "wb").write(ic43)
    open(os.path.join(OUT, "IC26_test_odd.bin"), "wb").write(ic26)

    print()
    print(f"IC43_test_even.bin  27C512  CRC32 {zlib.crc32(ic43):08X}")
    print(f"IC26_test_odd.bin   27C512  CRC32 {zlib.crc32(ic26):08X}")
    print(f"self-check CRCs     even {zlib.crc32(even):08X}  odd {zlib.crc32(odd):08X}")

    if args.mame:
        dest = os.path.join(OUT, "mame", "shinobi")
        os.makedirs(dest, exist_ok=True)
        with zipfile.ZipFile(args.mame) as z:
            for name in z.namelist():
                with z.open(name) as f, open(os.path.join(dest, os.path.basename(name)), "wb") as o:
                    shutil.copyfileobj(f, o)
        open(os.path.join(dest, "epr-12010.43"), "wb").write(ic43)
        open(os.path.join(dest, "epr-12008.26"), "wb").write(ic26)
        print(f"MAME test set       {dest}")


if __name__ == "__main__":
    main()
