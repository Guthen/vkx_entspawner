vkx_entspawner = vkx_entspawner or {}
vkx_entspawner.version = "2.3.0"
vkx_entspawner.save_path = "vkx_tools/entspawners/%s.json"
vkx_entspawner.spawners = vkx_entspawner.spawners or {}
vkx_entspawner.blocking_entity_blacklist = {
    ["keyframe_rope"] = true,
    ["trigger_multiple"] = true,
    ["trigger_once"] = true,
}


function vkx_entspawner.print( msg, ... )
    if #{ ... } > 0 then
        print( "VKX Entity Spawner ─ " .. msg:format( ... ) )
    else
        print( "VKX Entity Spawner ─ " .. msg )
    end
end

local convar_debug = CreateConVar( "vkx_entspawner_debug", "0" )
function vkx_entspawner.debug_print( msg, ... )
    if not convar_debug:GetBool() then return end
    vkx_entspawner.print( "Debug: " .. msg, ... )
end

function vkx_entspawner.get_spawner_center( spawner )
    local sum_pos = Vector()

    for i, v in ipairs( spawner.locations ) do
        sum_pos = sum_pos + v.pos
    end

    return sum_pos / #spawner.locations
end

if CLIENT then
    vkx_entspawner.ents_chance = vkx_entspawner.ents_chance or {}

    function vkx_entspawner.is_holding_tool()
        if not IsValid( LocalPlayer() ) then return false end 

        local weapon = LocalPlayer():GetActiveWeapon()
        if not IsValid( weapon ) or not ( weapon:GetClass() == "gmod_tool" ) or not ( weapon:GetMode() == "vkx_entspawner" ) then return false end

        return true
    end

    function vkx_entspawner.get_tool()
        if not IsValid( LocalPlayer() ) then return end
        return LocalPlayer():GetTool( "vkx_entspawner" )
    end

    function vkx_entspawner.refresh_tool_preview()
        local tool = vkx_entspawner.get_tool()
        if tool then
            tool:ComputePreviewLocations()
        end
    end

    function vkx_entspawner.delete_preview_locations()
        local tool = vkx_entspawner.get_tool()
        if tool then
            tool:ClearPreviewLocations()
        end
    end

    --  network spawners
    net.Receive( "vkx_entspawner:network", function( len )
        local spawners = net.ReadTable()
        vkx_entspawner.spawners = spawners
    end )

    local function retrieve_spawners()
        net.Start( "vkx_entspawner:network" )
        net.SendToServer()
    end
    concommand.Add( "vkx_entspawner_retrieve_spawners", retrieve_spawners )
    hook.Add( "InitPostEntity", "vkx_entspawner:network", retrieve_spawners )

    --  notification
    net.Receive( "vkx_entspawner:notify", function()
        notification.AddLegacy( net.ReadString(), net.ReadUInt( 3 ), 3 )
    end )
