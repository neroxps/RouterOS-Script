# Pubyun ddns update
# 脚本依赖 loadModule logger

# local variable
:local logTag "Pubyun"
# 脚本日志级别
:local logLevel "DEBUG"

# Load module
:global loadModule; if ( !any $loadModule ) do={
    do {/system script run [find name=loadModule]} on-error={:error "Script loadModule not found!"}
}

# set log level to debug
:local logger ([ $loadModule logger init=({"logTag"=$logTag;"level"=$logLevel;}) ]->"logger")

:local return do={
    :local msg
    if (any $2 and $1 = "error") do={
        set msg $2
        return {
            "result"=false;
            "logMessage"=$msg;
            "info"=$info
        }
    }
    return {"result"=true; "info"=$info}
}

# 更新地址
## 必须传入参数
## - Dep: 函数依赖数组
## - user: pubyun 的用户名
## - password: 函数依赖数组
## - domain: 函数依赖数组
## - ipaddress: ipv4 地址

:local update do={
    :local logTag "update"
    if ( ! any $Dep ) do={ :error message=("[$logTag] <update> Dep(Dependency) is not defined!") }
    :local return ($Dep->"return")
    :local logger ($Dep->"logger")
    :local result
    :local functionName $logTag
    :local apiUrl "http://members.3322.org/dyndns/update?"
    if (! any $user) do={ return [ $return error ("<$functionName> user is not defined!") ] }
    if (! any $password) do={ return [ $return error ("<$functionName> password is not defined!") ] }
    if (! any $domain) do={ return [ $return error ("<$functionName> domain is not defined!") ] }
    if (! any $ipaddress) do={ return [ $return error ("<$functionName> ipaddress is not defined!") ] }
    :local payload ("hostname=$domain&myip=$ipaddress")
    :set apiUrl ($apiUrl . $payload)
    $logger debug ("[$logTag] ====================== Request parameter======================")
    $logger debug ("[$logTag] user: $user")
    $logger debug ("[$logTag] password: $password")
    $logger debug ("[$logTag] domain: $domain")
    $logger debug ("[$logTag] ipaddress: $ipaddress")
    $logger debug ("[$logTag] ====================== Request full command ======================")
    $logger debug ("[$logTag] tool fetch url=$apiUrl mode=http user=$user password=$password output=user as-value")
    do {
        set result [/tool fetch url=$apiUrl mode=http user=$user password=$password output=user as-value]
    } on-error={
        return [ $return error ("[$logTag] <$functionName> Failed to update IP address!") ]
    }
    $logger debug ("[$logTag] ====================== Request result ======================")
    $logger debug ("[$logTag] " . [:tostr $result]);
    $logger debug ("[$logTag] ====================== END ======================")
    if ( ! any [find ($result->"data") "good"]  ) do={
        if ( ! any [ find ($result->"data") "nochg" ] ) do={
            return [ $return error ("<$functionName> Failed to update IP address! " . ($result->data)) ]
        }
    }
    return [ $return ]
}

return {
    "moduleName"="Pubyun";
    "update"=$update;
    "Dep"={
        "return"=$return;
        "logger"=$logger;
    }
}
