package.loaded["launcher.config"] = nil
require("launcher.config")
require("lfs")

Launcher = {}
Launcher.debug = 1 --debug更新模式（仅在windows下有效）
Launcher.ignoreUpdate = 1 --是否可忽略更新 1表示可忽略

Launcher.fListName = "flist"
Launcher.fVersionName = "version"
Launcher.libDir = "code/"
Launcher.lcherZipName = "launcher.zip"
Launcher.updateFilePostfix = ".upd"

Launcher.ResolutionPolicy = {
    EXACT_FIT = 0,
    NO_BORDER = 1,
    SHOW_ALL  = 2,
    FIXED_HEIGHT  = 3,
    FIXED_WIDTH  = 4,
    FILL_ALL = 5,
    UNKNOWN  = 6,
}

Launcher.PLATFORM_OS_WINDOWS = 0
Launcher.PLATFORM_OS_LINUX   = 1
Launcher.PLATFORM_OS_MAC     = 2
Launcher.PLATFORM_OS_ANDROID = 3
Launcher.PLATFORM_OS_IPHONE  = 4
Launcher.PLATFORM_OS_IPAD    = 5
Launcher.PLATFORM_OS_BLACKBERRY = 6
Launcher.PLATFORM_OS_NACL    = 7
Launcher.PLATFORM_OS_EMSCRIPTEN = 8
Launcher.PLATFORM_OS_TIZEN   = 9
Launcher.PLATFORM_OS_WINRT   = 10
Launcher.PLATFORM_OS_WP8     = 11

Launcher.PROGRESS_TIMER_BAR = 1
Launcher.PROGRESS_TIMER_RADIAL = 0

local sharedApplication = cc.Application:getInstance()
local sharedDirector = cc.Director:getInstance()
local target = sharedApplication:getTargetPlatform()
Launcher.platform    = "unknown"
Launcher.model       = "unknown"

if target == Launcher.PLATFORM_OS_WINDOWS then
    Launcher.platform = "windows"
elseif target == Launcher.PLATFORM_OS_MAC then
    Launcher.platform = "mac"
elseif target == Launcher.PLATFORM_OS_ANDROID then
    Launcher.platform = "android"
elseif target == Launcher.PLATFORM_OS_IPHONE or target == Launcher.PLATFORM_OS_IPAD then
    Launcher.platform = "ios"
    if target == Launcher.PLATFORM_OS_IPHONE then
        Launcher.model = "iphone"
    else
        Launcher.model = "ipad"
    end
elseif target == Launcher.PLATFORM_OS_WINRT then
    Launcher.platform = "winrt"
elseif target == Launcher.PLATFORM_OS_WP8 then
    Launcher.platform = "wp8"
end

-- 资源服务器url
if Launcher.platform == "ios" then
    Launcher.server = "http://down.efgame.cn:80/game/richman/iosudp/"
else
    Launcher.server = "http://down.efgame.cn:80/game/richman/udp/"
end


local winSize = sharedDirector:getWinSize()
Launcher.size = {width = winSize.width, height = winSize.height}
Launcher.width              = Launcher.size.width
Launcher.height             = Launcher.size.height
Launcher.cx                 = Launcher.width / 2
Launcher.cy                 = Launcher.height / 2

Launcher.writablePath = cc.FileUtils:getInstance():getWritablePath()

if Launcher.platform == "android" then
    --TODO:这里需要修改成自己项目中java文件，这个文件实现lua调用java的方法
	Launcher.javaClassName = "org/cocos2dx/lua/AppActivity"
	Launcher.luaj = {}
	function Launcher.luaj.callStaticMethod(className, methodName, args, sig)
        return LuaJavaBridge.callStaticMethod(className, methodName, args, sig)
    end


    local json = {}
    local cjson
    local function safeLoad()
        cjson = require("cjson")
    end

    if not pcall(safeLoad) then 
        cjson = nil
    end

    function Launcher.encode(var)
        local status, result = pcall(cjson.encode, var)
        if status then return result end
    end

    function Launcher.decode(text)
        local status, result = pcall(cjson.decode, text)
        if status then return result end
    end

    if cjson then
        json.null = cjson.null
    else
        json = nil
    end

    Launcher.json = json
    Launcher.cjson = cjson

elseif Launcher.platform == "ios" then
    --TODO:这里LuaObjcFun 是.mm 文件，实现lua调用oc方法
	Launcher.ocClassName = "LuaObjcFun"
	Launcher.luaoc = {}
	function Launcher.luaoc.callStaticMethod(className, methodName, args)
	    local ok, ret = LuaObjcBridge.callStaticMethod(className, methodName, args)
	    if not ok then
	        local msg = string.format("luaoc.callStaticMethod(\"%s\", \"%s\", \"%s\") - error: [%s] ",
	                className, methodName, tostring(args), tostring(ret))
	        if ret == -1 then
	            print(msg .. "INVALID PARAMETERS")
	        elseif ret == -2 then
	            print(msg .. "CLASS NOT FOUND")
	        elseif ret == -3 then
	            print(msg .. "METHOD NOT FOUND")
	        elseif ret == -4 then
	            print(msg .. "EXCEPTION OCCURRED")
	        elseif ret == -5 then
	            print(msg .. "INVALID METHOD SIGNATURE")
	        else
	            print(msg .. "UNKNOWN")
	        end
	    end
	    return ok, ret
	end
