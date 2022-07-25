# 更新获取 wan 口的 IPv4 和 IPv6 前缀地址，根据需要拼接成最终 ip，将IP地址加入到防火墙地址列表，方便防火墙规则设定。
# 可以新建定时脚本，每分钟执行一次定时修改 wan-ip 列表
# /system scheduler
# add interval=1m name=update_wan_ip on-event=update_wan_ip policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-time=startup
:local PPPOEINTERFACES [/interface pppoe-client print as-value]
:local CONFIG {
    "ipv4ListName"= "wan-ip";
    "ipv6ListName"={
        "dsm_ip"={
            "fadb:cadf:fadb:dadb";
        };
        "omv_ip"={
            "edd8:cfff:feee:bbbb";
        };
    }
}
if ([:len $PPPOEINTERFACES] = 0) do={
    :error "pppoe interface not found!"
}

# Check ip in list
:local ifIpInList do={
    :local listname $1;
    :local ipAddress $2;
    :local cmdHead;
    :local cmd;
    :local getAddressListID
    :local getAddressListAddress
    # 如果是 ipv4
    if ([:toip $ipAddress]) do={
        :set ipAddress [:toip $ipAddress]
        :set cmdHead "/ip"
    }
    # 如果是 ipv4=6
    if ([:toip6 $ipAddress]) do={
        :set ipAddress [:toip6 $ipAddress]
        :set cmdHead "/ipv6"
    }
    # 传入的 IP 地址不合法
    if ( ! any $cmdHead ) do={
        :error ("error [ifIpInList] ipaddress($ipAddress) is not a valid IP address.")
    }
    :set getAddressListID [:parse ("$cmdHead firewall address-list find where list=$listname") ]
    # 遍历 list 里面的 ip 比对
    :foreach id in=[$getAddressListID] do={
        :set getAddressListAddress [:parse ("$cmdHead firewall address-list get $id address") ]
        :local listIpAddr [$getAddressListAddress]
        :local ipv6SlashPos [ find $listIpAddr "/"]
        if ( any $ipv6SlashPos) do={
            :set listIpAddr [ toip6 [:pick $listIpAddr 0 $ipv6SlashPos]]
        } else={
            :set listIpAddr [ toip $listIpAddr ]
        }
        if ($ipAddress = $listIpAddr) do={
            return true
        }
    }
    return false
}

:local applyIpv4AddressList do={
    :local currentIP [/ip address get  [find interface=$interfaceName] address]
    :set currentIP [:pick $currentIP 0 [:find $currentIP "/"]];
    if (! [$ifIpInList $listName $currentIP]) do={
        # Interface address not in the list
        if ([:len [/ip firewall address-list find where ( comment=$interfaceName list=$listName)]] = 0) do={
            :put "[applyIpv4AddressList] Add interface:$interfaceName ip:$currentIP to address-list:$listName."
            /ip firewall address-list add list=$listName address=$currentIP comment=$interfaceName
        } else={
            :put "[applyIpv4AddressList ]Set interface:$interfaceName ip:$currentIP to address-list:$listName."
            /ip firewall address-list set [ find list=$listName comment=$interfaceName] address=$currentIP 
        }
    } else={
        :put "[applyIpv4AddressList] No change in interface($interfaceName) address"
    }
}

:local applyIpv6AddressList do={
    :local ipv6Prefix [/ipv6 dhcp-client get  [find interface=$interfaceName] prefix]
    :set ipv6Prefix [:pick $ipv6Prefix 0 [:find $ipv6Prefix "::" ]];
    foreach listName,ipv6SuffixList in=$ipv6ListName do={
        :foreach ipv6Suffix in=$ipv6SuffixList do={
            :local currentIP ("$ipv6Prefix:$ipv6Suffix")
            if (! [$ifIpInList $listName $currentIP]) do={
                # Interface address not in the list
                if ([:len [/ipv6 firewall address-list find where ( comment=$interfaceName list=$listName)]] = 0) do={
                    :put "Add interface:$interfaceName ip:$currentIP to address-list:$listName."
                    /ipv6 firewall address-list add list=$listName address=$currentIP comment=$interfaceName
                } else={
                    :put "Set interface:$interfaceName ip:$currentIP to address-list:$listName."
                    /ipv6 firewall address-list set [ find list=$listName comment=$interfaceName] address=$currentIP 
                }
            } else={
                :put "[applyIpv6AddressList] No change in interface($interfaceName) address"
            }
        }
    }
}

:for i from=0 to=([:len $PPPOEINTERFACES] - 1) do={
    :local interfaceName ($PPPOEINTERFACES->$i->"name")
    $applyIpv4AddressList interfaceName=$interfaceName listName=($CONFIG->"ipv4ListName") ifIpInList=$ifIpInList
    $applyIpv6AddressList interfaceName=$interfaceName ipv6ListName=($CONFIG->"ipv6ListName") ifIpInList=$ifIpInList
}
