#coding=utf-8
#!/usr/bin/python
import os 
import os.path 
import sys, getopt  
import subprocess
import shutil 
import time,  datetime
import platform
from hashlib import md5
import hashlib  
import binascii

def removeDir(dirName):
	if not os.path.isdir(dirName): 
		return
	filelist=[]
	filelist=os.listdir(dirName)
	for f in filelist:
		filepath = os.path.join( dirName, f )
		if os.path.isfile(filepath):
			os.remove(filepath)
		elif os.path.isdir(filepath):
			shutil.rmtree(filepath,True)

def copySingleFile(sourceFile, targetFile):
	if os.path.isfile(sourceFile): 
		if not os.path.exists(targetFile) or(os.path.exists(targetFile) and (os.path.getsize(targetFile) != os.path.getsize(sourceFile))):  
			open(targetFile, "wb").write(open(sourceFile, "rb").read()) 

def copyFiles(sourceDir,  targetDir, isAll): 
	for file in os.listdir(sourceDir): 
		sourceFile = os.path.join(sourceDir,  file) 
		targetFile = os.path.join(targetDir,  file) 
		if os.path.isfile(sourceFile): 
			if not isAll:
				extName = file.split('.', 1)[1] 
				if IgnoreCopyExtFileDic.has_key(extName):
					continue
			if not os.path.exists(targetDir):
				os.makedirs(targetDir)
			if not os.path.exists(targetFile) or(os.path.exists(targetFile) and (os.path.getsize(targetFile) != os.path.getsize(sourceFile))):  
				open(targetFile, "wb").write(open(sourceFile, "rb").read()) 
		if os.path.isdir(sourceFile): 
			First_Directory = False 
			copyFiles(sourceFile, targetFile, isAll)

def toHex(s):
	return binascii.b2a_hex(s).upper()

def md5sum(fname):

 	def read_chunks(fh):
		fh.seek(0)
		chunk = fh.read(8096)
		while chunk:
			yield chunk
			chunk = fh.read(8096)
		else: #最后要将游标放回文件开头
			fh.seek(0)
	m = hashlib.md5()
	if isinstance(fname, basestring) and os.path.exists(fname):
		with open(fname, "rb") as fh:
			for chunk in read_chunks(fh):
				m.update(toHex(chunk))
	#上传的文件缓存 或 已打开的文件流
	elif fname.__class__.__name__ in ["StringIO", "StringO"] or isinstance(fname, file):
		for chunk in read_chunks(fname):
			m.update(toHex(chunk))
	else:
		return "" 

	return m.hexdigest()


def calMD5ForFolder(dir):
	md5Dic = []
	folderDic = {}
	for root, subdirs, files in os.walk(dir):
		#get folder
		folderRelPath = os.path.relpath(root, dir)
		if folderRelPath != '.' and len(folderRelPath) > 0:
			normalFolderPath =  folderRelPath.replace('\\', '/') #convert to / path
			folderDic[normalFolderPath] = True

		#get md5
		for fileName in files:
			filefullpath = os.path.join(root, fileName)
			filerelpath = os.path.relpath(filefullpath, dir)
			size = os.path.getsize(filefullpath)
			normalPath =  filerelpath.replace('\\', '/') #convert to / path

			if IgnoreMd5FileDic.has_key(fileName): #ignode special file
				continue

			print normalPath
			md5 = md5sum(filefullpath)
			md5Dic.append({'name' : normalPath, 'code' : md5, 'size' : size})

		
	print 'MD5 figure end'	
	return md5Dic, folderDic

