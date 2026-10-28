--[[
    Passolini HUB -- point d'entree unique
    Genere automatiquement par VoidPusher, ne pas editer a la main.
    Build: 2026-10-28 13:22:22
]]

local UI_URL  = "https://raw.githubusercontent.com/csgo1compte-cloud/RayVoidUi/refs/heads/main/RayVoid"
local DISCORD = "https://discord.gg/Sxar4zKdt"
local API     = ""

local MAP = {
	["10629695169"] = {{n="teste",u="https://raw.githubusercontent.com/BadjoClan/Passolini-DIST/main/teste"}},
	["10708913337"] = {{n="Anime-Dice",u="https://raw.githubusercontent.com/BadjoClan/Passolini-DIST/main/Anime-Dice"}},
	["10740316645"] = {{n="My-Anime-Mine",u="https://raw.githubusercontent.com/BadjoClan/Passolini-DIST/main/My-Anime-Mine"}},
}

-- ---------------------------------------------------------------------------

-- On route sur GameId (l'univers), pas sur PlaceId : il est identique dans
-- le lobby et toutes les places d'un meme jeu.
local gameId  = tostring(game.GameId)
local entries = MAP[gameId]

-- Beacon de lancement : envoye pour CHAQUE execution du hub, supporte ou
-- non, AVANT toute decision de routage. C'est ce qui alimente le funnel
-- "lancements -> sessions reelles" et revele les jeux demandes mais pas
-- encore couverts. Fire-and-forget dans un task.spawn : ne bloque jamais
-- le chargement du script, et un echec reseau est sans consequence.
task.spawn(function()
    if API == "" then return end
    local fn = nil
    if syn and syn.request then fn = syn.request
    elseif http and http.request then fn = http.request
    elseif http_request then fn = http_request
    elseif request then fn = request end
    if not fn then return end

    local player = game:GetService("Players").LocalPlayer
    if not player then return end

    local gameName = "Unknown"
    pcall(function()
        gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    end)

    local execName = "Unknown"
    pcall(function() execName = identifyexecutor() or "Unknown" end)

    local body = game:GetService("HttpService"):JSONEncode({
        user_id   = tostring(player.UserId),
        username  = player.Name,
        place_id  = tostring(game.PlaceId),
        game_id   = gameId,
        game_name = gameName,
        executor  = execName,
    })

    pcall(fn, {
        Url = API .. "/loader/launch",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    })
end)

local function copyText(text)
    if setclipboard then
        pcall(setclipboard, text)
    end
end

local function runScript(url)
    local ok, src = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or type(src) ~= "string" or #src < 16 then
        warn("[Passolini HUB] download failed: " .. tostring(url))
        return false
    end
    local fn, err = loadstring(src)
    if not fn then
        warn("[Passolini HUB] compile failed: " .. tostring(err))
        return false
    end
    local ranOk, runErr = pcall(fn)
    if not ranOk then
        warn("[Passolini HUB] runtime error: " .. tostring(runErr))
        return false
    end
    return true
end

-- Chemin rapide : un seul script pour ce jeu, on charge sans passer par l'UI.
if entries and #entries == 1 then
    runScript(entries[1].u)
    return
end

-- A partir d'ici on a besoin de l'interface (selection ou jeu non supporte).
local okUi, Ui = pcall(function()
    return loadstring(game:HttpGet(UI_URL))()
end)
if not okUi or not Ui then
    warn("[Passolini HUB] UI failed to load")
    return
end

Ui:SetScriptName("Passolini HUB")

-- [ Plusieurs scripts pour ce jeu : selection ]
-- ShowCredit() seulement ici : c'est le seul cas ou l'UI sert vraiment a
-- lancer un script. Pas de credit affiche sur un ecran d'erreur qui ne
-- charge rien.
if entries and #entries > 1 then
    Ui:ShowCredit()

    local Window = Ui:CreateWindow({
        Name = "Passolini HUB",
        LoadingTitle = "Passolini HUB",
        LoadingSubtitle = "by Passolini",
        ConfigurationSaving = { Enabled = true, FolderName = "PassoliniHub", FileName = "hub" },
    })

    local Tab = Window:CreateTab("Scripts", "gamepad-2")

    Tab:CreateParagraph({
        Title = "Multiple scripts available",
        Content = tostring(#entries) .. " scripts exist for this game. Pick the one you want to load.",
    })

    for i = 1, #entries do
        local entry = entries[i]
        Tab:CreateButton({
            Name = "Load " .. entry.n,
            Callback = function()
                pcall(function() Ui:Destroy() end)
                task.wait(0.25)
                runScript(entry.u)
            end,
        })
    end

    return
end

-- [ Aucun script pour ce jeu : ecran minimal, redirection Discord uniquement ]
local Window = Ui:CreateWindow({
    Name = "Passolini HUB",
    LoadingTitle = "Passolini HUB",
    LoadingSubtitle = "by Passolini",
    ConfigurationSaving = { Enabled = true, FolderName = "PassoliniHub", FileName = "hub" },
})

local Info = Window:CreateTab("Not Supported", "bug")

Info:CreateParagraph({
    Title = "This script isn't supported",
    Content = "This game isn't supported. Join the Discord to see every available game.",
})

Info:CreateButton({
    Name = "Copy Discord invite",
    Callback = function()
        copyText(DISCORD)
        Ui:Notify({ Title = "Copied", Content = "Discord invite copied to clipboard.", Duration = 4 })
    end,
})
