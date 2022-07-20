# 脚本依赖：Module logger Wecom Dynu

# DDNS::Config 全局 DDNS 服务商配置
    # ddnsServices: 数组，是否启用某个 ddns 服务，enable 则启用，其余字符串一律不启用
    # 同个服务多个配置可以使用 dynu_1 dynu_2 这种写法，ddnsService 里面也需要修改对应名称。
    # Dynu 配置信息
        # apiKey:访问以下网站获取 dynuApiKey https://www.dynu.com/en-US/ControlPanel/APICredentials
        # domainId:通过以下 Linux 命令获取你域名的 id
        #    curl -X GET https://api.dynu.com/v2/dns -H "accept: application/json" -H "API-Key: <这里写你的 APIKEY>"
        # domainName:就是你获得的 ddns 域名
    # pubyun 配置信息（该服务商不支持 ipv6）
        # user：注册用户名
        # password： 密码
        # domain：DDNS 域名
:global "DDNS::Config" {
    "ddnsServices"={
        "dynu_1"="enable";
        "dynu_2"="enable";
        "pubyun"="disable"
    };
    "dynu_1"={
        "apiKey"="<apiKey>";
        "domainId"="<domainId>";
        "domainName"="<domainName>";
        "useIpv6"=true;
    };
    "dynu_2"={
        "apiKey"="<apiKey>";
        "domainId"="<domainId>";
        "domainName"="<domainName>";
        "useIpv6"=false;
    };
    "pubyun"={
        "user"="<yourUserName>";
        "password"="<yourPassword>";
        "domain"="<yourDomain>"
    };
}

# 脚本日志级别
:local logLevel "DEBUG"
# 是否使用 IPV6
:local useIPv6 true
# 这是你需要对外服务器 IPV6 主机位
## 例如你主机获取到的公网IPV6是 <240e:fb2:fff0:1f20:42d:6dff:fbf3:f2e2/64>
## 那么这里就写 “42d:6dff:fbf3:f2e2”
:local ipv6Suffix "<ipv6Suffix>"
# 是否把 ip 地址添加到防火墙 Address-list中，方便做一些防火墙策略，例如 nat loopback
:local isAddToAddressList true
# 支持多组 ipv6 和 comment，写法是 key 为 comment， ipv6 后缀为 value 
:local ipv6AddToAddress {
    "wan-ipv6-1"="42d:6dff:fbf3:f2e2";
    "wan-ipv6-2"="42d:6dff:fbf3:ff22"
}
:local ipv4Comment "wan-ip"

# 如果有多个 pppoe 请指定接口名字,如果希望脚本自动获取请留空即可
# :local pppoeInterfaceName "<pppoe interface name>"

# 只需要修改上面的参数

