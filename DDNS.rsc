# 脚本依赖：Module logger Wecom Dynu

# CONFIG 全局 DDNS 服务商配置
    # 服务名称: 数组，自定义命名，如果修改过配置，最好修改一下名字，否则可能只有 IP 变了才会生效。
    # type： 使用什么 DDNS 服务商类型，目前支持 Dynu DynuRecord Pubyun
    # enable： 是否启用该服务
    # ipv6： 数组（可选）
    #   - enable：布尔值，是否启用ipv6[true|false]
    #   - ipv6Suffix：对外服务的 IPv6 IP地址固定后缀
    # Dynu 配置信息
    #   - apiKey:访问以下网站获取 dynuApiKey https://www.dynu.com/en-US/ControlPanel/APICredentials
    #   - domainId:通过以下 Linux 命令获取你域名的 id
    #      > curl -X GET https://api.dynu.com/v2/dns -H "accept: application/json" -H "API-Key: <这里写你的 APIKEY>"
    #   - domainName:就是你获得的 ddns 域名
    #   - ttl: 域名全球生效时间（可选） 默认 60，最小 60，单位为秒
    #   - ipv4 数组
    #       - enable： 是否启用，如果 type 为 Dynu 则无视此配置，无论设什么都是启用
    #       - interfaceName： 从哪个公网接口获取IPv4地址提交给这个域名，如果 type 为 Dynu 此项没有配置的话，默认推送第一个接口
    #   - ipv6 数组
    #       - enable： 是否启用，如果 type 为 Dynu 则无视此配置，无论设什么都是启用
    #       - ipv6Suffix 对外服务的 ipv6 地址后缀
    #       - interfaceName： 从哪个公网接口获取IPv6前缀提交给这个域名，如果 type 为 Dynu 此项没有配置的话，默认推送第一个接口
    # DynuRecord 配置
    #   > Dynu 是支持修改某个 DDNS 域名的记录，支持三级以下自定义记录。
    #   > 你需要自己先去创建一个 Record 然后通过下面命令获得 RecordID
    #   > 同一个域名是支持多个 Record，如果你又多个公网IP，可以通过此接口上传ip
    #   - apiKey:访问以下网站获取 dynuApiKey https://www.dynu.com/en-US/ControlPanel/APICredentials
    #   - domainId:通过以下 Linux 命令获取你域名的 id
    #   > curl -X GET https://api.dynu.com/v2/dns -H "accept: application/json" -H "API-Key: <这里写你的 APIKEY>"
    #   - domainName:就是你获得的 ddns 域名
    #   - nodeName: 域名前缀名字，可以写多级域名例如 a.b.c.d，如果你dynu 后缀是 "example.accesscam.org" 那么最终域名就是 a.b.c.d.example.accesscam.org
    #   - ipv4 数组 (type 为 DynuRecord,ipv4 和 ipv6 只能设一个，两个都设的话，默认上传 ipv4)
    #       - enable： 是否启用，如果 type 为 Dynu 则无视此配置，无论设什么都是启用
    #       - interfaceName： 从哪个公网接口获取IPv4地址提交给这个域名，如果 type 为 Dynu 此项没有配置的话，默认推送第一个接口
    #   - ipv6 数组 (type 为 DynuRecord,ipv4 和 ipv6 只能设一个，两个都设的话，默认上传 ipv4)
    #       - enable： 是否启用，如果 type 为 Dynu 则无视此配置，无论设什么都是启用
    #       - ipv6Suffix 对外服务的 ipv6 地址后缀
    #       - interfaceName： 从哪个公网接口获取IPv6前缀提交给这个域名，如果 type 为 Dynu 此项没有配置的话，默认推送第一个接口
    #   - dnsRecordId: 通过以下 Linux 命令获取 RecordId 
    #   >  curl -X GET https://api.dynu.com/v2/dns/<domainId>/record -H "accept: application/json" -H "API-Key: <这里写你的 APIKEY>"
    #   > 上面命令返回的 id 就是 RecordID
    # pubyun 配置信息（该服务商不支持 ipv6）
    #    - user：注册用户名
    #    - password： 密码
    #    - domain：DDNS 域名
