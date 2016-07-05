module("L_RestHandler", package.seeall)

RESTHANDLE_SERVICE = "urn:demo-micasaverde-com:serviceId:HandleRest1"
TYPE_GET = "GET"
TYPE_POST = "POST"
local DEVICE_ID
local PARENT_DEVICE
local DEVICE_TYPE = "urn:demo-micasaverde-com:device:RestHandler:1"
local MSG_CLASS = "RestHandler"

local DEBUG_MODE = false
local taskHandle = -1

local TASK_ERROR = 2
local TASK_ERROR_PERM = -2
local TASK_SUCCESS = 4
local TASK_BUSY = 1

local function log(text, level)
	luup.log(string.format("%s: %s", MSG_CLASS, text), (level or 50))
end

local function debug(text)
	if (DEBUG_MODE) then
		log("debug: " .. text)
	end
end

local function task(text, mode)
	luup.log("task " .. text)
	if (mode == TASK_ERROR_PERM) then
		taskHandle = luup.task(text, TASK_ERROR, MSG_CLASS, taskHandle)
	else
		taskHandle = luup.task(text, mode, MSG_CLASS, taskHandle)

		-- Clear the previous error, since they're all transient
		if (mode ~= TASK_SUCCESS) then
			luup.call_delay("clearTask", 30, "", false)
		end
	end
end

--
-- Has to be "non-local" in order for MiOS to call it
--
function clearTask()
	task("Clearing...", TASK_SUCCESS)
end


-- function is called after startup to check input data
function startupDeferred()
	-- check url
	local empty = luup.variable_get(RESTHANDLE_SERVICE, "restUrl", PARENT_DEVICE)
	if (empty == nil or empty == "" ) then
		--
		-- Set the variable so that it appears in the Device/Advanced list
		--
		luup.variable_set(RESTHANDLE_SERVICE, "restUrl", "http://192.168.1.16:3500/inputs", PARENT_DEVICE)
		local msg = "Check REST URL."
		task(msg, TASK_ERROR_PERM)
		return
	end	
	-- check samplePeriod
	empty = luup.variable_get(RESTHANDLE_SERVICE, "samplePeriod", PARENT_DEVICE)
	if (empty == nil or empty == "" ) then
		--
		-- Set the variable so that it appears in the Device/Advanced list
		--
		luup.variable_set(RESTHANDLE_SERVICE, "samplePeriod", "", PARENT_DEVICE)
		local msg = "Set the samplePeriod, how often check resource"
		task(msg, TASK_ERROR_PERM)
		return
	end	
end

-- this runs when the first time device is created
function initialize(parentDevice)
    PARENT_DEVICE = parentDevice

	log("#" .. tostring(parentDevice) .. " starting up with id " .. luup.devices[parentDevice].id)

	--
	-- Set variables for  override, only "set" these if they aren't already set
	-- to force these Variables to appear in Vera's Device list.
	--
	if (luup.variable_get(RESTHANDLE_SERVICE, "bypass", parentDevice) == nil) then
		luup.variable_set(RESTHANDLE_SERVICE, "bypass", "1", parentDevice)
	end
	if (luup.variable_get(RESTHANDLE_SERVICE, "samplePeriod", parentDevice) == nil) then
		luup.variable_set(RESTHANDLE_SERVICE, "samplePeriod", "", parentDevice)
	end			
	if (luup.variable_get(RESTHANDLE_SERVICE, "outputObjectName", parentDevice) == nil) then
		luup.variable_set(RESTHANDLE_SERVICE, "outputObjectName", "", parentDevice)
	end		
	if (luup.variable_get(RESTHANDLE_SERVICE, "outputObjectValue", parentDevice) == nil) then
		luup.variable_set(RESTHANDLE_SERVICE, "outputObjectValue", "", parentDevice)
	end	
	if (luup.variable_get(RESTHANDLE_SERVICE, "inputObjectName", parentDevice) == nil) then
		luup.variable_set(RESTHANDLE_SERVICE, "inputObjectName", "", parentDevice)
	end		
	if (luup.variable_get(RESTHANDLE_SERVICE, "inputObjectType", parentDevice) == nil) then
		luup.variable_set(RESTHANDLE_SERVICE, "inputObjectType", "", parentDevice)
	end		
	
	--
	-- Do this deferred to avoid slowing down startup processes.
	--
	startupDeferred()
end

