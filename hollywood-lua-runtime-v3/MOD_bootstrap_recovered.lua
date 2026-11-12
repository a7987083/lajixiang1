do
  if _MOD then return end

  local M = { freeze = false, infEnergy = false, bonus = 999999 }
  _MOD = M

  local FROZEN = {
    gold     = true,
    gem      = true,
    gachagem = true,
  }

  local function slt(name)
    if not xyd or not xyd.slt then return nil end
    if not xyd.slt.isCreated(name) then return nil end
    return xyd.slt[name]
  end

  local function model(name)
    if not xyd or not xyd.models then return nil end
    local mt = getmetatable(xyd.models)
    if not mt or not mt.__i then return nil end
    return mt.__i[name]
  end

  M.realCount = function(ic, itemID)
    local a = ic:getItemCount(itemID, xyd.ItemChangeBaseFrom.FreeGet) or 0
    local b = ic:getItemCount(itemID, xyd.ItemChangeBaseFrom.Purchase) or 0
    return a + b
  end

  M.installItemChange = function()
    local ic = slt("itemChange")
    if not ic then return end
    if rawget(ic, "_mod_reduceItem") then return end

    ic._mod_reduceItem = ic.reduceItem
    ic.reduceItem = function(self, itemID, num, from, params, recordInfo)
      if M.freeze and itemID and FROZEN[itemID] and num and num > 0 then
        return true
      end
      return self._mod_reduceItem(self, itemID, num, from, params, recordInfo)
    end

    ic._mod_reducePaidGem = ic.reducePaidGem
    ic.reducePaidGem = function(self, num, from, params)
      if M.freeze and num and num > 0 then
        return true
      end
      return self._mod_reducePaidGem(self, num, from, params)
    end

    ic._mod_getItemCount = ic.getItemCount
    ic.getItemCount = function(self, itemID, from)
      local n = self._mod_getItemCount(self, itemID, from)
      if M.freeze and from == nil and itemID and FROZEN[itemID] then
        return (n or 0) + M.bonus
      end
      return n
    end

    print("[MergeMod] itemChange wrappers installed")
  end

  M.installPlayer = function()
    local pm = model("player")
    if not pm then return end
    if rawget(pm, "_mod_setGem") then return end

    pm._mod_setGem = pm.setGem
    pm.setGem = function(self, val, noUpdate)
      local ic = slt("itemChange")
      if M.freeze and ic then
        val = M.realCount(ic, xyd.ItemNameMap.Gem)
      end
      return self._mod_setGem(self, val, noUpdate)
    end

    pm._mod_setCoin = pm.setCoin
    pm.setCoin = function(self, val, noUpdate)
      local ic = slt("itemChange")
      if M.freeze and ic then
        val = M.realCount(ic, xyd.ItemNameMap.Gold)
      end
      return self._mod_setCoin(self, val, noUpdate)
    end

    print("[MergeMod] player wrappers installed")
  end

  M.refreshEnergy = function()
    if not M.infEnergy then return end
    local en = slt("energy")
    if not en then return end
    if en:getInfiniteEnergyRemainTime() < 600 then
      en:activateInfiniteEnergy(3600)
    end
  end

  -- Grants real currency into merge_user. addItem schedules checkUpload() one
  -- frame later, so this reaches the server. noBDRecord = true keeps it out of
  -- the analytics stream. Composes safely with the freeze wrappers: the
  -- setGem / setCoin wrappers below rewrite the argument to the real total, so
  -- the inflated display value never lands in player_profile.
  M.addItem = function(itemID, amount)
    local ic = slt("itemChange")
    if not ic or not amount or amount <= 0 then return end

    ic:addItem(
      { { [xyd.RewardConfigKey.ItemID] = itemID,
          [xyd.RewardConfigKey.ItemNum] = amount } },
      xyd.ItemChangeBaseFrom.FreeGet,
      nil, nil, nil,
      true
    )

    local player = model("player")
    if player then
      if itemID == xyd.ItemNameMap.Gem then
        player:setGem(ic:getItemCount(xyd.ItemNameMap.Gem))
      elseif itemID == xyd.ItemNameMap.Gold then
        player:setCoin(ic:getItemCount(xyd.ItemNameMap.Gold))
      end
    end
  end

  M.tick = function()
    pcall(M.installItemChange)
    pcall(M.installPlayer)
    pcall(M.refreshEnergy)
  end
end