:local CONFIG {
    "dynu_v4_v6"={
        "type"="Dynu";
        "enable"=true;
        "apiKey"="apiKey";
        "domainId"="domainId";
        "domainName"="domainName";
        "ipv4"={
            "enable"=true;
            "interfaceName"="pppoe-out1";
        }
        "ipv6"={
            "enable"=true;
            "interfaceName"="pppoe-out1";
            "ipv6Suffix"="ipv6Suffix";
        }
    };
    "dynu_v4"={
        "type"="DynuRecord";
        "enable"=true;
        "apiKey"="apiKey";
        "domainId"="domainId";
        "dnsRecordId"="dnsRecordId";
        "nodeName"="ipv4";
        "ttl"="60";
        "ipv4"={
            "enable"=true;
            "interfaceName"="pppoe-out1";
        }
    };
    "dynu_v6"={
        "type"="DynuRecord";
        "enable"=true;
        "apiKey"="apiKey";
        "domainId"="domainId";
        "dnsRecordId"="dnsRecordId";
        "nodeName"="ipv6";
        "ttl"="60";
        "ipv6"={
            "enable"=true;
            "interfaceName"="pppoe-out1";
            "ipv6Suffix"="ipv6Suffix";
        }
    };
    "pubyun"={
        "type"="Pubyun";
        "enable"=false;
        "user"="user";
        "password"="password";
        "domain"="domain";
        "ipv4"={
            "enable"=true;
            "interfaceName"="pppoe-out1";
        }
    };
}

# global variable
# 存储任务状态变量
:global ddnsTaskState;if ( ! any $ddnsTaskState) do={ :set ddnsTaskState {"taskRun"=true} }

# local variable
:local logTag "DDNS"
:local scriptName $logTag
# 脚本日志级别
:local logLevel "DEBUG"

# Load module
:global loadModule; if ( !any $loadModule ) do={
    do {/system script run [find name=loadModule]} on-error={:error "Script loadModule not found!"}
}

# import logger
:local logger ([ $loadModule logger init=({"logTag"=$logTag;"level"=$logLevel;}) ]->"logger")

# import Wecom
:local WecomArr [ $loadModule Wecom ]
:local WecomSend ($WecomArr->"send")
:local WecomDep ($WecomArr->"Dep")

# local function
# 获取接口 ipv4 地址
## 可选参数
#   - $1 如果没有传入第一餐宿是空的，则默认获取 pppoe 第一个结果
:local getPPPoeIPv4Addr do={
    :local logTag "getPPPoeIPv4Addr"
    if ( ! any $Dep ) do={ :error message=("[DDNSv2] [$logTag] Dep(Dependency) is not defined!") }
    :local logger ($Dep->"logger")
    :local ipAddress
    :local INTERFACENAME
    if ( any $1 ) do={
        :set INTERFACENAME $1
    } else={
        $logger debug ("[$logTag] !!!Warning!!! interfaceName is not defined, \
                default value applied (PPPOE first interface)")
        :do {
            :set INTERFACENAME ([ /interface pppoe-client print as-value where running=yes ]->0->"name")
        } on-error={
            $logger error ("[$logTag] No available pppoe interface found!")
            return $ipv6Prefix
        }
    }
    :do {
        :set ipAddress [/ip address get  [find interface=$INTERFACENAME] address]
        :set ipAddress [:pick $ipAddress 0 [:find $ipAddress "/"]];
    } on-error={
        $logger error ("[$logTag] Failed to get IP address from $INTERFACENAME interface")
        return $ipAddress
    }
    $logger debug ("[$logTag] IPv4 address ($ipAddress) from $INTERFACENAME")
    return $ipAddress
}

# 获取接口 ipv6 前缀，
## 可选参数
#   - $1 如果没有传入第一餐宿是空的，则默认获取 pppoe 第一个结果
:local getPPPoeIPv6Prefix do={
    :local logTag "getPPPoeIPv6Prefix"
    if ( ! any $Dep ) do={ :error message=("[DDNSv2] [$logTag] Dep(Dependency) is not defined!") }
    :local ipv6Prefix 
    :local INTERFACENAME
    :local logger ($Dep->"logger")
    if ( any $1 ) do={
        :set INTERFACENAME $1
    } else={
        $logger debug ("[$logTag] !!!Warning!!! interfaceName is not defined, default value applied \
                (PPPOE first interface)")
        :do {
            :set INTERFACENAME ([ /interface pppoe-client print as-value where running=yes ]->0->"name")
        } on-error={
            $logger error ("[$logTag] No available pppoe interface found!")
            return $ipv6Prefix
        }
    }
    :do {
        :set ipv6Prefix [/ipv6 dhcp-client get  [find interface=$INTERFACENAME] prefix]
        :set ipv6Prefix [:pick $ipv6Prefix 0 [:find $ipv6Prefix "::" ]];
    } on-error={
        $logger error ("[$logTag] Failed to get IP address from $INTERFACENAME interface")
        return $ipv6Prefix
    }
    $logger debug ("[$logTag] IPv6 prefix ($ipv6Prefix) from $INTERFACENAME")
    return $ipv6Prefix
}

