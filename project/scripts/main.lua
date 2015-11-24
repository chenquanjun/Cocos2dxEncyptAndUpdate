
function __G__TRACKBACK__(errorMessage)
print("----------------------------------------")
print("LUA ERROR: " .. tostring(errorMessage) .. "\n")
print(debug.traceback("", 2))
print("----------------------------------------")
end


local fileUtils = cc.FileUtils:getInstance()
fileUtils:setPopupNotify(false)
-- 清除fileCached 避免无法加载新的资源。
fileUtils:purgeCachedEntries()

cc.LuaLoadChunksFromZIP("code/launcher.zip")


package.loaded["launcher.launcher"] = nil
require("launcher.launcher")