function doRead()
    local samplePeriod = luup.variable_get(RESTHANDLE_SERVICE, "samplePeriod", PARENT_DEVICE) 
	local param = luup.variable_get(RESTHANDLE_SERVICE, "inputObjectName", PARENT_DEVICE) 
	local ltype = luup.variable_get(RESTHANDLE_SERVICE, "inputObjectType", PARENT_DEVICE) 
	local lobj = luup.variable_get(RESTHANDLE_SERVICE, "outputObjectName", PARENT_DEVICE)
	local yValue = readResource(param, ltype, samplePeriod, lobj)
	if yValue then
		 luup.variable_set(RESTHANDLE_SERVICE, "outputObjectValue", yValue, PARENT_DEVICE)
	end
end

function readResource(xParam, xType, xSamplePeriod, xObject)

    luup.variable_set(RESTHANDLE_SERVICE, "inputObjectName", xParam, PARENT_DEVICE)
	luup.variable_set(RESTHANDLE_SERVICE, "inputObjectType", xType, PARENT_DEVICE)
	luup.variable_set(RESTHANDLE_SERVICE, "samplePeriod", xSamplePeriod, PARENT_DEVICE)
	luup.variable_set(RESTHANDLE_SERVICE, "outputObjectName", xObject, PARENT_DEVICE)
	local bypass = luup.variable_get(RESTHANDLE_SERVICE, "bypass", PARENT_DEVICE)
	local samplePeriod = xSamplePeriod
	local lobject = xObject 
	local yValue = ""
	if bypass~="1" then
		local url = luup.variable_get(RESTHANDLE_SERVICE, "restUrl", PARENT_DEVICE)
		local path = url 
		local payload = ""
        if xType == TYPE_GET then
		    path = path .. "/" .. xParam
		elseif xType == TYPE_POST then
			payload = xParam
	    end 
		local code, resp = sendJsonRequest(path, payload, xType)
		local jsonObj=parseJson(resp)
	    debug("code: " .. tostring(code))
  	    debug("response: " .. resp)
 
		if code~=200 then
			local msg = "Failed to handle resource"
			task(msg, TASK_ERROR_PERM)		
		else
			local lvalue = jsonObj
			for i in string.gmatch(lobject, "[^%.]+") do
				lvalue=lvalue[i]
			end
			yValue = lvalue
		end
		if tonumber(samplePeriod) > 0 then
			debug("timer for nextRead set in " .. tostring(samplePeriod) .. " sec.")
			luup.call_timer("nextRead", 1, tostring(samplePeriod), "")			
		end
	end
	return yValue;
end


function parseJson(xString)
  JSON = (loadfile "/usr/lib/lua/JSON.lua")()   
  local object = JSON:decode(xString)
  return object
 end

function sendJsonRequest(xUrl,xPayload,xMethod)
  --local path = "http://192.168.1.16:3500/inputs"
  local path = xUrl
  package.loaded.http = nil
  local http = require("socket.http")
  package.loaded.ltn12 = nil
  local ltn12 = require("ltn12")
  --local payload = [[ {"key":"My Key","name":"My Name","description":"The description","state":1} ]]
  local payload = xPayload
 
  local response_body = { }
  local res, code, response_headers, status = http.request
  {
    url = path,
    method = xMethod,
    headers =
    {
      --["Authorization"] = "Maybe you need an Authorization header?", 
      ["Content-Type"] = "application/json",
      ["Content-Length"] = payload:len()
    },
    source = ltn12.source.string(payload),
    sink = ltn12.sink.table(response_body)
  }
  package.loaded.http = nil
  package.loaded.ltn12 = nil
  collectgarbage("collect")
  return code, table.concat(response_body)
end

function createDate(xDateTime)
	local t = xDateTime
	return t.year .. string.format( "%02d", t.month ) ..string.format( "%02d", t.day )  .. string.format( "%02d", t.hour )  .. string.format( "%02d", t.min )  .. string.format( "%02d", t.sec ) 
end

function test()
	local path = "http://192.168.1.16:3500/inputs" 
	local payload = ""
	xType = "GET"
	xParam = "ADC01"
	lobject = "obj.test" --value
	if xType == "GET" then
		path = path .. "/" .. xParam
	elseif xType == TYPE_POST then
		payload = xParam
	end 
	local code, resp = sendJsonRequest(path, payload, xType)
	local jsonObj=parseJson(resp)
	luup.log("code: " .. tostring(code))
	luup.log("response: " .. resp)

	if code~=200 then
		local msg = "Failed to handle resource"
		task(msg, TASK_ERROR_PERM)		
	else
		local lvalue = jsonObj
		for i in string.gmatch(lobject, "[^%.]+") do
			lvalue=lvalue[i]
		end
		yValue = lvalue
	end
	luup.log("value:")
	luup.log(yValue)
end
--test()
