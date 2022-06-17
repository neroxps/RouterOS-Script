# 日志记录器
## 描述：方便编写脚本的时候，既打印日志到控制台，又可以记录日志。
## 使用方法：
## :global logger
## $logger <info message> # 只打印不记录日志
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
:global "logger::setLevel" do={
    :global scriptLogLevel
    :local logTag "logger::setLevel"
    :local moduleName $1
    :local setLevel $2; 
    if (!any $setLevel) do={
        :local msg "[warning] [$logTag] setLevel is not defined!"
        :put $msg
        /log warning message=($msg)
        return false
    }
    :set ($scriptLogLevel->"modulesLevel"->$moduleName) $setLevel
}

:global logger do={
    # Global import
    :global scriptLogLevel
    
    # Check args
    if ([typeof $1] = "nothing") do={
        :local msg "[warning] [logger] msg is not defined!"
        :put $msg
        /log warning message=($msg)
        return false
    }
    
    # subFunction
    # 通过日志标记获取模块名字
    :local getModuleName do={
        # msg 内必须为 [moduleName::flowTag::flowTag] 这种形式标志才能获得 module name
        :local msg $1
        :local beginCount [find $msg "["]
        :local endCount [find $msg "::"]
        if (!any $endCount) do={:set endCount [find $msg "]"]}
        if ( (!any $beginCount) || (!any $endCount) ) do={
            return false
        }
        :local moduleName [pick $msg ($beginCount + 1) $endCount]
        if (any $moduleName) do={
            return $moduleName
        }
        return false
    }

    # 查询当前模块日志级别
    :local getLevel do={
        :global scriptLogLevel
        :local moduleName $1; if ($moduleName = false) do={return ($scriptLogLevel->"DEFAULT_LEVEL")}
        :local level ($scriptLogLevel->"modulesLevel"->$moduleName)
        if ([typeof $level] = "num") do={
            return $level
        } else {
            return ($scriptLogLevel->"DEFAULT_LEVEL")
        }
    }

    # Local variable
    :local type
    :local msg
    # 如果参数 2 为空，那么参数 1 就是 msg
    if ([typeof $2] = "nothing") do={
        :set msg $1
    } else={
        :set type $1
        :set msg $2
    }
    # 通过 logTag 查找模块名字
    :local moduleName [$getModuleName $msg]
    :local logLevel [$getLevel $moduleName]
    # 没第二参数的话只打印到控制台，不写到日志，此方法默认级别为 debug
    if ((([typeof $type] = "nothing") && ($logLevel <= $scriptLogLevel->"DEBUG")) || ($moduleName = false)) do={
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