# Dynu 更新 DDNS 脚本
# 脚本依赖 Module logger
# local variable
:local logTag "Dynu"
:local scriptName $logTag
# 脚本日志级别
:local logLevel "DEBUG"

# import Module
:global "Module::import"
if ( !any $"Module::import" ) do={
    do {/system script run [find name=Module]} on-error={:error "Script Module not found!"}
}
:global "Module::remove"
:global scriptLogLevel
:set ($scriptLogLevel->"modulesLevel"->$logTag) ($scriptLogLevel->"$logLevel")

$logger debug ("[$logTag] Dynu loading.")

# 向 dynu 推送新的 ip 地址
## 使用方法：
## :global "Dynu::push"
## $"Dynu::push" <apiKey=$apiKey> <domainId=$domainId> <domainName=$domainName> <ipv4Address=$ipv4Address> [ipv6Address=$ipv6Address]
## 返回值：
### - result：布尔值，确认推送状态
### - logMessage：错误日志内容，如果有错误则返回
## 范例：
### set pushResult [$"Dynu::push" apiKey="apiKey" domainId="domainId" domainName="domainName" ipv4Address=$ipv4Address ipv6Address=$ipv6Address]
### if (! ($pushResult->"result")) do={
###     :error message=($pushResult->"logMessage")
### }
:global "Dynu::push" do={
    :global "Module::import"
    :local logTag "Dynu::push"
    :local scriptName $logTag
    $"Module::import" logger $scriptName
    :global logger
    :local apiUrl
    :local payload 
    :local header
    :local result
    :local resultStr

    # 脚本返回函数
    ## 错误信息记录日志，其余一律返回一个焊油 result 为 true 的 array
    :local funcReturn do={
        :global logger
        :local msg
        if (any $2 and $1 = "error") do={
            set msg $2
            $logger error ("[$logTag] $msg")
            return {
                "result"=false;
                "logMessage"=$msg
            }
        }
        return {"result"=true;}
    }

    # function main
    # 检查 Function 传入变量是否正确
    if (!any $apiKey) do={ return [ $funcReturn error "apiKey is not defined" ]}
    if (!any $domainId) do={ return [ $funcReturn error "domainId is not defined" ]}
    if (!any $domainName) do={ return [ $funcReturn error "domainName is not defined" ]}
    if (!any $ipv4Address or [typeof [toip $ipv4Address]] != "ip" ) do={ 
        return [ $funcReturn error "The ipv4Address setting is wrong, please check the configuration." ]
    }
    if (any $ipv6Address) do={
        if ([ typeof [ toip6 $ipv6Address ] ] != "ip6") do={
            return [ $funcReturn error "The ipv6Address setting is wrong, please check the configuration." ]
        }
    }

    $logger info ("[$logTag] Start DDNS update. ipv4:$ipv4Address ipv6:$ipv6Address");
    :set apiUrl "https://api.dynu.com/v2/dns/$domainId";
    if ([typeof [:toip6 $ipv6Address]] = "ip6") do={
        set payload "{\"ipv4Address\":\"$ipv4Address\",\"name\": \"$domainName\",\"ipv6Address\":\"$ipv6Address\",\"ttl\": 60,\"ipv4\": true,\"ipv6\": true,\"ipv4WildcardAlias\": true,\"ipv6WildcardAlias\": true}"
    } else={
        set payload "{\"ipv4Address\":\"$ipv4Address\",\"name\": \"$domainName\",\"ipv6Address\":\"\",\"ttl\": 60,\"ipv4\": true,\"ipv6\": false,\"ipv4WildcardAlias\": true,\"ipv6WildcardAlias\": false}"
    }
    :set header "API-Key:$apiKey,accept:application/json"
    $logger debug ("[$logTag] apiUrl:$apiUrl, header:$header payload:$payload");
    do {
        $logger debug ("[$logTag] tool fetch url=$apiUrl mode=https output=user http-method=post http-header-field=$header http-data=$payload as-value")
        set result [/tool fetch url=$apiUrl mode=https output=user http-method=post http-header-field=$header http-data=$payload as-value]
        set resultStr [:tostr $result]
    } on-error={
        return [$funcReturn error "Failed to update IP address!"]
    }
    $logger debug ("[$logTag] result:$resultStr");
    if (($result->"data") != "{\"statusCode\":200}") do={
        return [$funcReturn error ("Failed to update IP address! error:" . $result->"data")]
    }
    $"Module::remove" logger $scriptName
    return [$funcReturn]
}