local Games = loadstring(game:HttpGet("https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/supportedgames.lua"))()

local URL = Games[game.PlaceId]

if URL then
  loadstring(game:HttpGet("URL"))()

end