else
    function vkx_entspawner.spawn_object( key, pos, ang )
        if not key or not pos or not ang then return end

        if list.Get( "Weapon" )[key] then
            return vkx_entspawner.spawn_weapon( key, pos, ang )
        elseif list.Get( "NPC" )[key] then
            return vkx_entspawner.spawn_npc( key, pos, ang )
        elseif list.Get( "SpawnableEntities" )[key] then
            return vkx_entspawner.spawn_entity( key, pos, ang )
        elseif list.Get( "Vehicles" )[key] then
            return vkx_entspawner.spawn_vehicle( key, pos, ang )
        elseif simfphys and list.Get( "simfphys_vehicles" )[key] then
            local vehicle = list.Get( "simfphys_vehicles" )[key]
            if vehicle.SpawnOffset then pos = pos + vehicle.SpawnOffset end
            return simfphys.SpawnVehicleSimple( key, pos, ang ), "vehicles"
        else
            return vkx_entspawner.print( "Try to spawn an Object %q which is not supported!", key )
        end
    end

    function vkx_entspawner.spawn_vehicle( key, pos, ang )
        local vehicle = list.Get( "Vehicles" )[key]
        if not vehicle then 
            return vkx_entspawner.print( "Try to spawn a Vehicle %q which doesn't exists!", key )
        end

        local ent = ents.Create( vehicle.Class )
        if not IsValid( ent ) then 
            return vkx_entspawner.print( "Failed to create %q for unknown reasons!", vehicle.Name ) 
        end
        if vehicle.Offset then pos = Vector( pos.x, pos.y, pos.z + vehicle.Offset ) end
        ent:SetPos( pos )
        ent:SetAngles( ang )
        if vehicle.Model then ent:SetModel( vehicle.Model ) end
        for k, v in pairs( vehicle.KeyValues or {} ) do
            ent:SetKeyValue( k, v )
        end
        ent:Spawn()

        return ent, "vehicles"
    end

    function vkx_entspawner.spawn_entity( key, pos, ang )
        local entity = list.Get( "SpawnableEntities" )[key]
        if not entity then
            return vkx_entspawner.print( "Try to spawn an Entity %q which doesn't exists!", key )
        end

        local ent = ents.Create( entity.ClassName )
        if not IsValid( ent ) then
            return vkx_entspawner.print( "Failed to create %q for unknow reasons!", weapon.PrintName )
        end
        ent:SetPos( pos )
        ent:SetAngles( ang )
        ent:Spawn()

        return ent, "sents"
    end

    function vkx_entspawner.spawn_weapon( key, pos, ang )
        local weapon = list.Get( "Weapon" )[key]
        if not weapon then
            return vkx_entspawner.print( "Try to spawn a Weapon %q which doesn't exists!", key )
        end

        local ent = ents.Create( weapon.ClassName )
        if not IsValid( ent ) then
            return vkx_entspawner.print( "Failed to create %q for unknow reasons!", weapon.PrintName )
        end
        ent:SetPos( pos + Vector( 0, 0, 8 ) )
        ent:SetAngles( ang )
        ent:Spawn()

        return ent, "sents"
    end

    function vkx_entspawner.spawn_npc( key, pos, ang )
        local npc = list.Get( "NPC" )[key]
        if not npc then 
            return vkx_entspawner.print( "Try to spawn a NPC %q which doesn't exists!", key )
        end

        local ent = ents.Create( npc.Class )
        if not IsValid( ent ) then 
            return vkx_entspawner.print( "Failed to create %q for unknown reasons!", npc.Name ) 
        end
        if npc.Offset then pos = Vector( pos.x, pos.y, pos.z + npc.Offset ) end
        ent:SetPos( pos + Vector( 0, 0, 32 ) )
        ent:SetAngles( ang )
        if npc.Model then ent:SetModel( npc.Model ) end
        if npc.Health then 
            ent:SetMaxHealth( npc.Health )
            ent:SetHealth( npc.Health )
        end
        for k, v in pairs( npc.KeyValues or {} ) do
            ent:SetKeyValue( k, v )
        end
        for i, v in ipairs( npc.Weapons or {} ) do
            ent:Give( v )
        end
        ent:Spawn()
        if not npc.NoDrop then ent:DropToFloor() end

        return ent, "npcs"
    end

    function vkx_entspawner.can_spawn_safely( ent )
        if not IsValid( ent ) then return false end
        --if ent:IsInWorld() then return false end

        local pos = ent:GetPos()
        local min, max = ent:GetModelBounds()
        for i, v in ipairs( ents.FindInBox( pos + min, pos + max ) ) do
            if not ( v == ent ) and not vkx_entspawner.blocking_entity_blacklist[v:GetClass()] and v:GetBrushPlaneCount() == 0 and not v:IsWeapon() then 
                vkx_entspawner.debug_print( "%q is blocking %q from spawning", tostring( v ), tostring( ent ) )    
                return false, v
            end
        end

        return true
    end

    function vkx_entspawner.save_perma_spawners()
        --  map perma
        local spawners = {}
        for i, spawner in pairs( vkx_entspawner.spawners ) do
            if spawner.perma then
                --  remove useless variables
                local spawner = table.Copy( spawner )
                for i, v in ipairs( spawner.locations ) do
                    v.entities = nil
                end
                spawner.last_time = nil
                spawner.perma = nil

                spawners[#spawners + 1] = spawner
            end
        end

        --  folder(s) path
        local folder = vkx_entspawner.save_path:Split( "/" )
        table.remove( folder )
        folder = table.concat( folder, "/" )
        file.CreateDir( folder )

        --  save
        local json = util.TableToJSON( spawners )
        if not json then return vkx_entspawner.print( "Failed to save the perma spawners!" ) end
        file.Write( vkx_entspawner.save_path:format( game.GetMap() ), json )
    end

    function vkx_entspawner.load_perma_spawners()
        vkx_entspawner.spawners = {}

        --  load
        local content = file.Read( vkx_entspawner.save_path:format( game.GetMap() ) )
        if not content then return end
        
        local spawners = util.JSONToTable( content )
        if not spawners then return vkx_entspawner.print( "Failed to load the perma spawners!" ) end

        --  add spawners
        for i, spawner in pairs( spawners ) do
            spawner.perma = true
            vkx_entspawner.new_spawner( spawner )
        end
        vkx_entspawner.print( "Load %d spawners!", #spawners )
    end
    hook.Add( "InitPostEntity", "vkx_entspawner:spawner", vkx_entspawner.load_perma_spawners )
    concommand.Add( "vkx_entspawner_load_spawners", vkx_entspawner.load_perma_spawners )

    --[[ 
        @function vkx_entspawner.new_spawner
            | description: Register a new spawner, network it and save it if 'perma' is true
            | params:
                spawner: table Spawner to register
                    | params:
                        locations: table[@Location] List of locations (position and angles) where entities will spawn
                        entities: table[@EntityChance] List of spawnable entities 
                        max: int Number of maximum entities per location
                        delay: float Time needed between each spawn
                        perma: bool? Is a Permanent Spawner, if so, the spawner will be saved
                        radius: int? Player Presence Radius, allow the spawner to run if a Player is in the radius 
                        radius_disappear: (bool? In addition to PPR, will disappear spawned entities if no Player is in the radius
            | return: @EntitySpawner spawner
        
        @structure Location
            | description: Represents a position and an angle
            | params:
                pos: Vector
                ang: Angle
        
        @structure EntityChance
            | description: Represents an entity class and his percent chance of getting it
            | params:
                key: string Entity Class Name
                percent: float Entity Chance, from 0 to 1, rounded to 2 decimals
        
        @structure EntitySpawner
            | description: Represents a spawner of entities
            | params:
                id: int Identifier of the spawner in the table `vkx_entspawner.spawners`
                locations: table[@Location] List of locations (position and angles) where entities will spawn
                entities: table[@EntityChance] List of spawnable entities 
                max: int Number of maximum entities per location
                delay: float Time needed between each spawn
                perma: bool? Is a Permanent Spawner, if so, the spawner will be saved
                last_time: float Last time the spawner was runned, use of CurTime
                radius: int Player Presence Radius, allow the spawner to run if a Player is in the radius 
                radius_disappear: bool? In addition to PPR, will disappear spawned entities if no Player is in the radius
    ]]
    function vkx_entspawner.new_spawner( spawner )
        --  round percent
        for i, v in ipairs( spawner.entities ) do
            v.percent = math.Round( v.percent, 2 )
        end

        --  add 'entities' table to each location
        for i, v in ipairs( spawner.locations ) do
            v.entities = {}
        end

        --  add spawner
        spawner.last_time = spawner.last_time or CurTime()
        spawner.radius = spawner.radius or 0
        spawner.id = spawner.id or #vkx_entspawner.spawners + 1
        vkx_entspawner.spawners[spawner.id] = spawner

        --  save
        if spawner.perma then
            vkx_entspawner.save_perma_spawners()
        end

        vkx_entspawner.safe_network_spawners()
        return spawner
    end

    function vkx_entspawner.delete_spawner( id )
        local spawner = vkx_entspawner.spawners[id]
        if not spawner then return end

        vkx_entspawner.spawners[id] = nil
        if spawner.perma then
            vkx_entspawner.save_perma_spawners()
        end
        vkx_entspawner.safe_network_spawners()
    end

    function vkx_entspawner.run_spawner( spawner, callback, err_callback )
        for i, v in ipairs( spawner.locations ) do
            --  limit?
            v.entities = v.entities or {}
            for i, ent in ipairs( v.entities ) do
                if not IsValid( ent ) then
                    table.remove( v.entities, i )
                end
            end

            --  spawn
            if #v.entities < spawner.max then
                for i, chance in ipairs( spawner.entities ) do
                    if math.random() <= chance.percent then 
                        local obj, type = vkx_entspawner.spawn_object( chance.key, v.pos, v.ang )
                        if IsValid( obj ) then
                            local can_spawn, blocking_entity = vkx_entspawner.can_spawn_safely( obj )
                            if not can_spawn then
                                if err_callback then err_callback( "cant_spawn", obj, blocking_entity ) end
                                obj:Remove()
                                break
                            end

                            if callback then callback( obj, type ) end
                            v.entities[#v.entities + 1] = obj
                        end

                        break
                    end
                end
            end
        end
    end

    --  network spawners
    util.AddNetworkString( "vkx_entspawner:network" )
    function vkx_entspawner.network_spawners( ply )
        --  get admins
        local admins = {}
        if not ply then
            for i, v in ipairs( player.GetAll() ) do
                if v:IsSuperAdmin() then
                    admins[#admins + 1] = v
                end
            end
        end

        --  serialize spawners
        local spawners = {}
        for i, spawner in pairs( vkx_entspawner.spawners ) do
            local cl_spawner = {}
            cl_spawner.perma = spawner.perma or nil
            cl_spawner.entities = spawner.entities
            cl_spawner.max = spawner.max
            cl_spawner.delay = spawner.delay
            cl_spawner.radius = spawner.radius
            cl_spawner.radius_disappear = spawner.radius_disappear
            cl_spawner.locations = {}
            for i, v in ipairs( spawner.locations ) do
                --  avoid 'entities' table
                cl_spawner.locations[#cl_spawner.locations + 1] = {
                    pos = v.pos,
                    ang = v.ang
                }
            end
            spawners[#spawners + 1] = cl_spawner
        end

        --  send
        net.Start( "vkx_entspawner:network" )
            net.WriteTable( spawners )
        net.Send( ply or admins )
    end

    function vkx_entspawner.safe_network_spawners( ply )
        timer.Create( "vkx_entspawner:network" .. ( IsValid( ply ) and ply:UniqueID() or "" ), .1, 1, function()
            vkx_entspawner.network_spawners( ply )
        end )
    end

    net.Receive( "vkx_entspawner:network", function( len, ply )
        if not ply:IsSuperAdmin() then return end

        vkx_entspawner.network_spawners( ply )
    end )

    --  spawner time
    local fake_cleanup_id = -1
    timer.Create( "vkx_entspawner:spawner", 1, 0, function()
        if player.GetCount() <= 0 then return end

        for i, spawner in pairs( vkx_entspawner.spawners ) do
            if CurTime() - spawner.last_time >= spawner.delay then
                --  run spawner
                local should_run = hook.Run( "vkx_entspawner:should_spawner_run", spawner )
                if not ( should_run == false ) then
                    vkx_entspawner.run_spawner( spawner, function( obj, type )
                        local list = cleanup.GetList()
                        list[fake_cleanup_id] = list[fake_cleanup_id] or {}
                        list[fake_cleanup_id][type] = list[fake_cleanup_id][type] or {}
                        list[fake_cleanup_id][type][#list[fake_cleanup_id][type] + 1] = obj
                    end )
                    spawner.last_time = CurTime()
                end
            end
        end
    end )

    hook.Add( "vkx_entspawner:should_spawner_run", "vkx_entspawner:player_radius", function( spawner )
        --  player presence radius
        if ( spawner.radius or 0 ) > 0 then
            local has_someone_within = false
            for i, ply in ipairs( player.GetAll() ) do
                if ply:GetPos():Distance( vkx_entspawner.get_spawner_center( spawner ) ) <= spawner.radius then
                    has_someone_within = true
                    break
                end
            end

            if not has_someone_within then
                --  player presence disappear
                if spawner.radius_disappear then
                    for i, v in ipairs( spawner.locations ) do
                        for i, ent in ipairs( v.entities ) do
                            if IsValid( ent ) then
                                ent:Remove()
                            end
                        end
                        v.entities = {}
                    end
                end

                return false
            end
        end
    end )

    --  notification
    util.AddNetworkString( "vkx_entspawner:notify" )
    function vkx_entspawner.notify( ply, msg, type )
        net.Start( "vkx_entspawner:notify" )
            net.WriteString( msg )
            net.WriteUInt( type, 3 )
        net.Send( ply )
    end
end



--  shape list
list.Set( "vkx_entspawner_shapes", "None", {
    z_order = 0,
    compute = function( tool )
        return { 
            {
                pos = Vector(), 
                ang = Angle(),
            },
        } 
    end,
} )
list.Set( "vkx_entspawner_shapes", "Circle", {
    z_order = 1,
    convars = {
        circle_number = {
            name = "Number",
            default = "3",
            template = {
                type = "Int",
                options = {
                    min = 1,
                    max = 64,
                },
            },
        },
        circle_radius = {
            name = "Radius",
            default = "64",
            template = {
                type = "Float",
                options = {
                    min = 32,
                    max = 1000,
                    --decimals = 2,
                },
            },
        },
        offset_angle = {
            name = "Offset Angle",
            default = "0",
            template = {
                type = "Int",
                options = {
                    min = 0,
                    max = 360,
                },
            },
        },
    },
    compute = function( tool )
        local positions = {}
        local radius, number = tool:GetClientNumber( "circle_radius", 64 ), tool:GetClientNumber( "circle_number", 1 )

        for a = 1, 360, 360 / number do
            local ang = math.rad( a )
            positions[#positions + 1] = {
                pos = Vector( math.cos( ang ), math.sin( ang ), 0 ) * radius,
                ang = Angle( 0, a + tool:GetClientNumber( "offset_angle", 0 ), 0 ),
            }
        end

        return positions
    end,
} )
list.Set( "vkx_entspawner_shapes", "Square", {
    z_order = 2,
    convars = {
        square_offset = {
            z_order = 0,
            name = "Offset",
            default = "64",
            template = {
                type = "Int",
                options = {
                    min = 32,
                    max = 1000,
                },
            },
        },
        square_width = {
            z_order = 1,
            name = "Width",
            default = "3",
            template = {
                type = "Int",
                options = {
                    min = 1,
                    max = 64,
                },
            },
        },
        square_length = {
            z_order = 2,
            name = "Length",
            default = "3",
            template = {
                type = "Int",
                options = {
                    min = 1,
                    max = 64,
                },
            },
        },
    },
    compute = function( tool )
        local positions = {}
        local offset = tool:GetClientNumber( "square_offset", 64 )

        local size_x, size_y = tool:GetClientNumber( "square_width", 3 ), tool:GetClientNumber( "square_length", 3 )
        local n, n_max = 0, size_x * size_y
        local center_offset = Vector( ( size_y + 1 ) * offset, ( size_x + 1 ) * offset, 0 ) / 2
        for y = 1, size_x do
            for x = 1, size_y do
                if n >= n_max then break end
                positions[#positions + 1] = {
                    pos = Vector( x * offset, y * offset, 0 ) - center_offset,
                    ang = Angle(),
                }
                n = n + 1
            end
        end

        return positions
    end,
} )
list.Set( "vkx_entspawner_shapes", "Random", {
    z_order = 3,
    convars = {
        random_number = {
            z_order = 0,
            name = "Number",
            default = "3",
            template = {
                type = "Int",
                options = {
                    min = 1,
                    max = 64,
                },
            },
        },
        random_radius = {
            z_order = 1,
            name = "Radius",
            default = "64",
            template = {
                type = "Float",
                options = {
                    min = 32,
                    max = 1000,
                    --decimals = 2,
                },
            },
        },
        random_x_ratio = {
            z_order = 2,
            name = "X Ratio",
            default = "1",
            template = {
                type = "Float",
                options = {
                    min = 0,
                    max = 1,
                    --decimals = 2,
                },
            },
        },
        random_y_ratio = {
            z_order = 3,
            name = "Y Ratio",
            default = "1",
            template = {
                type = "Float",
                options = {
                    min = 0,
                    max = 1,
                    --decimals = 2,
                },
            },
        },
    },
    compute = function( tool )
        local positions = {}
        local radius, number = tool:GetClientNumber( "random_radius", 64 ), tool:GetClientNumber( "random_number", 1 )
        local x_ratio, y_ratio = tool:GetClientNumber( "random_x_ratio", 1 ), tool:GetClientNumber( "random_y_ratio", 1 )

        for a = 1, 360, 360 / number do
            local ang, r = math.rad( a ), math.random( radius )
            positions[#positions + 1] = {
                pos = Vector( math.cos( ang ) * y_ratio * r, math.sin( ang ) * x_ratio * r, 0 ),
                ang = Angle( 0, math.random( 360 ), 0 ),
            }
        end

        return positions
    end,
} )