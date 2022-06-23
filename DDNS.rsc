# 脚本依赖：Module logger Wecom Dynu

# Dynu 配置信息
    # apiKey:访问以下网站获取 dynuApiKey https://www.dynu.com/en-US/ControlPanel/APICredentials
    # domainId:通过以下 Linux 命令获取你域名的 id
    #    curl -X GET https://api.dynu.com/v2/dns -H "accept: application/json" -H "API-Key: <这里写你的 APIKEY>"
    # domainName:就是你获得的 ddns 域名
:local dynuConfig {
    "apiKey"="<apiKey>";
    "domainId"="<domainId>";
    "domainName"="<domainName>";
}

# 是否使用 IPV6
:local useIPv6 true
# 这是你需要对外服务器 IPV6 主机位
## 例如你主机获取到的公网IPV6是 <240e:fb2:fff0:1f20:42d:6dff:fbf3:f2e2/64>
## 那么这里就写 “42d:6dff:fbf3:f2e2”
:local ipv6Suffix "<ipv6Suffix>"
# 是否把 ip 地址添加到防火墙 Address-list中，方便做一些防火墙策略，例如 nat loopback
:local isAddToAddressList true
# 可选，设置 Address-list 的 comment
:local ipv6Comment "wan-ipv6"
:local ipv4Comment "wan-ip"

# 如果有多个 pppoe 请指定接口名字,如果希望脚本自动获取请留空即可
# :local pppoeInterfaceName "<pppoe interface name>"

# 只需要修改上面的参数

# import global variable
:global wanIpv4Address;
:global wanIpv6Prefix;

# local variable
:local logTag "DDNS"
:local scriptName $logTag

# import Module
:global "Module::import"
if ( !any $"Module::import" ) do={
    do {/system script run [find name=Module]} on-error={:error "Script Module not found!"}
}
:global "Module::remove"
$"Module::import" logger $scriptName
:global logger
$"Module::import" Wecom $scriptName
:global "Wecom::send"
$"Module::import" Dynu $scriptName
:global "Dynu::push"
# 设置模块日志级别-如果需要 debug 模块请取消注释，在控制台执行脚本
:global  scriptLogLevel
:set ($scriptLogLevel->"modulesLevel"->$logTag) ($scriptLogLevel->"DEBUG")

# 将 wan ip 加入 firewall address-list 方便做防火墙策略
:local addToAddresList do={
    :global logger
    :local logTag "DDNS::addToAddresList"
    :local addressStr $1
    :local commentStr $2
    if (!any $commentStr) do={
        $logger warning ("[$logTag] commentStr is not defined.")
        if (any [toip6 $addressStr]) do={
            set commentStr "wan-ipv6"
        } else={
            set commentStr "wan-ip"
        }
        $logger warning ("[$logTag] commentStr uses default settings: $commentStr.")
    }
    $logger debug ("[$logTag] Set the ip $addressStr to address-list, the comment is \"$commentStr\"")
    do {
        if (any [toip6 $addressStr]) do={
            if ([len [/ipv6 firewall address-list find comment=$commentStr]] != 0) do={
                /ipv6 firewall address-list set [find list=$commentStr comment=$commentStr] address=$addressStr;
            } else={
                /ipv6 firewall address-list add list=$commentStr comment=$commentStr address=$addressStr;
            };
        } else={
            if ([len [/ip firewall address-list find comment=$commentStr]] != 0) do={
                /ip firewall address-list set [find list=$commentStr comment=$commentStr] address=$addressStr;
            } else={ 
                /ip firewall address-list add list=$commentStr comment=$commentStr address=$addressStr;
            };
        }
    } on-error={
        $logger error ("[$logTag] Failed to set the ip $addressStr to address-list,the comment is \"$commentStr\".")
    }
}

# 获取 pppoe 接口名称
:local wanInterfaceName
if (any $pppoeInterfaceName) do={
    :set wanInterfaceName $pppoeInterfaceName
} else={
    :set wanInterfaceName [/interface get [/interface find type=pppoe-out] name]
    if (!any $wanInterfaceName) do={
        $logger error ("[$logTag] Failed to get pppoe Interface Name, please define <wanInterfaceName> variable.")
        :error
    }
}
# 通过 DHCPv6 Client 获取 ipv6 前缀
:local ipv6Prefix
if ($useIPv6) do={
    :set ipv6Prefix [/ipv6 dhcp-client get  [find interface=$wanInterfaceName] prefix]
    :set ipv6Prefix [:pick $ipv6Prefix 0 [:find $ipv6Prefix "::" ]];
}
# 获取pppoe 的IP地址
:local currentWanIP [/ip address get  [find interface=$wanInterfaceName] address];
if (!any $currentWanIP) do={
    $logger error ("[$logTag] Unable to find IP address from $wanInterfaceName!")
    :error ("[$logTag] Unable to find IP address from $wanInterfaceName!")
}
# 获取 ipv4
:local ipv4Address [:pick $currentWanIP 0 [:find $currentWanIP "/"]];
# 获取 ipv6
:local ipv6Address 
if ($useIPv6) do={
    :set ipv6Address "$ipv6Prefix:$ipv6Suffix"
}

$logger ("[$logTag] ipv4G:$wanIpv4Address, ipv4L:$ipv4Address")
$logger ("[$logTag] ipv6G:$wanIpv6Prefix, ipv6L:$ipv6Prefix")
if ($wanIpv4Address != $ipv4Address || $wanIpv6Prefix != $ipv6Prefix) do= {
    :local pushResult
    # 将 ip 地址放入 address-list 方便做策略
    if ($isAddToAddressList) do={
        $addToAddresList $ipv4Address $ipv4Comment
        if ($useIPv6) do={$addToAddresList $ipv6Address $ipv6Comment}
    }

    set pushResult [$"Dynu::push" apiKey=($dynuConfig->"apiKey") domainId=($dynuConfig->"domainId") domainName=($dynuConfig->"domainName") ipv4Address=$ipv4Address ipv6Address=$ipv6Address]
    if (! ($pushResult->"result")) do={
        $logger error ("[$logTag] Failed to submit address to Dynu.")
        :error message=($pushResult->"logMessage")
    }
    :set wanIpv4Address $ipv4Address;
    if ($useIPv6) do={
        :set wanIpv6Prefix $ipv6Prefix;
        $"Wecom::send" ("\F0\9F\9F\A6 $wanInterfaceName ipv4 address update to $wanIpv4Address, ipv6 suffix update to $wanIpv6Prefix")
    } else={
        $"Wecom::send" ("\F0\9F\9F\A6 $wanInterfaceName ipv4 address update to $wanIpv4Address")
    }
    if ($wanIpv4Address in 100.64.0.0/10) do={
        $"Wecom::send" ("\E2\9A\A0\EF\B8\8F $wanInterfaceName ipv4 address is $wanIpv4Address, this address is not a public IP address, please contact the telecom operator.")
    }
} else={
    $logger ("[$logTag] IP address is up to date.")
}

# Remove module
$"Module::remove" Dynu $scriptName
$"Module::remove" Wecom $scriptName
$"Module::remove" logger $scriptName