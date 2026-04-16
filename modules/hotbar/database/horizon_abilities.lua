-- Static job ability lookup table for HorizonXI.
-- Source: HorizonXI Job Ability Progression Reference spreadsheet.
-- job = job ID matching libs/jobs.lua (1=WAR, 2=MNK, etc.)
-- level = character level the ability is learned.
-- pet = true for BST pet commands (level-gated but displayed in the pet section).

return {
    -- WAR (1)
    ['Mighty Strikes']  = { job = 1,  level = 1 },
    ['Provoke']         = { job = 1,  level = 5 },
    ['Berserk']         = { job = 1,  level = 15 },
    ['Defender']        = { job = 1,  level = 25 },
    ['Warcry']          = { job = 1,  level = 35 },
    ['Aggressor']       = { job = 1,  level = 45 },

    -- MNK (2)
    ['Hundred Fists']   = { job = 2,  level = 1 },
    ['Boost']           = { job = 2,  level = 5 },
    ['Focus']           = { job = 2,  level = 15 },
    ['Dodge']           = { job = 2,  level = 25 },
    ['Chakra']          = { job = 2,  level = 35 },
    ['Chi Blast']       = { job = 2,  level = 41 },
    ['Counterstance']   = { job = 2,  level = 45 },

    -- WHM (3)
    ['Benediction']     = { job = 3,  level = 1 },
    ['Divine Seal']     = { job = 3,  level = 15 },
    ['Devotion']        = { job = 3,  level = 45 },

    -- BLM (4)
    ['Manafont']        = { job = 4,  level = 1 },
    ['Elemental Seal']  = { job = 4,  level = 15 },

    -- RDM (5)
    ['Chainspell']      = { job = 5,  level = 1 },
    ['Convert']         = { job = 5,  level = 40 },

    -- THF (6)
    ['Perfect Dodge']   = { job = 6,  level = 1 },
    ['Steal']           = { job = 6,  level = 5 },
    ['Sneak Attack']    = { job = 6,  level = 15 },
    ['Flee']            = { job = 6,  level = 25 },
    ['Trick Attack']    = { job = 6,  level = 30 },
    ['Mug']             = { job = 6,  level = 35 },
    ['Bully']           = { job = 6,  level = 40 },
    ['Hide']            = { job = 6,  level = 45 },
    ['Accomplice']      = { job = 6,  level = 45 },
    ['Collaborator']    = { job = 6,  level = 45 },

    -- PLD (7)
    ['Invincible']      = { job = 7,  level = 1 },
    ['Holy Circle']     = { job = 7,  level = 5 },
    ['Shield Bash']     = { job = 7,  level = 15 },
    ['Sentinel']        = { job = 7,  level = 30 },
    ['Cover']           = { job = 7,  level = 35 },
    ['Chivalry']        = { job = 7,  level = 45 },
    ['Rampart']         = { job = 7,  level = 62 },

    -- DRK (8)
    ['Blood Weapon']    = { job = 8,  level = 1 },
    ['Arcane Circle']   = { job = 8,  level = 5 },
    ['Last Resort']     = { job = 8,  level = 15 },
    ['Weapon Bash']     = { job = 8,  level = 20 },
    ['Souleater']       = { job = 8,  level = 30 },

    -- BST (9)
    ['Familiar']        = { job = 9,  level = 1 },
    ['Charm']           = { job = 9,  level = 1 },
    ['Gauge']           = { job = 9,  level = 10 },
    ['Reward']          = { job = 9,  level = 12 },
    ['Call Beast']      = { job = 9,  level = 23 },
    ['Tame']            = { job = 9,  level = 30 },

    -- BST Pet Commands (9, pet = true)
    ['Fight']           = { job = 9,  level = 1,  pet = true },
    ['Heel']            = { job = 9,  level = 10, pet = true },
    ['Stay']            = { job = 9,  level = 15, pet = true },
    ['Sic']             = { job = 9,  level = 25, pet = true },
    ['Leave']           = { job = 9,  level = 35, pet = true },

    -- BRD (10)
    ['Soul Voice']      = { job = 10, level = 1 },

    -- RNG (11)
    ['Eagle Eye Shot']  = { job = 11, level = 1 },
    ['Sharpshot']       = { job = 11, level = 1 },
    ['Scavenge']        = { job = 11, level = 10 },
    ['Camouflage']      = { job = 11, level = 20 },
    ['Barrage']         = { job = 11, level = 30 },
    ['Shadowbind']      = { job = 11, level = 40 },
    ['Velocity Shot']   = { job = 11, level = 45 },
    ['Unlimited Shot']  = { job = 11, level = 51 },

    -- SAM (12)
    ['Meikyo Shisui']   = { job = 12, level = 1 },
    ['Warding Circle']  = { job = 12, level = 5 },
    ['Third Eye']       = { job = 12, level = 15 },
    ['Hasso']           = { job = 12, level = 25 },
    ['Meditate']        = { job = 12, level = 30 },
    ['Seigan']          = { job = 12, level = 35 },

    -- NIN (13)
    ['Mikage']          = { job = 13, level = 1 },
    ['Yonin']           = { job = 13, level = 20 },

    -- DRG (14)
    ['Spirit Surge']    = { job = 14, level = 1 },
    ['Call Wyvern']     = { job = 14, level = 1 },
    ['Ancient Circle']  = { job = 14, level = 5 },
    ['Jump']            = { job = 14, level = 10 },
    ['Spirit Link']     = { job = 14, level = 25 },
    ['High Jump']       = { job = 14, level = 35 },
    ['Super Jump']      = { job = 14, level = 50 },

    -- SMN (15)
    ['Astral Flow']     = { job = 15, level = 1 },
}
