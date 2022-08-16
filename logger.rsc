# 日志记录器
## 描述：方便编写脚本的时候，既打印日志到控制台，又可以记录日志。
## 使用方法：
## :local logger ([ $loadModule logger init=({"logTag"="<logTag>";"level"="DEBUG";}) ]->"logger")
## $logger <log message> # 只打印不记录日志
## $logger [info|warning|error|debug] <log message>

:global scriptLogLevel; if (!any $scriptLogLevel) do={
    :global scriptLogLevel ({
        "NOTSET"=0;
        "DEBUG"=10;
        "INFO"=20;
        "WARNING"=30;
        "ERROR"=40;
        "DEFAULT_LEVEL"=30;
        "modulesLevel"={};
    })
};

# 设置模块输出日志，如果未设定则为 WARNING 级别
:local setLevel do={
    :global scriptLogLevel
    :local logTag "setLevel"
    :local moduleName $1
    :local setLevel $2;
    if (!any $setLevel) do={
        :local msg "[warning] setLevel is not defined!"
        :put $msg
        /log warning message=($msg)
        return false
    }
    if (!any $moduleName) do={
        :local msg "[warning] moduleName is not defined!"
        :put $msg
        /log warning message=($msg)
        return false
    }
    :set ($scriptLogLevel->"modulesLevel"->$moduleName) $setLevel
}

:local logger do={
    # Global import
    :global scriptLogLevel
    
    # Check args
    if ([typeof $1] = "nothing") do={
        :local msg "[warning] [logger] msg is not defined!"
        :put $msg
        /log warning message=($msg)
        return false
    }
    
    # 查询当前模块日志级别
    :local getLevel do={
        :global scriptLogLevel
        :local moduleName $1; if ($moduleName = false) do={return ($scriptLogLevel->"DEFAULT_LEVEL")}
        :local level ($scriptLogLevel->"modulesLevel"->$moduleName)
        if ([typeof $level] = "num") do={
            return $level
        } else={
            return ($scriptLogLevel->"DEFAULT_LEVEL")
        }
    }

    # Local variable
    :local type
    :local msg
    # 通过 logTag 查找模块名字
    :local logTag "{{{logTag}}}"
    :local logLevel [$getLevel $logTag]
    # 如果参数 2 为空，那么参数 1 就是 msg
    if (! any $2) do={
        :set msg $1
    } else={
        :set type $1
        :set msg ("[$logTag] " . $2)
    }
    # 没第二参数的话只打印到控制台，不写到日志，此方法默认级别为 debug
    if ((! any $type) && ($logLevel <= $scriptLogLevel->"DEBUG")) do={
        :put ("[debug] $1")
        return true
    }
    if (($type = "info") && ($logLevel <= $scriptLogLevel->"INFO")) do={
        :put ("[$type] $msg")
        /log info message=($msg)
        return true
    }
    if (($type = "debug") && ($logLevel <= $scriptLogLevel->"DEBUG")) do={
        :put ("[$type] $msg")
        /log debug message=($msg)
        return true
    }
    if (($type = "error") && ($logLevel <= $scriptLogLevel->"ERROR")) do={
        :put ("[$type] $msg")
        /log error message=($msg)
        return true
    }
    if (($type = "warning") && ($logLevel <= $scriptLogLevel->"WARNING")) do={
        :put ("[$type] $msg")
        /log warning message=($msg)
        return true
    }
}

# logger 初始化脚本
## 方便调用脚本初始化 logTag
## 必须传入
## - init: 数组 {"logTag"=$logTag;"logLevel":"DEBUG"}
## - logTag: 初始化日志标记，区分是哪个脚本的日志
## - logLevel: 初始化日志级别（可选，不写则默认 WARNING 级别）
:local init do={
    :put ("[debug] [logger] Start initializing logger.")
    if ( ! any [/system script find name="replace"] ) do={
        :error "[error] [logger::init] Dependency script not found: replace!"
    }
    if ( [:typeof ($init->"logTag")] != "str" ) do={
        :error "[error] [logger::init] The logger module requires initialization parameters: init->logTag Type: string!"
    }
    :local logTag ($init->"logTag")
    :local script
    :local replace ([[:parse [/system script get replace source]]]->"replace")
    :local scriptString [/system script get logger source]
    :set scriptString [ $replace string=$scriptString keyWord="{{{logTag}}}" value=$logTag ]
    do { :set script [ :parse $scriptString ] } on-error={
        :put "[error] [logger::init] ================ error message ================"
        :put ("$scriptString")
        :put "[error] [logger::init] ================ message end ================"
        :error "[error] [logger::init] Failed to initialise logger!"
    }
    if ( any ($init->"level") ) do={
        :global scriptLogLevel
        :local logLevel ($init->"level")
        if ([:typeof $logLevel] != "num") do={
            :set logLevel ($scriptLogLevel->$logLevel)
            if (! any $logLevel) do={
                :put "[warning] [logger::init] The parameter passed to logLevel does not match \
                        the expectation. Default logLevel is WARNING."
                :set logLevel ($scriptLogLevel->"WARNING")
            }
        }
        :set ($scriptLogLevel->"modulesLevel"->$logTag) $logLevel
    }
    return [$script]
}

return {
    "moduleName"="logger"
    "setLevel"=$setLevel;
    "init"=$init;
    "logger"=$logger;
}