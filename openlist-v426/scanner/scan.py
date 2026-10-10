#!/usr/bin/env python3
"""Read-only Mach-O dependency inventory for IPA archives."""
import argparse, json, struct, zipfile
from pathlib import Path
from pathlib import PurePosixPath
THIN={bytes.fromhex('feedface'):('>',28),bytes.fromhex('cefaedfe'):('<',28),bytes.fromhex('feedfacf'):('>',32),bytes.fromhex('cffaedfe'):('<',32)}
FAT={bytes.fromhex('cafebabe'):('>',20),bytes.fromhex('bebafeca'):('<',20),bytes.fromhex('cafebabf'):('>',32),bytes.fromhex('bfbafeca'):('<',32)}
CMDS={12:'LC_LOAD_DYLIB',24:'LC_LOAD_WEAK_DYLIB',31:'LC_REEXPORT_DYLIB',35:'LC_LOAD_UPWARD_DYLIB',32:'LC_LAZY_LOAD_DYLIB'}
MAX_FILE=128*1024*1024
def slices(data,level=0):
    magic=bytes(data[:4])
    if magic in FAT:
        if level>=2: raise ValueError('nested fat limit')
        endian,entry=FAT[magic]
        if len(data)<8: raise ValueError('truncated fat header')
        count=struct.unpack_from(endian+'I',data,4)[0]
        if count>32: raise ValueError('too many architectures')
        result=[]
        for i in range(count):
            p=8+i*entry
            if p+entry>len(data): raise ValueError('truncated architecture table')
            if entry==20: off,size=struct.unpack_from(endian+'II',data,p+8)
            else: off,size=struct.unpack_from(endian+'QQ',data,p+8)
            if size>MAX_FILE or off+size>len(data): raise ValueError('bad architecture bounds')
            result+=slices(data[off:off+size],level+1)
        return result
    if magic not in THIN: return []
    endian,hsize=THIN[magic]
    if len(data)<hsize: raise ValueError('truncated Mach-O')
    cpu,ncmds,total=struct.unpack_from(endian+'III',data,4)[0],struct.unpack_from(endian+'I',data,16)[0],struct.unpack_from(endian+'I',data,20)[0]
    if ncmds>65536 or total>len(data)-hsize: raise ValueError('invalid commands size')
    end=hsize+total
    pos=hsize
    deps=[];rpaths=[];identity=None
    for _ in range(ncmds):
        if pos+8>end: raise ValueError('truncated command')
        cmd,size=struct.unpack_from(endian+'II',data,pos)
        kind=cmd&0x7fffffff
        if size<8 or pos+size>end: raise ValueError('invalid command bounds')
        if kind in CMDS or kind in (13,28):
            if size<12: raise ValueError('invalid command')
            offset=struct.unpack_from(endian+'I',data,pos+8)[0]
            if offset<12 or offset>=size: raise ValueError('invalid string offset')
            name=data[pos+offset:pos+size].split(b'\0',1)[0].decode('utf-8','replace')
            if kind in CMDS: deps.append({'type':CMDS[kind],'name':name})
            elif kind==13: identity=name
            else:rpaths.append(name)
        pos+=size
    cpu_names={0x100000c:'arm64',12:'arm',0x1000007:'x86_64',7:'x86'}
    return [{'arch':cpu_names.get(cpu,hex(cpu)),'dependencies':deps,'rpaths':rpaths,'id':identity}]
def scan(ipa):
    ipa=Path(ipa)
    if ipa.stat().st_size>1024**3: raise ValueError('IPA too large')
    results=[];errors=[]
    with zipfile.ZipFile(ipa) as z:
        if len(z.infolist())>20000: raise ValueError('too many archive entries')
        for item in z.infolist():
            path=item.filename
            if item.is_dir() or not path.startswith('Payload/') or '..' in PurePosixPath(path).parts or item.file_size<28 or item.file_size>MAX_FILE:continue
            try:
                with z.open(item) as f:
                    head=f.read(4)
                    if head not in THIN and head not in FAT:continue
                    data=head+f.read(MAX_FILE+1)
                if len(data)>MAX_FILE: raise ValueError('binary too large')
                arches=slices(data)
                if arches:results.append({'path':path,'architectures':arches})
            except (ValueError,EOFError,RuntimeError,zipfile.BadZipFile) as e:
                errors.append({'path':path,'error':str(e)})
    return {'mode':'read-only','ipa':ipa.name,'mach_o_count':len(results),'files':results,'errors':errors}
if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('ipa')
    print(json.dumps(scan(p.parse_args().ipa),ensure_ascii=False,indent=2))
