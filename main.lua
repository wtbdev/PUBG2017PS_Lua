-- UEHelpers = require("UEHelpers")
-- local UWorld = UEHelpers.GetWorld()

GameState = nil
World = nil
GameMode = nil
GamePlayStatics = nil
IsServer = false
LastWarningTime = 0
LastReleaseTime = 0

function DisableCullingForAllActors(World)
    World.StreamingLevels:ForEach(function (index, param)
        local streamLevel = param:get()
        local levelName = tostring(streamLevel:GetFullName())
        -- print("Iterating Level: " .. levelName)

        if string.find(levelName, "32") then
            goto continue
        end

        -- enable these levels
        streamLevel.bShouldBeLoaded = true;
        streamLevel.bShouldBeVisible = true;
        streamLevel.bDisableDistanceStreaming = true;
        streamLevel.bShouldBlockOnLoad = true;
        ::continue::
    end)
end

function Init()
    RegisterInitGameStatePostHook(function(gameMode)
        print("We got GameMode = " .. tostring(gameMode:get():GetFullName()))
        local mode = gameMode:get()
        mode.PlayerRespawn = true
        mode.WarmupTime = 3600
        mode.bCanAllSpectate = true
        mode.MultiplierBlueZone = 10
        -- Set the match to Airbrone
        mode.MatchStartType = 1
        mode.NumBots = 30

        local static = StaticFindObject("/Script/Engine.GameplayStatics")
        local world = FindFirstOf("World")

        GamePlayStatics = static:GetCDO()
        print("GamePlayStatics: " .. tostring(static:GetCDO():GetFullName()))

        print(tostring(world) .. ", name=" .. tostring(world:GetFullName()))
        LoopAsync(100, function()
            -- print(tostring(world.GameState:GetFullName()))
            if world.GameState:GetFullName() == nil then
                print("Waiting for GameState to be valid...")
                return false
            else

                print("state= " .. tostring(world.GameState:GetFullName()))
                -- world.GameState.RemainingTime = 3600

                -- Init the gamestate
                GameState = world.GameState
                GameState.bIsTeamMatch = true
                World = world

                GameMode = mode
                print("GameMode: " .. tostring(GameMode:GetFullName()))

                local serverPlayer = FindFirstOf("TslPlayerController")
                if serverPlayer:IsValid() and serverPlayer:HasAuthority() then

                    print("We are a server, continue to do our stuff")
                    DisableCullingForAllActors(world)
            
                    LoopAsync(100, function()
                        -- print("Spawning Bot...")
                        -- serverPlayer.CheatManager:SpawnBot()
                        if (GameState ~= nil) then
                            if (GameState.TotalWarningDuration ~= 0) then
                                if (GameState.TotalWarningDuration ~= LastWarningTime) then
                                    print("WarningDuration is " .. tostring(GameState.TotalWarningDuration) 
                                    .. "s, Fixing BlueZone Duration to " .. tostring(GameState.TotalWarningDuration / 2) .. "s...")
                                    GameState.TotalWarningDuration = GameState.TotalWarningDuration / 2
                                    LastWarningTime = GameState.TotalWarningDuration
                                end
                            end

                            if (GameState.TotalReleaseDuration ~= 0) then
                                if (GameState.TotalReleaseDuration ~= LastReleaseTime) then
                                    print("ReleaseDuration is " .. tostring(GameState.TotalReleaseDuration) 
                                    .. "s, Fixing RedZone Duration to " .. tostring(GameState.TotalReleaseDuration / 2) .. "s...")
                                    GameState.TotalReleaseDuration = GameState.TotalReleaseDuration / 2
                                    LastReleaseTime = GameState.TotalReleaseDuration
                                end
                            end
                        end
                        return false
                    end)
                else
                    print("We are a client")
                end

                return true
            end
        end)
    end)
end

-- Not working
function SpawnTestingPlayerPawn()
    local static = GamePlayStatics
    local world = World
    local botControllerClass = StaticFindObject("/Script/TslGame.TslBotAIController")
    local defaultPawn = StaticFindObject("/Game/Blueprints/Pawns/PlayerFemale_A.Default__PlayerFemale_A_C")
    local playerStateClass = StaticFindObject("/Script/TslGame.TslPlayerState")

    print("botControllerClass: " .. tostring(botControllerClass:GetFullName()))
    print("defaultPawn: " .. tostring(defaultPawn:GetFullName()))

    -- mode.PlayerControllerClass = botControllerClass

    local pawn = static:BeginDeferredActorSpawnFromClass(
        world,
        defaultPawn:GetClass(),
        nil ,1, nil
    )

    local bot = static:BeginDeferredActorSpawnFromClass(
                    world,
                    botControllerClass,
                    nil,1, nil
                )

    local playerState = static:BeginDeferredActorSpawnFromClass(
        world,
        playerStateClass,
        nil ,1, bot
    )

    static:FinishSpawningActor(pawn, nil)
    static:FinishSpawningActor(bot, pawn:GetTransform())
    static:FinishSpawningActor(playerState, pawn:GetTransform())

    pawn:K2_TeleportTo({
        ["X"] = 338062.06,
        ["Y"] = 170761.37,
        ["Z"] = 2200.10
        },
        {
            ["Pitch"] = 0.0,
            ["Yaw"] = 0.0,
            ["Roll"] = 0.0
        }
    )

    print("pawn: x=" .. tostring(pawn:GetTransform().Translation.X) .. ", y=" .. tostring(pawn:GetTransform().Translation.Y) .. ", z=" .. tostring(pawn:GetTransform().Translation.Z))
