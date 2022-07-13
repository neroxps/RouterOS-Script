# 请手动添加添加 firware L7 协议识别
## /ip firewall layer7-protocol add name=ezviz2 regexp="(\\x05\\x20\\x52.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?.\?\\x71\\x01)|IMKH"
## /ip firewall add action=add-dst-to-address-list address-list=ezviz_dst address-list-timeout=1m chain=forward comment=ezviz layer7-protocol=ezviz2 log-prefix=ezviz src-address=<这里写你的NVRIP地址>

# 流量阈值 这里是 2Mbps=2*1000*1000
:local trafficThreshold (1*1000*1000)
# 监控的IP地址
:local ezvizIpAddress "10.89.2.1"
:local mqttBroker "hass"
:local TRUE 1
:local FALSE 0
:global "nvr::nvrRemoteLink";
:local connectionArray
:local connectionCount

# 根据实时流量阈值筛选链接
# 调用方法：$getConnections threshold=(200*1000)
:local getConnections do={
    :local connections [:toarray "";]
    :local conPos 0
    :local dstIps
    :local getIp do={
        return [:pick $1 0 [:find $1 ":"]]
    }
    :local getPort do={
        return [:pick $1 ([:find $1 ":"] + 1) [:len $1]]
    }
    # 获得有效的IP
    :local getVaildIp do={
        :local ipaddrIds [/ip firewall address-list find where (list="ezviz_dst")]
        :local ips ({})
        :local pos 0
        :local checkPrivateIp do={
            if ( ($1 in "192.168.0.0/16") || ($1 in "10.0.0.0/8") || ($1 in "172.16.0.0/12") ) do={
                return false
            }
            return true
        }
        :foreach id in=$ipaddrIds do={
            :local ip [/ip firewall address-list get value-name="address" $id]
            if ([$checkPrivateIp $ip]) do={
                :set ($ips->$pos) $ip
                :set pos ($pos+1)
            }
        }
        return $ips
    }
    :set dstIps [$getVaildIp]
    if ([:len $dstIps] = 0) do={
        return ({})
    }
    # 检查当前目的 IP 地址列表流量，超过阈值则加入 connections 数组
    :foreach dstIp in=$dstIps do={
        :put "Find ip $dstIp"
        :put "threshold:$threshold"
        :local ids 
        :do {
            set ids [/ip firewall connection find where (dst-address ~ $dstIp orig-rate > $threshold) ] 
        } on-error={
            set ids ({})
        }
        :put ("Match rule ids count:" . [:len $ids])
        if ([:len $ids] > 0) do={
            :put ("ids:" . [tostr $ids])
            :foreach id in=$ids do={
                :local dstAddress [/ip firewall connection get value-name="dst-address" $id]
                :local protocol [/ip firewall connection get value-name="protocol" $id]
                :local origRate [/ip firewall connection get value-name="orig-rate" $id]
                set ($connections->$conPos) {"ip"=[$getIp $dstAddress];"port"=[$getPort $dstAddress];"protocol"=$protocol;"origRate"=$origRate;}
                set conPos ($conPos + 1)
            }
        }
        :put ("connections:" . [tostr $connections])
        :put ("connections count:" . [:len $connections ])
    }
    return $connections
}

# 将 connections 数组对象转换为 Json 的数组
:local convertConnectionsToJsonString do={
    :local array $1
    :local jsonString "["
    # 查询 ip 归属地
    :local getIpRegion do={
        :local ip $1
        :local result
        :local data
        :local apiUrl "http://ip-api.com/json/$ip"
        :local checkStatus do={
            :local json $1
            :local status [:pick $json ([:find $json "\"status\""] + 10) [:find $json "\",\"country\""]]
            if ($status = "success") do={
                return true
            }
            return false
        }
        # :local getCountry do={
        #     :local json $1
        #     :local country [:pick $json ([:find $json "\"country\":\""] + 11) [:find $json "\",\"countryCode\""]]
        #     return $country
        # }
        :local getCountryCode do={
            :local json $1
            :local country [:pick $json ([:find $json "\"countryCode\":\""] + 15) [:find $json "\",\"region\""]]
            return $country
        }
        # :local getRegionName do={
        #     :local json $1
        #     :local regionName [:pick $json ([:find $json "\"regionName\":\""] + 14) [:find $json "\",\"city\""]]
        #     return $regionName
        # }
        :local getRegion do={
            :local json $1
            :local regionName [:pick $json ([:find $json "\"region\":\""] + 10) [:find $json "\",\"regionName\""]]
            return $regionName
        }
        :local getCity do={
            :local json $1
            :local city [:pick $json ([:find $json "\"city\":\""] + 8) [:find $json "\",\"zip\""]]
            return $city
        }
        set result [/tool fetch url=$apiUrl mode=https output=user as-value]
        if ( (($result->"status") != "finished") || (! [$checkStatus ($result->"data")]) ) do={
            if ([:len ($result->"data")] > 0) do={
                :put ($result->"data")
            }
            return "Failed"
        }
        :set data ($result->"data")
        return ([$getCountryCode $data] . "." . [$getRegion $data] . "." . [$getCity $data])
    }
    :foreach connectioned in=$array do={
        :local ip ($connectioned->"ip")
        :local port ($connectioned->"port")
        :local protocol ($connectioned->"protocol")
        :local origRate ($connectioned->"origRate")
        :local ipRegion [$getIpRegion $ip]
        :local arrayString "{\"ip\":\"$ip\",\"port\":\"$port\",\"protocol\":\"$protocol\",\"origRate\":\"$origRate\",\"ipRegion\":\"$ipRegion\"}"
        :set jsonString ($jsonString . "$arrayString,")
    }
    :set jsonString ([:pick $jsonString 0 ( [:len $jsonString] - 1 )] . "]")
    return $jsonString
}

# 通过防火墙L7流量识别读取规则识别数量来判断
:local checkFirwareCount do={
    :local count
    :do {
        set count {[/ip firewall filter get [/ip firewall filter find comment="ezviz"]]->"packets"}
        # 重置防火墙L7流量识别计数器
        /ip firewall filter reset-counters [/ip firewall filter find comment="ezviz"]
    } on-error={
        return 0
    }
    return $count
}

# 防火墙 L7 识别大于 0 则进行流量筛查，超过阈值的链接发送 mqtt
:local count [$checkFirwareCount]
if ($count > 0) do={
    # 查询符合流量阈值的链接
    :set connectionArray [$getConnections IpAddress=$ezvizIpAddress threshold=$trafficThreshold]
    # 获取符合链接数量
    :set connectionCount [:len $connectionArray]
    :put "connectionCount: $connectionCount"
    if (($"nvr::nvrRemoteLink" != $TRUE) && ($connectionCount > 0)) do={
        :put "on"
        # 将链接转为 json array 字符串
        :local connectionString [$convertConnectionsToJsonString $connectionArray]
        :put "{\"state\":\"ON\",\"connection\":$connectionString}"
        /iot mqtt publish broker=$mqttBroker topic=/ros/nvrRemoteLink message="{\"state\":\"ON\",\"connection\":$connectionString}"
        :set "nvr::nvrRemoteLink" $TRUE
    }
} else={
    if ($"nvr::nvrRemoteLink" != $FALSE) do={
        :put "off"
        /iot mqtt publish broker=$mqttBroker topic=/ros/nvrRemoteLink message="{\"state\":\"OFF\"}"
        :set "nvr::nvrRemoteLink" $FALSE
    }
}