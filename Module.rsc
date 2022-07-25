# 使用方法
# # import Module
# import Module
# :global "Module::import"
# if ( !any $"Module::import" ) do={
#     do {/system script run [find name=Module]} on-error={:error "Script Module not found!"}
# }
# $"Module::import" logger $scriptName
# :global logger
# :global "Module::remove"
# $"Module::remove" logger <$scriptName>
# :global logger

# Module 模块日志级别
:local NOTSET 0;
:local DEBUG 10;
:local INFO 20;
:local WARNING 30;


# 模块命名规则
## 1. 模块名字以英文字母和阿拉伯数字
## 2. 模块内定义所有全局变量均采用 :global "[ModuleName]::[variableName]" 方式命名，以便卸载模块时候统一卸载
## 3. 模块脚本中如果调用 logger 记录日志，logTag 必须遵循 "[ModuleName]::[function]" 方式命名，否则 logger 日志模块无法识别日志等级。

# Module 日志级别
## Module 脚本日志只输出到控制台，并不记录到路由日志里
:global "Module::logLevel";if (!any $"Module::logLevel") do={:global "Module::logLevel" $WARNING;}
:global "Module::logTag" "Module"

# 模块锁，防止脚本结束卸载模块时候，另一个脚本正在调用模块失败
## 定义：
## :global "Module::lock" {
##    "<moduleName>"="|[<scriptName>|static]|<scriptName1>|"; # 如果设置为 static，模块将永不卸载 
## }
:global "Module::lock" {"Module"="|static|";};

# 解锁模块，将自己脚本名称在模块锁变量中删除
## :global "Module::unlockModule"
## $"Module::unlockModule" <moduleName> <scriptName>
:global "Module::unlockModule" do={
    :global "Module::logLevel"
    :global "Module::logTag"
    :global "Module::lock"
    :local moduleName $1
    :local scriptName $2;
    # 当传入变量带有 "scriptName::functionName" 符号时，裁剪scriptName
    if (any [find $scriptName "::"]) do={
        :local keyCount [find $scriptName "::"]
        :set scriptName [:pick $scriptName 0 $keyCount]
    }
    :local logTag "$"Module::logTag"::lockModule"
    :local moduleLockList ($"Module::lock"->$moduleName)
    :local keyword ("$scriptName|")
    if ([find $moduleLockList $scriptName] > 0) do={
        if ($"Module::logLevel" <= 10) do={:put ("[debug] [$logTag] Unlock $moduleName from $scriptName.")}
        :local keywordLen [:len $keyword]
        :local keywordBeginCount ([find $moduleLockList $keyword] - 1)
        :local keywordEndCount ($keywordBeginCount + $keywordLen)
        :set ($"Module::lock"->$moduleName) ([:pick $moduleLockList 0 $keywordBeginCount;] . [:pick $moduleLockList $keywordEndCount [:len $moduleLockList]])
    }
}

# 锁定模块，将自己脚本名称添加到模块锁变量
## :global "Module::lockModule"
## $"Module::lockModule" <moduleName> <scriptName>
:global "Module::lockModule" do={
    :global "Module::logLevel"
    :global "Module::logTag"
    :global "Module::lock"
    :local moduleName $1
    :local scriptName $2; if (!any $scriptName) do={:set scriptName "noName"}
    # 当传入变量带有 "scriptName::functionName" 符号时，裁剪scriptName
    if (any [find $scriptName "::"]) do={
        :local keyCount [find $scriptName "::"]
        :set scriptName [:pick $scriptName 0 $keyCount]
    }
    :local logTag "$"Module::logTag"::lockModule"
    :local moduleLockList ($"Module::lock"->$moduleName)
    if ($"Module::logLevel" <= 10) do={:put ("[debug] [$logTag] moduleLockList:$moduleLockList")}
    if (!any $moduleLockList) do={
        :set moduleLockList "|"
    }
    if ([find $moduleLockList $scriptName] < 1) do={
        if ($"Module::logLevel" <= 10) do={:put ("[debug] [$logTag] Lock $moduleName from $scriptName.")}
        :set ($"Module::lock"->$moduleName) ($moduleLockList . "$scriptName|")
    }
}

