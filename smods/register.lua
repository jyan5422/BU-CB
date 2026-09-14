-- Publishes our challenges into SMODS.Challenges.
--
-- The upstream handlers append their DATA tables straight to G.CHALLENGES,
-- which is all the challenge menu needs, so this deliberately does NOT call
-- SMODS.Challenge(): register() would insert into G.CHALLENGES a second time
-- (duplicating every entry) and SMODS.add_prefixes would rewrite the id to
-- c_chmod_*, breaking the raw ids the menu and localizeChalNames use.
--
-- SMODS still expects to find the running challenge by id:
-- SMODS.calculate_card_areas indexes SMODS.Challenges[G.GAME.challenge] and
-- reads .id off it, so leaving that table empty crashes on the first
-- debuff_card of any challenge run. Populating it directly keeps the ids
-- unchanged while giving SMODS the object it looks for.
if not SMODS.Challenges then return end

local published = 0
for _, data in ipairs(G.CHALLENGES or {}) do
  local id = data.id
  if id and (id:sub(1, 2) == "cm" or id:find("Daily_Challenge")) and not SMODS.Challenges[id] then
    -- Keyed by the id the game stores in G.GAME.challenge; `key` and `id` must
    -- agree, since SMODS reads both.
    data.key = data.key or id
    data.set = data.set or "Challenge"
    data.mod = data.mod or SMODS.current_mod
    SMODS.Challenges[id] = data
    published = published + 1
  end
end

sendInfoMessage(("Published %d challenges to SMODS.Challenges"):format(published), "ChallengeMod")
