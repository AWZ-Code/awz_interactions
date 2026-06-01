-- Custom prop model configuration.
--
-- Supported sections: chairs, benches, beds, baths, pianos, misc.
--
-- Simple entry:
--     'model_name'
--
-- Advanced entry:
--     { model = 'model_name', radius = 1.5, x = 0.0, y = 0.0, z = 0.5, heading = 180.0 }
--
-- Multiple seats on the same prop:
--     {
--         model = 'bench_model',
--         radius = 2.0,
--         seats = {
--             { label = 'left',   x =  0.55, y = 0.0, z = 0.5, heading = 180.0 },
--             { label = 'middle', x =  0.00, y = 0.0, z = 0.5, heading = 180.0 },
--             { label = 'right',  x = -0.55, y = 0.0, z = 0.5, heading = 180.0 },
--         }
--     }
--
-- Offset notes:
-- - x/y/z/heading are local offsets from the prop.
-- - Adjust z if the ped is too high or too low.
-- - Adjust heading if the ped faces the wrong direction.
-- - Adjust x/y if the ped is too far forward, backward, left, or right.

Config.CustomPropModels = {
    enabled = true,

    chairs = {
        {
            model = 'sdchurchchair',
            radius = 1.5,
            x = 0.0,
            y = -0.1,
            z = -0.1,
            heading = 180.0,
        },
    },

    benches = {
        {
            model = 'sdchurchbench',
            radius = 2.0,
            seats = {
                { label = 'left',  x =  0.5, y = -0.3, z = -0.375, heading = 180.0 },
                { label = 'right', x = -0.5, y = -0.3, z = -0.375, heading = 180.0 },
            }
        },
        {
            model = 'p_shoeshinestand01x',
            radius = 2.0,
            seats = {
                { label = 'right', x = -0.45, y = 0.25, z = 1.2, heading = 180.0 },
                { label = 'left',  x =  0.45, y = 0.25, z = 1.2, heading = 180.0 },
            }
        },
        {
            model = 'churchbench1',
            radius = 2.0,
            seats = {
                { label = 'left',  x = -1.5, y = 0.0, z = -0.3, heading = 180.0 },
                { label = 'right', x =  0.0, y = 0.0, z = -0.3, heading = 180.0 },
            }
        },
        {
            model = 'churchbench2',
            radius = 2.0,
            seats = {
                { label = 'left',  x = 0.0, y = 0.0, z = -0.3, heading = 180.0 },
                { label = 'right', x = 1.5, y = 0.0, z = -0.3, heading = 180.0 },
            }
        },
    },

    beds = {},

    baths = {
        {
            model = 'p_bath02x',
            radius = 1.5,
            x = 0.0,
            y = 0.5,
            z = 1.0,
            heading = 180.0,
            effect = 'clean',
            effectPhase = 'start',
        },
    },

    pianos = {
        {
            model = 'pipeorgan',
            radius = 2.0,
            isCompatible = IsPedHumanMale,
            x = 0.0,
            y = -0.70,
            z = -0.65,
            heading = 0.0,
        },
        {
            model = 'pipeorgan',
            radius = 2.0,
            isCompatible = IsPedHumanFemale,
            x = 0.0,
            y = -0.70,
            z = -0.625,
            heading = 0.0,
        },
    },

    misc = {
        -- Example for custom props that provide their own scenarios or animations:
        -- { model = 'pole', radius = 1.5, x = 0.0, y = 0.5, z = 1.0, heading = 180.0, animations = DancingAnimations },
    },
}
