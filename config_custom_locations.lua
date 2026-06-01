-- Custom fixed location configuration.
--
-- Use fixed locations when a prop cannot be detected reliably, or when a mapped
-- interior needs a manually calibrated chair, bench, bed, bath, or piano.
--
-- Entry format:
--     { coords = vector3(x, y, z), heading = 180.0, radius = 2.0 }
--
-- Optional fields:
--     label       = 'left'
--     effect      = 'clean'
--     effectPhase = 'start' -- start, stop, or both

Config.CustomLocations = {
    enabled = true,

    chairs = {
        -- { coords = vector3(0.0, 0.0, 0.0), heading = 180.0, radius = 1.5 },
    },

    benches = {
        -- { coords = vector3(0.0, 0.0, 0.0), heading = 180.0, radius = 2.0, label = 'left' },
        -- { coords = vector3(0.0, 0.0, 0.0), heading = 180.0, radius = 2.0, label = 'right' },
    },

    beds = {
        -- { coords = vector3(0.0, 0.0, 0.0), heading = 180.0, radius = 2.0 },
    },

    baths = {
        -- { coords = vector3(0.0, 0.0, 0.0), heading = 270.0, radius = 2.0, effect = 'clean', effectPhase = 'start' },
    },

    pianos = {
        -- { coords = vector3(0.0, 0.0, 0.0), heading = 0.0, radius = 2.0 },
    },
}