#-------------------------------------------------------------------
def initEnvironment():
	#注意：复制的资源分两种
	#第一种是加密的资源，从packres目录复制到APP_RESOURCE_ROOT。加密资源的类型在PackRes.php的whitelists定义。
	#第二种是普通资源，从res目录复制到APP_RESOURCE_ROOT。IgnoreCopyExtFileDic定义了不复制的文件类型（1、加密资源，如png文件；2、无用资源，如py文件）
	
	global ANDROID_APP_VERSION
	global IOS_APP_VERSION
	global ANDROID_VERSION
	global IOS_VERSION
	global BOOL_BUILD_APP #是否构建app

	global APP_ROOT #工程根目录 
	global APP_ANDROID_ROOT #安卓根目录
	global QUICK_ROOT #引擎根目录
	global QUICK_BIN_DIR #引擎bin目录
	global APP_RESOURCE_ROOT #生成app的资源目录
	global APP_RESOURCE_RES_DIR #资源目录

	global IgnoreCopyExtFileDic #不从res目录复制的资源
	global IgnoreMd5FileDic #不计算md5的文件名

	global APP_BUILD_USE_JIT #是否使用jit

	global PHP_NAME #php
	global SCRIPT_NAME #scriptsName

	global BUILD_PLATFORM #生成app对应的平台


	BOOL_BUILD_APP = True

	IgnoreCopyExtFileDic = {
		'jpg' : True,
		'png' : True,
		'tmx' : True,
		'plist' : True,
		'py' : True,
	}

	IgnoreMd5FileDic = {
		'.DS_Store' : True,
		'version' : True,
		'flist' : True,
		'launcher.zip' : True,
		'.' : True,
		'..' : True,
	}

	SYSTEM_TYPE = platform.system()

	APP_ROOT = os.getcwd()
	APP_ANDROID_ROOT = APP_ROOT + "/frameworks/runtime-src/proj.android"
	QUICK_ROOT = os.getenv('QUICK_V3_ROOT')

	if QUICK_ROOT == None:
		print "QUICK_V3_ROOT not set, please run setup_win.bat/setup_mac.sh in engine root or set QUICK_ROOT path"
		return False

	

	if(SYSTEM_TYPE =="Windows"):
		QUICK_BIN_DIR = QUICK_ROOT + "quick/bin"
		PHP_NAME = QUICK_BIN_DIR + "/win32/php.exe" #windows
		BUILD_PLATFORM = "android" #windows dafault build android
		SCRIPT_NAME = "/compile_scripts.bat"
	else:
		PHP_NAME = "php"
		BUILD_PLATFORM = "ios" #mac default build ios
		QUICK_BIN_DIR = QUICK_ROOT + "/quick/bin" #mac add '/'
		SCRIPT_NAME = "/compile_scripts.sh"

	if(BUILD_PLATFORM =="ios"):
		APP_BUILD_USE_JIT = False #ios not use jit

		if BOOL_BUILD_APP:
			APP_RESOURCE_ROOT = APP_ROOT + "/Resources" 
			APP_RESOURCE_RES_DIR = APP_RESOURCE_ROOT + "/res"
		else:
			APP_RESOURCE_ROOT = APP_ROOT + "/server/game/cocos2dx/udp"
			APP_RESOURCE_RES_DIR = APP_RESOURCE_ROOT

	else:
		APP_BUILD_USE_JIT = True

		if BOOL_BUILD_APP:
			APP_RESOURCE_ROOT = APP_ANDROID_ROOT + "/assets" #default build android
			APP_RESOURCE_RES_DIR = APP_RESOURCE_ROOT + "/res"
		else:
			APP_RESOURCE_ROOT = APP_ROOT + "/server/game/cocos2dx/udp"
			APP_RESOURCE_RES_DIR = APP_RESOURCE_ROOT

	print 'App root: %s' %(APP_ROOT)
	print 'App resource root: %s' %(APP_RESOURCE_ROOT)
	return True

def svnUpdate():
	print "1:svn update"
	try:
		args = ['svn', 'update']
		proc = subprocess.Popen(args, shell=False, stdout = subprocess.PIPE, stderr=subprocess.STDOUT)
		while proc.poll() == None:  
			print proc.stdout.readline(),
		print proc.stdout.read()
	except Exception,e:  
		print Exception,":",e


def packRes():
	print "2:pack res files"

	removeDir(APP_ROOT + "/packres/") #--->删除旧加密资源

	scriptName = QUICK_BIN_DIR + "/lib/pack_files.php"
	try:
		args = [PHP_NAME, scriptName, '-c', 'PackRes.php']
		proc = subprocess.Popen(args, shell=False, stdout = subprocess.PIPE, stderr=subprocess.STDOUT)
		while proc.poll() == None:  
		    print proc.stdout.readline(),
		print proc.stdout.read()
	except Exception,e:  
		print Exception,":",e

def copyResourceFiles():
	print "3:copy resource files"

	print "remove old resource files"
	removeDir(APP_RESOURCE_ROOT)

	if not os.path.exists(APP_RESOURCE_ROOT):
		print "create resource folder"
		os.makedirs(APP_RESOURCE_ROOT)

	if BOOL_BUILD_APP:  #copy all resource 
		print "copy config"
		copySingleFile(APP_ROOT + "/config.json", APP_RESOURCE_ROOT + "/config.json")
		copySingleFile(APP_ROOT + "/channel.lua", APP_RESOURCE_ROOT + "/channel.lua")
		
		print "copy src"
		copyFiles(APP_ROOT + "/scripts/",  APP_RESOURCE_ROOT + "/src/", True)

	print "copy res"
	copyFiles(APP_ROOT + "/res/",  APP_RESOURCE_RES_DIR, False)

	print "copy pack res"
	copyFiles(APP_ROOT + "/packres/",  APP_RESOURCE_RES_DIR, True)


