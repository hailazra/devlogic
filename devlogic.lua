local Games = loadstring(game:HttpGet("https://raw.githubusercontent.com/hailazra/devlogic/refs/heads/main/supportedgames.lua"))()

local URLGame = Games[game.PlaceId]

if URLGame then
  loadstring(game:HttpGet(URLGame))()

end
