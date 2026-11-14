local id, amount = __RESOURCE_ID__, __RESOURCE_AMOUNT__
local mm, data = ModuleManager, SaveRootData
local p = type(mm) == 'table' and rawget(mm, 'PropertySystem') or nil
if type(p) ~= 'table' or type(p.GetPropertyCount) ~= 'function'
   or type(p.CheckChangeData) ~= 'function' or type(data) ~= 'table'
   or type(data.UserData) ~= 'table' or type(data.UserData.Property) ~= 'table'
   or type(ECheckerboardType) ~= 'table' or ECheckerboardType.Main == nil
   or type(FunctionSource) ~= 'table' or FunctionSource.GM == nil
then return 'WAIT|等待游戏资源初始化' end
if id == 0 then
    return string.format('READY|钻石 %s  体力 %s  星星 %s',
        tostring(p:GetPropertyCount(1)), tostring(p:GetPropertyCount(2)),
        tostring(p:GetPropertyCount(3)))
end
assert(id == 1 or id == 2 or id == 3, '不支持的资源')
assert(amount >= 1 and amount <= 100 and amount == math.floor(amount), '数量须为1至100整数')
local before = p:GetPropertyCount(id)
assert(type(before) == 'number', '无法读取原余额')
-- Same call and argument order as this game's UIGMTools button.
p:CheckChangeData(id, amount, nil, ECheckerboardType.Main, FunctionSource.GM)
local after = p:GetPropertyCount(id)
local delta = after - before
if delta == amount then
    return string.format('OK|%s → %s（增加 %s，本地值已确认）', before, after, delta)
end
return string.format('UNCHANGED|%s → %s（实际增加 %s，预期 %s）', before, after, delta, amount)
