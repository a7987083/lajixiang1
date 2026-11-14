"""Behavior checks with Lua 5.3 and mock game APIs, NOT an iOS runtime test."""
from pathlib import Path
from lupa.lua53 import LuaRuntime
source = Path(__file__).with_name('ResourceOperation.lua').read_text()

def run(id=0, amount=0, setup=''):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
    balances = {[1]=25,[2]=30,[3]=40}; calls = 0
    SaveRootData = {UserData={Property={}}}
    PropertySystem = {
      GetPropertyCount=function(self,id) return balances[id] end,
      CheckChangeData=function() end
    }
    GM = {AddItem=function(id,n) calls=calls+1; balances[id]=balances[id]+n end}
    AntiCheatingHelper={IsHaveCheat=function() return false end}
    ''')
    lua.execute(setup)
    result = lua.execute(source.replace('__RESOURCE_ID__',str(id)).replace('__RESOURCE_AMOUNT__',str(amount)))
    return result, lua.globals().calls, lua.globals().balances

s,c,b = run(); assert s.startswith('READY|') and c==0 and b[1]==25
s,c,b = run(1,10); assert s.startswith('OK|') and c==1 and b[1]==35
for i in (2,3):
    s,c,b=run(i,5); assert s.startswith('OK|') and c==1
s,c,b=run(1,10,'GM.AddItem=function() calls=calls+1 end'); assert s.startswith('UNCHANGED|') and c==1 and b[1]==25
s,c,b=run(1,10,'SaveRootData.UserData=nil'); assert s.startswith('WAIT|') and c==0
s,c,b=run(1,10,'AntiCheatingHelper.IsHaveCheat=function() return true end'); assert s.startswith('BLOCKED|') and c==0
for i,n in [(4,10),(1,0),(1,101),(1,1.5)]:
    try: run(i,n)
    except Exception: pass
    else: raise AssertionError((i,n))
print('PASS: readiness, three resources, unchanged, uninitialized, blocked, invalid IDs/amounts (Lua 5.3 mocks only)')
