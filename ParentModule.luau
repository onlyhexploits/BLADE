local UiParentResolver = {}
local coreGui = game:GetService("CoreGui")
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local CANDIDATES = {
	function() return gethui and gethui() end,
	function()
		local localPlayer = playersService.LocalPlayer
		return localPlayer and localPlayer:FindFirstChild("PlayerGui")
	end,
	function() return coreGui end,
	function()
		local playerGui = playersService.LocalPlayer and playersService.LocalPlayer:FindFirstChild("PlayerGui")
		return playerGui and playerGui:FindFirstChild("RobloxGui")
	end,
	function() return replicatedStorage end,
}
local function isWritable(container)
	return pcall(function()
		local probe = Instance.new("Folder")
		probe.Name = "__byteProbe"
		probe.Parent = container
		probe:Destroy()
	end)
end
function UiParentResolver.resolve()
	for _, getter in ipairs(CANDIDATES) do
		local ok, container = pcall(getter)
		if ok and container and isWritable(container) then
			return container, getter
		end
	end
	return nil, nil
end
function UiParentResolver.attach(gui)
	if not gui or not gui:IsA("ScreenGui") then
		return false, "expected a ScreenGui"
	end
	local parent, err = UiParentResolver.resolve()
	if not parent then return false, err or "no writable parent found" end
	local ok, result = pcall(function()
		gui.Parent = parent
	end)
	if not ok then return false, tostring(result) end
	gui:GetPropertyChangedSignal("Parent"):Connect(function()
		if not gui.Parent then
			local newParent = UiParentResolver.resolve()
			if newParent then gui.Parent = newParent end
		end
	end)
	return true
end
return UiParentResolver