end

--- Get all player pawn instance
--- @return table<ATslCharacter> | nil
function GetAllPlayerPawns()
    local playerPawns = {}
    if (GameState ~= nil) then
        GameState.PlayerArray:ForEach(function(index, param)
            local playerPawn = param:get().Owner.Pawn
            playerPawns[index] = playerPawn
            end)
        return playerPawns
    else
        print("GameState is nil")
        return nil
    end
end

--- Get all player controller instance
--- @return table<ATslPlayerController> | nil
function GetAllPlayerControllers()
    local playerPawns = {}
    if (GameState ~= nil) then
        GameState.PlayerArray:ForEach(function(index, param)
            local playerPawn = param:get().Owner
            playerPawns[index] = playerPawn
            end)
        return playerPawns
    else
        print("GameState is nil")
        return nil
    end
end

--- Get all player state instance
--- @return table<ATslPlayerState> | nil
function GetAllPlayerStates()
    local playerPawns = {}
    if (GameState ~= nil) then
        GameState.PlayerArray:ForEach(function(index, param)
            local playerPawn = param:get()
            playerPawns[index] = playerPawn
            end)
        return playerPawns
    else
        print("GameState is nil")
        return nil
    end
end

function TeleportPlayersToStartPoint()
    local pawns = GetAllPlayerPawns()
    if (pawns ~= nil) then
        print("Teleporting players to start point")
        for i = 1, #pawns do
            local pawn = pawns[i]
            print("Teleporting player " .. pawn:GetFullName())
            pawn:K2_TeleportTo({
                ["X"] = 338062.06,
                ["Y"] = 170761.37,
                ["Z"] = 2200.10
                },
                {
                    ["Pitch"] = 0.0,
                    ["Yaw"] = 0.0,
                    ["Roll"] = 0.0
                })
        end
    end
end

function Hook_K2_OnRestartPlayer(object, func, param)
    local player = param:get()
    print("K2_OnRestartPlayer::before" .. player:K2_GetPawn():GetFName():ToString())
    -- player:K2_GetPawn():K2_TeleportTo({
    --     ["X"] = 338062.06,
    --     ["Y"] = 170761.37,
    --     ["Z"] = 2200.10
    --     },
    --     {
    --         ["Pitch"] = 0.0,
    --         ["Yaw"] = 0.0,
    --         ["Roll"] = 0.0
    --     })
    -- local teamClass = StaticFindObject("/Script/TslGame.Team")
    -- print("TeamClass is " .. teamClass:GetFullName())
    -- local team = StaticConstructObject(teamClass:GetClass(), player:K2_GetPawn().Team)
    -- if (team ~= nil) then
    --     print("Team is not nil, team = " .. team:GetFullName() .. " player = " .. tostring(player:K2_GetPawn().Team))
    -- end
    -- player:K2_GetPawn().Team = {
    --     ["PlayerLocation"] = {
    --         ["X"] = 0.0,
    --         ["Y"] = 0.0,
    --         ["Z"] = 0.0
    --     },
    --     ["PlayerRotation"] = {
    --         ["Yaw"] = 0.0,
    --         ["Pitch"] = 0.0,
    --         ["Roll"] = 0.0
    --     },
    --     ["PlayerName"] = "Player",
    --     ["Health"] = 100,
    --     ["HealthMax"] = 100,
    --     ["GroggyHealth"] = 100,
    --     ["GroggyHealthMax"] = 100,
    --     ["MapMarkerPosition"] = {
    --         ["X"] = 0.0,
    --         ["Y"] = 0.0
    --     },
    --     ["bIsDying"] = false,
    --     ["bIsGroggying"] = false,
    --     ["bQuitter"] = false,
    --     ["bShowMapMarker"] = false,
    --     ["TeamVehicleType"] = 0,
    --     ["BoostGauge"] = 0,
    --     ["MemberNumber"] = 1,
    --     ["TslCharacter"] = player:K2_GetPawn(),
    --     ["UniqueId"] = "114514"
    -- }
end

function Hook_K2_OnSetMatchState(object, func, param)
    local state = param:get():ToString()
    print("K2_OnSetMatchState::before, state=" .. state)

    if state == "InProgress" then
        print("Game is in progress, we can start our stuff")
        
        -- TeleportPlayersToStartPoint()
    end

    if state == "WaitingPostMatch" then
        print("Game Ended.Do Restarting...")
        if (GameMode ~= nil) then
            -- GameMode:RestartGame()
        end
    end

end

Init()





