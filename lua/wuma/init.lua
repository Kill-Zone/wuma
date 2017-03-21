
WUMA = WUMA or {}

WUMA.ConVars = WUMA.ConVars or {}
WUMA.ConVars.CVars = WUMA.ConVars.CVars or {}
WUMA.ConVars.ToClient = WUMA.ConVars.ToClient or {}

WUMA.VERSION = "1.0 Beta"
WUMA.AUTHOR = "Erik 'Weol' Rahka"
 
--Enums
WUMA.DELETE = "WUMA_delete"
WUMA.EMPTY = "WUMA_empty" 

--Paths
WUMA.DataDirectory = "WUMA/"
WUMA.SharedDirectroy = "WUMA/shared/"
WUMA.ClientDirectory = "WUMA/client/"
WUMA.ObjectsDirectory = "WUMA/objects/"
WUMA.UserDataDirectory = "users/"
WUMA.HomeDirectory = "WUMA/"

WUMA.WUMAGUI = "wuma gui"

function WUMA.Initialize()
   
	Msg("WUMA.Initialize()\n")
 
	include(WUMA.HomeDirectory.."files.lua")
	include(WUMA.HomeDirectory.."log.lua")
	  
	--Initialize data files  
	WUMA.Files.Initialize()

	--Load objects
	WUMA.LoadFolder(WUMA.ObjectsDirectory)
	WUMA.LoadCLFolder(WUMA.ObjectsDirectory)

	--Include core
	include(WUMA.HomeDirectory.."sql.lua")
	include(WUMA.HomeDirectory.."util.lua") 	
	include(WUMA.HomeDirectory.."functions.lua")
	include(WUMA.HomeDirectory.."datahandler.lua")
	include(WUMA.HomeDirectory.."users.lua")
	include(WUMA.HomeDirectory.."limits.lua")
	include(WUMA.HomeDirectory.."restrictions.lua")
	include(WUMA.HomeDirectory.."loadouts.lua")
	include(WUMA.HomeDirectory.."hooks.lua") 
	include(WUMA.HomeDirectory.."duplicator.lua")
	include(WUMA.HomeDirectory.."extentions/playerextention.lua")
	include(WUMA.HomeDirectory.."extentions/entityextention.lua")

	--Register WUMA access with CAMI
	CAMI.RegisterPrivilege{Name=WUMA.WUMAGUI,MinAccess="superadmin",Description="Access to WUMA GUI"}
	   
	--Who am I writing these for?
	WUMALog("Weol's User Management Addon version %s",WUMA.VERSION)
	
	--Initialize database
	WUMA.SQL.Initialize()
	
	--Load data 
	WUMA.LoadRestrictions()
	WUMA.LoadLimits()
	WUMA.LoadLoadouts()
	
	--Load shared files
	WUMALog("Loading shared files")
	WUMA.LoadCLFolder(WUMA.SharedDirectroy)
	WUMA.LoadFolder(WUMA.SharedDirectroy) 
	
	--Load client files
	WUMALog("Loading client files")
	WUMA.LoadCLFolder(WUMA.ClientDirectory)
	
	--Allow the poor scopes to think
	Scope:StartThink()
	
	//Add hook so playerextention loads when the first player joins
	hook.Add("PlayerAuthed", "WUMAPlayerAuthedPlayerExtentionInit", function()  
		include(WUMA.HomeDirectory.."extentions/playerextention.lua")
		hook.Remove("WUMAPlayerAuthedPlayerExtentionInit")
	end)
	
	--All overides should be loaded after WUMA
	hook.Call("PostWUMALoad")
	
end

function WUMA.CreateConVar(...)
	local convar = CreateConVar(...)
	WUMA.ConVars.CVars[convar:GetName()] = convar
	WUMA.ConVars.ToClient[convar:GetName()] = convar:GetString()
	
	cvars.AddChangeCallback(convar:GetName(), function(convar,old,new) 
		WUMA.ConVars.ToClient[convar] = new
	
		local tbl = {}
		tbl[convar] = new
		WUMA.GetAuthorizedUsers(function(users) 
			WUMA.SendInformation(users,WUMA.NET.SETTINGS,tbl) 
		end)
	end)
	
	return convar
end

function WUMA.GetTime()
	return os.time()
end

function WUMA.LoadFolder(dir)
	local files, directories = file.Find(dir.."*", "LUA")
	
	for _,file in pairs(files) do
		WUMADebug(" %s",file)
	
		include(dir..file)
	end
	
	for _,directory in pairs(directories) do
		WUMA.LoadFolder(dir..directory.."/") 
	end
end

function WUMA.LoadCLFolder(dir)
	local files, directories = file.Find(dir.."*", "LUA")
	
	for _,file in pairs(files) do	
		WUMADebug(" %s",dir..file)
		
		AddCSLuaFile(dir..file) 
	end
	
	for _,directory in pairs(directories) do
		WUMA.LoadCLFolder(dir..directory.."/")
	end
end
WUMA.Initialize()