def compileScriptFile(compileFileName, srcName, compileMode):
    scriptDir = APP_RESOURCE_RES_DIR + "/code/"
    if not os.path.exists(scriptDir):
        os.makedirs(scriptDir)
    try:
        scriptsName = QUICK_BIN_DIR + SCRIPT_NAME
        srcName = APP_ROOT + "/" + srcName
        outputName = scriptDir + compileFileName
        args = [scriptsName,'-i',srcName,'-o',outputName,'-e',compileMode,'-es','XXTEA','-ek','ilovecocos2dx']

        if APP_BUILD_USE_JIT:
            args.append('-jit')

        proc = subprocess.Popen(args, shell=False, stdout = subprocess.PIPE, stderr=subprocess.STDOUT)
        while proc.poll() == None:  
            outputStr = proc.stdout.readline()
            print outputStr,
        print proc.stdout.read(),
    except Exception,e:  
        print Exception,":",e



def compileFile():
	print "4:compile script file"

	compileScriptFile("game.zip", "src", "xxtea_zip") #--->代码加密
	compileScriptFile("launcher.zip", "pack_launcher", "xxtea_zip") #--->更新模块加密

def writeFile(fileName, strArr):
	if os.path.isfile(fileName):
		print "Remove old file!"
		os.remove(fileName)

	#write file
	f = file(fileName, 'w') 

	for _, contentStr in enumerate(strArr):
		f.write(contentStr)

	f.close()

def genFlist():
	print "5: generate flist"
	# flist文件格式 lua table
	# key
	#  --> dirPaths 目录
	#  --> fileInfoList 文件名，md5，size
	folderPath = APP_RESOURCE_RES_DIR

	md5Dic, folderDic = calMD5ForFolder(folderPath)

	#sort md5
	sortMd5Dic = sorted(md5Dic, cmp=lambda x,y : cmp(x['name'], y['name']))  

	#convert folder dic to arr
	folderNameArr = []

	for folderName, _ in folderDic.iteritems():
		folderNameArr.append(folderName)

	#sort folder name
	sortFolderArr = sorted(folderNameArr, cmp=lambda x,y : cmp(x, y)) 

	#str arr generate
	strArr = []

	strArr.append('local flist = {\n')

	#dirPaths
	strArr.append('\tdirPaths = {\n')

	for _,folderName in enumerate(sortFolderArr):
		strArr.append('\t\t{name = "%s"},\n' % folderName)

	strArr.append('\t},\n')

	#fileInfoList
	strArr.append('\tfileInfoList = {\n')
	
	for index, md5Info in enumerate(sortMd5Dic):
		name = md5Info['name']
		code = md5Info['code']
		size = md5Info['size']
		strArr.append('\t\t{name = "%s", code = "%s", size = %d},\n' % (name, code, size))

	strArr.append('\t},\n')
	strArr.append('}\n')
	strArr.append('return flist\n')

	writeFile(folderPath + "/flist", strArr)

def genVersion():
	print "6: generate version"
	folderPath = APP_RESOURCE_RES_DIR
	#str arr generate
	strArr = []
	strArr.append('local version = {\n')

	strArr.append('\tandroidAppVersion = %d,\n' % ANDROID_APP_VERSION)
	strArr.append('\tiosAppVersion = %d,\n' % IOS_APP_VERSION)
	strArr.append('\tandroidVersion = "%s",\n' % ANDROID_VERSION)
	strArr.append('\tiosVersion = "%s",\n' % IOS_VERSION)

	strArr.append('}\n')
	strArr.append('return version\n')

	writeFile(folderPath + "/version", strArr)

if __name__ == '__main__': 
	print 'Pack App start!--------->'
	isInit = initEnvironment()

	if isInit == True:
		#若不更新资源则直接执行copyResourceFiles和compileScript
		
		svnUpdate() #--->更新svn

		packRes() #--->资源加密（若资源如图片等未更新则此步可忽略）

		copyResourceFiles() #--->复制res资源
		
		compileFile() #--->lua文件加密

		genFlist() #--->生成flist文件

		ANDROID_APP_VERSION = 1 #app 更新版本才需要更改
		IOS_APP_VERSION = 1 #app 更新版本才需要更改
		ANDROID_VERSION = "1.0.1"
		IOS_VERSION = "1.0.1"

		genVersion() #--->生成version文件

	print '<---------Pack App end!'