# Dynu 更新 DDNS 脚本
# 脚本依赖 Module logger
# local variable
:local logTag "Dynu"
:local scriptName $logTag

# import Module
:global "Module::import"
if ( !any $"Module::import" ) do={
    do {/system script run [find name=Module]} on-error={:error "Script Module not found!"}
}
:global "Module::remove"
:global scriptLogLevel
:set ($scriptLogLevel->"modulesLevel"->$logTag) ($scriptLogLevel->"INFO")

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

    # function main
    # 检查 Function 传入变量是否存在
    if (!any $apiKey) do={ logger error ("[$logTag] apiKey is not defined"); :error}
    if (!any $domainId) do={ logger error ("[$logTag] domainId is not defined"); :error}
    if (!any $domainName) do={ logger error ("[$logTag] domainName is not defined"); :error}
    if (!any $ipv4Address) do={ logger error ("[$logTag] ipv4Address is not defined"); :error}

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
        set result [/tool fetch url=$apiUrl mode=https output=user http-method=post http-header-field=$header http-data=$payload as-value]
        set resultStr [:tostr $result]
    } on-error={
        $logger error ("[$logTag] Failed to update IP address! result:$resultStr") 
        return {"result"=false; "logMessage"=("[$logTag] Failed to update IP address! result:$resultStr");}
    }
    $logger debug ("[$logTag] result:$resultStr");
    if (($result->"data") != "{\"statusCode\":200}") do={
        $logger error ("[$logTag] Failed to update IP address! error:" . $result->"data") 
        return {"result"=false; "logMessage"=("[$logTag] Failed to update IP address! error:" . $result->"data");}
    }
    $"Module::remove" logger $scriptName
    return {"result"=true;}
}