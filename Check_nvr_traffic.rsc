# 请手动添加添加 firware L7 协议识别
## /ip firewall layer7-protocol add name=ezviz regexp="^.+(IMKH|EzNz).+"
## /ip firewall add action=accept chain=forward comment=ezviz layer7-protocol=ezviz log-prefix=ezviz src-address=<这里写你的NVRIP地址>

# 流量阈值 这里是 200Kbps
:local trafficThreshold 20240
# 监控的IP地址
:local ezvizIpAddress "10.89.2.1"
:local mqttBroker "hass"
:local TRUE 1
:local FALSE 0
:global "nvr::nvrRemoteLink";
:local connections
:local connectionCount

# 根据实时流量阈值筛选链接
# 调用方法：$getConnections IpAddress="10.89.2.1" threshold=10240
:local getConnections do={
    :local id
    :local connections ({})
    :local getIp do={
        return [:pick $1 0 [:find $1 ":"]]
    }
    :local getPort do={
        return [:pick $1 ([:find $1 ":"] + 1) [:len $1]]
    }
    :do {
        set id [/ip firewall connection find where (src-address ~ $IpAddress orig-rate>$threshold)]
        if ([:len $id] = 0) do={
            :put "No matching connection found."
            return $connections
        }
        :for i from=0 to=([:len $id] - 1) do={ 
            :local dstAddress [/ip firewall connection get value-name="dst-address" ($id->$i)]
            :local protocol [/ip firewall connection get value-name="protocol" ($id->$i)]
            set ($connections->$i) {"ip"=[$getIp $dstAddress];"port"=[$getPort $dstAddress];"protocol"=$protocol}
         }
    } on-error={
        return $connections
    }
    return $connections
}

# 将 connections 数组对象转换为 Json 的数组
:local convertConnectionsToJsonString do={
    :local connections $1
    :local jsonString "["
    :foreach connection in=$connections do={
        :local ip ($connection->"ip")
        :local port ($connection->"port")
        :local protocol ($connection->"protocol")
        :local arrayString "{\"ip\":\"$ip\",\"port\":\"$port\",\"protocol\":\"$protocol\"}"
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
    :set connections [$getConnections IpAddress=$ezvizIpAddress threshold=$trafficThreshold]
    # 获取符合链接数量
    :set connectionCount [:len $connections]
    if (($"nvr::nvrRemoteLink" != $TRUE) && ($connectionCount > 0)) do={
        :put "on"
        # 将链接转为 json array 字符串
        :local connectionString [$convertConnectionsToJsonString $connections]
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