# 统一返回接口
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

# Dynu
## 传入参数
#   - config 单个 dynu 配置数组 example： config=($CONFIG->"dynu_1")
#   - Dep 数组 方便调用脚本其他函数 [ $(Dep->"getIPv4") ]
:local dynu do={
    # logger setting
    :local functionName "dynu"
    :local logTag $functionName
    if ( ! any $Dep ) do={ :error message=("[$logTag] Dep(Dependency) is not defined!") }
    # import local dependency
    :local logger ($Dep->"logger")
    :local return ($Dep->"return")
    :local getIPv4 ($Dep->"getIPv4")
    :local getIPv6Prefix ($Dep->"getIPv6Prefix")
    # import Dynu
    :local DynuArr [ :global loadModule; $loadModule Dynu ]
    :local dnsPost ($DynuArr->"dnsPost")
    :local recordPost ($DynuArr->"recordPost")
    :local DynuDep ($DynuArr->"Dep")
    # check config
    if ( ! any $config ) do={ return [ $return error ("<$functionName> config not defined!") ] }
    # get config variable
    :local type ($config->"type")
    :local apiKey ($config->"apiKey")
    :local domainId ($config->"domainId")
    # 检查 config 参数是否正确
    if ( ! any $type ) do={ return [ $return error ("<$functionName> type not defined! config:$config") ] }
    if ( ! any $apiKey ) do={ return [ $return error ("<$functionName> apiKey not defined! config:$config") ] }
    if ( ! any $domainId ) do={ return [ $return error ("<$functionName> domainId not defined! config:$config") ] }
    # 设定 notMatchType 标签，默认为 true 方便方法最后判断是否匹配 type
    :local notMatchType true
    :local returnResult
    # Dynu dns post
    if ( $type = "Dynu" ) do={
        :set notMatchType false
        :set logTag ("$logTag::Dynu")
        :local domainName ($config->"domainName")
        :local ipv4InterfaceName ($config->"ipv4"->"interfaceName")
        :local ipv6InterfaceName
        :local ipv4 [ $getIPv4 $ipv4InterfaceName Dep=$Dep]
        # 检查 ipv4 是否正确，Dynu DNS 接口必须上传 ipv4
        if ( ! any [ toip $ipv4 ] ) do={
            return [ 
                $return error ("<$functionName> ipv4 address checksum failure. \
                                ipv4:$ipv4, interfaceName:$ipv4InterfaceName")
            ]
        }
        :local ipv6
        # 检查 ipv6 ，Dynu DNS 接口 ipv6 是可选参数
        if ( ($config->"ipv6"->"enable") || ($config->"ipv6"->"enable") = "true" ) do={
            :set ipv6InterfaceName ($config->"ipv6"->"interfaceName")
            :local ipv6Suffix ($config->"ipv6"->"ipv6Suffix")
            :set ipv6 ([ $getIPv6Prefix $ipv6InterfaceName Dep=$Dep ] . ":" . $ipv6Suffix )
            if ( ! any [ toip6 $ipv6 ] ) do={
                return [
                    $return error ("<$functionName> ipv6 address checksum failure. \
                                    ipv6:$ipv6, interfaceName:$ipv6InterfaceName, ipv6Suffix:$ipv6Suffix")
                ]
            }
        }
        $logger debug ("[$logTag] dnsPost full command:\
                        \$dnsPost \
                            id=$domainId \
                            apiKey=$apiKey \
                            ipv4Address=$ipv4 \
                            ipv6Address=$ipv6 \
                            domainName=$domainName \
                            Dep=\$DynuDep")
        # 如果 ipv6 是空，dnsPost 方法会自动禁用 ipv6
        :set returnResult [
            $dnsPost \
                id=$domainId \
                apiKey=$apiKey \
                ipv4Address=$ipv4 \
                ipv6Address=$ipv6 \
                domainName=$domainName \
                Dep=$DynuDep
        ]
        :set ($returnResult->"info") {
            "ipv4"=$ipv4;
            "ipv6"=$ipv6;
        }
        return $returnResult
    }

    # Dynu record post
    if ( $type = "DynuRecord" ) do={
        :set notMatchType false
        :local dnsRecordId ($config->"dnsRecordId")
        :local nodeName ($config->"nodeName")
        :local ipv4InterfaceName ($config->"ipv4"->"interfaceName")
        :local ipv6InterfaceName ($config->"ipv6"->"interfaceName")
        :local ipv6Suffix ($config->"ipv6"->"ipv6Suffix")
        :local ipAddress
        :local isIpv4 false;
        :local isIpv6 false;
        :local result
        :local info
        # 检查 record 配置
        if ( ! any $dnsRecordId ) do={ 
            return [ $return error ("<$functionName> dnsRecordId not defined! config:$config") ] 
        }
        if ( ! any $nodeName ) do={ 
            return [ $return error ("<$functionName> nodeName not defined! config:$config") ] 
        }
        # Determining ip type
        if ( ($config->"ipv4"->"enable") || ($config->"ipv4"->"enable") = "true" ) do={
            :set isIpv4 true;
        }
        if ( ($config->"ipv6"->"enable") || ($config->"ipv6"->"enable") = "true" ) do={
            :set isIpv6 true;
        }
        # 如果 ipv4 与 ipv6 都配置了，默认只生效 ipv4 配置
        if ( $isIpv4 ) do={
            :set ipAddress [ $getIPv4 $ipv4InterfaceName Dep=$Dep ]
            $logger debug ("[$logTag] Use ipv4 address:($ipAddress).")
            if ( ! any [ toip $ipAddress ] ) do={
                return [ 
                    $return error ("<$functionName> ipv4 address checksum failure. \
                        ipv4:$ipAddress, interfaceName:$ipv4InterfaceName")
                ]
            }
            :set ($info->"ipv4") $ipAddress
        } else={
            if ( $isIpv6 ) do={
                :set ipAddress ([ $getIPv6Prefix $ipv6InterfaceName Dep=$Dep ] . ":" . $ipv6Suffix )
                $logger debug ("[$logTag] Use ipv6 address:($ipAddress).")
                if ( ! any [ toip6 $ipAddress ] ) do={
                    return [
                        $return error ("<$functionName> ipv6 address checksum failure. \
                            ipv6:$ipAddress, interfaceName:$ipv6InterfaceName, ipv6Suffix:$ipv6Suffix")
                    ]
                }
            } else={
                return [
                    $return error ("<$functionName> No ipv4 or ipv6 configuration found, \
                        please check configuration. config:$config")
                ]
            }
            :set ($info->"ipv6") $ipAddress
        }
        $logger debug ("[$logTag] recordPost full command:\
            \$recordPost \
                id=$domainId \
                apiKey=$apiKey \
                dnsRecordId=$dnsRecordId \
                ipAddress=$ipAddress \
                nodeName=$nodeName \
                Dep=\$DynuDep
            ")
        :set returnResult  [
            $recordPost \
                id=$domainId \
                apiKey=$apiKey \
                dnsRecordId=$dnsRecordId \
                ipAddress=$ipAddress \
                nodeName=$nodeName \
                Dep=$DynuDep
        ]
        :set ($returnResult->"info") $info
        return $returnResult
    }
    if ( $notMatchType ) do={
        return [
            $return error ("<$functionName> Type($type) error, \
                Dynu only supports types (Dynu,DynuRecord).config:$config")
        ]
    }
}

# pubyun
:local pubyun do={
    :local functionName "pubyun"
    :local returnResult
    :local logTag $functionName
    if ( ! any $Dep ) do={ :error message=("[$logTag] Dep(Dependency) is not defined!") }
    # import local dependency
    :local logger ($Dep->"logger")
    :local return ($Dep->"return")
    :local getIPv4 ($Dep->"getIPv4")
    # import Pubyun
    :local PubyunArr [ :global loadModule; $loadModule "Pubyun" ]
    :local update ($PubyunArr->"update")
    :local PubyunDep ($PubyunArr->"Dep")
    # check config
    if ( ! any $config ) do={ return [ $return error ("<$functionName> config not defined!") ] }
    # get config variable
    :local user ($config->"user")
    :local password ($config->"password")
    :local domain ($config->"domain")
    if ( ! any $user ) do={ return [ $return error ("<$functionName> user not defined! config:$config") ] }
    if ( ! any $password ) do={ return [ $return error ("<$functionName> password not defined! config:$config") ] }
    if ( ! any $domain ) do={ return [ $return error ("<$functionName> domain not defined! config:$config") ] }
    :local ipv4InterfaceName ($config->"ipv4"->"interfaceName")
    :local ipv4 [ $getIPv4 $ipv4InterfaceName Dep=$Dep ]
    # 检查 ipv4 是否正确
    if ( ! any [ toip $ipv4 ] ) do={
        return [ 
            $return error ("<$functionName> ipv4 address checksum failure. \
                            ipv4:$ipv4, interfaceName:$ipv4InterfaceName")
        ]
    }
    $logger debug ("[$logTag] update full command:\
                    \$update \
                    user=$user \
                    password=$password \
                    domain=$domain \
                    ipaddress=$ipv4 \
                    Dep=\$PubyunDep")
    :set returnResult [
        $update \
            user=$user \
            password=$password \
            domain=$domain \
            ipaddress=$ipv4 \
            Dep=$PubyunDep
    ]
    :set ($returnResult->"info") {
        "ipv4"=$ipv4;
    }
    return $returnResult
}

# 检查任务状态
## 必须输入参数
## - taskName 任务名称
:local checkTaskState do={
    :local logTag "checkTaskState"
    :global ddnsTaskState;
    :local taskName $1
    if ( ! any taskName ) do={ :error message=(" [DDNSv2] [$logTag] taskName is not defined!") }
    if ( ! any ($ddnsTaskState->$taskName) ) do={
        :set ($ddnsTaskState->$taskName) true
    }
    return ($ddnsTaskState->$taskName)
}

# 对比 $ddnsTaskState->$name->"info" 与当前IP地址是否有变化
:local ipIsUpdate do={
    :local logTag "ipIsUpdate"
    if ( ! any $Dep ) do={ :error message=("[$logTag] Dep(Dependency) is not defined!") }
    :local logger ($Dep->"logger")
    :local CONFIG ($Dep->"CONFIG")
    :local strToBool ($Dep->"strToBool")
    :local getIPv4 ($Dep->"getIPv4")
    :local getIPv6Prefix ($Dep->"getIPv6Prefix")
    :global ddnsTaskState
    :foreach name,config in=$CONFIG do={
        # 服务是否使能
        if ( [ $strToBool ($config->"enable") ] ) do={
            # 如果当前任务未定义 ddnsTaskState 则需要更新
            if ( ! any ($ddnsTaskState->$name) ) do={
                set ($ddnsTaskState->$name->"update") true
            } else={
                # info 内如果有 ipv4 则对比其服务的值
                if ( any ($ddnsTaskState->$name->"info"->"ipv4") ) do={
                    :local ipv4 [ $getIPv4 ($config->"ipv4"->"interfaceName") Dep=$Dep ]
                    if ($ipv4 != ($ddnsTaskState->$name->"info"->"ipv4")) do={
                        $logger debug ("[$logTag] interface:" . \
                            ($config->"ipv4"->"interfaceName") . \
                            " Current IP:$ipv4 Info IP:" . ($ddnsTaskState->$name->"info"->"ipv4"))
                        set ($ddnsTaskState->$name->"update") true
                    }
                }
                # info 内如果有 ipv6 则对比其服务的值
                if ( any ($ddnsTaskState->$name->"info"->"ipv6") ) do={
                    :local ipv6Prefix [ $getIPv6Prefix ($config->"ipv6"->"interfaceName") Dep=$Dep ]
                    :local ipv6 ($ipv6Prefix . ":" . ($config->"ipv6"->"ipv6Suffix"))
                    if ($ipv6 != ($ddnsTaskState->$name->"info"->"ipv6")) do={
                        $logger debug ("[$logTag] interface:" . \
                            ($config->"ipv6"->"interfaceName") . \
                            " Current IP:$ipv6 Info IP:" . ($ddnsTaskState->$name->"info"->"ipv6"))
                        set ($ddnsTaskState->$name->"update") true
                    }
                }
            }
        }
    }
    :foreach task in=$ddnsTaskState do={
        if ( ($task->"update") = true ) do={
            :set ($ddnsTaskState->"taskRun") true
            return true
        }
    }
    :set ($ddnsTaskState->"taskRun") false
    return false
}

# 将字符串转为布尔值
:local strToBool do={
    if ( $1 = "true" or $1 = "True" or \
        $1 = "TRUE" or  $1 = true ) do={
        return true
    } else={
        return false
    }
}

# main
:local result
:local logMessage
# 传入 local function 依赖，方便在局部变量函数内调用脚本其他函数
:local Dep {
    "getIPv4"=$getPPPoeIPv4Addr;
    "getIPv6Prefix"=$getPPPoeIPv6Prefix;
    "return"=$return;
    "logger"=$logger;
    "CONFIG"=$CONFIG;
    "strToBool"=$strToBool;
}
# 检查是否需要更新IP
if ( ! [$ipIsUpdate Dep=$Dep] ) do={
    $logger debug "IP address is up to date"
    return "IP address is up to date"
}

# 数组存储微信推送逐行消息
:local WecomMsgArr [:toarray ""]
# 微信推送的标题
:set ($WecomMsgArr->[:len $WecomMsgArr]) "### DDNS Update tasks"
:local lastType
:local findType
:foreach serviceName,serviceConfig in=$CONFIG do={
    :set findType false
    # 如果 enable 是字符串类型则转为布尔值
    set ($serviceConfig->"enable") [ $strToBool ($serviceConfig->"enable"); ]
    if ( ($serviceConfig->"enable") && ($ddnsTaskState->$serviceName->"update") ) do={
        # Dynu in type
        if ( any [ find ($serviceConfig->"type") "Dynu" ] ) do={
            :set findType true
            $logger debug ("Start apply Dynu from $serviceName.")
            set lastType ($serviceConfig->"type")
            set result [ $dynu config=$serviceConfig Dep=$Dep]
        }
        # pubyun in type
        if ( any [ find ( $serviceConfig->"type") "Pubyun" ] ) do={
            :set findType true
            $logger debug ("Start apply Pubyun from $serviceName.")
            set lastType ($serviceConfig->"type")
            set result [ $pubyun config=$serviceConfig Dep=$Dep]
        }
        if ( ! $findType ) do={
            $logger error ("Service($serviceName) cannot find a matching type(" . ($serviceConfig->"type") . ")")
        } else={
            # DDNS服务更新失败
            if ( ($result->"result") = false ) do={
                :set logMessage ($result->"logMessage")
                :set ($WecomMsgArr->[:len $WecomMsgArr]) ("### \E3\80\90$serviceName\E3\80\91: \E2\9D\8C")
                :set ($WecomMsgArr->[:len $WecomMsgArr]) ("- errorLog:`$logMessage`")
                # 更新失败则设置更新标记，下次继续更新，info 信息存储在全局变量，方便对比IP是否改变。
                :set ($ddnsTaskState->$serviceName) {
                    "update"=true;
                    "info"=($result->"info")
                }
                $logger error ("$logMessage")
            } else={
                :set ($WecomMsgArr->[:len $WecomMsgArr]) ("### \E3\80\90$serviceName\E3\80\91: \E2\9C\85")
                # 更新完成则设置更新标记，不再更新，info 信息存储在全局变量，方便对比IP是否改变。
                :set ($ddnsTaskState->$serviceName) {
                    "update"=false;
                    "info"=($result->"info")    
                }
            }
            # 企业微信每个服务获取的推送 ip 地址信息
            if ( any ($result->"info"->"ipv4")) do={
                :set ($WecomMsgArr->[:len $WecomMsgArr]) ("- ipv4: " . ($result->"info"->"ipv4"))
            }
            if ( any ($result->"info"->"ipv6")) do={
                :set ($WecomMsgArr->[:len $WecomMsgArr]) ("- ipv6: " . ($result->"info"->"ipv6"))
            }
            # 添加微信推送报告
            :set ($WecomMsgArr->$WecomMsgPos) $WecomMsg
            # 防止频繁请求同一个服务，导致 api 访问超限
            if ($lastType = ($serviceConfig->"type")) do={ :delay 2s; }
        }
    }
}
:local WecomMsg
$logger debug ("============== WecomMsg ==============")
:foreach msg in=$WecomMsgArr do={
    if ( ! any $WecomMsg) do={
        :set WecomMsg ($msg . "\n")
    } else={
        :set WecomMsg ($WecomMsg . $msg ."\n")
    }
    :put $msg
}
$logger debug ("============== WecomMsg End ==============")
$WecomSend $WecomMsg Dep=$WecomDep markdown=true