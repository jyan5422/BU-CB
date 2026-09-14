-- Registers the challenges with SMODS.
--
-- The handlers appended their DATA tables to G.CHALLENGES (the Lovely path).
-- SMODS.Challenge owns that list, so the entries are moved across and the
-- raw appends removed, leaving SMODS as the single source of truth.

-- Every id referenced by rules.custom needs a registered modifier, or the
-- rules box indexes a nil config and the run crashes on blind select.
local function collect_modifier_keys(challenges)
  local seen, keys = {}, {}
  for _, data in ipairs(challenges) do
    for _, v in ipairs(data.rules and data.rules.custom or {}) do
      if v.id and not seen[v.id] then
        seen[v.id] = true
        keys[#keys + 1] = v.id
      end
    end
  end
  return keys
end

-- Mirrors the ownership test in core.lua's challenge_list_page: ours are the
-- "cm"-prefixed ids plus the daily entries. Vanilla challenges are left alone.
local challenges = {}
for _, data in ipairs(G.CHALLENGES) do
  local id = data.id
  if id and (id:sub(1, 2) == "cm" or id:find("Daily_Challenge")) then
    challenges[#challenges + 1] = data
  end
end

if SMODS.Modifier then
  for _, key in ipairs(collect_modifier_keys(challenges)) do
    SMODS.Modifier({ key = key, config = {} })
  end
end

for _, data in ipairs(challenges) do
  for i = #G.CHALLENGES, 1, -1 do
    if G.CHALLENGES[i] == data then table.remove(G.CHALLENGES, i) end
  end

  SMODS.Challenge({
    key = data.id,
    loc_txt = { name = data.name },
    rules = data.rules,
    jokers = data.jokers,
    consumeables = data.consumeables,
    vouchers = data.vouchers,
    deck = data.deck,
    restrictions = data.restrictions,
    unlocked = function(self) return true end,
  })
end
