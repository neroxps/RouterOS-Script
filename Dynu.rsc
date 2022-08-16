# Dynu DDNS API
# 脚本依赖 loadModule logger

# example
# # Load module
# :global loadModule; if ( !any $loadModule ) do={
#     do {/system script run [find name=loadModule]} on-error={:error "Script loadModule not found!"}
# }
# :local DynuV2Arr [ $loadModule Dynu ]
# :local DynuV2Dep ($DynuV2Arr->"Dep")
# :local dnsPost ($DynuV2Arr->"dnsPost")
# :local recordPost ($DynuV2Arr->"recordPost")

# $dnsPost \
#     id="<id>" \
#     apiKey="<Api Key>" \
#     ipv4Address="1.1.1.1" \
#     ipv6Address="fe80::1" \
#     domainName="<domainName>" \
#     Dep=$DynuV2Dep

# $recordPost \
#     id="<id>" \
#     apiKey="<Api Key>" \
#     dnsRecordId="<dnsRecordId>" \
#     ipAddress="fe80::1" \
#     nodeName="ipv6" \
#     Dep=$DynuV2Dep

# local variable
:local logTag "Dynu"
# 脚本日志级别
:local logLevel "DEBUG"

# Load module
:global loadModule; if ( !any $loadModule ) do={
    do {/system script run [find name=loadModule]} on-error={:error "Script loadModule not found!"}
}

# import logger
:local logger ([ $loadModule logger init=({"logTag"=$logTag;"level"=$logLevel;}) ]->"logger")


# 脚本返回函数
## 错误信息记录日志，其余一律返回一个焊油 result 为 true 的 array
:local return do={
    :local msg
    if (any $2 and $1 = "error") do={
        set msg $2
        return {
            "result"=false;
            "logMessage"=$msg
        }
    }
    return {"result"=true;}
}

# 发起 API 请求
## $request \
##      path="dns/{id}/record/{dnsRecordId}" \
##      apiKey="< dynu api key>" \
##      method=post \
##      payload="{\"nodeName\":\"mail\",\"recordType\":\"A\",\"ttl\":300,\"state\":true,\"group\":\"\",\"ipv4Address\":\"204.25.79.214\"}" \
##      Dep=$DynuV2Dep
## 必须传入参数
### - path: Dyny 接口路径
### - apiKey: Dynu api Key
### - method: 接口请求模式 [get|post|delete]
### - payload: 传入 json格式字符串参数
### - Dep: 函数依赖数组
:local request do={
    :local logTag "request"
    if ( ! any $Dep ) do={ :error message=("[Dynu] [$logTag] Dep(Dependency) is not defined!")}
    # import logger
    :local logger ($Dep->"logger")
    # import return
    :local return ($Dep->"return")
    :local domain "api.dynu.com"
    :local version "v2"
    :local header
    :local result
    :local resultStr
    :local apiUrl
    if (! any $path) do={ return [ $return error ("path is not defined!") ] }
    if (! any $apiKey) do={ return [ $return error ("apiKey is not defined!") ]}
    if (! any $method) do={ return [ $return error ("method is not defined!") ]}
    if (! any $payload) do={ return [ $return error ("payload is not defined!") ]}
    :set apiUrl ("https://$domain/$version/$path")
    :set header ("API-Key:$apiKey,accept:application/json")
    $logger debug ("[$logTag] ====================== Request parameter======================")
    $logger debug ("[$logTag] path: $path")
    $logger debug ("[$logTag] apiKey: $apiKey")
    $logger debug ("[$logTag] method: $method")
    $logger debug ("[$logTag] ====================== Request payload ======================")
    $logger debug ("[$logTag] payload: $payload")
    $logger debug ("[$logTag] ====================== Request full command ======================")
    $logger debug ("[$logTag] tool fetch url=$apiUrl mode=https output=user http-method=post http-header-field=$header http-data=$payload as-value")
    do {
        set result [/tool fetch url=$apiUrl mode=https output=user http-method=$method http-header-field=$header http-data=$payload as-value]
        set resultStr [:tostr $result]
    } on-error={
        return [$return error "Failed to update IP address!"]
    }
    $logger debug ("[$logTag] ====================== Request result ======================")
    $logger debug ("[$logTag] $resultStr");
    $logger debug ("[$logTag] ====================== END ======================")
    if ( ! any [find ($result->"data") "\"statusCode\":200"] ) do={
        return [$return error ("[$logTag] Request failed message:" . ($result->"data"))]
    }
    return [$return]
}

