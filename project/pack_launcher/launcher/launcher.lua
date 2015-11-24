package.loaded["launcher.init"] = nil
require("launcher.init")

local function enter_game(enterGameInfo)
    LAUNCHER_UPDATE_ERROR_COUNT = nil --clear
    print("Update: update complete, enter game")
    --TODO:这里加载游戏包
    cc.LuaLoadChunksFromZIP("code/game.zip")
	require("app.MyApp").new():run(enterGameInfo)
end

local LauncherScene = lcher_class("LauncherScene", function()
	local scene = cc.Scene:create()
	scene.name = "LauncherScene"
    return scene
end)


function LauncherScene:ctor()
	self._path = Launcher.writablePath .. "upd/"
	if Launcher.needUpdate then
		Launcher.performWithDelayGlobal(function()
    		self:checkUpdate_()
    	end, 0.1)
	else
		enter_game()
	end
end

function LauncherScene:delayToReloadMain_()
    print("Update: delay reload main", self.ignoreAllMsg)
    if self.ignoreAllMsg == 1 then
        return
    end

    self.ignoreAllMsg = 1

    Launcher.performWithDelayGlobal(function ()
        print("Update: require main")
        package.loaded["main"] = nil
        require("main")
    end, 0.5)
end

function LauncherScene:getPlatformKey_()
    if Launcher.debug == 1 and Launcher.platform == "windows" then --debug
        return "android"
    end
    return Launcher.platform
end

function LauncherScene:checkUpdate_()
    print("Update: update server:"..Launcher.server)
	Launcher.mkDir(self._path) --创建update文件夹

	self._curListFile =  self._path .. Launcher.fListName
    self._curVersionFile = self._path .. Launcher.fVersionName

    if Launcher.fileExists(self._curVersionFile) then
        self._versionDic = Launcher.doFile(self._curVersionFile)
    end  

	if Launcher.fileExists(self._curListFile) then
        self._fileList = Launcher.doFile(self._curListFile)
    end

    if self._versionDic ~= nil then
        local appVersionCode = Launcher.getAppVersionCode() 
        local appVersionKey = self:getPlatformKey_().."AppVersion"
        local lastUpdateVersionCode = self._versionDic[appVersionKey]
        print("Update: version code", appVersionCode, lastUpdateVersionCode)
        if appVersionCode and lastUpdateVersionCode then
            lastUpdateVersionCode = tonumber(lastUpdateVersionCode)
            if appVersionCode < lastUpdateVersionCode then

                local function keepAlertFunc_()
                    local errorStr
                    if Launcher.platform == "ios" then
                        errorStr = "当前版本过旧，请到AppStore更新版本！错误号："..lastUpdateVersionCode

                    elseif Launcher.platform == "android" then
                        errorStr = "当前版本过旧，请到应用市场更新版本！错误号："..lastUpdateVersionCode

                    else
                        errorStr = "当前版本过旧！错误号："..lastUpdateVersionCode
                    end

                    Launcher.showAlert("警告", errorStr, {"确定"}, function (event)
                        keepAlertFunc_()            
                    end)
                end

                keepAlertFunc_()
                return
            elseif appVersionCode > lastUpdateVersionCode then --控制app打包的版本是否删除旧资源
                print("Update: remove old update file",appVersionCode,lastUpdateVersionCode)
                --新的app已经更新需要删除upd/目录下的所有文件
                Launcher.removePath(self._path)
                -- require("main")
                self:delayToReloadMain_()
                return
            end
        end

    else
        self._versionDic = Launcher.doFile(Launcher.fVersionName)
    	self._fileList = Launcher.doFile(Launcher.fListName)
    end

    self._textLabel = cc.Label:createWithTTF(STR_LCHER_HAS_UPDATE, LCHER_FONT, 20)
    self._textLabel:setColor({r = 255, g = 255, b = 255})
    self._textLabel:setPosition(Launcher.cx, Launcher.cy - 60)
    self:addChild(self._textLabel)

    --check local flist and version
    if self._fileList == nil then
    	self._updateRetType = Launcher.UpdateRetType.FLIST_FILE_NOT_EXIST_ERROR
    	self:endUpdate_()
        return 
    end

    if self._versionDic == nil then
        self._updateRetType = Launcher.UpdateRetType.VERSION_FILE_NOT_EXIST_ERROR
        self:endUpdate_()
        return 
    end

    --update launcher
    self:requestFromServer_(Launcher.libDir .. Launcher.lcherZipName, Launcher.RequestType.LAUNCHER, 30)
end