end


--是否需要更新
Launcher.needUpdate = true

--请求类型
Launcher.RequestType = { 
    LAUNCHER = 0, --更新模块
    FLIST = 1, --文件列表
    RES = 2, --资源
    VERSION = 3, --版本信息
}
--更新结果
Launcher.UpdateRetType = { 
    SUCCESSED                    = 0, 
    INIT_NETWORD_ERROR           = 1,
    NETWORK_ERROR                = 2, --网络错误
    MD5_ERROR                    = 3, --md5错误
    OTHER_ERROR                  = 4, --未知错误
    FLIST_DOWNLOAD_ERROR         = 5, --flist下载错误
    FLIST_REFRESH_ERROR          = 6, --flist文件更新错误
    VERSION_DOWNLOAD_ERROR       = 7, --版本文件下载错误
    VERSION_COMPARE_ERROR        = 8, --版本文件比较错误
    VERSION_REFRESH_ERROR        = 9, --版本文件更新错误
    FLIST_FILE_NOT_EXIST_ERROR   = 10,
    VERSION_FILE_NOT_EXIST_ERROR = 11,
    LAUNCHER_UPDATE_ERROR        = 12,
}

function lcher_handler(obj, method)
    return function(...)
        return method(obj, ...)
    end
end

function lcher_class(classname, super)
    local superType = type(super)
    local cls

    if superType ~= "function" and superType ~= "table" then
        superType = nil
        super = nil
    end

    if superType == "function" or (super and super.__ctype == 1) then
        -- inherited from native C++ Object
        cls = {}

        if superType == "table" then
            -- copy fields from super
            for k,v in pairs(super) do cls[k] = v end
            cls.__create = super.__create
            cls.super    = super
        else
            cls.__create = super
            cls.ctor = function() end
        end

        cls.__cname = classname
        cls.__ctype = 1

        function cls.new(...)
            local instance = cls.__create(...)
            -- copy fields from class to native object
            for k,v in pairs(cls) do instance[k] = v end
            instance.class = cls
            instance:ctor(...)
            return instance
        end

    else
        -- inherited from Lua Object
        if super then
            cls = {}
            setmetatable(cls, {__index = super})
            cls.super = super
        else
            cls = {ctor = function() end}
        end

        cls.__cname = classname
        cls.__ctype = 2 -- lua
        cls.__index = cls

        function cls.new(...)
            local instance = setmetatable({}, cls)
            instance.class = cls
            instance:ctor(...)
            return instance
        end
    end

    return cls
end

function Launcher.hex(s)
    s = string.gsub(s,"(.)",function (x) return string.format("%02X",string.byte(x)) end)
    return s
end

function Launcher.fileExists(path)
    return cc.FileUtils:getInstance():isFileExist(path)
end

function Launcher.readFile(path)
    return cc.FileUtils:getInstance():getDataFromFile(path)
end

function Launcher.writefile(path, content, mode)
    mode = mode or "w+b"
    local file = io.open(path, mode)
    if file then
        if file:write(content) == nil then return false end
        io.close(file)
        return true
    else
        return false
    end
end

function Launcher.split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter=='') then return false end
    local pos,arr = 0, {}
    -- for each divider found
    for st,sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end

function Launcher.ltrim(input)
    return string.gsub(input, "^[ \t\n\r]+", "")
end

function Launcher.rtrim(input)
    return string.gsub(input, "[ \t\n\r]+$", "")
end

function Launcher.trim(input)
    input = string.gsub(input, "^[ \t\n\r]+", "")
    return string.gsub(input, "[ \t\n\r]+$", "")
end


