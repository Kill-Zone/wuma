
WUMA = WUMA or {}
local WUMADebug = WUMADebug
local WUMALog = WUMALog
WUMA.Limits = WUMA.Limits or {}
WUMA.UsergroupLimits = WUMA.UsergroupLimits or {}
 
function WUMA.LoadLimits()
	local saved, tbl = WUMA.GetSavedLimits() or {}, {}

	for _, limit in pairs(saved) do
		local id = limit:GetID()
		local usergroup = limit:GetUserGroup()
		WUMA.Limits[id] = limit

		if not WUMA.UsergroupLimits[usergroup] then WUMA.UsergroupLimits[usergroup] = {} end
		WUMA.UsergroupLimits[usergroup][id] = 1 --Its really the key we are saving
	end
end

function WUMA.GetSavedLimits(user)
	local tbl = {}
	
	if (user) then
		tbl = WUMA.ReadUserLimits(user)
	else
		local saved = util.JSONToTable(WUMA.Files.Read(WUMA.DataDirectory.."limits.txt")) or {}

		for key,obj in pairs(saved) do
			if istable(obj) then
				obj.parent = user
				tbl[key] = Limit:new(obj)
			end
		end
	end
	
	return tbl
end

function WUMA.ReadUserLimits(user)
	if not isstring(user) then user = user:SteamID() end

	local tbl = {}
	
	local saved = util.JSONToTable(WUMA.Files.Read(WUMA.GetUserFile(user,Limit))) or {}
		
	for key,obj in pairs(saved) do
		obj.parent = user
		tbl[key] = Limit:new(obj)
	end 
	
	return tbl
end

function WUMA.GetLimits(user)
	if user and not isstring(user) then
		return user:GetLimits()
	elseif user and isstring(user) then
		return WUMA.Limits[user]
	else
		return WUMA.Limits
	end
end

function WUMA.LimitsExist() 
	if (table.Count(WUMA.Limits) > 0) then return true end
end

function WUMA.HasLimit(usergroup,item)
	if isstring(usergroup) then
		if WUMA.GetSavedLimits()[Limit:GenerateID(usergroup,item)] then return true end
	else
		if WUMA.GetSavedLimits()[usergroup:GetID()] then return true end
	end 
	return false
end

function WUMA.AddLimit(caller,usergroup,item,limit,exclusive,scope)

	if (item == limit) then return false end
	if (tonumber(item) != nil) then return false end

	local limit = Limit:new({string=item,usergroup=usergroup,limit=limit,exclusive=exclusive,scope=scope})

	WUMA.Limits[limit:GetID()] = limit
	
	if not WUMA.UsergroupLimits[usergroup] then WUMA.UsergroupLimits[usergroup] = {} end
	WUMA.UsergroupLimits[usergroup][limit:GetID()] = 1
	
	local affected = WUMA.UpdateUsergroup(usergroup,function(user)
		user:AddLimit(limit:Clone())
	end)
	
	local function recursive(group)
		local heirs = WUMA.GetUsergroupHeirs(Limit:GetID(),group)
		for k, heir in pairs(heirs) do
			if not WUMA.Limits[Limit:GenerateID(heir,item)] then
				WUMA.UpdateUsergroup(heir,function(ply)
					ply:AddLimit(limit)
				end)
				recursive(heir)
			end
		end
	end
	recursive(usergroup)
	
	WUMA.AddClientUpdate(Limit,function(tbl)
		tbl[limit:GetID()] = limit:GetBarebones()
		
		return tbl
	end)
	
	WUMA.ScheduleDataUpdate(Limit:GetID(), function(tbl)
		tbl[limit:GetID()] = limit:GetBarebones()
		
		return tbl
	end)

	WUMA.InvalidateCache(Limit:GetID())

	return affected

end

function WUMA.RemoveLimit(caller,usergroup,item)
	local id = Limit:GenerateID(usergroup,item)
	
	if not WUMA.Limits[id] then return false end
	
	WUMA.Limits[id] = nil
		
	if WUMA.UsergroupLimits[usergroup] then
		WUMA.UsergroupLimits[usergroup][id] = nil
		if (table.Count(WUMA.UsergroupLimits[usergroup]) < 1) then WUMA.UsergroupLimits[usergroup] = nil end
	end

	local limit
	local ancestor = WUMA.GetUsergroupAncestor(Limit:GetID(), usergroup)
	while ancestor do
		limit = WUMA.Limits[Limit:GenerateID(ancestor,item)]
		if limit then
			break
		end
		ancestor = WUMA.GetUsergroupAncestor(Limit:GetID(), ancestor)
	end
	
	local affected = WUMA.UpdateUsergroup(usergroup,function(ply)
		ply:RemoveLimit(Limit:GenerateID(nil,item))
		if limit then ply:AddLimit(limit) end
	end)
	
	local function recursive(group)
		local heirs = WUMA.GetUsergroupHeirs(Limit:GetID(),group)
		for _, heir in pairs(heirs) do
			if not WUMA.Restrictions[Limit:GenerateID(heir,item)] then
				WUMA.UpdateUsergroup(heir,function(ply)
					ply:RemoveLimit(Limit:GenerateID(nil,item))
					if limit then
						ply:AddLimit(limit)
					end
				end)
				recursive(heir)
			end
		end
	end
	recursive(usergroup)

	WUMA.AddClientUpdate(Limit,function(tbl)
		tbl[id] = WUMA.DELETE
		
		return tbl
	end)
	
	WUMA.ScheduleDataUpdate(Limit:GetID(), function(tbl)
		tbl[id] = nil
		
		return tbl
	end)
	
	WUMA.InvalidateCache(Limit:GetID())

	return affected

end

function WUMA.AddUserLimit(caller,user,item,limit,exclusive,scope)

	if (item == limit) then return false end
	if (tonumber(item) != nil) then return false end
	
	local limit = Limit:new({string=item,limit=limit,exclusive=exclusive,scope=scope})

	if isentity(user) then
		user:AddLimit(limit)
		
		user = user:SteamID()
	end
	
	WUMA.AddClientUpdate(Limit,function(tbl)
		tbl[limit:GetID()] = limit:GetBarebones()
		
		return tbl
	end,user)
	
	WUMA.ScheduleUserDataUpdate(user,Limit:GetID(), function(tbl)
		tbl[limit:GetID()] = limit:GetBarebones()
		
		return tbl
	end)
	
end

function WUMA.RemoveUserLimit(caller,user,item)
	local id = Limit:GenerateID(_,item)
	
	if isstring(user) and WUMA.GetUsers()[user] then user = WUMA.GetUsers()[user] end
	if isentity(user) then
		user:RemoveLimit(id, true)
		
		user = user:SteamID()
	end
	
	WUMA.AddClientUpdate(Limit,function(tbl)
		tbl[id] = WUMA.DELETE
		
		return tbl
	end,user)
		
	WUMA.ScheduleUserDataUpdate(user,Limit:GetID(), function(tbl)
		tbl[id] = nil
			
		return tbl
	end)
end

function WUMA.RefreshGroupLimits(user, usergroup)
	user:CacheLimits()
	user:SetLimits({})
	
	WUMA.AssignLimits(user, usergroup)
end

WUMA.RegisterDataID(Limit:GetID(), "limits.txt", WUMA.GetSavedLimits, WUMA.isTableEmpty)
WUMA.RegisterUserDataID(Limit:GetID(), "limits.txt", WUMA.GetSavedLimits, WUMA.isTableEmpty)
 