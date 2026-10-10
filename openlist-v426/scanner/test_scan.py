import struct
import tempfile
import unittest
import zipfile
from pathlib import Path
from scan import slices, scan

def mach_o():
    name=b'@rpath/Test.dylib\0'
    cmdsize=(24+len(name)+7)//8*8
    head=struct.pack('<IIIIIIII',0xfeedfacf,0x100000c,2,2,1,cmdsize,0,0)
    cmd=struct.pack('<IIIIII',12,cmdsize,24,2,0,0)+name.ljust(cmdsize-24,b'\0')
    return head+cmd

class Tests(unittest.TestCase):
    def test_arm64_dependency(self):
        result=slices(mach_o())
        self.assertEqual(result[0]['arch'],'arm64')
        self.assertEqual(result[0]['dependencies'][0]['name'],'@rpath/Test.dylib')

    def test_corrupted_command(self):
        bad=bytearray(mach_o())
        struct.pack_into('<I',bad,36,0xffffffff)
        with self.assertRaises(ValueError):
            slices(bad)

    def test_archive_is_not_modified(self):
        with tempfile.TemporaryDirectory() as directory:
            ipa=Path(directory)/'test.ipa'
            with zipfile.ZipFile(ipa,'w') as z:
                z.writestr('Payload/Test.app/Test',mach_o())
            original=ipa.read_bytes()
            result=scan(ipa)
            self.assertEqual(result['mach_o_count'],1)
            self.assertEqual(ipa.read_bytes(),original)

if __name__=='__main__':
    unittest.main()
