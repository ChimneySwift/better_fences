better_fences = {
    version = "0.1.0",
}

-- This function returns true if the fence should be an end fence, false if a regular fence
function better_fences._should_be_endfence(pos)
    local check_positions = {
        {x=pos.x+1, y=pos.y, z=pos.z},
        {x=pos.x-1, y=pos.y, z=pos.z},
        {x=pos.x, y=pos.y, z=pos.z+1},
        {x=pos.x, y=pos.y, z=pos.z-1},
    }

    local adjacent = 0
    for _, p in pairs(check_positions) do
        local node = minetest.get_node(p)

        if minetest.get_item_group(node.name, "fence") > 0 or minetest.get_item_group(node.name, "wall") > 0 then
            adjacent = adjacent + 1
            if adjacent >= 2 then break end
        end
    end

    if adjacent >= 2 then
        return false
    else
        return true
    end
end

function better_fences._get_newfence(pos)
    local node = minetest.get_node(pos)
    local def = minetest.registered_nodes[node.name]
    local endfence = better_fences._should_be_endfence(pos)

    if not endfence and minetest.get_item_group(node.name, "end_fence") > 0 then
        return (def._regular_fence or false)
    elseif endfence and minetest.get_item_group(node.name, "end_fence") < 1 then
        return (def._end_fence or false)
    end

    return false
end

-- This function updates a single fence node on the map
function better_fences.update_fence(pos)
    local newfence = better_fences._get_newfence(pos)
    if newfence then minetest.set_node(pos, {name=newfence}) end
end

-- This function updates every fence node surounding a fence on the map
function better_fences.update_surrounding(pos)
    local check_positions = {
        {x=pos.x+1, y=pos.y, z=pos.z},
        {x=pos.x-1, y=pos.y, z=pos.z},
        {x=pos.x, y=pos.y, z=pos.z+1},
        {x=pos.x, y=pos.y, z=pos.z-1},
    }

    for _, p in pairs(check_positions) do
        local newfence = better_fences._get_newfence(p)
        if newfence then minetest.set_node(p, {name=newfence}) end
    end
end

function better_fences.on_place(itemstack, placer, pointed_thing)
    local pos = pointed_thing.above
    local def = minetest.registered_nodes[itemstack:get_name()]
    if not def then minetest.log("error", "Could not get node definition for fence placed by "..placer:get_player_name()); return; end

    if not (creative and creative.is_enabled_for(placer:get_player_name())) then
        local taken = itemstack:take_item(1)
        if taken:get_count() < 1 then return end
    end

    if better_fences._should_be_endfence(pos) then
        minetest.set_node(pos, {name=def._end_fence})
    else
        minetest.set_node(pos, {name=def._regular_fence})
    end

    better_fences.update_surrounding(pos)

    return itemstack
end

function better_fences.on_dig(pos, node, digger)
    minetest.node_dig(pos, node, digger)
    better_fences.update_surrounding(pos)
end


-- The bulk of this function is based off the function in the default mod.
function better_fences.register_fence(name, def)
    local fence_texture = "default_fence_overlay.png^" .. def.texture ..
            "^default_fence_overlay.png^[makealpha:255,126,126"

    -- Allow almost everything to be overridden
    local default_fields = {
        paramtype = "light",
        drawtype = "nodebox",
        node_box = {
            type = "connected",
            fixed = {{-1/8, -1/2, -1/8, 1/8, 1/2, 1/8}},
            -- connect_top =
            -- connect_bottom =
            connect_front = {{-1/16,3/16,-1/2,1/16,5/16,-1/8},
                {-1/16,-5/16,-1/2,1/16,-3/16,-1/8}},
            connect_left = {{-1/2,3/16,-1/16,-1/8,5/16,1/16},
                {-1/2,-5/16,-1/16,-1/8,-3/16,1/16}},
            connect_back = {{-1/16,3/16,1/8,1/16,5/16,1/2},
                {-1/16,-5/16,1/8,1/16,-3/16,1/2}},
            connect_right = {{1/8,3/16,-1/16,1/2,5/16,1/16},
                {1/8,-5/16,-1/16,1/2,-3/16,1/16}},
        },
        inventory_image = (def.inventory_image == nil and fence_texture),
        wield_image = (def.wield_image == nil and fence_texture),
        tiles = {def.texture},
        sunlight_propagates = true,
        is_ground_content = false,
        groups = {},
        on_place = better_fences.on_place,
        on_dig = better_fences.on_dig,

        -- For figuring out which fence to place
        _end_fence = name.."_end",
        _regular_fence = name,
    }

    for k, v in pairs(default_fields) do
        if not def[k] then
            def[k] = v
        end
    end

    def.texture = nil
    def.material = nil

    -- Now add the actual fences. 2 fences are added, one that attaches to all nodes and one that only attaches to fences.
    local regular_fence_fields = table.copy(def)
    regular_fence_fields.connects_to = {"group:fence", "group:wall",}

    minetest.register_node(name, regular_fence_fields)

    local end_fence_fields = table.copy(def)
    end_fence_fields.connects_to = {"group:fence", "group:crumbly", "group:cracky", "group:snappy", "group:choppy", "group:oddly_breakable_by_hand",}
    end_fence_fields.groups.end_fence = 1
    end_fence_fields.groups.not_in_creative_inventory = 1
    end_fence_fields.description = def.description.." End (you hacker you!)"
    end_fence_fields.drop = name

    minetest.register_node(name.."_end", end_fence_fields)

    if def.craft then
        minetest.register_craft(def.craft)
        def.craft = nil
    else
        minetest.register_craft({
            output = name .. " 4",
            recipe = {
                { def.material, 'group:stick', def.material },
                { def.material, 'group:stick', def.material },
            }
        })
    end
