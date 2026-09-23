#!/usr/bin/env python3
import argparse, hashlib, struct

MH_MAGIC_64 = 0xfeedfacf
LC_LOAD_DYLIB = 0x0c
LC_LOAD_WEAK_DYLIB = 0x80000018


def align8(n): return (n + 7) & ~7

def sha256(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for b in iter(lambda:f.read(1<<20), b''): h.update(b)
    return h.hexdigest()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('input')
    ap.add_argument('output')
    ap.add_argument('--load', default='@loader_path/CyberSkinStandalone.dylib')
    ap.add_argument('--strong', action='store_true', help='use LC_LOAD_DYLIB; default is weak to avoid dyld abort when helper is absent/moved')
    a=ap.parse_args()
    data=bytearray(open(a.input,'rb').read())
    if len(data) < 32: raise SystemExit('short Mach-O')
    magic,cputype,cpusubtype,filetype,ncmds,sizeofcmds,flags,reserved=struct.unpack_from('<IIIIIIII',data,0)
    if magic != MH_MAGIC_64: raise SystemExit(f'expected thin little-endian Mach-O64, got 0x{magic:08x}')
    off=32
    dylibs=[]
    first_fileoff=len(data)
    for _ in range(ncmds):
        cmd,cmdsize=struct.unpack_from('<II',data,off)
        if cmdsize < 8 or off+cmdsize>len(data): raise SystemExit('corrupt load command')
        if cmd == 0x19:
            nsects=struct.unpack_from('<I',data,off+64)[0]
            so=off+72
            for _s in range(nsects):
                sec_off=struct.unpack_from('<I',data,so+48)[0]
                sec_size=struct.unpack_from('<Q',data,so+40)[0]
                if sec_off and sec_size: first_fileoff=min(first_fileoff,sec_off)
                so += 80
        if cmd in (0xc,0xd,0x18,0x1f,0x80000018,0x8000001f,0x80000023):
            noff=struct.unpack_from('<I',data,off+8)[0]
            end=data.find(0, off+noff, off+cmdsize)
            if end!=-1: dylibs.append(bytes(data[off+noff:end]).decode('utf-8','replace'))
        off += cmdsize
    if a.load in dylibs:
        open(a.output,'wb').write(data)
        print('already present', a.load)
        return
    raw=a.load.encode()+b'\0'
    cmdsize=align8(24+len(raw))
    insert=32+sizeofcmds
    if insert+cmdsize > first_fileoff:
        raise SystemExit(f'no load-command slack: need {cmdsize}, have {first_fileoff-insert}')
    if any(data[insert:insert+cmdsize]):
        raise SystemExit('load-command slack is non-zero; refusing destructive patch')
    load_cmd = LC_LOAD_DYLIB if a.strong else LC_LOAD_WEAK_DYLIB
    cmd=struct.pack('<IIIIII',load_cmd,cmdsize,24,0,0,0)+raw
    cmd += b'\0'*(cmdsize-len(cmd))
    data[insert:insert+cmdsize]=cmd
    struct.pack_into('<II',data,16,ncmds+1,sizeofcmds+cmdsize)
    open(a.output,'wb').write(data)
    print('input_sha256=',sha256(a.input))
    print('output_sha256=',sha256(a.output))
    print('added=',a.load)
    print('mode=', 'strong' if a.strong else 'weak')
    print('ncmds=',ncmds,'->',ncmds+1,'sizeofcmds=',sizeofcmds,'->',sizeofcmds+cmdsize,'first_section_fileoff=',hex(first_fileoff))

if __name__=='__main__': main()
