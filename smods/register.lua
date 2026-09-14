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
    --
    -- Nothing else is added to the table. Starting a run puts it in G.GAME as
    -- challenge_tab, and save_run serializes that through
    -- recursive_table_cull, which walks every nested table. A `mod` field
    -- pointing at SMODS.current_mod dragged in its dependency tree (a version
    -- table plus a comparison function) and the walk died with "loop in
    -- gettable", so only plain scalars belong here.
    data.key = data.key or id
    -- SMODS.eval_individual calls object:calculate(context), and
    -- calculate/calc_dollar_bonus are no-op defaults on the SMODS.Challenge
    -- class that registered objects inherit. These tables come from the
    -- upstream handlers with no metatable, so inherit from the class rather
    -- than reimplementing its defaults here.
    if not getmetatable(data) then
      setmetatable(data, { __index = SMODS.Challenge })
    end
    SMODS.Challenges[id] = data
    published = published + 1
  end
end

sendInfoMessage(("Published %d challenges to SMODS.Challenges"):format(published), "ChallengeMod")
