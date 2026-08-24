-- ChallengeMod main file - SMODS already sets SMODS.current_mod with path
-- Load challenge definitions from Challenges.lua
assert(loadfile(SMODS.current_mod.path .. "Challenges.lua"))()