# ddns 服务商推送脚本调用
:local updateScripts {
    "dynu"=":put \"runScript runing\"
            :global \"Module::import\"
            \$\"Module::import\" Dynu \$scriptName
            :global \"Dynu::push\"
            :global \"DDNS::Config\"
            :local config (\$\"DDNS::Config\"->\$configName)
            :local useIpv6 (\$config->\"useIpv6\")
            :local result
            :put \"ipv6:\$ipv6Address\"
            :if (\$useIpv6 = \"false\") do={
                :put \"ipv6 disable\";
                set result [\$\"Dynu::push\" apiKey=(\$config->\"apiKey\") domainId=(\$config->\"domainId\") domainName=(\$config->\"domainName\") ipv4Address=\$ipv4Address]
            } else={
                set result [\$\"Dynu::push\" apiKey=(\$config->\"apiKey\") domainId=(\$config->\"domainId\") domainName=(\$config->\"domainName\") ipv4Address=\$ipv4Address ipv6Address=\$ipv6Address]
            }
            :global \"Module::remove\"
            \$\"Module::remove\" Dynu \$scriptName
            return \$result"
    "pubyun"=":global \"DDNS::Config\";
            :local result
            :local config (\$\"DDNS::Config\"->\$configName)
            :put [:tostr \$config]
            :local apiUrl \"http://members.3322.org/dyndns/update\?\"
            :local payload (\"hostname=\" . (\$config->\"domain\") . \"&myip=\" . \$ipv4Address)
            :set apiUrl (\$apiUrl . \$payload)
            do {
                set result [/tool fetch url=\$apiUrl mode=http user=(\$config->\"user\") password=(\$config->\"password\") output=user as-value]
            } on-error={
                return {
                    \"result\"=false;
                    \"logMessage\"=\"Failed to update IP address!\";
                }
            }
            if ( [typeof [ find (\$result->\"data\") \"good\" ]] != \"num\" )do={
                if ([typeof [ find (\$result->\"data\") \"nochg\" ]] != \"num\" ) do={
                    return {
                        \"result\"=false;
                        \"logMessage\"=(\"Failed to update IP address! \" . (\$result->data));
                    }
                }
            }
            return {
                \"result\"=true;
            }"
}

# import global variable
:global wanIpv4Address;
:global wanIpv6Prefix;
# 微信推送标记，防止重复推送
:global "DDNS::WecomMsg" ({})
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
# 设置模块日志级别-如果需要 debug 模块请取消注释，在控制台执行脚本
:global  scriptLogLevel
:set ($scriptLogLevel->"modulesLevel"->$logTag) ($scriptLogLevel->"$logLevel")

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

$logger debug ("[$logTag] ipv4G:$wanIpv4Address, ipv4L:$ipv4Address")
$logger debug ("[$logTag] ipv6G:$wanIpv6Prefix, ipv6L:$ipv6Prefix")
if ($wanIpv4Address != $ipv4Address || $wanIpv6Prefix != $ipv6Prefix) do= {

    # 将 ip 地址放入 address-list 方便做策略
    if ($isAddToAddressList) do={
        $addToAddresList $ipv4Address $ipv4Comment
        if ($useIPv6) do={
            foreach ipv6Comment,ipv6Suffix in=$ipv6AddToAddress do={
                $addToAddresList ("$ipv6Prefix:$ipv6Suffix") $ipv6Comment
            }
        }
    }

    # 更新所有 ddns 服务
    :foreach ddnsServiceName,isEnable in=($"DDNS::Config"->"ddnsServices") do={
        if ($isEnable = "enable" || $isEnable = "ENABLE") do={
            # 如果 ddnsServiceName 是 "dynu_1" 这种格式，则需提取服务
            :local name
            if ([:find $ddnsServiceName "_"]) do={
                :set name [:pick $ddnsServiceName 0 [find $ddnsServiceName "_"]]
            } else={
                :set name $ddnsServiceName
            }
            $logger debug ("[$logTag] configName is $name")
            :local scriptResult
            :local ddnsRun [:parse ($updateScripts->$name);]
            set scriptResult [$ddnsRun  ipv4Address=$ipv4Address ipv6Address=$ipv6Address scriptName=$scriptName configName=$ddnsServiceName]
            if (! ($scriptResult->"result")) do={
                $logger error ("[$logTag] " . ($scriptResult->"logMessage"))
                if (($"DDNS::WecomMsg"->"$ddnsServiceName") = "NOTSET") do={
                    $"Wecom::send" ("## \E2\9D\8C DDNS update fail!\nDDNS Service **[$ddnsServiceName]** update fail! Log messige:\n>" . ($scriptResult->"logMessage")) markdown="true"
                    set ($"DDNS::WecomMsg"->"$ddnsServiceName") "DDNS update fail!"
                }
                :error message=("[$ddnsServiceName] error:" . ($scriptResult->"logMessage"))
            } else {
                set ($"DDNS::WecomMsg"->"$ddnsServiceName") "NOTSET"
            }
            # 同一服务商请求过快会导致请求失败
            :delay 2s;
        }
    }
    :set wanIpv4Address $ipv4Address;
    if ($useIPv6) do={
        :set wanIpv6Prefix $ipv6Prefix;
        $"Wecom::send" ("### \E2\9C\85 ddns update task complete\n ### $wanInterfaceName\n- **ipv4 address:** $wanIpv4Address\n- **ipv6 suffix:** $wanIpv6Prefix") markdown="true"
    } else={
        $"Wecom::send" ("### \E2\9C\85 ddns update task complete\n ### $wanInterfaceName\n- **ipv4 address:** $wanIpv4Address") markdown="true"
    }
    if ($wanIpv4Address in 100.64.0.0/10) do={
        $"Wecom::send" ("\E2\9D\97 ##ip address is not public ip\n>$wanInterfaceName ipv4 address is $wanIpv4Address, this address is not a public IP address, please contact the telecom operator.") markdown="true"
    }
} else={
    $logger debug ("[$logTag] IP address is up to date.")
}

# Remove module
$"Module::remove" Dynu $scriptName
$"Module::remove" Wecom $scriptName
$"Module::remove" logger $scriptName