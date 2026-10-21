#!/usr/bin/env python3
"""Make the ELF dynamic section writable when PT_LOAD segments overlap.

`autoPatchelfHook` (i.e. patchelf) has to add a DT_RUNPATH pointing at the Nix
store.  For binaries that have no spare room in .dynstr/.dynamic, patchelf
rewrites the file: it prepends the new string/dynamic data and adds a writable
PT_LOAD in front of the original read-only PT_LOAD.  Both segments end up
mapping the very same virtual addresses, and the kernel maps PT_LOADs in
program header order, so the later read-only mapping wins for the shared
pages.

glibc's ld.so stores the `r_debug` pointer into the executable's DT_DEBUG
entry during startup (dl_main), i.e. it writes into .dynamic.  With that page
mapped read-only the write faults and the process dies with SIGSEGV before a
single shared library is loaded:

    node[239321]: segfault at efea60 ... error 7 in ld-linux-x86-64.so.2

This script restores a consistent layout by giving every PT_LOAD that covers
the dynamic segment the PF_W flag, so the last mapping of that page is
writable.  It is idempotent and a no-op on healthy binaries.
"""

import struct
import sys

ELF_MAGIC = b"\x7fELF"
PT_LOAD = 1
PT_DYNAMIC = 2
PF_W = 2
PAGE = 0x1000


def align_down(value):
    return value & ~(PAGE - 1)


def align_up(value):
    return (value + PAGE - 1) & ~(PAGE - 1)


def main(path):
    with open(path, "r+b") as f:
        ehdr = f.read(64)
        if ehdr[:4] != ELF_MAGIC:
            sys.exit(f"{path}: not an ELF file")
        ei_class, ei_data = ehdr[4], ehdr[5]
        if (ei_class, ei_data) != (2, 1):
            sys.exit(f"{path}: only 64-bit little-endian ELF is supported")

        e_phoff = struct.unpack_from("<Q", ehdr, 0x20)[0]
        e_phentsize = struct.unpack_from("<H", ehdr, 0x36)[0]
        e_phnum = struct.unpack_from("<H", ehdr, 0x38)[0]

        phdrs = []
        for i in range(e_phnum):
            f.seek(e_phoff + i * e_phentsize)
            entry = f.read(e_phentsize)
            p_type, p_flags = struct.unpack_from("<II", entry, 0)
            p_vaddr = struct.unpack_from("<Q", entry, 16)[0]
            p_memsz = struct.unpack_from("<Q", entry, 40)[0]
            phdrs.append(
                {
                    "index": i,
                    "offset": e_phoff + i * e_phentsize,
                    "type": p_type,
                    "flags": p_flags,
                    "vaddr": p_vaddr,
                    "memsz": p_memsz,
                }
            )

        dynamic = next((p for p in phdrs if p["type"] == PT_DYNAMIC), None)
        if dynamic is None:
            print(f"{path}: no PT_DYNAMIC segment, nothing to do")
            return 0

        dyn_start = align_down(dynamic["vaddr"])
        dyn_end = align_up(dynamic["vaddr"] + dynamic["memsz"])

        patched = 0
        for phdr in phdrs:
            if phdr["type"] != PT_LOAD or phdr["flags"] & PF_W:
                continue
            start = align_down(phdr["vaddr"])
            end = align_up(phdr["vaddr"] + phdr["memsz"])
            if start < dyn_end and dyn_start < end:
                # A later, writable mapping of the dynamic page must win.
                f.seek(phdr["offset"] + 4)
                f.write(struct.pack("<I", phdr["flags"] | PF_W))
                patched += 1
                print(
                    f"{path}: PT_LOAD #{phdr['index']} "
                    f"[{start:#x},{end:#x}) overlaps dynamic section, marked writable"
                )

    if patched == 0:
        print(f"{path}: dynamic section already writable, no change")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} /path/to/elf")
    sys.exit(main(sys.argv[1]))