-- 对应不同错误作出不同的提示
function LauncherScene:endUpdate_()
    local updateRetType = self._updateRetType 
	if updateRetType == Launcher.UpdateRetType.SUCCESSED then
        local enterGameInfo
        if self._versionDic then
            local platformKey = self:getPlatformKey_()
            local versionkey = platformKey.."Version"
            local appVersionKey = platformKey.."AppVersion"
            local versionName = self._versionDic[versionkey]
            local versionCode = self._versionDic[appVersionKey]

            enterGameInfo = {
                versionName = versionName,
                versionCode = versionCode,
            }
        end
        
        enter_game(enterGameInfo)
    else        
        print("Update: end update with errorCode:", updateRetType)
        if not LAUNCHER_UPDATE_ERROR_COUNT then
            LAUNCHER_UPDATE_ERROR_COUNT = 1
        else
            LAUNCHER_UPDATE_ERROR_COUNT = LAUNCHER_UPDATE_ERROR_COUNT + 1
        end

        updateRetType = updateRetType or "unknown"

        local errorStr = "更新失败，错误码："..updateRetType
        if LAUNCHER_UPDATE_ERROR_COUNT > 5 then
            errorStr = errorStr.."\n失败次数较多，请检查您的网络状况或重新安装软件"
        end

        if Launcher.ignoreUpdate == 1 then --可忽略更新
            Launcher.showAlert("警告", errorStr, {"忽略", "重试"}, function (event)
                if event.buttonIndex == 1 then --忽略
                    enter_game()
                else
                    self:delayToReloadMain_()
                end
            end)
        else
            Launcher.showAlert("警告", errorStr, {"重试"}, function (event)
                self:delayToReloadMain_()
            end)                
        end
	end
end

function LauncherScene:requestFromServer_(filename, requestType, waittime)
    local url = Launcher.server .. filename

    local request = cc.HTTPRequest:createWithUrl(function(event) 
        self:onResponse_(event, requestType)
    end, url, cc.kCCHTTPRequestMethodGET)

    if request then
        request:setTimeout(waittime or 30)
        request:start()
    else
        --初始化网络错误
        self._updateRetType = UpdateRetType.INIT_NETWORD_ERROR
        self:endUpdate_()
    end
end

function LauncherScene:onResponse_(event, requestType)
    if self.ignoreAllMsg == 1 then --消息延迟
        return
    end

    local request = event.request
    if event.name == "completed" then
        if request:getResponseStatusCode() ~= 200 then
            if requestType == Launcher.RequestType.LAUNCHER then --更新launcher失败
                self._updateRetType = Launcher.UpdateRetType.LAUNCHER_UPDATE_ERROR
            else
                self._updateRetType = Launcher.UpdateRetType.NETWORK_ERROR
            end
 
        	self:endUpdate_()
        else
            local dataRecv = request:getResponseData()
            if requestType == Launcher.RequestType.LAUNCHER then
            	self:onLauncherPacakgeFinished_(dataRecv)
            elseif requestType == Launcher.RequestType.FLIST then
            	self:onFileListDownloaded_(dataRecv)

             elseif requestType == Launcher.RequestType.VERSION then
                self:onVersionDownloaded_(dataRecv)
            else
            	self:onResFileDownloaded_(dataRecv)
            end
        end
    elseif event.name == "progress" then
    	 if requestType == Launcher.RequestType.RES then
    	 	self:onResProgress_(event.dltotal)
    	 end
    else
        if requestType == Launcher.RequestType.LAUNCHER then --更新launcher失败
            self._updateRetType = Launcher.UpdateRetType.LAUNCHER_UPDATE_ERROR
        else
            self._updateRetType = Launcher.UpdateRetType.NETWORK_ERROR
        end
        self:endUpdate_()
    end
end

function LauncherScene:onLauncherPacakgeFinished_(dataRecv)
	Launcher.mkDir(self._path .. Launcher.libDir)
	local localmd5 = nil
	local localPath = self._path .. Launcher.libDir .. Launcher.lcherZipName
	if not Launcher.fileExists(localPath) then
		localPath = Launcher.libDir .. Launcher.lcherZipName
	end
		
	localmd5 = Launcher.fileMd5(localPath)

	local downloadMd5 =  Launcher.fileDataMd5(dataRecv)

	if downloadMd5 ~= localmd5 then --launcher different, update
		Launcher.writefile(self._path .. Launcher.libDir .. Launcher.lcherZipName, dataRecv)
        self:delayToReloadMain_()
    else
        print("Update: request version file")
    	self:requestFromServer_(Launcher.fVersionName, Launcher.RequestType.VERSION)
    end
end

