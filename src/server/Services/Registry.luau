-- Holds every service so they can call each other without require loops.
-- Main.server.luau fills this in; services read from it at runtime
-- (e.g. Registry.EggService.DropAll(player)), never at load time.

return {} :: { [string]: any }