# 检查模块是否加载
## 使用方法：
## :global "Module::isLoaded" 
## $"Module::isLoaded" <moduleName>
### 参数：
###   - moduleName: 模块名字，如 logger
:global "Module::isLoaded" do={
    :global "Module::logLevel"
    :global "Module::logTag"
    :local logTag ("$"Module::logTag"::isLoaded")
    :local module $1
    if ( [:len [/system script environment find name~("^$module")] ] > 0 ) do={
        if ($"Module::logLevel" <= 20) do={:put ("[info] [$logTag] Module [$module] is loaded.");}
        return true
    } else={
        if ($"Module::logLevel" <= 10) do={:put ("[debug] [$logTag] Module $module not load.");}
        return false
    }
}

#加载模块
## 使用方法：
## :global "Module::import"
## $"Module::import" <moduleName> <scriptName> [reload=true]
### 参数：
###   - moduleName: 模块名字，如 logger
###   - scriptName: 当前脚本名字，如 DDNS_dynu，作用于模块锁定
###   - reload: 布尔值，不管模块是否加载都执行加载操作，如 [true|false] 
:global "Module::import" do={
    :global "Module::logLevel"
    :global "Module::isLoaded"
    :global "Module::remove"
    :global "Module::logTag"
    :global  "Module::lockModule"
    :local logTag ("$"Module::logTag"::import")
    :local module $1

    :local scriptName $2
    # 当传入变量带有 "scriptName::functionName" 符号时，裁剪scriptName
    if (any [find $scriptName "::"]) do={
        :local keyCount [find $scriptName "::"]
        :set scriptName [:pick $scriptName 0 $keyCount]
    }
    if ($"Module::logLevel" <= 10) do={:put ("[debug] [$logTag] module:$module, scriptName:$scriptName")}
    # 重载模块，除了 Module 自身其余模块均可重载
    if ($reload = true) do={
        if ($module = "Module") do={
            if ($"Module::logLevel" <= 30) do={:put ("[warning] [$logTag] Module does not support reload.")}
        } else={
            $"Module::remove" $module $scriptName force=true
        }
    }
    $"Module::lockModule" $module $scriptName
    if ( ![$"Module::isLoaded" $module]) do={
        # 如果模块在文件脚本存在则加载它
        if ( [:len [/file find name=("$module.rsc")]] > 0 ) do={
            if ($"Module::logLevel" <= 10) do={:put ("[debug] [$logTag] Load modules via file [$module.rsc]")}
            /import "$module.rsc"
            if ( ![$"Module::isLoaded" $module] ) do={
                :error ("[error] [$logTag] Module $module.rsc load failed！");
            }
        } 
        # 如果模块在脚本中，则运行脚本加载模块
        if ([:len [/system script find name=$module]] > 0) do={
            if ($"Module::logLevel" <= 10) do={:put ("[debug] [$logTag] Load modules via script <$module>")}
            /system script run [/system script find name=$module]
            if ( ![ $"Module::isLoaded" $module ] ) do={
                :error ("[error] [$logTag] Module $module.rsc load failed！");
            }
        } else={
            :error ("[error] [$logTag] Module [$module] not found!")
        }
    }
}

# 卸载模块，匹配模块名字
## 使用方法：
## :global "Module::remove"
## $"Module::remove" <moduleName> <scriptName> [force=true]
### 参数：
###   - moduleName: 模块名字，如 logger
###   - scriptName: 当前脚本名字，如 DDNS_dynu，作用于模块解锁
###   - force: 不管是否锁定一律卸载，请谨慎使用
:global "Module::remove" do={
    :global "Module::logLevel"
    :global "Module::lock"
    :global "Module::unlockModule"
    :global "Module::logTag"
    :local  logTag "$"Module::logTag"::remove"
    :local moduleName $1
    :local scriptName $2
    $"Module::unlockModule" $moduleName $scriptName
    # 如果模块锁为空
    if ( ([ :len ($"Module::lock"->$moduleName )] < 2) || ($force = true) ) do={
        # 强制卸载清空模块锁
        if ($force = true) do={ :set ($"Module::lock"->$moduleName ) "|"}
        :local regex ("^$moduleName(::|\$)")
        if ($"Module::logLevel" <= 10) do={:put ("[debug] [$logTag] remove all modules named $moduleName.")}
        system script environment remove [/system script environment find where name~$regex]
    } else={
        if ($"Module::logLevel" <= 10) do={:put ("[debug] [$logTag] $moduleName is locked. Lock module script list:" . ($"Module::lock"->$moduleName ))}
    }
}