end

-- Unregister default fences
local default_fences = {
    "default:fence_wood",
    "default:fence_acacia_wood",
    "default:fence_junglewood",
    "default:fence_pine_wood",
    "default:fence_aspen_wood",
}

for _, f in pairs(default_fences) do
    minetest.unregister_item(f)
end

-- Register new fences
better_fences.register_fence("better_fences:fence_wood", {
    description = "Wooden Fence",
    texture = "default_fence_wood.png",
    material = "default:wood",
    groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, fence = 1},
    sounds = default.node_sound_wood_defaults()
})
minetest.register_alias("default:fence_wood", "better_fences:fence_wood")


better_fences.register_fence("better_fences:fence_acacia_wood", {
    description = "Acacia Fence",
    texture = "default_fence_acacia_wood.png",
    material = "default:acacia_wood",
    groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, fence = 1},
    sounds = default.node_sound_wood_defaults()
})
minetest.register_alias("default:fence_acacia_wood", "better_fences:fence_acacia_wood")


better_fences.register_fence("better_fences:fence_junglewood", {
    description = "Jungle Wood Fence",
    texture = "default_fence_junglewood.png",
    material = "default:junglewood",
    groups = {choppy = 2, oddly_breakable_by_hand = 2, flammable = 2, fence = 1},
    sounds = default.node_sound_wood_defaults()
})
minetest.register_alias("default:fence_junglewood", "better_fences:fence_junglewood")


better_fences.register_fence("better_fences:fence_pine_wood", {
    description = "Pine Fence",
    texture = "default_fence_pine_wood.png",
    material = "default:pine_wood",
    groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 3, fence = 1},
    sounds = default.node_sound_wood_defaults()
})
minetest.register_alias("default:fence_pine_wood", "better_fences:fence_pine_wood")


better_fences.register_fence("better_fences:fence_aspen_wood", {
    description = "Aspen Fence",
    texture = "default_fence_aspen_wood.png",
    material = "default:aspen_wood",
    groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 3, fence = 1},
    sounds = default.node_sound_wood_defaults()
})
minetest.register_alias("default:fence_pine_wood", "better_fences:fence_pine_wood")

-- Also register walls
if minetest.get_modpath("walls") then
    local default_walls = {
        "walls:cobble",
        "walls:mossycobble",
        "walls:desertcobble",
    }

    for _, f in pairs(default_walls) do
        minetest.unregister_item(f)
    end

    function better_fences.register_wall(wall_name, wall_desc, wall_texture, wall_mat)
        better_fences.register_fence(wall_name, {
            description = wall_desc,
            texture = wall_texture,
            wield_image = false,
            inventory_image = false,
            material = wall_mat,
            groups = { cracky = 3, wall = 1, stone = 2 },
            sounds = default.node_sound_stone_defaults(),
            node_box = {
                type = "connected",
                fixed = {{-1/4, -1/2, -1/4, 1/4, 1/2, 1/4}},
                -- connect_bottom =
                connect_front = {{-3/16, -1/2, -1/2,  3/16, 3/8, -1/4}},
                connect_left = {{-1/2, -1/2, -3/16, -1/4, 3/8,  3/16}},
                connect_back = {{-3/16, -1/2,  1/4,  3/16, 3/8,  1/2}},
                connect_right = {{ 1/4, -1/2, -3/16,  1/2, 3/8,  3/16}},
            },
            craft = {
                output = wall_name.." 6",
                recipe = {
                    { '', '', '' },
                    { wall_mat, wall_mat, wall_mat},
                    { wall_mat, wall_mat, wall_mat},
                }
            },
        })
    end

    better_fences.register_wall("better_fences:wall_cobble", "Cobblestone Wall", "default_cobble.png", "default:cobble")
    minetest.register_alias("walls:cobble", "better_fences:wall_cobble")

    better_fences.register_wall("better_fences:wall_mossycobble", "Mossy Cobblestone Wall", "default_mossycobble.png", "default:mossycobble")
    minetest.register_alias("walls:mossycobble", "better_fences:wall_mossycobble")

    better_fences.register_wall("better_fences:wall_desertcobble", "Desert Cobblestone Wall", "default_desert_cobble.png", "default:desert_cobble")
    minetest.register_alias("walls:desertcobble", "better_fences:wall_desertcobble")
end