# 更新域名解析
## $dnsPost \
##      apiKey=<dynu api key> \
##      ipv4Address="1.1.1.1" \
##      domainName="abc.accesscam.org" \
##      Dep=$DynuV2Dep
## 必须传入参数
### - apiKey: Dyny api key
### - ipv4Address: ipv4 地址
### - domainName: 域名全称
### - Dep: 函数依赖数组
## 可选传入参数
### - id: Dynu dns ID
### - ipv6Address: ipv6 地址
### - ipv4WildcardAlias: ipv4域名是否使用泛域名 字符串的布尔值["true"|"false"]
### - ipv6WildcardAlias: ipv6域名是否使用泛域名 字符串的布尔值["true"|"false"]
### - ttl: 全球生效时间默认 60
:local dnsPost do={
    :local logTag "dnsPost"
    if ( ! any $Dep ) do={ :error message=("[Dynu] [$logTag] Dep(Dependency) is not defined!")}
    :local return ($Dep->"return")
    :local request ($Dep->"request")
    :local payload
    :local path "dns"
    :local TTL 60
    :local USEIPV6 "false"
    :local IPV4WILDCARDALIAS "false"
    :local IPV6WILDCARDALIAS "false"
    if (! any $apiKey) do={ return [ $return error ("apiKey is not defined")] }
    if (! any $ipv4Address) do={ return [ $return error ("ipv4Address is not defined") ]}
    if (! any $domainName) do={ return [ $return error ("domainName is not defined") ]}
    if ( any $id ) do={ :set path ( $path . "/" . $id . "/" ) }
    if ( any $ttl ) do={ :set TTL $ttl }
    if ( any $ipv4WildcardAlias ) do={ :set IPV4WILDCARDALIAS $ipv4WildcardAlias }
    if ( any $ipv6Address ) do={ :set USEIPV6 "true" }
    if ( any $ipv6WildcardAlias ) do={ :set IPV6WILDCARDALIAS $ipv6WildcardAlias }
    set payload ("{\"ipv4Address\":\"$ipv4Address\",\"name\": \"$domainName\",\"ipv6Address\":\"$ipv6Address\",\"ttl\": $TTL,\"ipv4\": true,\"ipv6\": $USEIPV6,\"ipv4WildcardAlias\": $IPV4WILDCARDALIAS,\"ipv6WildcardAlias\": $IPV6WILDCARDALIAS}")
    return [$request path=$path apiKey=$apiKey method="post" payload=$payload Dep=$Dep]
}

# 更新子域域名记录
## 必须传入参数
### - id: Dynu dns ID
### - dnsRecordId: 子域的 ID
### - apiKey: Dyny api key
### - ipAddress: IP地址 可以是 ipv4 也可以是 ipv6 ，合法地址即可
### - nodeName: 子域名称如 www 
### - Dep: 函数依赖数组
## 可选传入参数
### - state: 记录是否启用字符串类型的布尔值 ["true"|"false"] 默认："true"
### - ttl: 全球生效时间默认 60
### - group: 域名在 dynu 的分组名称，默认为字符串类型空值 ""

:local recordPost do={
    :local logTag "recordPost"
    if ( ! any $Dep ) do={ :error message=("[$logTag] Dep(Dependency) is not defined!")}
    :local return ($Dep->"return")
    :local request ($Dep->"request")
    :local payload
    :local path ( "dns/$id/record/$dnsRecordId" )
    :local TTL 60
    :local GROUP ""
    :local STATE "true"
    if (! any $apiKey) do={ return [ $return error ("apiKey is not defined")] }
    if (! any $dnsRecordId) do={ return [ $return error ("dnsRecordId is not defined") ]}
    if (! any $id) do={ return [ $return error ("id is not defined") ]}
    if (! any $ipAddress) do={ return [ $return error ("ipAddress is not defined") ]}
    if (! any $nodeName) do={ return [ $return error ("nodeName is not defined") ]}
    if ( any $ttl ) do={ :set TTL $ttl }
    if ( any $state ) do={ :set STATE $state }
    if ( any $group ) do={ :set GROUP $group }
    :set payload "{\"nodeName\":\"$nodeName\",\"ttl\":$TTL,\"state\":$STATE,\"group\":\"$GROUP\","
    if (any [toip $ipAddress]) do={
        :set payload ( $payload . "\"recordType\":\"A\",\"ipv4Address\":\"$ipAddress\"}" )
    } else={
        if (any [toip6 $ipAddress]) do={
            :set payload ( $payload . "\"recordType\":\"AAAA\",\"ipv6Address\":\"$ipAddress\"}" )
        } else={
            $return error ("ipaddress($ipAddress) is not a valid IP address.")
        }
    }
    return [$request path=$path apiKey=$apiKey method="post" payload=$payload Dep=$Dep]
}

return {
    "moduleName"="Dynu";
    "dnsPost"=$dnsPost;
    "recordPost"=$recordPost;
    "Dep"={
        "request"=$request;
        "return"=$return;
        "logger"=$logger
    }
}