function LauncherScene:onVersionDownloaded_(dataRecv)
    self._newVersionFile = self._curVersionFile .. Launcher.updateFilePostfix
    Launcher.writefile(self._newVersionFile, dataRecv)
    self._versionDicNew = Launcher.doFile(self._newVersionFile)
    if self._versionDicNew == nil then
        print("Update Error: new version dic not exist")
        self._updateRetType = Launcher.UpdateRetType.VERSION_DOWNLOAD_ERROR
        self:endUpdate_()
        return
    end

    local appVersionKey = self:getPlatformKey_().."AppVersion"
    local lastUpdateVersionCode = self._versionDic[appVersionKey]
    local newUpdateVersionCode = self._versionDicNew[appVersionKey]

    if newUpdateVersionCode and lastUpdateVersionCode then
        newUpdateVersionCode = tonumber(newUpdateVersionCode)
        lastUpdateVersionCode = tonumber(lastUpdateVersionCode)
        if newUpdateVersionCode > lastUpdateVersionCode then
            local function keepAlertFunc_()
                local errorStr
                if Launcher.platform == "ios" then
                    errorStr = "当前版本过旧，请到AppStore更新版本！错误号："..lastUpdateVersionCode

                elseif Launcher.platform == "android" then
                    errorStr = "当前版本过旧，请到应用市场更新版本！错误号："..lastUpdateVersionCode

                else
                    errorStr = "当前版本过旧！错误号："..lastUpdateVersionCode
                end

                Launcher.showAlert("警告", errorStr, {"确定"}, function (event)
                    keepAlertFunc_()            
                end)
            end

            keepAlertFunc_()
            return
        end
    end


    local versionkey = self:getPlatformKey_().."Version"
    local newVersionStr = self._versionDicNew[versionkey]
    local versionStr = self._versionDic[versionkey]

    if newVersionStr == nil or versionStr == nil then
        print("Update Error: version key not exist ", newVersionStr, versionStr)
        self._updateRetType = Launcher.UpdateRetType.VERSION_COMPARE_ERROR
        self:endUpdate_()
        return
    end


    if newVersionStr == versionStr then
        print("Update Error: already new version")
        Launcher.removePath(self._newVersionFile)
        self._updateRetType = Launcher.UpdateRetType.SUCCESSED
        self:endUpdate_()
        return
    end

    local alertStr = "检查到可用更新v"..newVersionStr.."\n更新过程中将消耗一定流量，请尽量在Wi-Fi环境下更新"
    Launcher.showAlert("提示", alertStr, {"更新"}, function (event)
        print("Update: request flist file")
        self:requestFromServer_(Launcher.fListName, Launcher.RequestType.FLIST)
    end)
end

function LauncherScene:onFileListDownloaded_(dataRecv)
	self._newListFile = self._curListFile .. Launcher.updateFilePostfix
	Launcher.writefile(self._newListFile, dataRecv)
	self._fileListNew = Launcher.doFile(self._newListFile)
	if self._fileListNew == nil then
        self._updateRetType = Launcher.UpdateRetType.FLIST_DOWNLOAD_ERROR
		self:endUpdate_()
		return
	end

	--创建资源目录
	local dirPaths = self._fileListNew.dirPaths
    for i=1,#(dirPaths) do
        Launcher.mkDir(self._path..(dirPaths[i].name))
    end

    self:updateNeedDownloadFiles_()

    self._numFileCheck = 0
    self:reqNextResFile_()

end

function LauncherScene:onResFileDownloaded_(dataRecv)
	local fn = self._curFileInfo.name .. Launcher.updateFilePostfix
	Launcher.writefile(self._path .. fn, dataRecv)
	if Launcher.checkFileWithMd5(self._path .. fn, self._curFileInfo.code) then
		table.insert(self._downList, fn)
		self._hasDownloadSize = self._hasDownloadSize + self._curFileInfo.size
		self._hasCurFileDownloadSize = 0
		self:reqNextResFile_()
	else
		--文件验证失败
        self._updateRetType = Launcher.UpdateRetType.MD5_ERROR
    	self:endUpdate_()
	end
end

function LauncherScene:onResProgress_(dltotal)
	self._hasCurFileDownloadSize = dltotal
    self:updateProgressUI_()
end