function Launcher.dump(value, desciption, nesting)
    if type(nesting) ~= "number" then nesting = 3 end

    local lookupTable = {}
    local result = {}

    local function _v(v)
        if type(v) == "string" then
            v = "\"" .. v .. "\""
        end
        return tostring(v)
    end

    local traceback = Launcher.split(debug.traceback("", 2), "\n")
    print("dump from: " .. Launcher.trim(traceback[3]))

    local function _dump(value, desciption, indent, nest, keylen)
        desciption = desciption or "<var>"
        spc = ""
        if type(keylen) == "number" then
            spc = string.rep(" ", keylen - string.len(_v(desciption)))
        end
        if type(value) ~= "table" then
            result[#result +1 ] = string.format("%s%s%s = %s", indent, _v(desciption), spc, _v(value))
        elseif lookupTable[value] then
            result[#result +1 ] = string.format("%s%s%s = *REF*", indent, desciption, spc)
        else
            lookupTable[value] = true
            if nest > nesting then
                result[#result +1 ] = string.format("%s%s = *MAX NESTING*", indent, desciption)
            else
                result[#result +1 ] = string.format("%s%s = {", indent, _v(desciption))
                local indent2 = indent.."    "
                local keys = {}
                local keylen = 0
                local values = {}
                for k, v in pairs(value) do
                    keys[#keys + 1] = k
                    local vk = _v(k)
                    local vkl = string.len(vk)
                    if vkl > keylen then keylen = vkl end
                    values[k] = v
                end
                table.sort(keys, function(a, b)
                    if type(a) == "number" and type(b) == "number" then
                        return a < b
                    else
                        return tostring(a) < tostring(b)
                    end
                end)
                for i, k in ipairs(keys) do
                    _dump(values[k], k, indent2, nest + 1, keylen)
                end
                result[#result +1] = string.format("%s}", indent)
            end
        end
    end
    _dump(value, desciption, "- ", 1)

    for i, line in ipairs(result) do
        print(line)
    end
end

function Launcher.removePath(path)
    local mode = lfs.attributes(path, "mode")
    if mode == "directory" then
        local dirPath = path.."/"
        for file in lfs.dir(dirPath) do
            if file ~= "." and file ~= ".." then 
                local f = dirPath..file 
                Launcher.removePath(f)
            end 
        end
        os.remove(path)
    else
        os.remove(path)
    end
end

function Launcher.mkDir(path)
    if not Launcher.fileExists(path) then
        return lfs.mkdir(path)
    end
    return true
end

function Launcher.doFile(path)
    local fileData = cc.HelperFunc:getFileData(path)
    local fun = loadstring(fileData)
    local ret, flist = pcall(fun)
    if ret then
        return flist
    end
    return flist
end

function Launcher.fileDataMd5(fileData)
	if fileData ~= nil then
		return cc.Crypto:MD5(Launcher.hex(fileData), false)
	else
		return nil
	end
end

function Launcher.fileMd5(filePath)
	local data = Launcher.readFile(filePath)
	return Launcher.fileDataMd5(data)
end

function Launcher.checkFileDataWithMd5(data, cryptoCode)
	if cryptoCode == nil then
        return true
    end

    local fMd5 = cc.Crypto:MD5(Launcher.hex(data), false)
    if fMd5 == cryptoCode then
        return true
    end

    return false
end

function Launcher.checkFileWithMd5(filePath, cryptoCode)
	if not Launcher.fileExists(filePath) then
        return false
    end

    local data = Launcher.readFile(filePath)
    if data == nil then
        return false
    end

    return Launcher.checkFileDataWithMd5(data, cryptoCode)
end

--获取app编译版本号
function Launcher.getAppVersionCode()
    local appVersion = nil
    if Launcher.platform == "android" then
        local javaMethodName = "getVersion"
        local javaParams = { }
        local javaMethodSig = "()Ljava/lang/String;"
        local ok, version = Launcher.luaj.callStaticMethod(Launcher.javaClassName, javaMethodName, javaParams, javaMethodSig)
        if ok then
            if string.len(version)>0 then
                local splitArr = Launcher.split(version, "|")
                if splitArr and #splitArr > 0 then
                    versionStr = splitArr[2]
                    if versionStr then
                        appVersion = tonumber(versionStr)
                    end
                end
            end

        end
    elseif Launcher.platform == "ios" then
        local ok, ret = Launcher.luaoc.callStaticMethod(Launcher.ocClassName, "getAppVersionCode")
        if ok then
            appVersion = ret
        end
    end
    return appVersion
end


function Launcher.performWithDelayGlobal(listener, time)
	local scheduler = sharedDirector:getScheduler()
    local handle = nil
    handle = scheduler:scheduleScriptFunc(function()
        scheduler:unscheduleScriptEntry(handle)
        listener()
    end, time, false)
end

function Launcher.runWithScene(scene)
	local curScene = sharedDirector:getRunningScene()
	if curScene then
		sharedDirector:replaceScene(scene)
	else
		sharedDirector:runWithScene(scene)
	end
end

function Launcher.map(t, fn)
    for k, v in pairs(t) do
        t[k] = fn(v, k)
    end
end

function Launcher.showAlert(title, message, buttonLabels, listener)
    if type(buttonLabels) ~= "table" then
        buttonLabels = {tostring(buttonLabels)}
    else
        Launcher.map(buttonLabels, function(v) return tostring(v) end)
    end

    if Launcher.platform == "android" then
        local tempListner = function(event)
            if type(event) == "string" then
                event = Launcher.decode(event)
                event.buttonIndex = tonumber(event.buttonIndex)
            end
            if listener then listener(event) end
        end
        Launcher.luaj.callStaticMethod("org/cocos2dx/utils/PSNative", "createAlert", {title, message, buttonLabels, tempListner}, "(Ljava/lang/String;Ljava/lang/String;Ljava/util/Vector;I)V");
    else
        local defaultLabel = ""
        if #buttonLabels > 0 then
            defaultLabel = buttonLabels[1]
            table.remove(buttonLabels, 1)
        end

        cc.Native:createAlert(title, message, defaultLabel)
        for i, label in ipairs(buttonLabels) do
            cc.Native:addAlertButton(label)
        end

        if type(listener) ~= "function" then
            listener = function() end
        end

        cc.Native:showAlert(listener)
    end
end
