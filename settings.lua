---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by seancheey.
--- DateTime: 10/8/20 2:36 AM
---

data:extend {
    {
        type = "int-setting",
        setting_type = "runtime-per-user",
        name = "path-finding-test-per-tick",
        default_value = 15,
        minimum_value = 1,
        maximum_value = 100
    },
    {
        type = "int-setting",
        setting_type = "runtime-per-user",
        name = "max-path-finding-explore-num",
        default_value = 10000,
        minimum_value = 1000,
        maximum_value = 1000000
    },
    {
        type = "double-setting",
        setting_type = "runtime-per-user",
        name = "greedy-level",
        default_value = 1.05,
        minimum_value = 1,
        maximum_value = 2
    },
}