function LauncherScene:updateNeedDownloadFiles_()
	self._needDownloadFiles = {}
    self._needRemoveFiles = {}
    self._downList = {}
    self._needDownloadSize = 0
    self._hasDownloadSize = 0
    self._hasCurFileDownloadSize = 0

    local newFileInfoList = self._fileListNew.fileInfoList
    local oldFileInfoList = self._fileList.fileInfoList

    local hasChanged = false
    for i=1, #(newFileInfoList) do
        hasChanged = false
        for k=1, #(oldFileInfoList) do
            if newFileInfoList[i].name == oldFileInfoList[k].name then
                hasChanged = true
                if newFileInfoList[i].code ~= oldFileInfoList[k].code then
                    local fn = newFileInfoList[i].name .. Launcher.updateFilePostfix
                    if Launcher.checkFileWithMd5(self._path .. fn, newFileInfoList[i].code) then
                        table.insert(self._downList, fn)
                    else
                        self._needDownloadSize = self._needDownloadSize + newFileInfoList[i].size
                        table.insert(self._needDownloadFiles, newFileInfoList[i])
                    end
                end
                table.remove(oldFileInfoList, k)
                break
            end
        end
        if hasChanged == false then
            self._needDownloadSize = self._needDownloadSize + newFileInfoList[i].size
            table.insert(self._needDownloadFiles, newFileInfoList[i])
        end
    end
    self._needRemoveFiles = oldFileInfoList

    print("self._needDownloadFiles count = " .. (#self._needDownloadFiles))

    self._progressLabel = cc.Label:createWithTTF("0%", LCHER_FONT, 20)
    self._progressLabel:setColor({r = 255, g = 255, b = 255})
    self._progressLabel:setPosition(Launcher.cx, Launcher.cy - 20)
    self:addChild(self._progressLabel)

    local progressBarBg = cc.FilteredSpriteWithOne:create("images/loading/loading_word_bg.png")
    local grayFilter = cc.GrayFilter:create(0.2, 0.3, 0.5, 0.2)
    progressBarBg:setFilter(grayFilter)
    self:addChild(progressBarBg)
    local progressBarBgSize = progressBarBg:getContentSize()
    local progressBarPt = {x = Launcher.cx, y = Launcher.cy + progressBarBgSize.height * 0.5}
    progressBarBg:setPosition(progressBarPt)

    self._progressBar = cc.ProgressTimer:create(cc.Sprite:create("images/loading/loading_word_bg.png"))
    self._progressBar:setType(Launcher.PROGRESS_TIMER_BAR)
    self._progressBar:setMidpoint({x = 0, y = 0})
    self._progressBar:setBarChangeRate({x = 0, y = 1})
    self._progressBar:setPosition(progressBarPt)
    self:addChild(self._progressBar)

    self._textLabel:setString(STR_LCHER_UPDATING_TEXT)

end

function LauncherScene:updateProgressUI_()
	local downloadPro = ((self._hasDownloadSize + self._hasCurFileDownloadSize) * 100) / (self._needDownloadSize)
    self._progressBar:setPercentage(downloadPro)
    self._progressLabel:setString(string.format("%d%%", downloadPro))
end

function LauncherScene:reqNextResFile_()
    self:updateProgressUI_()
    self._numFileCheck = self._numFileCheck + 1
    self._curFileInfo = self._needDownloadFiles[self._numFileCheck]
    if self._curFileInfo and self._curFileInfo.name then
    	self:requestFromServer_(self._curFileInfo.name, Launcher.RequestType.RES)
    else
    	self:endAllResFileDownloaded_()
    end

end

function LauncherScene:endAllResFileDownloaded_()
    --更新version文件
    local versionData = Launcher.readFile(self._newVersionFile)
    Launcher.writefile(self._curVersionFile, versionData)
    self._versionDic = Launcher.doFile(self._curVersionFile)
    if self._versionDic == nil then
        print("Update: refresh version file failed")
        self._updateRetType = Launcher.UpdateRetType.VERSION_REFRESH_ERROR
        self:endUpdate_()
        return
    end
    Launcher.removePath(self._newVersionFile)

    --更新flist文件
	local flistData = Launcher.readFile(self._newListFile)
    Launcher.writefile(self._curListFile, flistData)
    self._fileList = Launcher.doFile(self._curListFile)
    if self._fileList == nil then
        print("Update: refresh flist file failed")
        self._updateRetType = Launcher.UpdateRetType.FLIST_REFRESH_ERROR
    	self:endUpdate_()
        return
    end
    Launcher.removePath(self._newListFile)

    local offset = -1 - string.len(Launcher.updateFilePostfix)
    for i,v in ipairs(self._downList) do
        v = self._path .. v
        local data = Launcher.readFile(v)

        local fn = string.sub(v, 1, offset)
        Launcher.writefile(fn, data)
        Launcher.removePath(v)
    end

    for i,v in ipairs(self._needRemoveFiles) do
        Launcher.removePath(self._path .. (v.name))
    end

    self._updateRetType = Launcher.UpdateRetType.SUCCESSED
    self:endUpdate_()
end




local lchr = LauncherScene.new()
Launcher.runWithScene(lchr)